import Foundation

enum SpotifyAuthorization {
    static let currentGrantVersion = "recent-albums-v1"
    static let scopes = [
        "user-read-currently-playing",
        "user-read-playback-state",
        "user-read-recently-played"
    ]

    static var hasCurrentGrant: Bool {
        CredentialVault.string(CredentialAccount.spotifyGrantVersion) == currentGrantVersion
    }
}

struct RecentAlbumArtwork: Equatable, Sendable {
    let albumID: String
    let albumName: String
    let artworkURL: URL
    let spotifyURL: URL
}

enum RecentAlbumArtworkSelector {
    static func includes(releaseType: String) -> Bool {
        releaseType == "album"
    }

    static func uniqueAlbums(
        from candidates: [RecentAlbumArtwork],
        limit: Int
    ) -> [RecentAlbumArtwork] {
        guard limit > 0 else {
            return []
        }

        var seenAlbumIDs = Set<String>()
        var result: [RecentAlbumArtwork] = []

        for candidate in candidates where seenAlbumIDs.insert(candidate.albumID).inserted {
            result.append(candidate)
            if result.count == limit {
                break
            }
        }
        return result
    }
}

struct SpotifyService {
    private static let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
    private static let currentlyPlayingURL = URL(
        string: "https://api.spotify.com/v1/me/player/currently-playing?additional_types=track,episode"
    )!
    private static let recentlyPlayedURL = URL(
        string: "https://api.spotify.com/v1/me/player/recently-played?limit=50"
    )!

    func exchangeAuthorizationCode(
        _ code: String,
        clientID: String,
        verifier: String
    ) async throws {
        let request = HTTPClient.formRequest(
            url: Self.tokenURL,
            values: [
                "client_id": clientID,
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": SharedConfiguration.spotifyRedirectURI,
                "code_verifier": verifier
            ]
        )
        let data = try await HTTPClient.sendValidated(request)
        let response = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        try CredentialVault.saveToken(
            response.token(),
            account: CredentialAccount.spotifyToken
        )
    }

    func activeArtworkProbe() async -> PlaybackProbe {
        guard let clientID = CredentialVault.string(CredentialAccount.spotifyClientID),
              CredentialVault.token(CredentialAccount.spotifyToken) != nil
        else {
            return .idle
        }
        guard SpotifyAuthorization.hasCurrentGrant else {
            return .unavailable(
                "Reconnect Spotify in the app to enable the recent-albums grid."
            )
        }

        do {
            let response = try await authorizedGET(
                url: Self.currentlyPlayingURL,
                clientID: clientID
            )

            if response.1.statusCode == 204 {
                return .idle
            }
            guard (200..<300).contains(response.1.statusCode) else {
                let message = String(data: response.0.prefix(1_024), encoding: .utf8) ?? ""
                throw HTTPClientError.statusCode(response.1.statusCode, message)
            }

            let playing = try JSONDecoder().decode(SpotifyCurrentlyPlaying.self, from: response.0)
            guard playing.isPlaying else {
                return .idle
            }

            if let image = playing.item?.album?.images.max(by: {
                ($0.width ?? 0) < ($1.width ?? 0)
            }), let url = URL(string: image.url) {
                return .playing(url)
            }

            if let urlString = playing.item?.images?.first?.url,
               let url = URL(string: urlString) {
                return .playing(url)
            }
            return .playingWithoutArtwork("Spotify is playing, but it did not provide artwork.")
        } catch {
            return .unavailable("Spotify: \(error.localizedDescription)")
        }
    }

    func recentAlbumArtwork(limit: Int = 9) async throws -> [RecentAlbumArtwork] {
        guard let clientID = CredentialVault.string(CredentialAccount.spotifyClientID),
              CredentialVault.token(CredentialAccount.spotifyToken) != nil
        else {
            return []
        }
        guard SpotifyAuthorization.hasCurrentGrant else {
            throw SpotifyServiceError.scopeUpgradeRequired
        }

        let response = try await authorizedGET(
            url: Self.recentlyPlayedURL,
            clientID: clientID
        )
        if response.1.statusCode == 403 {
            throw SpotifyServiceError.recentHistoryDenied
        }
        guard (200..<300).contains(response.1.statusCode) else {
            let message = String(data: response.0.prefix(1_024), encoding: .utf8) ?? ""
            throw HTTPClientError.statusCode(response.1.statusCode, message)
        }

        let history = try JSONDecoder().decode(SpotifyRecentlyPlayed.self, from: response.0)
        let candidates = history.items.compactMap { item -> RecentAlbumArtwork? in
            guard RecentAlbumArtworkSelector.includes(
                releaseType: item.track.album.albumType
            ),
            let image = item.track.album.images.max(by: {
                ($0.width ?? 0) < ($1.width ?? 0)
            }),
            let artworkURL = URL(string: image.url),
            let spotifyURL = URL(
                string: "https://open.spotify.com/album/\(item.track.album.id)"
            ) else {
                return nil
            }
            return RecentAlbumArtwork(
                albumID: item.track.album.id,
                albumName: item.track.album.name,
                artworkURL: artworkURL,
                spotifyURL: spotifyURL
            )
        }
        return RecentAlbumArtworkSelector.uniqueAlbums(from: candidates, limit: limit)
    }

    private func authorizedGET(
        url: URL,
        clientID: String
    ) async throws -> (Data, HTTPURLResponse) {
        var token = try await validToken(clientID: clientID)
        var request = HTTPClient.bearerRequest(url: url, accessToken: token.accessToken)
        var response = try await HTTPClient.send(request)
        if response.1.statusCode == 401 {
            token = try await refreshToken(clientID: clientID, force: true)
            request = HTTPClient.bearerRequest(url: url, accessToken: token.accessToken)
            response = try await HTTPClient.send(request)
        }
        return response
    }

    private func validToken(clientID: String) async throws -> OAuthToken {
        guard let token = CredentialVault.token(CredentialAccount.spotifyToken) else {
            throw SpotifyServiceError.notAuthenticated
        }
        if token.needsRefresh {
            return try await refreshToken(clientID: clientID, force: false)
        }
        return token
    }

    private func refreshToken(clientID: String, force: Bool) async throws -> OAuthToken {
        guard let currentToken = CredentialVault.token(CredentialAccount.spotifyToken),
              let refreshToken = currentToken.refreshToken
        else {
            throw SpotifyServiceError.missingRefreshToken
        }
        if !force && !currentToken.needsRefresh {
            return currentToken
        }

        let request = HTTPClient.formRequest(
            url: Self.tokenURL,
            values: [
                "client_id": clientID,
                "grant_type": "refresh_token",
                "refresh_token": refreshToken
            ]
        )
        let data = try await HTTPClient.sendValidated(request)
        let response = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        let token = response.token(preservingRefreshToken: refreshToken)
        try CredentialVault.saveToken(token, account: CredentialAccount.spotifyToken)
        return token
    }
}

enum SpotifyServiceError: LocalizedError {
    case notAuthenticated
    case missingRefreshToken
    case scopeUpgradeRequired
    case recentHistoryDenied

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Spotify is not authenticated."
        case .missingRefreshToken:
            return "Spotify must be connected again."
        case .scopeUpgradeRequired:
            return "Reconnect Spotify in the app to grant recent-playback access."
        case .recentHistoryDenied:
            return "Spotify denied recent-playback access. Reconnect Spotify and confirm this account is allowlisted."
        }
    }
}

private struct SpotifyImage: Decodable {
    let url: String
    let width: Int?
}

private struct SpotifyCurrentlyPlaying: Decodable {
    let isPlaying: Bool
    let item: Item?

    enum CodingKeys: String, CodingKey {
        case isPlaying = "is_playing"
        case item
    }

    struct Item: Decodable {
        let album: Album?
        let images: [SpotifyImage]?
    }

    struct Album: Decodable {
        let images: [SpotifyImage]
    }
}

private struct SpotifyRecentlyPlayed: Decodable {
    let items: [Item]

    struct Item: Decodable {
        let track: Track
    }

    struct Track: Decodable {
        let album: Album
    }

    struct Album: Decodable {
        let id: String
        let name: String
        let albumType: String
        let images: [SpotifyImage]

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case albumType = "album_type"
            case images
        }
    }
}
