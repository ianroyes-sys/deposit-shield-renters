import SwiftUI

/// Ports p/[id]/compare/page.tsx.
struct CompareView: View {
    let propertyId: UUID

    @State private var loadState: LoadState = .loading
    @State private var detail: PropertyDetail?
    @State private var signedURLs: [String: URL] = [:]

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            AsyncStateView(state: loadState, retry: { Task { await load() } }) {
                if let detail {
                    content(detail)
                }
            }
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func content(_ detail: PropertyDetail) -> some View {
        let hasAnyPhotos = detail.rooms.contains { !$0.moveInPhotos.isEmpty || !$0.moveOutPhotos.isEmpty }

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Move-in vs. move-out").font(DS.serif(26)).foregroundStyle(DS.ink)
                    Text("Room by room, side by side.").font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.5))
                }
                LedgerRuleDivider()

                if !hasAnyPhotos {
                    EmptyStateCard(icon: "square.split.2x1", title: "Nothing to compare yet", description: "Capture at least one move-in and one move-out photo to see a comparison.")
                } else {
                    ForEach(detail.rooms) { room in
                        let worse = room.moveOutPhotos.filter { $0.condition != .good }
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Text(room.room.name).font(DS.serif(19)).foregroundStyle(DS.ink)
                                if !worse.isEmpty {
                                    StatusPill(label: "Condition changed", tone: .neutral)
                                        .foregroundStyle(DS.clay)
                                }
                            }
                            HStack(alignment: .top, spacing: 14) {
                                PhaseColumn(label: "Move-in", photos: room.moveInPhotos, signedURLs: signedURLs)
                                PhaseColumn(label: "Move-out", photos: room.moveOutPhotos, signedURLs: signedURLs)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func load() async {
        loadState = .loading
        do {
            guard let detail = try await DataStore.fetchPropertyDetail(propertyId: propertyId) else {
                loadState = .failed("This property could not be found.")
                return
            }
            self.detail = detail
            let paths = detail.rooms.flatMap { $0.moveInPhotos.map(\.storage_path) + $0.moveOutPhotos.map(\.storage_path) }
            signedURLs = await DataStore.signedURLs(bucket: "photos", paths: paths)
            loadState = .loaded
        } catch {
            loadState = .failed("Couldn't load this comparison.\n\(error.localizedDescription)")
        }
    }
}

private struct PhaseColumn: View {
    let label: String
    let photos: [Photo]
    let signedURLs: [String: URL]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased()).font(DS.mono(10.5, weight: .semibold)).tracking(0.6).foregroundStyle(DS.brass)
            if photos.isEmpty {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(DS.ink.opacity(0.1), style: StrokeStyle(dash: [5, 5]))
                    .frame(height: 90)
                    .overlay(Text("No photos").font(.system(size: 11)).foregroundStyle(DS.ink.opacity(0.4)))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(photos) { photo in
                        VStack(spacing: 4) {
                            ZStack {
                                DS.ink.opacity(0.05)
                                if let url = signedURLs[photo.storage_path] {
                                    AsyncImage(url: url) { p in
                                        if case .success(let img) = p { img.resizable().aspectRatio(contentMode: .fill) }
                                    }
                                }
                            }
                            .aspectRatio(1, contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            ConditionBadge(condition: photo.condition)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
