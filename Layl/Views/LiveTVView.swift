import SwiftUI

struct LiveTVView: View {
    @Environment(AppModel.self) private var app
    @State private var category = Copy.all
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var categories: [String] {
        var names = [Copy.all]
        for channel in app.catalog.channels where !names.contains(channel.category) {
            names.append(channel.category)
        }
        return names
    }

    private var channels: [LiveChannel] {
        let all = app.catalog.channels
        guard category != Copy.all else { return all }
        return all.filter { $0.category == category }
    }

    var body: some View {
        LaylScreen {
            Group {
                if sizeClass == .regular {
                    HStack(spacing: 0) {
                        categoryColumn.frame(width: 220)
                        Divider().overlay(Color.white.opacity(0.08))
                        channelList
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        chipRow
                        channelList
                    }
                }
            }
        }
        .navigationTitle(Copy.live)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var chipRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { name in
                    Button(name) { category = name }
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .buttonStyle(.glass(.regular.tint(category == name ? Color.white.opacity(0.22) : Color.clear)))
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }

    private var categoryColumn: some View {
        List(categories, id: \.self) { name in
            Button(name) { category = name }
                .font(.system(size: 16, weight: category == name ? .bold : .regular))
                .foregroundStyle(.white)
        }
        .scrollContentBackground(.hidden)
    }

    private var channelList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(channels) { channel in
                    NavigationLink(value: Route.channel(channel.id)) {
                        channelRow(channel)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
    }

    private func channelRow(_ channel: LiveChannel) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Artwork(asset: channel.logoAsset, url: channel.logoURL, system: "tv")
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name)
                    .font(.system(size: 16, weight: .semibold))
                Text(channel.currentProgram()?.title ?? Copy.noEPG)
                    .font(.system(size: 13))
                    .foregroundStyle(LaylColor.secondary)
                    .lineLimit(1)
                if let current = channel.currentProgram() {
                    WatchBar(fraction: fraction(current))
                        .frame(width: 120)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(Copy.liveBadge)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(LaylColor.pg, in: Capsule())
                Text("\(channel.number)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LaylColor.tertiary)
            }
        }
        .padding(10)
        .background(LaylColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func fraction(_ program: EPGProgram) -> Double {
        let length = program.end.timeIntervalSince(program.start)
        guard length > 0 else { return 0 }
        return min(max(Date.now.timeIntervalSince(program.start) / length, 0), 1)
    }
}

struct ChannelDetailView: View {
    @Environment(AppModel.self) private var app
    let channelID: String
    private var channel: LiveChannel? { app.catalog.channel(id: channelID) }

    var body: some View {
        LaylScreen {
            if let channel {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ZStack {
                            Artwork(asset: channel.logoAsset, url: channel.logoURL, system: "tv")
                                .frame(height: 220)
                                .clipped()
                            LinearGradient(colors: [.clear, LaylColor.backgroundDeep], startPoint: .center, endPoint: .bottom)
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            Text(channel.name)
                                .font(.system(size: 32, weight: .bold))
                            Text(channel.category)
                                .foregroundStyle(LaylColor.secondary)
                            WhiteActionButton(title: Copy.play, systemImage: "play.fill") {
                                app.play(channel: channel)
                            }
                            .environment(\.layoutDirection, .leftToRight)
                            Text(Copy.programs)
                                .font(.title3.weight(.bold))
                                .padding(.top, 8)
                            let upcoming = channel.upcoming(limit: 8)
                            if upcoming.isEmpty {
                                Text(Copy.noEPG).foregroundStyle(LaylColor.secondary)
                            } else {
                                ForEach(upcoming) { program in
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(program.start, format: .dateTime.hour().minute())
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(LaylColor.lilac)
                                            Text(program.end, format: .dateTime.hour().minute())
                                                .font(.system(size: 12))
                                                .foregroundStyle(LaylColor.tertiary)
                                        }
                                        .frame(width: 64, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(program.title).font(.system(size: 16, weight: .semibold))
                                                if program.contains(.now) {
                                                    Text(Copy.now)
                                                        .font(.system(size: 11, weight: .bold))
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(LaylColor.pg, in: Capsule())
                                                }
                                            }
                                            Text(program.overview)
                                                .font(.system(size: 13))
                                                .foregroundStyle(LaylColor.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                        .frame(maxWidth: 760)
                        .frame(maxWidth: .infinity)
                    }
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .top)
            } else {
                EmptyPane(title: Copy.noResults, message: Copy.noResultsBody)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
