import SwiftUI

/// The home screen for a single association, once joined/created — a
/// role-gated menu (board sees everything; residents see a reduced set)
/// feeding one shared NavigationStack path for every feature screen.
struct CommunityShellView: View {
    let membership: MembershipRow

    @State private var path: [CommunityRoute] = []
    @State private var showPaywall = false
    @State private var isPaid: Bool = false

    private var isBoard: Bool { membership.role == .board }
    private var associationId: UUID { membership.association_id }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                DS.paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        LedgerRuleDivider()

                        if isBoard {
                            MenuRow(icon: "exclamationmark.triangle.fill", title: "Violations", subtitle: "Open enforcement cases") { path.append(.violations) }
                            MenuRow(icon: "chart.bar.doc.horizontal.fill", title: "Consistency Ledger", subtitle: "Even enforcement, documented") { path.append(.ledger) }
                            MenuRow(icon: "checkmark.rectangle.stack.fill", title: "Inspections", subtitle: "Common-area walk-throughs") { path.append(.inspections) }
                            MenuRow(icon: "square.and.pencil", title: "ARC Requests", subtitle: "Architectural review") { path.append(.arc) }
                            MenuRow(icon: "megaphone.fill", title: "Board Room", subtitle: "Announcements & motions") { path.append(.boardRoom) }
                            MenuRow(icon: "person.2.fill", title: "Members", subtitle: "Directory & join codes") { path.append(.members) }
                        } else {
                            MenuRow(icon: "megaphone.fill", title: "Announcements", subtitle: "What the board is sharing") { path.append(.boardRoom) }
                            MenuRow(icon: "square.and.pencil", title: "My ARC Requests", subtitle: "Submit or track a request") { path.append(.arc) }
                            MenuRow(icon: "chart.bar.doc.horizontal.fill", title: "Consistency Ledger", subtitle: "How enforcement is tracked") { path.append(.ledger) }
                            MenuRow(icon: "person.2.fill", title: "Directory", subtitle: "Who's in this community") { path.append(.members) }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(membership.associations.name.uppercased())
                        .font(DS.mono(11, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(DS.brass)
                        .lineLimit(1)
                }
            }
            .navigationDestination(for: CommunityRoute.self) { route in
                destination(for: route)
            }
            .sheet(isPresented: $showPaywall) {
                CommunitiesPaywallView(associationId: associationId) {
                    isPaid = true
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(DS.brass)
                Text(isBoard ? "Board member" : "Resident")
                    .font(DS.mono(11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(DS.brass)
            }
            Text(membership.associations.name).font(DS.serif(26)).foregroundStyle(DS.ink)
            if isPaid {
                StatusPill(label: "Communities Pro", tone: .brass)
            } else if isBoard {
                HStack(spacing: 10) {
                    StatusPill(label: "Free plan", tone: .neutral)
                    Button {
                        Haptics.tap()
                        showPaywall = true
                    } label: {
                        Text("Upgrade").font(.system(size: 12, weight: .semibold)).foregroundStyle(DS.brass)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear { isPaid = membership.associations.is_paid }
    }

    @ViewBuilder
    private func destination(for route: CommunityRoute) -> some View {
        switch route {
        case .violations:
            ViolationsListView(associationId: associationId, isBoard: isBoard, path: $path)
        case .newViolation:
            NewViolationView(associationId: associationId, path: $path)
        case .violationDetail(let id):
            ViolationDetailView(violationId: id, associationId: associationId, isBoard: isBoard)
        case .ledger:
            ConsistencyLedgerView(associationId: associationId, isBoard: isBoard)
        case .inspections:
            InspectionsView(associationId: associationId, isBoard: isBoard, path: $path)
        case .newInspectionArea:
            NewInspectionAreaView(associationId: associationId)
        case .logInspection(let areaId):
            LogInspectionView(associationId: associationId, areaId: areaId)
        case .arc:
            ARCRequestsView(associationId: associationId, isBoard: isBoard, membership: membership, path: $path)
        case .newARC:
            NewARCRequestView(associationId: associationId, membership: membership)
        case .boardRoom:
            BoardRoomView(associationId: associationId, isBoard: isBoard, membership: membership, path: $path)
        case .newAnnouncement:
            NewAnnouncementView(associationId: associationId)
        case .newMotion:
            NewMotionView(associationId: associationId)
        case .members:
            MembersView(associationId: associationId, isBoard: isBoard)
        case .codes:
            JoinCodesView(associationId: associationId)
        }
    }
}

private struct MenuRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            LedgerCard(padding: 16) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(DS.brass50).frame(width: 42, height: 42)
                        Image(systemName: icon).foregroundStyle(DS.brass)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(DS.ink)
                        Text(subtitle).font(.system(size: 12)).foregroundStyle(DS.ink.opacity(0.5))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.25))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
