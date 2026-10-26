import SwiftUI

/// Ports p/[id]/page.tsx + room-checklist.tsx.
struct PropertyOverviewView: View {
    let propertyId: UUID
    @Binding var path: [AppRoute]

    @State private var loadState: LoadState = .loading
    @State private var detail: PropertyDetail?
    @State private var thumbnails: [String: URL] = [:]
    @State private var toast: String?

    private var activePhase: Phase {
        detail?.property.move_in_completed_at != nil ? .move_out : .move_in
    }

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            AsyncStateView(state: loadState, retry: { Task { await load() } }) {
                if let detail {
                    body(for: detail)
                }
            }
        }
        .toastOverlay($toast)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func body(for detail: PropertyDetail) -> some View {
        let property = detail.property
        let rooms = detail.rooms
        let activeRooms = max(rooms.count, 1)
        let documentedRooms = rooms.filter { !$0.photos(for: activePhase).isEmpty }.count
        let progress = Double(documentedRooms) / Double(activeRooms) * 100
        let canStartMoveOut = property.move_in_completed_at != nil && property.move_out_completed_at == nil
        let canCompare = detail.totalMoveInPhotos > 0 && detail.totalMoveOutPhotos > 0
        let canEvidence = property.move_out_completed_at != nil

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Formatters.propertyDisplayName(property)).font(DS.serif(26)).foregroundStyle(DS.ink)
                        Text(addressLabel(property)).font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.5))
                    }
                    Spacer()
                    HStack(spacing: 10) {
                        ProgressRingView(value: progress)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(activePhase.label) progress").font(.system(size: 10.5)).foregroundStyle(DS.ink.opacity(0.45))
                            Text("\(documentedRooms) / \(activeRooms) rooms").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink)
                        }
                    }
                    .padding(10)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(DS.ink.opacity(0.08)))
                }

                LedgerRuleDivider()

                actionButtons(property: property, canStartMoveOut: canStartMoveOut, canCompare: canCompare, canEvidence: canEvidence)

                Text("Rooms").font(DS.serif(19)).foregroundStyle(DS.ink)
                RoomChecklistGrid(rooms: rooms, activePhase: activePhase, thumbnails: thumbnails)

                DeadlineCardView(state: property.state, moveOutCompletedAt: property.move_out_completed_at)

                LedgerCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Deposit amount").font(.system(size: 11.5)).foregroundStyle(DS.ink.opacity(0.45))
                        Text(Formatters.cents(property.deposit_amount_cents)).font(DS.serif(24)).foregroundStyle(DS.ink)
                        if property.is_paid {
                            StatusPill(label: "Shield active", tone: .brass)
                        } else {
                            Text("Unlock unlimited photos, the full report, and the evidence packet \u{2014} one time, this property only.")
                                .font(.system(size: 12)).foregroundStyle(DS.ink.opacity(0.5))
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func actionButtons(property: Property, canStartMoveOut: Bool, canCompare: Bool, canEvidence: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                PillCTA(title: activePhase == .move_in ? "Continue walkthrough" : "Continue move-out walkthrough", filled: true) {
                    path.append(.walkthrough(propertyId: propertyId, phase: activePhase))
                }
                if property.move_in_completed_at != nil {
                    PillCTA(title: "Generate report", filled: false) {
                        path.append(.report(propertyId: propertyId))
                    }
                }
                if canStartMoveOut {
                    PillCTA(title: "Start move-out", filled: false) {
                        path.append(.walkthrough(propertyId: propertyId, phase: .move_out))
                    }
                }
                if canCompare {
                    PillCTA(title: "Compare", filled: false) {
                        path.append(.compare(propertyId: propertyId))
                    }
                }
                if canEvidence {
                    PillCTA(title: "Evidence packet", filled: false) {
                        path.append(.evidence(propertyId: propertyId))
                    }
                }
            }
        }
    }

    private func addressLabel(_ property: Property) -> String {
        guard let line1 = property.address_line1, !line1.isEmpty else { return "No address on file" }
        var label = line1
        if let city = property.city, !city.isEmpty { label += ", \(city)" }
        if let state = property.state, !state.isEmpty { label += ", \(state)" }
        return label
    }

    private func load() async {
        loadState = .loading
        do {
            guard let detail = try await DataStore.fetchPropertyDetail(propertyId: propertyId) else {
                loadState = .failed("This property could not be found.")
                return
            }
            self.detail = detail
            let phase = detail.property.move_in_completed_at != nil ? Phase.move_out : Phase.move_in
            let paths = detail.rooms.compactMap { $0.photos(for: phase).first?.storage_path }
            thumbnails = await DataStore.signedURLs(bucket: "photos", paths: paths)
            loadState = .loaded
        } catch {
            loadState = .failed("Couldn't load this property.\n\(error.localizedDescription)")
        }
    }
}

private struct PillCTA: View {
    let title: String
    let filled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(filled ? .white : DS.ink.opacity(0.75))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(filled ? DS.emerald : Color.white, in: Capsule())
                .overlay(Capsule().strokeBorder(filled ? Color.clear : DS.ink.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

private struct RoomChecklistGrid: View {
    let rooms: [RoomWithPhotos]
    let activePhase: Phase
    let thumbnails: [String: URL]

    var body: some View {
        if rooms.isEmpty {
            VStack {
                Text("No rooms yet.").font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(DS.ink.opacity(0.1), style: StrokeStyle(dash: [5, 5])))
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(rooms) { room in
                    let photos = room.photos(for: activePhase)
                    let done = !photos.isEmpty
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(DS.ink.opacity(0.05))
                            if let first = photos.first, let url = thumbnails[first.storage_path] {
                                AsyncImage(url: url) { p in
                                    if case .success(let img) = p { img.resizable().aspectRatio(contentMode: .fill) }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            } else {
                                Image(systemName: "photo").foregroundStyle(DS.ink.opacity(0.2))
                            }
                        }
                        .frame(width: 48, height: 48)
                        .clipped()

                        VStack(alignment: .leading, spacing: 1) {
                            Text(room.room.name).font(.system(size: 13.5, weight: .medium)).foregroundStyle(DS.ink).lineLimit(1)
                            Text("\(photos.count) photo\(photos.count == 1 ? "" : "s")").font(.system(size: 11)).foregroundStyle(DS.ink.opacity(0.45))
                        }
                        Spacer(minLength: 0)
                        Circle().fill(done ? DS.emerald : DS.ink.opacity(0.12)).frame(width: 9, height: 9)
                    }
                    .padding(10)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(DS.ink.opacity(0.08)))
                }
            }
        }
    }
}
