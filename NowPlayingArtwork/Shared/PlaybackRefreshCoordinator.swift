import Foundation
import WidgetKit

enum PlaybackRefreshOutcome: Equatable, Sendable {
    case updated
    case noPlayback(URL?)
    case failed(String)
}

enum PlaybackRefreshCoordinator {
    static func refresh() async -> PlaybackRefreshOutcome {
        async let sonos = SonosService().activeArtworkProbe()
        async let spotify = SpotifyService().activeArtworkProbe()
        let decision = await PlaybackSelector.decide(sonos: sonos, spotify: spotify)

        switch decision {
        case .artwork(let url):
            do {
                try await ArtworkCache.downloadAndStore(from: url)
                WidgetCenter.shared.reloadTimelines(ofKind: SharedConfiguration.widgetKind)
                return .updated
            } catch {
                return .failed("Artwork: \(error.localizedDescription)")
            }
        case .fallback:
            return .noPlayback(FallbackAppSettings.url)
        case .unavailable(let message):
            return .failed(message)
        }
    }
}
