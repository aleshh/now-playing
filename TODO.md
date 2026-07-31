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
- [x] Idle artwork adapts by album count and widget size: single cover, 2×2, or large-only 3×3
- [x] Each visible recent-album cell opens that album in Spotify
- [x] Grid layouts use rounded covers, black gutters, and a container-relative outer inset
- [x] Recent history includes only releases Spotify classifies as albums
- [x] Grid album taps open only when the refreshed playback status remains idle
- [x] Timeline generation checks Spotify automatically on a five-minute requested schedule
- [x] Persist and merge the nine most recently observed albums across Spotify checks

## Spotify setup

- [ ] Create or open the app in the Spotify Developer Dashboard.
- [ ] Set its iOS bundle ID to `com.alesh.NowPlayingArtwork`.
- [ ] Register this exact redirect URI:

  `now-playing-artwork-login://spotify/callback`

- [ ] Copy the Spotify client ID. The Spotify client secret is not needed.
- [ ] Run the main app, enter the client ID, and tap **Connect Spotify**.
- [ ] If upgrading an existing installation, reconnect Spotify once to grant `user-read-recently-played`.
- [ ] Start Spotify playback and tap **Refresh Now** in the main app.
- [ ] Confirm that cached artwork appears.
- [ ] Stop playback, tap **Refresh Now**, and confirm the recent-albums layout appears.
- [ ] Verify one recent album fills both widgets.
- [ ] Verify two through four recent albums use 2×2 in both widgets with unused cells black.
- [ ] Verify five or more recent albums use 3×3 in large and at most 2×2 in small.
- [ ] Confirm grid covers are subtly rounded and the outer corners follow the widget shape.
- [ ] Confirm Spotify singles and compilations do not appear in the recent-albums grid.
- [ ] Confirm the grid eventually fills to nine distinct albums even when Spotify returns fewer unique albums in its latest 50 tracks.
- [ ] Tap several different grid cells and confirm each opens its corresponding Spotify album.
- [ ] While a grid is visible, start playback and tap an old grid cover; confirm the widget updates to current artwork without opening the old album.
- [ ] Leave the widget untapped and confirm WidgetKit eventually refreshes it after playback changes.
- [ ] Tap unused black grid space and confirm it opens the configured Widget Tap App.
- [ ] Add both the small and large **Now Playing Artwork** widgets.
- [ ] Tap each widget and confirm that the whole square is tappable and the artwork refreshes.

If Spotify rejects the login in development mode, add the Spotify account under the developer app's permitted development users.

## Possible App Store release

There are two separate approval gates for a public release: Apple App Review and Spotify API access. App Store or TestFlight distribution does not remove Spotify's development-mode restrictions.

### Production authentication

- [ ] Replace the editable client-ID field with one Spotify client ID bundled in the app's build configuration.
- [ ] Keep Authorization Code with PKCE; do not add or ship a Spotify client secret.
- [ ] Continue storing each user's access and refresh tokens in the shared Keychain.
- [ ] Let every user tap **Connect Spotify** and authorize their own Spotify account. Users do not need Spotify developer accounts or their own client IDs.

A Spotify client ID is a public identifier and can be included in the app. A client secret must never be included in an iOS app.

### Spotify access limitation

- Spotify development mode currently permits up to five allowlisted Spotify users.
- Those users may use the app on their own devices; the limit is on Spotify accounts, not devices.
- TestFlight and App Store distribution still use the same Spotify quota mode.
- A broadly available release therefore requires Spotify extended quota access.
- Spotify's current extended-access criteria target established, legally registered organizations and include a launched service, commercial viability, availability in key markets, and at least 250,000 monthly active users. This makes approval difficult for a new independent app.

Official reference: [Spotify quota modes](https://developer.spotify.com/documentation/web-api/concepts/quota-modes)

### Spotify artwork and branding

The current artwork-only, edge-to-edge widget is suitable for personal development, but likely needs redesign before public distribution:

- [ ] Display Spotify attribution with Spotify-provided metadata and artwork.
- [ ] Link displayed content back to the relevant Spotify content.
- [ ] Do not present Spotify cover art as standalone content.
- [ ] Do not crop, distort, or place overlays on Spotify artwork.
- [ ] Reconcile those requirements with the current single-button, edge-to-edge widget design.

Official references: [Spotify Developer Policy](https://developer.spotify.com/policy) and [Spotify Design Guidelines](https://developer.spotify.com/documentation/design)

### Apple release requirements

- [ ] Add a public privacy-policy URL.
- [ ] Add support and product website URLs.
- [ ] Prepare the App Store icon, screenshots, description, and privacy disclosures.
- [ ] Give App Review working access and clear instructions for testing Spotify authentication and the widget.
- [ ] Verify that the app follows Spotify's terms for third-party content and services.
- [ ] Test authentication, artwork refresh, widget-tap app opening, and both widget sizes in a Release build.

Official reference: [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

### Practical release paths

- **Personal/friends:** Continue with the current Spotify development app and allowlist up to five Spotify accounts.
- **Public with Spotify:** Obtain extended quota access and redesign Spotify artwork presentation to meet its policy and branding requirements.
- **Public without Spotify:** Use a separately permitted source such as a future Sonos integration or locally supplied artwork.

## Apple capability checks

For both the app and widget targets in **Signing & Capabilities**:

- [ ] Confirm the same Team is selected and automatic signing is enabled.
- [ ] Confirm **App Groups** contains `group.com.alesh.NowPlayingArtwork`.
- [ ] Confirm **Keychain Sharing** contains `com.alesh.NowPlayingArtwork.shared`.

The Associated Domains capability is intentionally not needed in Spotify-only mode.

## Widget tap app

- [ ] Enter an installed app URL in the main app, for example `spotify://` or `music://`.
- [ ] Tap **Save Widget Tap App**.
- [ ] Tap the widget during and outside Spotify playback and confirm that the configured app opens.
- [ ] Confirm that the adaptive recent-albums layout appears when nothing is playing and that a failed refresh preserves the last successful image.

On iOS 18.2+, the configured app opens directly after the artwork refresh. On iOS 17–18.1, the host app briefly opens before forwarding to it.

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

- Default widget taps use the configured widget-tap app after refreshing; album-cell taps open their album only when playback remains idle.
- Idle playback updates the recent-albums grid; refresh failures leave the most recently cached artwork unchanged.
- Artwork downloads are validated, capped at 20 MB, and written atomically to the App Group.
- OAuth credentials and tokens are stored in the shared Keychain rather than UserDefaults.
- The widget supports the square system-small and system-large families.
