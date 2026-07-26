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
