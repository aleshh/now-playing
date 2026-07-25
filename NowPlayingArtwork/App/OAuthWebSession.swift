import AuthenticationServices
import UIKit

@MainActor
final class OAuthWebSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func authenticate(at url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.session = nil
                if let error {
                    continuation.resume(throwing: error)
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: OAuthFlowError.missingCallback)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session

            guard session.start() else {
                self.session = nil
                continuation.resume(throwing: OAuthFlowError.couldNotStart)
                return
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return window
        }
        return ASPresentationAnchor()
    }
}

enum OAuthFlowError: LocalizedError {
    case couldNotStart
    case missingCallback
    case missingCode
    case invalidState
    case invalidConfiguration(String)
    case provider(String)

    var errorDescription: String? {
        switch self {
        case .couldNotStart:
            return "The sign-in session could not start."
        case .missingCallback:
            return "The sign-in provider did not return a callback URL."
        case .missingCode:
            return "The sign-in provider did not return an authorization code."
        case .invalidState:
            return "The sign-in callback could not be verified. Please try again."
        case .invalidConfiguration(let message):
            return message
        case .provider(let message):
            return message
        }
    }
}
