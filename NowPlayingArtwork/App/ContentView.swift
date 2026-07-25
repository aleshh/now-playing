import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var model: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                artworkSection
                spotifySection
                sonosSection
                fallbackSection

                if let message = model.statusMessage {
                    Section("Status") {
                        Text(message)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Now Playing")
        }
        .onOpenURL { url in
            Task { await model.handleIncomingURL(url) }
        }
        .task(id: scenePhase) {
            await forwardPendingFallbackIfNeeded()
        }
    }

    private var artworkSection: some View {
        Section("Widget Artwork") {
            HStack(spacing: 16) {
                ArtworkThumbnail(data: model.cachedArtworkData)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        model.cachedArtworkData == nil
                            ? "No cached artwork"
                            : "Cached artwork ready"
                    )
                    .font(.headline)

                    Button {
                        Task { await model.refreshArtwork() }
                    } label: {
                        if model.isRefreshing {
                            ProgressView()
                        } else {
                            Text("Refresh Now")
                        }
                    }
                    .disabled(model.isRefreshing)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var spotifySection: some View {
        Section {
            TextField("Client ID", text: $model.spotifyClientID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if model.isSpotifyConnected {
                Button("Disconnect Spotify", role: .destructive) {
                    model.disconnectSpotify()
                }
            } else {
                Button {
                    Task { await model.connectSpotify() }
                } label: {
                    busyLabel("Connect Spotify", busy: model.isSpotifyBusy)
                }
                .disabled(model.isSpotifyBusy)
            }
        } header: {
            ServiceHeader(title: "Spotify", connected: model.isSpotifyConnected)
        } footer: {
            Text("Register \(SharedConfiguration.spotifyRedirectURI) in the Spotify developer dashboard.")
        }
    }

    private var sonosSection: some View {
        Section {
            TextField("Client ID", text: $model.sonosClientID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("Client secret", text: $model.sonosClientSecret)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if model.isSonosConnected {
                Button("Disconnect Sonos", role: .destructive) {
                    model.disconnectSonos()
                }
            } else {
                Button {
                    if let url = model.beginSonosConnection() {
                        openURL(url)
                    }
                } label: {
                    busyLabel("Connect Sonos", busy: model.isSonosBusy)
                }
            }
        } header: {
            ServiceHeader(title: "Sonos", connected: model.isSonosConnected)
        } footer: {
            Text("Sonos redirects to \(SharedConfiguration.sonosRedirectURI). The domain must be configured for Universal Links. For a distributed app, exchange the Sonos code on a server so its client secret never ships to devices.")
        }
    }

    private var fallbackSection: some View {
        Section {
            TextField("App URL (for example, spotify://)", text: $model.fallbackURLText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            Button("Save Fallback App") {
                model.saveFallbackURL()
            }
        } header: {
            Text("Fallback App")
        } footer: {
            Text("Opened only when both connected services report no active playback.")
        }
    }

    @ViewBuilder
    private func busyLabel(_ title: String, busy: Bool) -> some View {
        if busy {
            HStack {
                ProgressView()
                Text(title)
            }
        } else {
            Text(title)
        }
    }

    private func forwardPendingFallbackIfNeeded() async {
        guard scenePhase == .active else {
            return
        }
        if #available(iOS 18.2, *) {
            return
        }

        for _ in 0..<240 {
            if Task.isCancelled {
                return
            }
            if let fallbackURL = PendingFallbackStore.takeIfFresh() {
                openURL(fallbackURL)
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }
}

private struct ServiceHeader: View {
    let title: String
    let connected: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Label(
                connected ? "Connected" : "Not connected",
                systemImage: connected ? "checkmark.circle.fill" : "circle"
            )
            .font(.caption)
            .foregroundStyle(connected ? .green : .secondary)
            .textCase(nil)
        }
    }
}

private struct ArtworkThumbnail: View {
    let data: Data?

    var body: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(uiColor: .secondarySystemBackground)
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
