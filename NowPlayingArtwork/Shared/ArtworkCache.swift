import Foundation
import UIKit

enum ArtworkCacheError: LocalizedError {
    case appGroupUnavailable
    case invalidImage
    case imageTooLarge
    case invalidResponse

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
        }
    }
}

enum ArtworkCache {
    private static let filename = "active-album-artwork"
    private static let maximumArtworkSize = 20 * 1_024 * 1_024

    static func cachedData() -> Data? {
        guard let url = cacheURL else {
            return nil
        }
        return try? Data(contentsOf: url, options: .mappedIfSafe)
    }

    static func downloadAndStore(from url: URL) async throws {
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
        guard let cacheURL else {
            throw ArtworkCacheError.appGroupUnavailable
        }
        try data.write(
            to: cacheURL,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    private static var cacheURL: URL? {
        FileManager.default
            .containerURL(
                forSecurityApplicationGroupIdentifier: SharedConfiguration.appGroupIdentifier
            )?
            .appendingPathComponent(filename, isDirectory: false)
    }
}
