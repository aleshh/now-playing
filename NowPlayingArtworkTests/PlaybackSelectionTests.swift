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
}
