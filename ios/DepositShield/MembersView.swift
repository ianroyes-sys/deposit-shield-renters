import SwiftUI

struct MembersView: View {
    let associationId: UUID
    let isBoard: Bool

    @State private var loadState: LoadState = .loading
    @State private var members: [AssociationMember] = []
    @State private var error: String?
    @State private var removing: UUID?

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            AsyncStateView(state: loadState, retry: { Task { await load() } }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if isBoard {
                            NavigationLink {
                                JoinCodesView(associationId: associationId)
                            } label: {
                                LedgerCard(padding: 16) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "qrcode").font(.system(size: 20)).foregroundStyle(DS.brass)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Join codes").font(.system(size: 15, weight: .semibold)).foregroundStyle(DS.ink)
                                            Text("Invite board members and residents").font(.system(size: 12)).foregroundStyle(DS.ink.opacity(0.5))
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").foregroundStyle(DS.ink.opacity(0.3))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Directory (\(members.count))").font(DS.serif(18)).foregroundStyle(DS.ink)
                            if let error {
                                Text(error).font(.system(size: 13)).foregroundStyle(DS.clay)
                            }
                            ForEach(members) { member in
                                MemberRow(member: member, isBoard: isBoard, removing: removing == member.id, onRemove: { remove(member) })
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Members")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loadState = .loading
        do {
            members = try await HOADataStore.fetchMembers(associationId: associationId)
            loadState = .loaded
        } catch {
            loadState = .failed("Couldn't load the directory.\n\(HOAError.from(error).localizedDescription)")
        }
    }

    private func remove(_ member: AssociationMember) {
        error = nil
        removing = member.id
        Task {
            do {
                try await HOADataStore.removeMember(memberId: member.id)
                await load()
                await MainActor.run { removing = nil }
            } catch {
                await MainActor.run {
                    removing = nil
                    self.error = HOAError.from(error).localizedDescription
                }
            }
        }
    }
}

private struct MemberRow: View {
    let member: AssociationMember
    let isBoard: Bool
    let removing: Bool
    let onRemove: () -> Void

    @State private var confirming = false

    var body: some View {
        LedgerCard(padding: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(DS.brass50).frame(width: 38, height: 38)
                    Text(initials).font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.brass)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.display_name?.isEmpty == false ? member.display_name! : "Unnamed member").font(.system(size: 14.5, weight: .medium)).foregroundStyle(DS.ink)
                    Text([member.unit_label, member.role == .board ? "Board" : "Resident"].compactMap { $0 }.joined(separator: " \u{b7} "))
                        .font(.system(size: 12)).foregroundStyle(DS.ink.opacity(0.5))
                }
                Spacer()
                if isBoard {
                    if confirming {
                        HStack(spacing: 6) {
                            Button {
                                onRemove()
                            } label: {
                                if removing { ProgressView().scaleEffect(0.7) } else { Text("Remove").font(.system(size: 12, weight: .semibold)).foregroundStyle(DS.clay) }
                            }
                            .buttonStyle(.plain)
                            Button("Cancel") { confirming = false }
                                .font(.system(size: 12)).foregroundStyle(DS.ink.opacity(0.4))
                                .buttonStyle(.plain)
                        }
                    } else {
                        Button {
                            confirming = true
                        } label: {
                            Image(systemName: "minus.circle").foregroundStyle(DS.ink.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var initials: String {
        let name = member.display_name?.isEmpty == false ? member.display_name! : "?"
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}
