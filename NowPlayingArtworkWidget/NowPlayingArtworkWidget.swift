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
        completion(
            ArtworkEntry(
                date: Date(),
                artworkData: cachedArtwork(for: context.family)
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ArtworkEntry>) -> Void) {
        let entry = ArtworkEntry(
            date: Date(),
            artworkData: cachedArtwork(for: context.family)
        )
        completion(
            Timeline(
                entries: [entry],
                policy: .after(Date().addingTimeInterval(60 * 60))
            )
        )
    }

    private func cachedArtwork(for family: WidgetFamily) -> Data? {
        ArtworkCache.cachedData(
            for: family == .systemSmall ? .small : .large
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
                Color.black
                Image(systemName: "music.note")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
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
        .description("Shows current artwork or a grid of recent albums. Tap to refresh.")
        .supportedFamilies([.systemSmall, .systemLarge])
        .contentMarginsDisabled()
    }
}
