import SwiftUI

/// Board-only per RLS. Residents who somehow reach this screen (they can't
/// via the menu) get an honest empty state rather than a crash.
struct JoinCodesView: View {
    let associationId: UUID

    @State private var loadState: LoadState = .loading
    @State private var codes: [AssociationCode] = []
    @State private var associationName = ""
    @State private var shareText: String?

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            AsyncStateView(state: loadState, retry: { Task { await load() } }) {
                if codes.isEmpty {
                    EmptyStateCard(icon: "lock.shield", title: "Codes aren't visible here", description: "Only board members can view join codes.")
                        .padding(20)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(codes, id: \.code) { code in
                                CodeCard(code: code, associationName: associationName, onShare: { shareText = shareMessage(for: code) })
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationTitle("Join codes")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: Binding(get: { shareText.map(IdentifiableText.init) }, set: { shareText = $0?.text })) { wrapped in
            ShareSheet(items: [wrapped.text])
        }
    }

    private func shareMessage(for code: AssociationCode) -> String {
        let roleLabel = code.role == .board ? "board member" : "resident"
        return "Join \(associationName.isEmpty ? "our association" : associationName) on Deposit Shield as a \(roleLabel) \u{2014} code: \(code.code)"
    }

    private func load() async {
        loadState = .loading
        do {
            let memberships = try await HOADataStore.fetchMemberships()
            associationName = memberships.first { $0.association_id == associationId }?.associations.name ?? ""
            codes = try await HOADataStore.fetchCodes(associationId: associationId)
            loadState = .loaded
        } catch {
            loadState = .failed("Couldn't load join codes.\n\(HOAError.from(error).localizedDescription)")
        }
    }
}

private struct CodeCard: View {
    let code: AssociationCode
    let associationName: String
    let onShare: () -> Void

    var body: some View {
        LedgerCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(code.role == .board ? "Board code" : "Resident code").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.6))
                    Spacer()
                    if code.role == .resident {
                        StatusPill(label: "Always free", tone: .brass)
                    }
                }
                Text(code.code).font(DS.mono(24, weight: .bold)).foregroundStyle(DS.ink).tracking(1)
                Button {
                    Haptics.tap()
                    onShare()
                } label: {
                    Text("Share invite")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(DS.brass, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct IdentifiableText: Identifiable {
    let text: String
    var id: String { text }
}
