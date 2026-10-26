import SwiftUI

struct ViolationsListView: View {
    let associationId: UUID
    let isBoard: Bool
    @Binding var path: [CommunityRoute]

    @State private var loadState: LoadState = .loading
    @State private var violations: [Violation] = []

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            AsyncStateView(state: loadState, retry: { Task { await load() } }) {
                if violations.isEmpty {
                    EmptyStateCard(icon: "checkmark.seal", title: "No violations logged", description: "When you open a case, it shows up here with its full escalation history.", actionTitle: isBoard ? "New violation" : nil, action: isBoard ? { path.append(.newViolation) } : nil)
                        .padding(20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(violations) { v in
                                Button {
                                    Haptics.tap()
                                    path.append(.violationDetail(v.id))
                                } label: {
                                    ViolationRow(violation: v)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationTitle("Violations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isBoard {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        path.append(.newViolation)
                    } label: {
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
            violations = try await HOADataStore.fetchViolations(associationId: associationId)
            loadState = .loaded
        } catch {
            loadState = .failed("Couldn't load violations.\n\(HOAError.from(error).localizedDescription)")
        }
    }
}

private struct ViolationRow: View {
    let violation: Violation

    private var tone: StatusTone {
        switch violation.status {
        case .open: return .neutral
        case .courtesy_sent, .warning_sent: return .progress
        case .fine_issued: return .neutral
        case .resolved: return .success
        case .dismissed: return .neutral
        }
    }

    var body: some View {
        LedgerCard(padding: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(violation.unit_label ?? violation.address ?? "Unit not set").font(.system(size: 15, weight: .semibold)).foregroundStyle(DS.ink)
                    Text(violation.category).font(.system(size: 12)).foregroundStyle(DS.brass)
                    if let rule = violation.rule_reference, !rule.isEmpty {
                        Text(rule).font(DS.mono(10.5)).foregroundStyle(DS.ink.opacity(0.4))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    StatusPill(label: violation.status.label, tone: tone)
                    Text(Formatters.date(violation.opened_at)).font(.system(size: 10.5)).foregroundStyle(DS.ink.opacity(0.4))
                }
            }
        }
    }
}
