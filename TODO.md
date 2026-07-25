# Now Playing Artwork — To Do

## Current state

- [x] Main bundle ID: `com.alesh.NowPlayingArtwork`
- [x] Widget bundle ID: `com.alesh.NowPlayingArtwork.widget`
- [x] Test bundle ID: `com.alesh.NowPlayingArtwork.tests`
- [x] Development Team: `F4928M42KQ`
- [x] App Group: `group.com.alesh.NowPlayingArtwork`
- [x] Shared Keychain group: `com.alesh.NowPlayingArtwork.shared`
- [x] Spotify-only mode enabled with `SONOS_ENABLED = NO`
- [x] Sonos settings are hidden and Sonos is not queried by the widget
- [x] Associated Domains entitlement removed until Sonos is enabled

## Spotify setup

- [ ] Create or open the app in the Spotify Developer Dashboard.
- [ ] Set its iOS bundle ID to `com.alesh.NowPlayingArtwork`.
- [ ] Register this exact redirect URI:

  `now-playing-artwork-login://spotify/callback`

- [ ] Copy the Spotify client ID. The Spotify client secret is not needed.
- [ ] Run the main app, enter the client ID, and tap **Connect Spotify**.
- [ ] Start Spotify playback and tap **Refresh Now** in the main app.
- [ ] Confirm that cached artwork appears.
- [ ] Add the **Now Playing Artwork** small widget and tap it to refresh.

If Spotify rejects the login in development mode, add the Spotify account under the developer app's permitted development users.

## Apple capability checks

For both the app and widget targets in **Signing & Capabilities**:

- [ ] Confirm the same Team is selected and automatic signing is enabled.
- [ ] Confirm **App Groups** contains `group.com.alesh.NowPlayingArtwork`.
- [ ] Confirm **Keychain Sharing** contains `com.alesh.NowPlayingArtwork.shared`.

The Associated Domains capability is intentionally not needed in Spotify-only mode.

## Fallback app

- [ ] Enter an installed app URL in the main app, for example `spotify://` or `music://`.
- [ ] Tap **Save Fallback App**.
- [ ] Pause Spotify and tap the widget to verify fallback behavior.

On iOS 18.2+, the fallback opens directly. On iOS 17–18.1, the host app briefly opens before forwarding to the fallback.

## Deferred Sonos setup

Do not store the Sonos client secret in this file or commit it to source control.

### 1. Choose the callback hostname

Pick a public HTTPS hostname on the owned domain, for example:

`auth.example-owned-domain.com`

The complete redirect URI will be:

`https://auth.example-owned-domain.com/sonos/callback`

### 2. Publish the Apple App Site Association file

Serve this file without an extension:

`https://auth.example-owned-domain.com/.well-known/apple-app-site-association`

It must return HTTP 200 over HTTPS, use an `application/json` content type, and not redirect.

Use this content:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "F4928M42KQ.com.alesh.NowPlayingArtwork",
        "paths": ["/sonos/callback"]
      }
    ]
  }
}
```

Also serve a simple fallback page at `/sonos/callback` for cases where the app is not installed.

### 3. Re-enable Sonos in Xcode

- [ ] Change `OAUTH_CALLBACK_DOMAIN` for Debug and Release from `example.com` to the real hostname. Enter only the hostname, without `https://` or a path.
- [ ] Change `SONOS_ENABLED` for Debug and Release to `YES`.
- [ ] Add **Associated Domains** to the main app target only.
- [ ] Add `applinks:auth.example-owned-domain.com` to that capability.
- [ ] Verify that `App.entitlements` contains:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:$(OAUTH_CALLBACK_DOMAIN)</string>
</array>
```

- [ ] Delete and reinstall the app after publishing or changing the AASA file so iOS refreshes the association.

### 4. Create the Sonos integration

- [ ] Create a Sonos Control Integration.
- [ ] Register the exact redirect URI:

  `https://auth.example-owned-domain.com/sonos/callback`

- [ ] Create a client credential key.
- [ ] Run the app, enter the Sonos client ID and secret, and tap **Connect Sonos**.
- [ ] Approve the `playback-control-all` scope.

The current implementation stores the user-supplied Sonos secret in the shared Keychain and exchanges tokens on-device. This is acceptable for a personal installation, but Sonos recommends moving token exchange and refresh to a server before distributing the app.

### 5. Verify Sonos

- [ ] Tap the callback URL from Notes or Messages and confirm it launches the app.
- [ ] Start different playback on Sonos and Spotify.
- [ ] Tap the widget and confirm Sonos artwork wins.
- [ ] Stop Sonos playback, tap again, and confirm Spotify artwork appears.

## Notes

- A network or authentication failure does not launch the fallback because the app cannot safely conclude that nothing is playing.
- Artwork downloads are validated, capped at 20 MB, and written atomically to the App Group.
- OAuth credentials and tokens are stored in the shared Keychain rather than UserDefaults.
- The widget supports the system-small family.
