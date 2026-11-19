import AVFoundation
import AVKit
import MediaPlayer
import SwiftUI

struct MediaChoice: Identifiable, Hashable {
    var id: String
    var name: String
}

@MainActor
@Observable
final class PlayerModel {
    var playable: PlayableItem
    let player = AVPlayer()
    let pip = PiPController()
    private let app: AppModel
    private var token: Any?
    private var endObserver: NSObjectProtocol?
    private var commandTokens: [(MPRemoteCommand, Any)] = []
    private var started = false
    private var lastSavedSecond = -1
    private var hideTask: Task<Void, Never>?
    private var subtitleGroup: AVMediaSelectionGroup?
    private var audioGroup: AVMediaSelectionGroup?
    private var subtitleMap: [String: AVMediaSelectionOption] = [:]
    private var audioMap: [String: AVMediaSelectionOption] = [:]

    var isPlaying = false
    var isBuffering = false
    var current: Double = 0
    var duration: Double = 0
    var isScrubbing = false
    var showsControls = true
    var subtitles: [MediaChoice] = []
    var audios: [MediaChoice] = []
    var selectedSubtitle: String?
    var selectedAudio: String?
    var message: String?

    init(playable: PlayableItem, app: AppModel) {
        self.playable = playable
        self.app = app
    }

    var canSeek: Bool { !playable.isLive && duration.isFinite && duration > 1 }

    func start() {
        guard !started else { return }
        started = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
        let item = AVPlayerItem(url: playable.url)
        item.preferredPeakBitRate = app.quality.peakBitRate
        player.replaceCurrentItem(with: item)
        observe(item)
        installRemoteCommands()
        player.play()
        isPlaying = true
        scheduleHide()
        Task { await prepare(item) }
    }

    func teardown() {
        hideTask?.cancel()
        if let token { player.removeTimeObserver(token) }
        token = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player.pause()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        for (command, target) in commandTokens {
            command.removeTarget(target)
        }
        commandTokens.removeAll()
    }

    func togglePlay() {
        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
            showsControls = true
        } else {
            player.play()
            isPlaying = true
            scheduleHide()
        }
        updateNowPlaying()
    }

    func toggleControls() {
        showsControls.toggle()
        if showsControls { scheduleHide() }
    }

    func seek(by delta: Double) {
        guard canSeek else { return }
        let upper = duration > 0 ? duration : current
        let target = min(max(current + delta, 0), upper)
        current = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        scheduleHide()
    }

    func setScrubbing(_ editing: Bool) {
        isScrubbing = editing
        if !editing {
            player.seek(to: CMTime(seconds: current, preferredTimescale: 600))
            scheduleHide()
        }
    }

    func selectSubtitle(_ id: String?) {
        guard let item = player.currentItem, let group = subtitleGroup else { return }
        if let id, let option = subtitleMap[id] {
            item.select(option, in: group)
        } else {
            item.select(nil, in: group)
        }
        selectedSubtitle = id
    }

    func selectAudio(_ id: String?) {
        guard let item = player.currentItem, let group = audioGroup, let id, let option = audioMap[id] else { return }
        item.select(option, in: group)
        selectedAudio = id
    }

    private func observe(_ item: AVPlayerItem) {
        let interval = CMTime(seconds: 0.4, preferredTimescale: 600)
        token = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.consume(time)
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleEnded()
            }
        }
    }

    private func consume(_ time: CMTime) {
        if !isScrubbing, time.seconds.isFinite { current = max(time.seconds, 0) }
        let itemDuration = player.currentItem?.duration.seconds ?? 0
        if itemDuration.isFinite, itemDuration > 0 { duration = itemDuration }
        isPlaying = player.timeControlStatus == .playing
        isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
        let second = Int(current)
        if second > 0, second % 5 == 0, second != lastSavedSecond {
            lastSavedSecond = second
            app.saveWatchProgress(item: playable, position: current, duration: duration)
            updateNowPlaying()
        }
    }

    private func prepare(_ item: AVPlayerItem) async {
        let asset = item.asset
        if let group = try? await asset.loadMediaSelectionGroup(for: .legible) {
            subtitleGroup = group
            var choices: [MediaChoice] = []
            subtitleMap = [:]
            for (index, option) in group.options.enumerated() {
                let id = "sub-\(index)"
                subtitleMap[id] = option
                choices.append(MediaChoice(id: id, name: option.displayName(with: Locale(identifier: "ar"))))
            }
            subtitles = choices
        }
        if let group = try? await asset.loadMediaSelectionGroup(for: .audible) {
            audioGroup = group
            var choices: [MediaChoice] = []
            audioMap = [:]
            for (index, option) in group.options.enumerated() {
                let id = "aud-\(index)"
                audioMap[id] = option
                choices.append(MediaChoice(id: id, name: option.displayName(with: Locale(identifier: "ar"))))
            }
            audios = choices
            selectedAudio = choices.first?.id
        }
        if let saved = app.library.progress(profile: app.activeProfileID, mediaID: playable.mediaID),
           saved.position > 5,
           saved.duration - saved.position > 8 {
            let time = CMTime(seconds: saved.position, preferredTimescale: 600)
            await player.seek(to: time)
            current = saved.position
        }
    }

    private func handleEnded() {
        app.saveWatchProgress(item: playable, position: duration, duration: duration)
        guard let next = app.nextPlayable(after: playable) else {
            isPlaying = false
            showsControls = true
            return
        }
        playable = next
        let item = AVPlayerItem(url: next.url)
        item.preferredPeakBitRate = app.quality.peakBitRate
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        player.replaceCurrentItem(with: item)
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.handleEnded()
            }
        }
        current = 0
        duration = 0
        player.play()
        Task { await prepare(item) }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled, isPlaying, !isScrubbing else { return }
            showsControls = false
        }
    }

    private func installRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: 10)]
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: 10)]
        commandTokens.append((center.playCommand, center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.player.play() }
            return .success
        }))
        commandTokens.append((center.pauseCommand, center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.player.pause() }
            return .success
        }))
        commandTokens.append((center.skipForwardCommand, center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.seek(by: 10) }
            return .success
        }))
        commandTokens.append((center.skipBackwardCommand, center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.seek(by: -10) }
            return .success
        }))
        updateNowPlaying()
    }

    private func updateNowPlaying() {
        guard duration.isFinite else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: playable.title,
            MPMediaItemPropertyArtist: playable.subtitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: current,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1 : 0
        ]
    }
}

final class PiPController: NSObject, AVPictureInPictureControllerDelegate {
    private var controller: AVPictureInPictureController?

    var isPossible: Bool { controller?.isPictureInPicturePossible ?? AVPictureInPictureController.isPictureInPictureSupported() }

    func attach(layer: AVPlayerLayer) {
        guard controller == nil, AVPictureInPictureController.isPictureInPictureSupported() else { return }
        let created = AVPictureInPictureController(playerLayer: layer)
        created.delegate = self
        created.canStartPictureInPictureAutomaticallyFromInline = true
        controller = created
    }

    func toggle() {
        guard let controller else { return }
        if controller.isPictureInPictureActive {
            controller.stopPictureInPicture()
        } else {
            controller.startPictureInPicture()
        }
    }
}

struct PlayerScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let request: PlayerRequest
    @State private var model: PlayerModel?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let model {
                PlayerBody(model: model) { dismiss() }
            }
        }
        .onAppear {
            if model == nil {
                let created = PlayerModel(playable: request.item, app: app)
                model = created
                created.start()
            }
        }
        .onDisappear { model?.teardown() }
        .preferredColorScheme(.dark)
        .statusBarHidden(model?.showsControls == false)
        .persistentSystemOverlays(model?.showsControls == false ? .hidden : .automatic)
    }
}

private struct PlayerBody: View {
    @Bindable var model: PlayerModel
    var close: () -> Void

    var body: some View {
        ZStack {
            MovieSurface(player: model.player) { layer in
                model.pip.attach(layer: layer)
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { model.toggleControls() }

            if model.isBuffering {
                ProgressView().tint(.white).controlSize(.large)
            }

            if model.showsControls {
                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    bottomPanel
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(Copy.close)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.playable.title)
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                Text(model.playable.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
            Spacer()
            if model.playable.isLive {
                Text(Copy.liveBadge)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(LaylColor.pg, in: Capsule())
            }
            AirPlayButton().frame(width: 40, height: 40).accessibilityLabel(Copy.airplay)
        }
        .padding(.top, 8)
    }

    private var bottomPanel: some View {
        VStack(spacing: 14) {
            if model.canSeek {
                VStack(spacing: 6) {
                    Slider(
                        value: Binding(get: { model.current }, set: { model.current = $0 }),
                        in: 0...max(model.duration, 1)
                    ) { editing in
                        model.setScrubbing(editing)
                    }
                    .tint(.white)
                    HStack {
                        Text(Self.clock(model.current))
                        Spacer()
                        Text(Self.clock(max(model.duration - model.current, 0)))
                    }
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                    .environment(\.layoutDirection, .leftToRight)
                }
            }
            GlassEffectContainer(spacing: 16) {
                HStack(spacing: 22) {
                    transport(system: "gobackward.10", label: "عشر ثوانٍ للخلف") { model.seek(by: -10) }
                        .disabled(!model.canSeek)
                    Button { model.togglePlay() } label: {
                        Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 64, height: 64)
                            .background(Color.white, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(model.isPlaying ? "إيقاف مؤقت" : Copy.play)
                    transport(system: "goforward.10", label: "عشر ثوانٍ للأمام") { model.seek(by: 10) }
                        .disabled(!model.canSeek)
                }
                .environment(\.layoutDirection, .leftToRight)
            }
            HStack(spacing: 10) {
                Button { model.pip.toggle() } label: {
                    Image(systemName: "pip")
                        .frame(width: 44, height: 36)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(Copy.pip)
                .disabled(!model.pip.isPossible)

                Menu {
                    Button(Copy.off) { model.selectSubtitle(nil) }
                    if model.subtitles.isEmpty {
                        Text(Copy.noneAvailable)
                    }
                    ForEach(model.subtitles) { choice in
                        Button(choice.name) { model.selectSubtitle(choice.id) }
                    }
                } label: {
                    Image(systemName: "captions.bubble")
                        .frame(width: 44, height: 36)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(Copy.subtitles)

                Menu {
                    if model.audios.isEmpty {
                        Text(Copy.noneAvailable)
                    }
                    ForEach(model.audios) { choice in
                        Button(choice.name) { model.selectAudio(choice.id) }
                    }
                } label: {
                    Image(systemName: "waveform")
                        .frame(width: 44, height: 36)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(Copy.audio)
                Spacer()
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func transport(system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(label)
    }

    private static func clock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }
}

private struct MovieSurface: UIViewRepresentable {
    let player: AVPlayer
    var onLayer: (AVPlayerLayer) -> Void

    func makeUIView(context: Context) -> MovieHostView {
        let view = MovieHostView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: MovieHostView, context: Context) {
        uiView.playerLayer.player = player
        if !context.coordinator.attached {
            context.coordinator.attached = true
            let layer = uiView.playerLayer
            DispatchQueue.main.async { onLayer(layer) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var attached = false
    }
}

private final class MovieHostView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
