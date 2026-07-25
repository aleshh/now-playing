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
        let widgetTapURL = WidgetTapAppSettings.url
        _ = await PlaybackRefreshCoordinator.refresh()

        if let widgetTapURL {
            return .result(opensIntent: OpenURLIntent(widgetTapURL))
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
        let widgetTapURL = WidgetTapAppSettings.url
        _ = await PlaybackRefreshCoordinator.refresh()
        if let widgetTapURL {
            PendingWidgetTapURLStore.put(widgetTapURL)
        }
        return .result()
    }
}
