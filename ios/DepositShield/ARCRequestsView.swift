import SwiftUI

struct ARCRequestsView: View {
    let associationId: UUID
    let isBoard: Bool
    let membership: MembershipRow
    @Binding var path: [CommunityRoute]

    @State private var loadState: LoadState = .loading
    @State private var requests: [ARCRequest] = []
    @State private var actingOn: UUID?
    @State private var error: String?

    private var visibleRequests: [ARCRequest] {
        isBoard ? requests : requests.filter { $0.requester == membership.user_id }
    }

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            AsyncStateView(state: loadState, retry: { Task { await load() } }) {
                if visibleRequests.isEmpty {
                    EmptyStateCard(icon: "square.and.pencil", title: isBoard ? "No ARC requests yet" : "No requests yet", description: isBoard ? "Resident architectural review requests will show up here." : "Submit a request before starting exterior changes \u{2014} paint, fencing, additions, and more.", actionTitle: isBoard ? nil : "New request", action: isBoard ? nil : { path.append(.newARC) })
                        .padding(20)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            if let error {
                                Text(error).font(.system(size: 13)).foregroundStyle(DS.clay)
                            }
                            ForEach(visibleRequests) { request in
                                RequestCard(request: request, isBoard: isBoard, isOwn: request.requester == membership.user_id, acting: actingOn == request.id, onApprove: { act(request, status: .approved) }, onDeny: { act(request, status: .denied) }, onWithdraw: { withdraw(request) })
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationTitle(isBoard ? "ARC requests" : "My ARC requests")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isBoard {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { path.append(.newARC) } label: {
                        Image(systemName: "plus.circle.fill").foregroundStyle(DS.brass)
                    }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loadState = .loading
        do {
            requests = try await HOADataStore.fetchARCRequests(associationId: associationId)
            loadState = .loaded
        } catch {
            loadState = .failed("Couldn't load ARC requests.\n\(HOAError.from(error).localizedDescription)")
        }
    }

    private func act(_ request: ARCRequest, status: ARCStatus) {
        error = nil
        actingOn = request.id
        Task {
            do {
                try await HOADataStore.decideARCRequest(id: request.id, status: status, note: nil)
                await load()
                await MainActor.run { actingOn = nil }
            } catch {
                await MainActor.run {
                    actingOn = nil
                    self.error = HOAError.from(error).localizedDescription
                }
            }
        }
    }

    private func withdraw(_ request: ARCRequest) {
        error = nil
        actingOn = request.id
        Task {
            do {
                try await HOADataStore.withdrawARCRequest(id: request.id)
                await load()
                await MainActor.run { actingOn = nil }
            } catch {
                await MainActor.run {
                    actingOn = nil
                    self.error = HOAError.from(error).localizedDescription
                }
            }
        }
    }
}

private struct RequestCard: View {
    let request: ARCRequest
    let isBoard: Bool
    let isOwn: Bool
    let acting: Bool
    let onApprove: () -> Void
    let onDeny: () -> Void
    let onWithdraw: () -> Void

    private var tone: StatusTone {
        switch request.status {
        case .pending: return .progress
        case .approved: return .success
        case .denied: return .neutral
        case .withdrawn: return .neutral
        }
    }

    var body: some View {
        LedgerCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(request.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(DS.ink)
                        if let unit = request.unit_label, !unit.isEmpty {
                            Text(unit).font(.system(size: 12)).foregroundStyle(DS.brass)
                        }
                    }
                    Spacer()
                    StatusPill(label: request.status.label, tone: tone)
                }
                if let description = request.description, !description.isEmpty {
                    Text(description).font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.65))
                }
                if let note = request.decision_note, !note.isEmpty {
                    Text("Board note: \(note)").font(.system(size: 12)).foregroundStyle(DS.ink.opacity(0.5)).italic()
                }
                Text("Submitted \(Formatters.date(request.created_at))").font(.system(size: 11)).foregroundStyle(DS.ink.opacity(0.4))

                if isBoard && request.status == .pending {
                    HStack(spacing: 10) {
                        actionButton("Approve", tint: DS.emerald, action: onApprove)
                        actionButton("Deny", tint: DS.clay, action: onDeny)
                    }
                } else if isOwn && request.status == .pending {
                    actionButton("Withdraw", tint: DS.ink.opacity(0.5), action: onWithdraw)
                }
            }
        }
    }

    private func actionButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 6) {
                if acting { ProgressView().tint(tint).scaleEffect(0.7) }
                Text(title)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(tint.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(acting)
    }
}
