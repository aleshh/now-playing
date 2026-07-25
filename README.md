# Now Playing Artwork

An iOS 17+ SwiftUI app with a system-small WidgetKit extension. Tapping the edge-to-edge widget checks Sonos and Spotify in parallel, prefers Sonos, caches validated artwork in an App Group, and reloads the widget. With no cached image, the widget shows a neutral music-note placeholder.

OAuth tokens, client IDs, and the Sonos client secret use a shared Keychain access group. Artwork and the fallback URL use the shared App Group container.

> The current project configuration is Spotify-only (`SONOS_ENABLED = NO`). Deferred Sonos setup is tracked in `TODO.md`.

## Required project setup

Open `NowPlayingArtwork.xcodeproj` and update these project-level build settings for both Debug and Release:

- `APP_GROUP_IDENTIFIER`: an App Group registered for both targets.
- `SHARED_KEYCHAIN_GROUP`: a Keychain group suffix registered for both targets.
- `OAUTH_CALLBACK_DOMAIN`: an HTTPS domain you control.
- Change both `com.example...` product bundle identifiers and select your Development Team.

Keep the widget bundle identifier prefixed by the app bundle identifier. Xcode expands these settings into both targets' Info plists and entitlements.

## Spotify

1. Create a Spotify developer app and register its iOS bundle ID.
2. Register `now-playing-artwork-login://spotify/callback` as its redirect URI.
3. Launch the app, paste the client ID, and choose **Connect Spotify**.

The app uses Authorization Code with PKCE and requests `user-read-currently-playing` plus `user-read-playback-state`.

Official references: [Spotify PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow), [currently playing](https://developer.spotify.com/documentation/web-api/reference/get-the-users-currently-playing-track).

## Sonos

Sonos requires a publicly routable HTTPS redirect. Configure your control integration with:

`https://<OAUTH_CALLBACK_DOMAIN>/sonos/callback`

Configure that URL as a Universal Link for the app. Serve an `apple-app-site-association` file from:

`https://<OAUTH_CALLBACK_DOMAIN>/.well-known/apple-app-site-association`

Example:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "<TEAM_ID>.<APP_BUNDLE_ID>",
        "paths": ["/sonos/callback"]
      }
    ]
  }
}
```

Then launch the app, enter the Sonos client ID and secret, and choose **Connect Sonos**. The app requests `playback-control-all`.

Sonos recommends exchanging the authorization code on a server because it uses the client secret. This project stores the user-supplied secret in the shared Keychain for a self-hosted/personal deployment; route token exchange and refresh through your backend before distributing the app.

Official references: [Sonos authorization](https://docs.sonos.com/docs/authorize), [get groups](https://docs.sonos.com/reference/groups-getgroups-householdid), [playback metadata](https://docs.sonos.com/reference/playbackmetadata-getmetadatastatus-groupid).

## Use

1. Connect either or both services in the main app.
2. Set an optional fallback URL such as `spotify://` or `music://`.
3. Add the **Now Playing Artwork** small widget.
4. Tap anywhere on the widget to refresh.

On iOS 18.2+, the intent refreshes in place and opens the fallback only when both services are idle. On iOS 17–18.1, AppIntents cannot conditionally return an opening intent, so the compatibility intent briefly launches the host app; the host forwards to the fallback only when both services are idle.

If a configured playback service fails to respond, the app does not launch the fallback because it cannot safely conclude that nothing is playing.

## Verification

The app, widget extension, AppIntent metadata, resources, and unit-test target compile with:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project NowPlayingArtwork.xcodeproj \
  -scheme NowPlayingArtwork \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build-for-testing
```

Run the tests from Xcode on an available iOS simulator or device.
