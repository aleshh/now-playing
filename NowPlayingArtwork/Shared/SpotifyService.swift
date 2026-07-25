import Foundation

struct SpotifyService {
    private static let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
    private static let currentlyPlayingURL = URL(
        string: "https://api.spotify.com/v1/me/player/currently-playing?additional_types=track,episode"
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

        do {
            var token = try await validToken(clientID: clientID)
            var response = try await currentlyPlaying(accessToken: token.accessToken)
            if response.1.statusCode == 401 {
                token = try await refreshToken(clientID: clientID, force: true)
                response = try await currentlyPlaying(accessToken: token.accessToken)
            }

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

    private func currentlyPlaying(
        accessToken: String
    ) async throws -> (Data, HTTPURLResponse) {
        let request = HTTPClient.bearerRequest(
            url: Self.currentlyPlayingURL,
            accessToken: accessToken
        )
        return try await HTTPClient.send(request)
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

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Spotify is not authenticated."
        case .missingRefreshToken:
            return "Spotify must be connected again."
        }
    }
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
        let images: [Image]?
    }

    struct Album: Decodable {
        let images: [Image]
    }

    struct Image: Decodable {
        let url: String
        let width: Int?
    }
}
