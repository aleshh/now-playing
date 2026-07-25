import SwiftUI
import UIKit
import WidgetKit

struct ArtworkEntry: TimelineEntry {
    let date: Date
    let artworkData: Data?
}

struct ArtworkTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ArtworkEntry {
        ArtworkEntry(date: Date(), artworkData: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ArtworkEntry) -> Void) {
        completion(ArtworkEntry(date: Date(), artworkData: ArtworkCache.cachedData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ArtworkEntry>) -> Void) {
        let entry = ArtworkEntry(date: Date(), artworkData: ArtworkCache.cachedData())
        completion(
            Timeline(
                entries: [entry],
                policy: .after(Date().addingTimeInterval(60 * 60))
            )
        )
    }
}

struct NowPlayingArtworkWidgetView: View {
    let entry: ArtworkEntry

    var body: some View {
        widgetButton
            .buttonStyle(.plain)
            .containerBackground(.clear, for: .widget)
    }

    @ViewBuilder
    private var widgetButton: some View {
        if #available(iOS 18.2, *) {
            Button(intent: RefreshArtworkIntent()) {
                buttonLabel
            }
        } else {
            Button(intent: LegacyRefreshArtworkIntent()) {
                buttonLabel
            }
        }
    }

    private var buttonLabel: some View {
        artwork
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var artwork: some View {
        if let data = entry.artworkData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            ZStack {
                Color(uiColor: .secondarySystemBackground)
                Image(systemName: "music.note")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
    }
}

@main
struct NowPlayingArtworkWidget: Widget {
    let kind = SharedConfiguration.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ArtworkTimelineProvider()) { entry in
            NowPlayingArtworkWidgetView(entry: entry)
        }
        .configurationDisplayName("Now Playing Artwork")
        .description("Tap to refresh artwork from Sonos or Spotify.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
