import AppIntents
import Foundation

@available(iOS 18.2, *)
struct RefreshArtworkIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Now Playing Artwork"
    static let description = IntentDescription(
        "Checks Sonos and Spotify, then updates the widget with the active album artwork."
    )
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        let outcome = await PlaybackRefreshCoordinator.refresh()

        if case .noPlayback(let fallbackURL) = outcome, let fallbackURL {
            return .result(opensIntent: OpenURLIntent(fallbackURL))
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

    func perform() async throws -> some IntentResult {
        let outcome = await PlaybackRefreshCoordinator.refresh()
        if case .noPlayback(let fallbackURL) = outcome, let fallbackURL {
            PendingFallbackStore.put(fallbackURL)
        }
        return .result()
    }
}
