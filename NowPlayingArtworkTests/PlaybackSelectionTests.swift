import XCTest
@testable import NowPlayingArtwork

final class PlaybackSelectionTests: XCTestCase {
    private let spotifyURL = URL(string: "https://example.com/spotify.jpg")!
    private let sonosURL = URL(string: "https://example.com/sonos.jpg")!

    func testSonosWinsWhenBothArePlaying() {
        let decision = PlaybackSelector.decide(
            sonos: .playing(sonosURL),
            spotify: .playing(spotifyURL)
        )
        XCTAssertEqual(decision, .artwork(sonosURL))
    }

    func testSpotifyIsUsedWhenSonosIsIdle() {
        let decision = PlaybackSelector.decide(
            sonos: .idle,
            spotify: .playing(spotifyURL)
        )
        XCTAssertEqual(decision, .artwork(spotifyURL))
    }

    func testFallbackIsUsedOnlyWhenBothAreIdle() {
        XCTAssertEqual(
            PlaybackSelector.decide(sonos: .idle, spotify: .idle),
            .fallback
        )
    }

    func testServiceFailureDoesNotLaunchFallback() {
        let decision = PlaybackSelector.decide(
            sonos: .unavailable("offline"),
            spotify: .idle
        )
        XCTAssertEqual(decision, .unavailable("offline"))
    }

    func testSonosPlaybackWithoutArtworkStillTakesPriority() {
        let decision = PlaybackSelector.decide(
            sonos: .playingWithoutArtwork("missing Sonos artwork"),
            spotify: .playing(spotifyURL)
        )
        XCTAssertEqual(decision, .unavailable("missing Sonos artwork"))
    }

    func testRecentAlbumsAreUniqueAndRemainMostRecentFirst() {
        let firstURL = URL(string: "https://example.com/first.jpg")!
        let duplicateURL = URL(string: "https://example.com/first-again.jpg")!
        let secondURL = URL(string: "https://example.com/second.jpg")!
        let first = recentAlbum(id: "first", artworkURL: firstURL)
        let duplicate = recentAlbum(id: "first", artworkURL: duplicateURL)
        let second = recentAlbum(id: "second", artworkURL: secondURL)
        let candidates = [
            first,
            duplicate,
            second
        ]

        XCTAssertEqual(
            RecentAlbumArtworkSelector.uniqueAlbums(from: candidates, limit: 9),
            [first, second]
        )
    }

    func testRecentAlbumSelectionHonorsGridLimit() {
        let candidates = (0..<12).map { index in
            recentAlbum(
                id: "album-\(index)",
                artworkURL: URL(string: "https://example.com/\(index).jpg")!
            )
        }

        XCTAssertEqual(
            RecentAlbumArtworkSelector.uniqueAlbums(from: candidates, limit: 9).count,
            9
        )
    }

    func testRememberedAlbumsFillAShortSpotifyResult() {
        let recent = [
            recentAlbum(id: "album-0", artworkURL: spotifyURL),
            recentAlbum(id: "album-1", artworkURL: sonosURL)
        ]
        let remembered = (0..<9).map { index in
            recentAlbum(
                id: "album-\(index)",
                artworkURL: URL(
                    string: "https://example.com/remembered-\(index).jpg"
                )!
            )
        }

        let merged = RecentAlbumArtworkSelector.mergedAlbums(
            recent: recent,
            remembered: remembered,
            limit: 9
        )

        XCTAssertEqual(merged.count, 9)
        XCTAssertEqual(merged.prefix(2), recent.prefix(2))
        XCTAssertEqual(
            merged.map(\.albumID),
            (0..<9).map { "album-\($0)" }
        )
    }

    func testReplayedAlbumMovesToFrontWithCurrentMetadata() {
        let replayed = recentAlbum(
            id: "album-2",
            artworkURL: URL(string: "https://example.com/new-art.jpg")!
        )
        let remembered = (0..<4).map { index in
            recentAlbum(
                id: "album-\(index)",
                artworkURL: URL(
                    string: "https://example.com/old-art-\(index).jpg"
                )!
            )
        }

        let merged = RecentAlbumArtworkSelector.mergedAlbums(
            recent: [replayed],
            remembered: remembered,
            limit: 9
        )

        XCTAssertEqual(merged.first, replayed)
        XCTAssertEqual(
            merged.map(\.albumID),
            ["album-2", "album-0", "album-1", "album-3"]
        )
    }

    func testRecentGridIncludesOnlySpotifyAlbumReleases() {
        XCTAssertTrue(
            RecentAlbumArtworkSelector.includes(releaseType: "album")
        )
        XCTAssertFalse(
            RecentAlbumArtworkSelector.includes(releaseType: "single")
        )
        XCTAssertFalse(
            RecentAlbumArtworkSelector.includes(releaseType: "compilation")
        )
    }

    func testOneRecentAlbumUsesTheFullWidgetInBothSizes() {
        XCTAssertEqual(
            RecentArtworkLayoutSelector.layout(for: 1, variant: .small),
            .single
        )
        XCTAssertEqual(
            RecentArtworkLayoutSelector.layout(for: 1, variant: .large),
            .single
        )
    }

    func testFewerThanFiveAlbumsUseTwoByTwoInBothSizes() {
        for count in 2...4 {
            XCTAssertEqual(
                RecentArtworkLayoutSelector.layout(for: count, variant: .small),
                .grid(columns: 2, maximumItems: 4)
            )
            XCTAssertEqual(
                RecentArtworkLayoutSelector.layout(for: count, variant: .large),
                .grid(columns: 2, maximumItems: 4)
            )
        }
    }

    func testFiveOrMoreAlbumsUseThreeByThreeOnlyInLargeWidget() {
        for count in 5...9 {
            XCTAssertEqual(
                RecentArtworkLayoutSelector.layout(for: count, variant: .small),
                .grid(columns: 2, maximumItems: 4)
            )
            XCTAssertEqual(
                RecentArtworkLayoutSelector.layout(for: count, variant: .large),
                .grid(columns: 3, maximumItems: 9)
            )
        }
    }

    func testAlbumTapOpensOnlyAfterRefreshConfirmsIdlePlayback() {
        XCTAssertTrue(
            PlaybackRefreshOutcome.updatedRecentGrid.confirmsNoActivePlayback
        )
        XCTAssertTrue(
            PlaybackRefreshOutcome.noPlayback.confirmsNoActivePlayback
        )
        XCTAssertFalse(
            PlaybackRefreshOutcome.updated.confirmsNoActivePlayback
        )
        XCTAssertFalse(
            PlaybackRefreshOutcome.failed("offline").confirmsNoActivePlayback
        )
    }

    func testAutomaticRefreshScheduleHonorsMinimumInterval() {
        let now = Date(timeIntervalSince1970: 10_000)

        XCTAssertTrue(
            PlaybackRefreshSchedule.automaticRefreshIsDue(
                lastAttempt: nil,
                at: now
            )
        )
        XCTAssertFalse(
            PlaybackRefreshSchedule.automaticRefreshIsDue(
                lastAttempt: now.addingTimeInterval(
                    -PlaybackRefreshSchedule.minimumAutomaticInterval + 1
                ),
                at: now
            )
        )
        XCTAssertTrue(
            PlaybackRefreshSchedule.automaticRefreshIsDue(
                lastAttempt: now.addingTimeInterval(
                    -PlaybackRefreshSchedule.minimumAutomaticInterval
                ),
                at: now
            )
        )
    }

    private func recentAlbum(
        id: String,
        artworkURL: URL
    ) -> RecentAlbumArtwork {
        RecentAlbumArtwork(
            albumID: id,
            albumName: "Album \(id)",
            artworkURL: artworkURL,
            spotifyURL: URL(string: "https://open.spotify.com/album/\(id)")!
        )
    }
}
