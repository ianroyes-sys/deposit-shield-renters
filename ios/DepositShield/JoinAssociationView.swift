import SwiftUI

/// Calls the join_association RPC — role (board/resident) is inferred
/// server-side from the code prefix (B-xxxx vs R-xxxx).
struct JoinAssociationView: View {
    let onJoined: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var displayName = ""
    @State private var unitLabel = ""
    @State private var joining = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                DS.paper.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 6) {
                            Image(systemName: "number.circle.fill").font(.system(size: 30)).foregroundStyle(DS.brass)
                            Text("Join with a code").font(DS.serif(22)).foregroundStyle(DS.ink)
                            Text("Get this from your HOA board \u{2014} it starts with B- or R-.")
                                .font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.55)).multilineTextAlignment(.center)
                        }
                        .padding(.top, 12)

                        LedgerCard {
                            VStack(alignment: .leading, spacing: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Join code").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
                                    TextField("R-XXXXXXXX", text: $code)
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                        .font(DS.mono(16, weight: .semibold))
                                        .ledgerFieldStyle()
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Your name").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
                                    TextField("e.g. Jordan Lee", text: $displayName).ledgerFieldStyle()
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Your unit / address (optional)").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
                                    TextField("e.g. 14B", text: $unitLabel).ledgerFieldStyle()
                                }
                            }
                        }

                        if let error {
                            Text(error).font(.system(size: 13)).foregroundStyle(DS.clay)
                        }

                        Button {
                            Haptics.tap()
                            submit()
                        } label: {
                            HStack(spacing: 8) {
                                if joining { ProgressView().tint(.white).scaleEffect(0.85) }
                                Text(joining ? "Joining\u{2026}" : "Join association")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(LinearGradient(colors: [DS.brass, DS.brassLight], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(joining || code.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Join association")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submit() {
        error = nil
        joining = true
        Task {
            do {
                _ = try await HOADataStore.joinAssociation(
                    code: code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                    displayName: displayName.isEmpty ? nil : displayName,
                    unitLabel: unitLabel.isEmpty ? nil : unitLabel
                )
                await onJoined()
                await MainActor.run {
                    joining = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    joining = false
                    self.error = HOAError.from(error).localizedDescription
                }
            }
        }
    }
}
