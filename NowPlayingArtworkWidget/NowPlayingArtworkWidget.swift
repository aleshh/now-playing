import SwiftUI
import UIKit
import WidgetKit

struct ArtworkEntry: TimelineEntry {
    let date: Date
    let artworkData: Data?
    let linkLayout: CachedArtworkLinkLayout?
}

struct ArtworkTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ArtworkEntry {
        ArtworkEntry(date: Date(), artworkData: nil, linkLayout: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ArtworkEntry) -> Void) {
        completion(
            ArtworkEntry(
                date: Date(),
                artworkData: cachedArtwork(for: context.family),
                linkLayout: cachedLinkLayout(for: context.family)
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ArtworkEntry>) -> Void) {
        let entry = ArtworkEntry(
            date: Date(),
            artworkData: cachedArtwork(for: context.family),
            linkLayout: cachedLinkLayout(for: context.family)
        )
        completion(
            Timeline(
                entries: [entry],
                policy: .after(Date().addingTimeInterval(60 * 60))
            )
        )
    }

    private func cachedArtwork(for family: WidgetFamily) -> Data? {
        ArtworkCache.cachedData(for: cacheVariant(for: family))
    }

    private func cachedLinkLayout(
        for family: WidgetFamily
    ) -> CachedArtworkLinkLayout? {
        ArtworkCache.cachedLinkLayout(for: cacheVariant(for: family))
    }

    private func cacheVariant(for family: WidgetFamily) -> ArtworkCacheVariant {
        family == .systemSmall ? .small : .large
    }
}

struct NowPlayingArtworkWidgetView: View {
    let entry: ArtworkEntry

    var body: some View {
        ZStack {
            widgetButton
                .accessibilityHidden(entry.linkLayout != nil)

            if let linkLayout = entry.linkLayout {
                albumTapOverlay(linkLayout)
            }
        }
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

    private func albumTapOverlay(
        _ layout: CachedArtworkLinkLayout
    ) -> some View {
        GeometryReader { geometry in
            if layout.columns == 1, let link = layout.links.first {
                albumButton(link)
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
            } else {
                let outerPadding = ArtworkCache.gridOuterPadding
                let contentSize = CGSize(
                    width: max(0, geometry.size.width - outerPadding * 2),
                    height: max(0, geometry.size.height - outerPadding * 2)
                )
                let imageDimension = max(contentSize.width, contentSize.height)
                let imageOrigin = CGPoint(
                    x: outerPadding + (contentSize.width - imageDimension) / 2,
                    y: outerPadding + (contentSize.height - imageDimension) / 2
                )
                let gutter = imageDimension * ArtworkCache.gridGutterFraction
                let cellDimension = (
                    imageDimension - gutter * CGFloat(layout.columns - 1)
                ) / CGFloat(layout.columns)

                ZStack(alignment: .topLeading) {
                    ForEach(Array(layout.links.enumerated()), id: \.offset) { index, link in
                        albumButton(link)
                            .frame(width: cellDimension, height: cellDimension)
                            .offset(
                                x: imageOrigin.x
                                    + CGFloat(index % layout.columns)
                                    * (cellDimension + gutter),
                                y: imageOrigin.y
                                    + CGFloat(index / layout.columns)
                                    * (cellDimension + gutter)
                            )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func albumButton(_ link: CachedArtworkLink) -> some View {
        if #available(iOS 18.2, *) {
            Button(intent: RefreshArtworkIntent(albumURLString: link.urlString)) {
                transparentTapTarget
            }
            .accessibilityLabel(Text(link.accessibilityLabel))
        } else {
            Button(intent: LegacyRefreshArtworkIntent(albumURLString: link.urlString)) {
                transparentTapTarget
            }
            .accessibilityLabel(Text(link.accessibilityLabel))
        }
    }

    private var transparentTapTarget: some View {
        Rectangle()
            .fill(Color.black.opacity(0.001))
            .contentShape(Rectangle())
    }

    private var buttonLabel: some View {
        artwork
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var artwork: some View {
        if let data = entry.artworkData, let image = UIImage(data: data) {
            if let layout = entry.linkLayout, layout.columns > 1 {
                ZStack {
                    Color.black
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .clipShape(ContainerRelativeShape())
                        .padding(ArtworkCache.gridOuterPadding)
                }
            } else {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
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
        .description("Shows current artwork or recent albums. Tap an album to open it.")
        .supportedFamilies([.systemSmall, .systemLarge])
        .contentMarginsDisabled()
    }
}
