import SwiftUI
import UniformTypeIdentifiers

enum PlaylistDraftKind: String, CaseIterable, Identifiable {
    case m3u, xtream
    var id: String { rawValue }
    var title: String { self == .m3u ? "M3U / M3U8" : "Xtream Codes" }
}

@MainActor
@Observable
final class PlaylistFormModel {
    var kind: PlaylistDraftKind = .m3u
    var name = ""
    var url = ""
    var epg = ""
    var server = ""
    var username = ""
    var password = ""
    var showImporter = false
}

struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @State private var showAdd = false

    var body: some View {
        LaylScreen {
            VStack(spacing: 22) {
                Spacer()
                Image(systemName: "moon.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(LaylColor.lilac)
                    .shadow(color: LaylColor.purple.opacity(0.8), radius: 24)
                Text(Copy.brand)
                    .font(.system(size: 48, weight: .bold))
                Text(Copy.onboardingTitle)
                    .font(.title2.weight(.semibold))
                Text(Copy.onboardingBody)
                    .font(.body)
                    .foregroundStyle(LaylColor.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Spacer()
                VStack(spacing: 12) {
                    WhiteActionButton(title: Copy.exploreDemo, systemImage: "play.fill") {
                        app.showDemo = true
                        app.finishOnboarding()
                    }
                    .environment(\.layoutDirection, .leftToRight)
                    Button(Copy.addPlaylist) { showAdd = true }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .frame(maxWidth: 520)
            }
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                AddPlaylistView {
                    app.finishOnboarding()
                    showAdd = false
                }
            }
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
    }
}

struct PlaylistsView: View {
    @Environment(AppModel.self) private var app
    @State private var showAdd = false

    var body: some View {
        LaylScreen {
            List {
                if app.playlists.isEmpty {
                    Text("لم تُضف أي قائمة بعد. المحتوى التجريبي يبقى ظاهراً حتى تخفيه من الإعدادات.")
                        .foregroundStyle(LaylColor.secondary)
                        .listRowBackground(Color.clear)
                }
                ForEach(app.playlists) { playlist in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(playlist.name).font(.system(size: 16, weight: .semibold))
                        Text(playlist.kind == .m3u ? "M3U" : "Xtream")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(LaylColor.lilac)
                        Text(playlist.url)
                            .font(.system(size: 12))
                            .foregroundStyle(LaylColor.tertiary)
                            .lineLimit(1)
                        if let date = playlist.lastSyncedAt {
                            Text(date, format: .dateTime.day().month().hour().minute())
                                .font(.caption)
                                .foregroundStyle(LaylColor.tertiary)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .swipeActions {
                        Button(Copy.delete, role: .destructive) { app.deletePlaylist(playlist) }
                        Button(Copy.retry) { Task { await app.refresh(playlist) } }
                            .tint(LaylColor.purple)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("قوائم التشغيل")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.glass)
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack { AddPlaylistView(onSaved: { showAdd = false }) }
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
        .overlay {
            if app.isSyncing { ProgressView().tint(.white) }
        }
    }
}

struct AddPlaylistView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var form = PlaylistFormModel()
    var onSaved: () -> Void

    var body: some View {
        LaylScreen {
            Form {
                Picker("النوع", selection: binding(\.kind)) {
                    ForEach(PlaylistDraftKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                TextField(Copy.playlistName, text: binding(\.name))
                if form.kind == .m3u {
                    TextField(Copy.m3uURL, text: binding(\.url))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField(Copy.epgURL, text: binding(\.epg))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button(Copy.importFile) { form.showImporter = true }
                    Button(Copy.loadSample) {
                        app.alertMessage = nil
                        app.loadSamplePlaylist()
                        if app.alertMessage == nil { onSaved() }
                    }
                } else {
                    TextField(Copy.server, text: binding(\.server))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField(Copy.username, text: binding(\.username))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField(Copy.password, text: binding(\.password))
                }
                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            Spacer()
                            if app.isSyncing {
                                ProgressView().tint(.white)
                            } else {
                                Text(Copy.save).font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(LaylColor.purple)
                    .disabled(app.isSyncing || !canSave)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(Copy.addPlaylist)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(Copy.close) { dismiss() }
            }
        }
        .fileImporter(isPresented: binding(\.showImporter), allowedContentTypes: [.plainText, .data, .xml]) { result in
            if case .success(let url) = result {
                Task {
                    app.alertMessage = nil
                    await app.importM3UFile(url)
                    if app.alertMessage == nil { onSaved() }
                }
            }
        }
    }

    private var canSave: Bool {
        if form.kind == .m3u { return !form.url.trimmingCharacters(in: .whitespaces).isEmpty }
        return !form.server.isEmpty && !form.username.isEmpty && !form.password.isEmpty
    }

    private func binding<Value>(_ keyPath: ReferenceWritableKeyPath<PlaylistFormModel, Value>) -> Binding<Value> {
        Binding(get: { form[keyPath: keyPath] }, set: { form[keyPath: keyPath] = $0 })
    }

    private func save() async {
        app.alertMessage = nil
        if form.kind == .m3u {
            await app.addM3U(name: form.name, urlString: form.url, epgURL: form.epg)
        } else {
            await app.addXtream(name: form.name, server: form.server, username: form.username, password: form.password)
        }
        if app.alertMessage == nil { onSaved() }
    }
}
