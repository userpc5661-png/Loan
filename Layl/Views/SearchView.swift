import SwiftUI

@MainActor
@Observable
final class SearchModel {
    var query = ""
    var scope: SearchScope = .all
    var results: [SearchHit] = []
    private var task: Task<Void, Never>?

    func schedule(app: AppModel) {
        task?.cancel()
        let text = query
        let scope = self.scope
        task = Task {
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard !Task.isCancelled else { return }
            results = app.search(text, scope: scope)
        }
    }

    func commit(app: AppModel) {
        app.rememberSearch(query)
        results = app.search(query, scope: scope)
    }
}

struct SearchView: View {
    @Environment(AppModel.self) private var app
    @State private var model = SearchModel()

    var body: some View {
        LaylScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(Copy.search)
                        .font(.system(size: 32, weight: .bold))
                        .padding(.horizontal, 16)
                    field
                    scopes
                    content
                }
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: app.revision) { _, _ in
            model.results = app.search(model.query, scope: model.scope)
        }
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(LaylColor.secondary)
            TextField(Copy.searchPrompt, text: Binding(get: { model.query }, set: { model.query = $0 }))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { model.commit(app: app) }
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(LaylColor.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .onChange(of: model.query) { _, _ in
            model.schedule(app: app)
        }
    }

    private var scopes: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(SearchScope.allCases) { scope in
                    Button {
                        model.scope = scope
                        model.results = app.search(model.query, scope: scope)
                    } label: {
                        Text(scope.title)
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                    }
                    .buttonStyle(.glass(.regular.tint(model.scope == scope ? Color.white.opacity(0.2) : Color.clear)))
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var content: some View {
        if model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !app.recentSearches.isEmpty {
                Text(Copy.recent)
                    .font(.headline)
                    .padding(.horizontal, 16)
                ForEach(app.recentSearches, id: \.self) { term in
                    Button {
                        model.query = term
                        model.commit(app: app)
                    } label: {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(LaylColor.tertiary)
                            Text(term)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            posterRail(title: Copy.trending, items: Array((app.catalog.series.map(\.item) + app.catalog.movies).prefix(12)))
        } else if model.results.isEmpty {
            EmptyPane(title: Copy.noResults, message: Copy.noResultsBody)
                .padding(.top, 24)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(model.results) { hit in
                    hitRow(hit)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func posterRail(title: String, items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: title).padding(.horizontal, 16)
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink(value: Route.detail(item.id)) {
                            PosterCard(item: item, width: 118)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private func hitRow(_ hit: SearchHit) -> some View {
        switch hit {
        case .media(let item):
            NavigationLink(value: Route.detail(item.id)) {
                row(title: item.title, subtitle: item.genreLine, asset: item.posterAsset, url: item.posterURL)
            }
            .buttonStyle(.plain)
        case .channel(let channel):
            NavigationLink(value: Route.channel(channel.id)) {
                row(title: channel.name, subtitle: channel.category, asset: channel.logoAsset, url: channel.logoURL)
            }
            .buttonStyle(.plain)
        case .clip(let clip):
            Button {
                app.play(clip: clip)
            } label: {
                row(title: clip.title, subtitle: clip.creator, asset: clip.posterAsset, url: nil)
            }
            .buttonStyle(.plain)
        }
    }

    private func row(title: String, subtitle: String, asset: String?, url: String?) -> some View {
        HStack(spacing: 12) {
            Artwork(asset: asset, url: url)
                .frame(width: 72, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                Text(subtitle).font(.system(size: 13)).foregroundStyle(LaylColor.secondary).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.left")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LaylColor.tertiary)
                .flipsForRightToLeftLayoutDirection(false)
        }
    }
}
