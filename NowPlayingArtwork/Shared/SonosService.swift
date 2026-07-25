import Foundation

struct SonosService {
    private static let tokenURL = URL(string: "https://api.sonos.com/login/v3/oauth/access")!
    private static let controlBaseURL = URL(string: "https://api.ws.sonos.com/control/api/v1")!

    func exchangeAuthorizationCode(
        _ code: String,
        clientID: String,
        clientSecret: String
    ) async throws {
        let request = HTTPClient.formRequest(
            url: Self.tokenURL,
            values: [
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": SharedConfiguration.sonosRedirectURI
            ],
            authorization: basicAuthorization(clientID: clientID, clientSecret: clientSecret)
        )
        let data = try await HTTPClient.sendValidated(request)
        let response = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        try CredentialVault.saveToken(
            response.token(),
            account: CredentialAccount.sonosToken
        )
    }

    func activeArtworkProbe() async -> PlaybackProbe {
        guard let clientID = CredentialVault.string(CredentialAccount.sonosClientID),
              let clientSecret = CredentialVault.string(CredentialAccount.sonosClientSecret),
              CredentialVault.token(CredentialAccount.sonosToken) != nil
        else {
            return .idle
        }

        do {
            var token = try await validToken(clientID: clientID, clientSecret: clientSecret)
            do {
                return try await queryArtwork(accessToken: token.accessToken)
            } catch HTTPClientError.statusCode(let code, _) where code == 401 {
                token = try await refreshToken(
                    clientID: clientID,
                    clientSecret: clientSecret,
                    force: true
                )
                return try await queryArtwork(accessToken: token.accessToken)
            }
        } catch {
            return .unavailable("Sonos: \(error.localizedDescription)")
        }
    }

    private func queryArtwork(accessToken: String) async throws -> PlaybackProbe {
        let householdsURL = Self.controlBaseURL.appendingPathComponent("households")
        let householdData = try await HTTPClient.sendValidated(
            HTTPClient.bearerRequest(url: householdsURL, accessToken: accessToken)
        )
        let households = try JSONDecoder().decode(SonosHouseholds.self, from: householdData)
        var foundActiveGroup = false

        for household in households.households {
            let groupsURL = Self.controlBaseURL
                .appendingPathComponent("households")
                .appendingPathComponent(household.id)
                .appendingPathComponent("groups")
            let groupsData = try await HTTPClient.sendValidated(
                HTTPClient.bearerRequest(url: groupsURL, accessToken: accessToken)
            )
            let groups = try JSONDecoder().decode(SonosGroups.self, from: groupsData)

            for group in groups.groups where group.isActivelyPlaying {
                foundActiveGroup = true
                let metadataURL = Self.controlBaseURL
                    .appendingPathComponent("groups")
                    .appendingPathComponent(group.id)
                    .appendingPathComponent("playbackMetadata")
                let metadataData = try await HTTPClient.sendValidated(
                    HTTPClient.bearerRequest(url: metadataURL, accessToken: accessToken)
                )
                let metadata = try JSONDecoder().decode(SonosMetadata.self, from: metadataData)
                if let url = metadata.artworkURL {
                    return .playing(url)
                }
            }
        }
        if foundActiveGroup {
            return .playingWithoutArtwork("Sonos is playing, but it did not provide artwork.")
        }
        return .idle
    }

    private func validToken(
        clientID: String,
        clientSecret: String
    ) async throws -> OAuthToken {
        guard let token = CredentialVault.token(CredentialAccount.sonosToken) else {
            throw SonosServiceError.notAuthenticated
        }
        if token.needsRefresh {
            return try await refreshToken(
                clientID: clientID,
                clientSecret: clientSecret,
                force: false
            )
        }
        return token
    }

    private func refreshToken(
        clientID: String,
        clientSecret: String,
        force: Bool
    ) async throws -> OAuthToken {
        guard let currentToken = CredentialVault.token(CredentialAccount.sonosToken),
              let refreshToken = currentToken.refreshToken
        else {
            throw SonosServiceError.missingRefreshToken
        }
        if !force && !currentToken.needsRefresh {
            return currentToken
        }

        let request = HTTPClient.formRequest(
            url: Self.tokenURL,
            values: [
                "grant_type": "refresh_token",
                "refresh_token": refreshToken
            ],
            authorization: basicAuthorization(clientID: clientID, clientSecret: clientSecret)
        )
        let data = try await HTTPClient.sendValidated(request)
        let response = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        let token = response.token(preservingRefreshToken: refreshToken)
        try CredentialVault.saveToken(token, account: CredentialAccount.sonosToken)
        return token
    }

    private func basicAuthorization(clientID: String, clientSecret: String) -> String {
        let credentials = Data("\(clientID):\(clientSecret)".utf8).base64EncodedString()
        return "Basic \(credentials)"
    }
}

enum SonosServiceError: LocalizedError {
    case notAuthenticated
    case missingRefreshToken

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Sonos is not authenticated."
        case .missingRefreshToken:
            return "Sonos must be connected again."
        }
    }
}

private struct SonosHouseholds: Decodable {
    let households: [Household]

    struct Household: Decodable {
        let id: String
    }
}

private struct SonosGroups: Decodable {
    let groups: [Group]

    struct Group: Decodable {
        let id: String
        let playbackState: String

        var isActivelyPlaying: Bool {
            playbackState == "PLAYBACK_STATE_PLAYING"
                || playbackState == "PLAYBACK_STATE_BUFFERING"
        }
    }
}

private struct SonosMetadata: Decodable {
    let currentItem: Item?
    let container: Container?

    var artworkURL: URL? {
        let candidates = [
            currentItem?.track?.imageUrl,
            currentItem?.imageUrl,
            container?.imageUrl
        ]
        return candidates.compactMap { value in
            value.flatMap(URL.init(string:))
        }.first
    }

    struct Item: Decodable {
        let track: Track?
        let imageUrl: String?
    }

    struct Track: Decodable {
        let imageUrl: String?
    }

    struct Container: Decodable {
        let imageUrl: String?
    }
}
