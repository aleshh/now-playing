import Foundation

enum SharedConfiguration {
    static let defaultAppGroupIdentifier = "group.com.example.NowPlayingArtwork"
    static let defaultKeychainGroupSuffix = "com.example.NowPlayingArtwork.shared"
    static let widgetKind = "NowPlayingArtworkWidget"

    static var appGroupIdentifier: String {
        infoValue(named: "AppGroupIdentifier") ?? defaultAppGroupIdentifier
    }

    static var keychainGroupSuffix: String {
        infoValue(named: "SharedKeychainGroup") ?? defaultKeychainGroupSuffix
    }

    static var sonosRedirectURI: String {
        infoValue(named: "SonosRedirectURI") ?? "https://example.com/sonos/callback"
    }

    static var sonosEnabled: Bool {
        if let value = Bundle.main.object(forInfoDictionaryKey: "SonosEnabled") as? Bool {
            return value
        }
        return (Bundle.main.object(forInfoDictionaryKey: "SonosEnabled") as? String)?
            .localizedCaseInsensitiveCompare("YES") == .orderedSame
    }

    static let spotifyRedirectURI = "now-playing-artwork-login://spotify/callback"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    private static func infoValue(named key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty,
              !value.contains("$(")
        else {
            return nil
        }
        return value
    }
}

enum WidgetTapAppSettings {
    // Keep the original key so existing installations retain their saved URL.
    private static let urlKey = "fallbackAppURL"

    static var url: URL? {
        guard let value = SharedConfiguration.sharedDefaults.string(forKey: urlKey) else {
            return nil
        }
        return normalizedURL(from: value)
    }

    static func save(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            SharedConfiguration.sharedDefaults.removeObject(forKey: urlKey)
        } else {
            SharedConfiguration.sharedDefaults.set(trimmed, forKey: urlKey)
        }
    }

    static func normalizedURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              !["javascript", "data", "file"].contains(scheme)
        else {
            return nil
        }
        return url
    }
}

enum PendingWidgetTapURLStore {
    private static let urlKey = "pendingFallbackURL"
    private static let dateKey = "pendingFallbackDate"

    static func put(_ url: URL) {
        let defaults = SharedConfiguration.sharedDefaults
        defaults.set(url.absoluteString, forKey: urlKey)
        defaults.set(Date().timeIntervalSince1970, forKey: dateKey)
    }

    static func takeIfFresh(maximumAge: TimeInterval = 30) -> URL? {
        let defaults = SharedConfiguration.sharedDefaults
        guard let value = defaults.string(forKey: urlKey) else {
            return nil
        }

        let timestamp = defaults.double(forKey: dateKey)
        defaults.removeObject(forKey: urlKey)
        defaults.removeObject(forKey: dateKey)

        guard Date().timeIntervalSince1970 - timestamp <= maximumAge else {
            return nil
        }
        return WidgetTapAppSettings.normalizedURL(from: value)
    }
}
