import Foundation
import WidgetKit

enum PlaybackRefreshOutcome: Equatable, Sendable {
    case updated
    case updatedRecentGrid
    case noPlayback
    case failed(String)
}

enum PlaybackRefreshCoordinator {
    static func refresh() async -> PlaybackRefreshOutcome {
        async let spotifyProbe = SpotifyService().activeArtworkProbe()
        let sonosProbe: PlaybackProbe
        if SharedConfiguration.sonosEnabled {
            sonosProbe = await SonosService().activeArtworkProbe()
        } else {
            sonosProbe = .idle
        }
        let decision = await PlaybackSelector.decide(
            sonos: sonosProbe,
            spotify: spotifyProbe
        )

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
            do {
                let recentAlbums = try await SpotifyService().recentAlbumArtwork()
                guard !recentAlbums.isEmpty else {
                    return .noPlayback
                }
                try await ArtworkCache.downloadGridAndStore(from: recentAlbums)
                WidgetCenter.shared.reloadTimelines(ofKind: SharedConfiguration.widgetKind)
                return .updatedRecentGrid
            } catch {
                return .failed("Recent albums: \(error.localizedDescription)")
            }
        case .unavailable(let message):
            return .failed(message)
        }
    }
}
