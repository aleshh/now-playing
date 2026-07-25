# Now Playing Artwork

An iOS 17+ SwiftUI app with small and large square widgets. The widget displays the most recently cached album artwork edge-to-edge. Tapping it checks Spotify for active playback, caches newer artwork when available, reloads the widget, and opens a configured app such as Spotify.

If playback is idle or a refresh fails, the last successful artwork remains visible. Before the first successful refresh, the widget shows a dark music-note placeholder.

> The project is currently configured for Spotify only. Sonos is disabled and its future setup is documented in [TODO.md](TODO.md).

## What you need

- A Mac with a recent version of Xcode that supports iOS 17.
- An iPhone or iPad running iOS 17 or later.
- An Apple Account and development team that can use App Groups and Keychain Sharing.
- A Spotify account with access to the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
- Spotify Premium on the account that owns the developer app. Spotify currently requires this for development-mode apps.
- The Spotify iOS app installed if you want `spotify://` to open after a widget tap.

No Spotify client secret is needed or used. This app uses Authorization Code with PKCE, which is intended for clients that cannot safely store a secret.

## 1. Download and open the project

Clone or download this repository, then open:

`NowPlayingArtwork.xcodeproj`

Select the **NowPlayingArtwork** scheme in Xcode.

## 2. Configure your Apple signing identifiers

The checked-in project contains the original developer's identifiers. Replace them with identifiers owned by your Apple development team.

Choose a unique base bundle identifier, for example:

`com.yourname.NowPlayingArtwork`

In Xcode:

1. Select the blue **NowPlayingArtwork** project in the Project navigator.
2. Select the **NowPlayingArtwork** app target.
3. Under **Signing & Capabilities**, enable automatic signing, select your Team, and set the main bundle identifier to your unique value.
4. Select the **NowPlayingArtworkWidget** target, choose the same Team, and set its bundle identifier to the main identifier plus `.widget`.
5. If you intend to run unit tests, give **NowPlayingArtworkTests** a unique `.tests` bundle identifier as well.

Example:

| Target | Identifier |
| --- | --- |
| App | `com.yourname.NowPlayingArtwork` |
| Widget | `com.yourname.NowPlayingArtwork.widget` |
| Tests | `com.yourname.NowPlayingArtwork.tests` |

### Shared App Group

The app and widget use an App Group to share cached artwork and the widget-tap URL.

1. In the project-level **Build Settings**, find `APP_GROUP_IDENTIFIER`.
2. Set it for Debug and Release to a unique value such as:

   `group.com.yourname.NowPlayingArtwork`

3. Under **Signing & Capabilities** for both the app and widget targets, confirm **App Groups** is present.
4. Create or select that exact App Group for both targets.

### Shared Keychain group

The app and widget use Keychain Sharing for the Spotify client ID and OAuth tokens.

1. In the project-level **Build Settings**, find `SHARED_KEYCHAIN_GROUP`.
2. Set it for Debug and Release to a unique value such as:

   `com.yourname.NowPlayingArtwork.shared`

3. Under **Signing & Capabilities** for both the app and widget targets, confirm **Keychain Sharing** is present.
4. Use that exact Keychain group for both targets.

Leave `SONOS_ENABLED` set to `NO`. `OAUTH_CALLBACK_DOMAIN` is not used while Sonos is disabled.

Apple references: [Adding capabilities](https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app), [App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups), and [Keychain Sharing](https://developer.apple.com/documentation/xcode/configuring-keychain-sharing).

## 3. Create your Spotify client ID

1. Sign in to the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).
2. Choose **Create app**.
3. Enter any app name and description you want.
4. Add this exact Redirect URI, including its path:

   `now-playing-artwork-login://spotify/callback`

5. Under **Which API/SDKs are you planning to use?**, select **Web API**. This project calls the Web API directly and does not include Spotify's iOS SDK or Web Playback SDK.
6. Accept Spotify's developer terms and save the app.
7. Open the new developer app and copy its **Client ID**. Do not copy or use the client secret.

The redirect URI must match exactly. It is already registered as a URL scheme in the iOS project and should not be changed unless you also change the Swift code, app Info plist, and Spotify dashboard setting.

Spotify references: [creating and configuring an app](https://developer.spotify.com/documentation/web-api/concepts/apps), [Authorization Code with PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow), and [currently playing endpoint](https://developer.spotify.com/documentation/web-api/reference/get-the-users-currently-playing-track).

### Additional Spotify users

New Spotify apps start in development mode and support up to five authenticated Spotify users total. Add each account that will use the app to its allowlist:

1. Open your app in the Spotify Developer Dashboard.
2. Open **Settings**.
3. Open **Users Management**.
4. Choose **Add new user** and enter the user's name and Spotify account email.

A non-allowlisted user may complete login but receive `403 Forbidden` when the app requests playback data. App Store or TestFlight installation does not bypass this restriction.

See [Spotify quota modes](https://developer.spotify.com/documentation/web-api/concepts/quota-modes) for the current limits.

## 4. Install and connect the app

1. Connect your iPhone or iPad to the Mac and select it as the Xcode run destination.
2. If prompted, enable **Developer Mode** on the device.
3. Build and run the **NowPlayingArtwork** app.
4. Paste your Spotify Client ID into the app.
5. Tap **Connect Spotify**, sign in, and approve access.
6. Under **Widget Tap App**, enter:

   `spotify://`

7. Tap **Save Widget Tap App**.
8. Start playing a track in Spotify.
9. Return to Now Playing and tap **Refresh Now**. The app should show the cached artwork.

The app requests only `user-read-currently-playing` and `user-read-playback-state`.

## 5. Add and test the widget

1. Long-press the Home Screen and open the widget gallery.
2. Find **Now Playing Artwork**.
3. Add either the small or large square widget.
4. Tap the widget.

The tap refreshes the cached artwork and then opens Spotify. On iOS 18.2 or later, Spotify opens directly after the intent finishes. On iOS 17 through 18.1, the Now Playing host app briefly opens before forwarding to Spotify.

The widget is user-driven: it refreshes when tapped and also rereads the cache when WidgetKit requests a new timeline. iOS ultimately controls widget refresh scheduling.

## Troubleshooting

### Spotify sign-in reports an invalid redirect URI

Confirm the Spotify dashboard contains exactly:

`now-playing-artwork-login://spotify/callback`

Do not add a trailing slash or change capitalization.

### Spotify login succeeds, but refresh returns 403

- Confirm the Spotify developer-app owner still has Premium.
- If using a different Spotify account, add it under **Settings → Users Management** in the Spotify Developer Dashboard.

### The widget remains on the dark placeholder

- Start active Spotify playback and use **Refresh Now** in the main app first.
- Confirm the same App Group is selected for both app and widget targets.
- Confirm both targets use the same development Team.
- Rebuild the app, then remove and re-add the widget if WidgetKit is showing an older installed extension.

### Spotify does not open after tapping the widget

- Confirm Spotify is installed.
- Confirm **Widget Tap App** contains `spotify://`.
- Tap **Save Widget Tap App** after entering it.
- Test on a physical device; the Spotify app normally is not installed in the simulator.

### Spotify disconnects or Keychain access fails

Confirm both app and widget targets have Keychain Sharing enabled with the same `SHARED_KEYCHAIN_GROUP` value and are signed by the same Team.

### Xcode reports signing or App Group errors

Confirm every bundle identifier and App Group is unique and registered to your own development team. Keep automatic signing enabled unless you intentionally manage profiles yourself.

## Storage and privacy

- Spotify access and refresh tokens and the client ID are stored in the shared Keychain.
- Cached artwork and the widget-tap URL are stored in the shared App Group container.
- The client secret is never requested or stored.
- Artwork downloads are validated, limited to 20 MB, and written atomically.
- Disconnecting Spotify removes its OAuth token. It does not delete the most recently cached artwork.

## Current limitations

- Spotify development mode is limited to five allowlisted users and currently requires the developer-app owner to have Premium.
- A public Spotify-backed release requires separate Spotify quota approval and policy work; see [TODO.md](TODO.md#possible-app-store-release).
- Sonos support remains disabled.

## Build verification

To compile the app, widget, AppIntent metadata, resources, and unit-test target without signing:

```sh
xcodebuild -project NowPlayingArtwork.xcodeproj \
  -scheme NowPlayingArtwork \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build-for-testing
```

Run the unit tests from Xcode using an available simulator or device.
