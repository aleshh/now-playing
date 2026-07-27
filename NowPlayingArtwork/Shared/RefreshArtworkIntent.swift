import AppIntents
import Foundation

@available(iOS 18.2, *)
struct RefreshArtworkIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Now Playing Artwork"
    static let description = IntentDescription(
        "Checks Sonos and Spotify, then updates the widget with the active album artwork."
    )
    static let openAppWhenRun = false

    @Parameter(title: "Spotify Album URL")
    var albumURLString: String?

    init() {
        albumURLString = nil
    }

    init(albumURLString: String) {
        self.albumURLString = albumURLString
    }

    func perform() async throws -> some IntentResult {
        let outcome = await PlaybackRefreshCoordinator.refresh()
        let destinationURL = WidgetTapDestination.openIntentURL(
            albumURLString: albumURLString,
            after: outcome
        )

        if let destinationURL {
            return .result(opensIntent: OpenURLIntent(destinationURL))
        }
        return .result()
    }
}

struct LegacyRefreshArtworkIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Now Playing Artwork"
    static let description = IntentDescription(
        "Checks Sonos and Spotify, then updates the widget with the active album artwork."
    )
    static let openAppWhenRun = true

    @Parameter(title: "Spotify Album URL")
    var albumURLString: String?

    init() {
        albumURLString = nil
    }

    init(albumURLString: String) {
        self.albumURLString = albumURLString
    }

    func perform() async throws -> some IntentResult {
        let outcome = await PlaybackRefreshCoordinator.refresh()
        let destinationURL = WidgetTapDestination.legacyURL(
            albumURLString: albumURLString,
            after: outcome
        )
        if let destinationURL {
            PendingWidgetTapURLStore.put(destinationURL)
        }
        return .result()
    }
}

private enum WidgetTapDestination {
    private static let spotifyHomeURL = URL(string: "https://open.spotify.com/")!

    static func openIntentURL(
        albumURLString: String?,
        after outcome: PlaybackRefreshOutcome
    ) -> URL? {
        if let albumURL = spotifyAlbumURL(from: albumURLString) {
            return outcome.confirmsNoActivePlayback ? albumURL : nil
        }
        guard let configuredURL = WidgetTapAppSettings.url else {
            return nil
        }
        if configuredURL.scheme?.lowercased() == "spotify" {
            return spotifyHomeURL
        }
        guard ["http", "https"].contains(configuredURL.scheme?.lowercased() ?? "") else {
            return nil
        }
        return configuredURL
    }

    static func legacyURL(
        albumURLString: String?,
        after outcome: PlaybackRefreshOutcome
    ) -> URL? {
        if let albumURL = spotifyAlbumURL(from: albumURLString) {
            return outcome.confirmsNoActivePlayback ? albumURL : nil
        }
        return WidgetTapAppSettings.url
    }

    private static func spotifyAlbumURL(from value: String?) -> URL? {
        guard let value,
              let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "open.spotify.com",
              url.path.hasPrefix("/album/")
        else {
            return nil
        }
        return url
    }
}
