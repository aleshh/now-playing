import Foundation
import UIKit

enum ArtworkCacheError: LocalizedError {
    case appGroupUnavailable
    case invalidImage
    case imageTooLarge
    case invalidResponse
    case noGridImages

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "The App Group container is unavailable."
        case .invalidImage:
            return "The downloaded artwork was not a valid image."
        case .imageTooLarge:
            return "The downloaded artwork exceeded the 20 MB cache limit."
        case .invalidResponse:
            return "The artwork server returned an invalid response."
        case .noGridImages:
            return "None of the recent album artwork could be downloaded."
        }
    }
}

enum ArtworkCacheVariant: CaseIterable {
    case small
    case large
}

enum RecentArtworkLayout: Equatable {
    case single
    case grid(columns: Int, maximumItems: Int)
}

enum RecentArtworkLayoutSelector {
    static func layout(
        for albumCount: Int,
        variant: ArtworkCacheVariant
    ) -> RecentArtworkLayout? {
        guard albumCount > 0 else {
            return nil
        }
        if albumCount == 1 {
            return .single
        }

        switch variant {
        case .small:
            return .grid(columns: 2, maximumItems: 4)
        case .large:
            if albumCount < 5 {
                return .grid(columns: 2, maximumItems: 4)
            }
            return .grid(columns: 3, maximumItems: 9)
        }
    }
}

enum ArtworkCache {
    private static let legacyFilename = "active-album-artwork"
    private static let smallFilename = "widget-artwork-small"
    private static let largeFilename = "widget-artwork-large"
    private static let maximumArtworkSize = 20 * 1_024 * 1_024
    private static let gridDimension = 900
    private static let gridCount = 9

    static func cachedData() -> Data? {
        cachedData(for: .large)
    }

    static func cachedData(for variant: ArtworkCacheVariant) -> Data? {
        readData(from: cacheURL(for: variant))
            ?? readData(from: cacheURL(filename: legacyFilename))
    }

    static func downloadAndStore(from url: URL) async throws {
        let data = try await downloadValidatedImageData(from: url)
        for variant in ArtworkCacheVariant.allCases {
            try store(data, for: variant)
        }
        try store(data, filename: legacyFilename)
    }

    static func downloadGridAndStore(from urls: [URL]) async throws {
        let selectedURLs = Array(urls.prefix(gridCount))
        var downloadedData = [Data?](repeating: nil, count: selectedURLs.count)

        await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, url) in selectedURLs.enumerated() {
                group.addTask {
                    (
                        index,
                        try? await downloadValidatedImageData(from: url)
                    )
                }
            }

            for await (index, data) in group {
                downloadedData[index] = data
            }
        }

        let artwork = downloadedData.compactMap { data -> (data: Data, image: UIImage)? in
            guard let data, let image = UIImage(data: data) else {
                return nil
            }
            return (data, image)
        }
        guard !artwork.isEmpty else {
            throw ArtworkCacheError.noGridImages
        }

        let smallData = try presentationData(from: artwork, variant: .small)
        let largeData = try presentationData(from: artwork, variant: .large)
        try store(smallData, for: .small)
        try store(largeData, for: .large)
        try store(largeData, filename: legacyFilename)
    }

    private static func presentationData(
        from artwork: [(data: Data, image: UIImage)],
        variant: ArtworkCacheVariant
    ) throws -> Data {
        guard let layout = RecentArtworkLayoutSelector.layout(
            for: artwork.count,
            variant: variant
        ) else {
            throw ArtworkCacheError.noGridImages
        }

        switch layout {
        case .single:
            return artwork[0].data
        case .grid(let columns, let maximumItems):
            return try gridData(
                from: artwork.prefix(maximumItems).map { $0.image },
                columns: columns
            )
        }
    }

    private static func gridData(
        from images: [UIImage],
        columns: Int
    ) throws -> Data {
        let dimension = CGFloat(gridDimension)
        let cellDimension = dimension / CGFloat(columns)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: dimension, height: dimension),
            format: format
        )
        let gridImage = renderer.image { context in
            UIColor.black.setFill()
            context.fill(
                CGRect(x: 0, y: 0, width: dimension, height: dimension)
            )

            for (index, image) in images.enumerated() {
                let row = index / columns
                let column = index % columns
                let cell = CGRect(
                    x: CGFloat(column) * cellDimension,
                    y: CGFloat(row) * cellDimension,
                    width: cellDimension,
                    height: cellDimension
                )
                drawAspectFill(image, in: cell, context: context.cgContext)
            }
        }

        guard let data = gridImage.jpegData(compressionQuality: 0.9) else {
            throw ArtworkCacheError.invalidImage
        }
        return data
    }

    private static func downloadValidatedImageData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode)
        else {
            throw ArtworkCacheError.invalidResponse
        }
        guard data.count <= maximumArtworkSize else {
            throw ArtworkCacheError.imageTooLarge
        }
        guard UIImage(data: data) != nil else {
            throw ArtworkCacheError.invalidImage
        }
        return data
    }

    private static func store(
        _ data: Data,
        for variant: ArtworkCacheVariant
    ) throws {
        try store(data, filename: filename(for: variant))
    }

    private static func store(
        _ data: Data,
        filename: String
    ) throws {
        guard let cacheURL = cacheURL(filename: filename) else {
            throw ArtworkCacheError.appGroupUnavailable
        }
        try data.write(
            to: cacheURL,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    private static func drawAspectFill(
        _ image: UIImage,
        in cell: CGRect,
        context: CGContext
    ) {
        let widthScale = cell.width / image.size.width
        let heightScale = cell.height / image.size.height
        let scale = max(widthScale, heightScale)
        let size = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let destination = CGRect(
            x: cell.midX - size.width / 2,
            y: cell.midY - size.height / 2,
            width: size.width,
            height: size.height
        )

        context.saveGState()
        context.clip(to: cell)
        image.draw(in: destination)
        context.restoreGState()
    }

    private static func readData(from url: URL?) -> Data? {
        guard let url else {
            return nil
        }
        return try? Data(contentsOf: url, options: .mappedIfSafe)
    }

    private static func filename(for variant: ArtworkCacheVariant) -> String {
        switch variant {
        case .small:
            return smallFilename
        case .large:
            return largeFilename
        }
    }

    private static func cacheURL(for variant: ArtworkCacheVariant) -> URL? {
        cacheURL(filename: filename(for: variant))
    }

    private static func cacheURL(filename: String) -> URL? {
        FileManager.default
            .containerURL(
                forSecurityApplicationGroupIdentifier: SharedConfiguration.appGroupIdentifier
            )?
            .appendingPathComponent(filename, isDirectory: false)
    }
}
