import AVFoundation
import SwiftUI
import UIKit

struct ClipsView: View {
    @Environment(AppModel.self) private var app
    @State private var currentID: String?

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(app.catalog.clips) { clip in
                        ClipPage(clip: clip, isActive: currentID == clip.id && app.selectedTab == .clips)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .id(clip.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentID)
            .scrollIndicators(.hidden)
            .ignoresSafeArea()
            .onAppear {
                if currentID == nil { currentID = app.catalog.clips.first?.id }
            }
        }
        .background(Color.black)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct ClipPage: View {
    @Environment(AppModel.self) private var app
    let clip: ClipItem
    let isActive: Bool
    @State private var player: AVPlayer?
    @State private var liked = false

    var body: some View {
        ZStack {
            Artwork(asset: clip.posterAsset, url: nil)
                .ignoresSafeArea()
            if let player {
                ClipPlayer(player: player)
                    .ignoresSafeArea()
            }
            LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(clip.creator)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LaylColor.lilac)
                        Text(clip.title)
                            .font(.system(size: 26, weight: .bold))
                        Text(clip.overview)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(3)
                        Button(Copy.openPlayer) { app.play(clip: clip) }
                            .buttonStyle(.glass)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: 16) {
                        clipButton(system: liked ? "heart.fill" : "heart", title: Copy.liked) {
                            liked.toggle()
                        }
                        clipButton(system: app.isFavorite(clip.id) ? "checkmark" : "plus", title: Copy.myList) {
                            app.toggleFavorite(clip.asMedia)
                        }
                        ShareLink(item: clip.title) {
                            VStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("مشاركة")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .frame(width: 64)
                        }
                        .buttonStyle(.glass)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
        }
        .onChange(of: isActive, initial: true) { _, active in
            syncPlayback(active)
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func clipButton(system: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: system)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .frame(width: 72)
        }
        .buttonStyle(.glass)
    }

    private func syncPlayback(_ active: Bool) {
        guard active, let remote = clip.streamURL, let url = URL(string: remote) else {
            player?.pause()
            return
        }
        if player == nil {
            let item = AVPlayerItem(url: url)
            let created = AVPlayer(playerItem: item)
            created.isMuted = false
            player = created
        }
        player?.play()
    }
}

private struct ClipPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> ClipHostView {
        let view = ClipHostView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: ClipHostView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class ClipHostView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

private extension ClipItem {
    var asMedia: MediaItem {
        MediaItem(
            id: id,
            kind: .clip,
            title: title,
            overview: overview,
            year: nil,
            rating: nil,
            quality: nil,
            genres: [],
            posterAsset: posterAsset,
            posterURL: nil,
            backdropAsset: posterAsset,
            backdropURL: nil,
            streamURL: streamURL,
            durationMinutes: nil,
            category: Copy.clips,
            playlistID: nil,
            isDemo: isDemo,
            credit: nil
        )
    }
}
