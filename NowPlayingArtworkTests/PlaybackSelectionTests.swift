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
        let candidates = [
            RecentAlbumArtwork(albumID: "first", url: firstURL),
            RecentAlbumArtwork(albumID: "first", url: duplicateURL),
            RecentAlbumArtwork(albumID: "second", url: secondURL)
        ]

        XCTAssertEqual(
            RecentAlbumArtworkSelector.uniqueURLs(from: candidates, limit: 9),
            [firstURL, secondURL]
        )
    }

    func testRecentAlbumSelectionHonorsGridLimit() {
        let candidates = (0..<12).map { index in
            RecentAlbumArtwork(
                albumID: "album-\(index)",
                url: URL(string: "https://example.com/\(index).jpg")!
            )
        }

        XCTAssertEqual(
            RecentAlbumArtworkSelector.uniqueURLs(from: candidates, limit: 9).count,
            9
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
}
