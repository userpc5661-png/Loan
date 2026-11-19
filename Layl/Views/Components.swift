import AVKit
import SwiftUI
import UIKit

struct Artwork: View {
    var asset: String?
    var url: String?
    var system = "moon.stars.fill"
    var contentMode: ContentMode = .fill

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [LaylColor.purpleDeep, LaylColor.backgroundDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let asset, asset.hasPrefix("symbol:") {
                Image(systemName: String(asset.dropFirst("symbol:".count)))
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(LaylColor.lilac)
            } else {
                Image(systemName: system)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            if let asset, !asset.isEmpty, !asset.hasPrefix("symbol:"), UIImage(named: asset) != nil {
                Image(asset)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if let url, let remote = URL(string: url) {
                RemoteImage(url: remote, contentMode: contentMode)
            }
        }
        .clipped()
    }
}

struct RemoteImage: View {
    let url: URL
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            }
        }
        .task(id: url) {
            image = await ImageCache.shared.image(for: url)
        }
    }
}

struct WhiteActionButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .flipsForRightToLeftLayoutDirection(false)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: LaylMetrics.buttonHeight)
            .background(Color.white, in: RoundedRectangle(cornerRadius: LaylMetrics.buttonRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct DarkActionButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .flipsForRightToLeftLayoutDirection(false)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: LaylMetrics.buttonHeight)
            .background(LaylColor.darkButton, in: RoundedRectangle(cornerRadius: LaylMetrics.buttonRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct GlassLabelButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: LaylMetrics.buttonHeight)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(title)
    }
}

struct RatingBadge: View {
    var text: String
    var prominent = false

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(prominent ? LaylColor.pg : LaylColor.hdFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct SectionTitle: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WatchBar: View {
    var fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.28))
                Capsule()
                    .fill(LaylColor.lilac)
                    .frame(width: max(4, proxy.size.width * fraction))
            }
        }
        .frame(height: 3)
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct EmptyPane: View {
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.stars")
                .font(.system(size: 36))
                .foregroundStyle(LaylColor.lilac)
            Text(title)
                .font(.title3.weight(.bold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(LaylColor.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.glassProminent)
                    .tint(LaylColor.purple)
                    .padding(.top, 6)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

struct PosterCard: View {
    var item: MediaItem
    var width: CGFloat
    var progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Artwork(asset: item.posterAsset, url: item.posterURL)
                .frame(width: width, height: width * 1.48)
                .clipShape(RoundedRectangle(cornerRadius: LaylMetrics.posterRadius, style: .continuous))
                .overlay(alignment: .bottom) {
                    if let progress, progress > 0.02 {
                        WatchBar(fraction: progress)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                    }
                }
            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: width, alignment: .leading)
        }
    }
}

struct IconHitButton: View {
    var systemImage: String
    var label: String
    var badge = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 40)
                .overlay(alignment: .topTrailing) {
                    if badge {
                        Circle()
                            .fill(LaylColor.pg)
                            .frame(width: 7, height: 7)
                            .offset(x: 2, y: 8)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct AirPlayButton: UIViewRepresentable {
    var tint: UIColor = .white

    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = tint
        view.activeTintColor = UIColor(red: 0.74, green: 0.60, blue: 1, alpha: 1)
        view.prioritizesVideoDevices = true
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
