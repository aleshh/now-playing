import Foundation
import WidgetKit

enum PlaybackRefreshOutcome: Equatable, Sendable {
    case updated
    case updatedRecentGrid
    case noPlayback
    case failed(String)

    var confirmsNoActivePlayback: Bool {
        switch self {
        case .updatedRecentGrid, .noPlayback:
            return true
        case .updated, .failed:
            return false
        }
    }
}

enum PlaybackRefreshSchedule {
    static let timelineInterval: TimeInterval = 30 * 60
    static let minimumAutomaticInterval: TimeInterval = 5 * 60

    private static let lastAttemptKey = "lastPlaybackRefreshAttempt"

    static func reserveAutomaticRefresh(at date: Date = Date()) -> Bool {
        guard automaticRefreshIsDue(
            lastAttempt: lastAttemptDate,
            at: date
        ) else {
            return false
        }
        recordAttempt(at: date)
        return true
    }

    static func automaticRefreshIsDue(
        lastAttempt: Date?,
        at date: Date
    ) -> Bool {
        guard let lastAttempt else {
            return true
        }
        return date.timeIntervalSince(lastAttempt) >= minimumAutomaticInterval
    }

    static func recordAttempt(at date: Date = Date()) {
        SharedConfiguration.sharedDefaults.set(
            date.timeIntervalSince1970,
            forKey: lastAttemptKey
        )
    }

    private static var lastAttemptDate: Date? {
        let timestamp = SharedConfiguration.sharedDefaults.double(
            forKey: lastAttemptKey
        )
        guard timestamp > 0 else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }
}

enum PlaybackRefreshCoordinator {
    static func refresh(
        reloadWidgetTimelines: Bool = true
    ) async -> PlaybackRefreshOutcome {
        PlaybackRefreshSchedule.recordAttempt()

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
                if reloadWidgetTimelines {
                    WidgetCenter.shared.reloadTimelines(
                        ofKind: SharedConfiguration.widgetKind
                    )
                }
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
                if reloadWidgetTimelines {
                    WidgetCenter.shared.reloadTimelines(
                        ofKind: SharedConfiguration.widgetKind
                    )
                }
                return .updatedRecentGrid
            } catch {
                return .failed("Recent albums: \(error.localizedDescription)")
            }
        case .unavailable(let message):
            return .failed(message)
        }
    }
}
