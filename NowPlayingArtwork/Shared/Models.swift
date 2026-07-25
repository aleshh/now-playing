import Foundation

struct OAuthToken: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresAt: Date

    var needsRefresh: Bool {
        expiresAt.timeIntervalSinceNow < 60
    }

    init(
        accessToken: String,
        refreshToken: String?,
        tokenType: String,
        expiresIn: TimeInterval
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresAt = Date().addingTimeInterval(max(0, expiresIn))
    }
}

struct OAuthTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String?
    let expiresIn: Double

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }

    func token(preservingRefreshToken existingRefreshToken: String? = nil) -> OAuthToken {
        OAuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken ?? existingRefreshToken,
            tokenType: tokenType ?? "Bearer",
            expiresIn: expiresIn
        )
    }
}

enum PlaybackProbe: Equatable, Sendable {
    case playing(URL)
    case playingWithoutArtwork(String)
    case idle
    case unavailable(String)
}

enum PlaybackDecision: Equatable, Sendable {
    case artwork(URL)
    case fallback
    case unavailable(String)
}

enum PlaybackSelector {
    static func decide(sonos: PlaybackProbe, spotify: PlaybackProbe) -> PlaybackDecision {
        if case .playing(let url) = sonos {
            return .artwork(url)
        }
        if case .playingWithoutArtwork(let message) = sonos {
            return .unavailable(message)
        }
        if case .playing(let url) = spotify {
            return .artwork(url)
        }
        if case .playingWithoutArtwork(let message) = spotify {
            return .unavailable(message)
        }

        let errors = [sonos, spotify].compactMap { probe -> String? in
            if case .unavailable(let message) = probe {
                return message
            }
            return nil
        }
        if !errors.isEmpty {
            return .unavailable(errors.joined(separator: "\n"))
        }
        return .fallback
    }
}
