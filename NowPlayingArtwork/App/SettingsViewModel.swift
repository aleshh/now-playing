import CryptoKit
import Foundation
import Security

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var spotifyClientID: String
    @Published var sonosClientID: String
    @Published var sonosClientSecret: String
    @Published var fallbackURLText: String

    @Published private(set) var isSpotifyConnected: Bool
    @Published private(set) var isSonosConnected: Bool
    @Published private(set) var isSpotifyBusy = false
    @Published private(set) var isSonosBusy = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var cachedArtworkData: Data?

    private let webSession = OAuthWebSession()

    init() {
        spotifyClientID = CredentialVault.string(CredentialAccount.spotifyClientID) ?? ""
        sonosClientID = CredentialVault.string(CredentialAccount.sonosClientID) ?? ""
        sonosClientSecret = CredentialVault.string(CredentialAccount.sonosClientSecret) ?? ""
        fallbackURLText = FallbackAppSettings.url?.absoluteString ?? ""
        isSpotifyConnected = CredentialVault.token(CredentialAccount.spotifyToken) != nil
        isSonosConnected = CredentialVault.token(CredentialAccount.sonosToken) != nil
        cachedArtworkData = ArtworkCache.cachedData()
    }

    func connectSpotify() async {
        let clientID = spotifyClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty else {
            statusMessage = "Enter a Spotify client ID first."
            return
        }

        isSpotifyBusy = true
        defer { isSpotifyBusy = false }

        do {
            try CredentialVault.saveString(clientID, account: CredentialAccount.spotifyClientID)
            let verifier = try Self.pkceVerifier()
            let state = UUID().uuidString
            let authorizationURL = try spotifyAuthorizationURL(
                clientID: clientID,
                state: state,
                challenge: Self.pkceChallenge(for: verifier)
            )

            let callbackURL = try await webSession.authenticate(
                at: authorizationURL,
                callbackScheme: "now-playing-artwork-login"
            )
            let callback = try Self.oauthCallback(from: callbackURL, expectedState: state)
            try await SpotifyService().exchangeAuthorizationCode(
                callback,
                clientID: clientID,
                verifier: verifier
            )
            isSpotifyConnected = true
            statusMessage = "Spotify connected."
        } catch {
            statusMessage = "Spotify sign-in failed: \(error.localizedDescription)"
        }
    }

    func beginSonosConnection() -> URL? {
        let clientID = sonosClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = sonosClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty, !clientSecret.isEmpty else {
            statusMessage = "Enter the Sonos client ID and secret first."
            return nil
        }
        guard let redirectURL = URL(string: SharedConfiguration.sonosRedirectURI),
              redirectURL.scheme?.lowercased() == "https"
        else {
            statusMessage = "Set a valid HTTPS SonosRedirectURI in the app target."
            return nil
        }

        do {
            try CredentialVault.saveString(clientID, account: CredentialAccount.sonosClientID)
            try CredentialVault.saveString(clientSecret, account: CredentialAccount.sonosClientSecret)
            let state = UUID().uuidString
            try CredentialVault.saveString(state, account: CredentialAccount.sonosOAuthState)

            var components = URLComponents(string: "https://api.sonos.com/login/v3/oauth")
            components?.queryItems = [
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "state", value: state),
                URLQueryItem(name: "scope", value: "playback-control-all"),
                URLQueryItem(name: "redirect_uri", value: redirectURL.absoluteString)
            ]
            guard let url = components?.url else {
                throw OAuthFlowError.invalidConfiguration("Could not create the Sonos sign-in URL.")
            }
            isSonosBusy = true
            statusMessage = "Finish Sonos sign-in in the browser."
            return url
        } catch {
            isSonosBusy = false
            statusMessage = "Sonos sign-in failed: \(error.localizedDescription)"
            return nil
        }
    }

    func handleIncomingURL(_ url: URL) async {
        guard Self.matchesSonosRedirect(url) else {
            return
        }

        isSonosBusy = true
        defer { isSonosBusy = false }

        do {
            guard let expectedState = CredentialVault.string(CredentialAccount.sonosOAuthState) else {
                throw OAuthFlowError.invalidState
            }
            let code = try Self.oauthCallback(from: url, expectedState: expectedState)
            guard let clientID = CredentialVault.string(CredentialAccount.sonosClientID),
                  let clientSecret = CredentialVault.string(CredentialAccount.sonosClientSecret)
            else {
                throw OAuthFlowError.invalidConfiguration("The Sonos credentials are missing.")
            }

            try await SonosService().exchangeAuthorizationCode(
                code,
                clientID: clientID,
                clientSecret: clientSecret
            )
            CredentialVault.remove(CredentialAccount.sonosOAuthState)
            isSonosConnected = true
            statusMessage = "Sonos connected."
        } catch {
            statusMessage = "Sonos sign-in failed: \(error.localizedDescription)"
        }
    }

    func saveFallbackURL() {
        if fallbackURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            FallbackAppSettings.save("")
            statusMessage = "Fallback app cleared."
        } else if FallbackAppSettings.normalizedURL(from: fallbackURLText) != nil {
            FallbackAppSettings.save(fallbackURLText)
            statusMessage = "Fallback app saved."
        } else {
            statusMessage = "Enter a valid app URL, such as spotify://."
        }
    }

    func disconnectSpotify() {
        CredentialVault.remove(CredentialAccount.spotifyToken)
        isSpotifyConnected = false
        statusMessage = "Spotify disconnected."
    }

    func disconnectSonos() {
        CredentialVault.remove(CredentialAccount.sonosToken)
        CredentialVault.remove(CredentialAccount.sonosOAuthState)
        isSonosConnected = false
        isSonosBusy = false
        statusMessage = "Sonos disconnected."
    }

    func refreshArtwork() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let outcome = await PlaybackRefreshCoordinator.refresh()
        switch outcome {
        case .updated:
            cachedArtworkData = ArtworkCache.cachedData()
            statusMessage = "Widget artwork updated."
        case .noPlayback:
            statusMessage = "Nothing is currently playing."
        case .failed(let message):
            statusMessage = message
        }
    }

    private func spotifyAuthorizationURL(
        clientID: String,
        state: String,
        challenge: String
    ) throws -> URL {
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: SharedConfiguration.spotifyRedirectURI),
            URLQueryItem(name: "scope", value: "user-read-currently-playing user-read-playback-state"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge)
        ]
        guard let url = components?.url else {
            throw OAuthFlowError.invalidConfiguration("Could not create the Spotify sign-in URL.")
        }
        return url
    }

    private static func oauthCallback(from url: URL, expectedState: String) throws -> String {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let values = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.value.map { (item.name, $0) }
        })
        if let error = values["error"] {
            throw OAuthFlowError.provider(error)
        }
        guard values["state"] == expectedState else {
            throw OAuthFlowError.invalidState
        }
        guard let code = values["code"], !code.isEmpty else {
            throw OAuthFlowError.missingCode
        }
        return code
    }

    private static func matchesSonosRedirect(_ url: URL) -> Bool {
        guard let expected = URL(string: SharedConfiguration.sonosRedirectURI) else {
            return false
        }
        return url.scheme?.lowercased() == expected.scheme?.lowercased()
            && url.host?.lowercased() == expected.host?.lowercased()
            && url.path == expected.path
    }

    private static func pkceVerifier() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw OAuthFlowError.invalidConfiguration("Could not create a secure sign-in challenge.")
        }
        return Data(bytes).base64URLEncodedString()
    }

    private static func pkceChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
