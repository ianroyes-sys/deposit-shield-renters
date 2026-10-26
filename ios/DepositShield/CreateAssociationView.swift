import SwiftUI

/// Calls the create_association RPC — creator becomes board, codes are
/// auto-generated server-side.
struct CreateAssociationView: View {
    let onCreated: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var city = ""
    @State private var state = ""
    @State private var displayName = ""
    @State private var unitLabel = ""
    @State private var creating = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                DS.paper.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill").font(.system(size: 30)).foregroundStyle(DS.brass)
                            Text("Start your association").font(DS.serif(22)).foregroundStyle(DS.ink)
                            Text("You'll be the first board member. Join codes are generated automatically.")
                                .font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.55)).multilineTextAlignment(.center)
                        }
                        .padding(.top, 12)

                        LedgerCard {
                            VStack(alignment: .leading, spacing: 14) {
                                field("Association name", "e.g. Elmwood Homeowners Association", $name)
                                HStack(spacing: 12) {
                                    field("City", "", $city)
                                    field("State", "TX", $state).frame(width: 90)
                                }
                                field("Your name", "e.g. Jordan Lee", $displayName)
                                field("Your unit / address (optional)", "e.g. 14B", $unitLabel)
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
                                if creating { ProgressView().tint(.white).scaleEffect(0.85) }
                                Text(creating ? "Creating\u{2026}" : "Create association")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(LinearGradient(colors: [DS.brass, DS.brassLight], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(creating || name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New association")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func field(_ label: String, _ placeholder: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
            TextField(placeholder, text: text).ledgerFieldStyle()
        }
    }

    private func submit() {
        error = nil
        creating = true
        Task {
            do {
                _ = try await HOADataStore.createAssociation(
                    name: name, city: city.isEmpty ? nil : city, state: state.isEmpty ? nil : state,
                    displayName: displayName.isEmpty ? nil : displayName, unitLabel: unitLabel.isEmpty ? nil : unitLabel
                )
                await onCreated()
                await MainActor.run {
                    creating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    creating = false
                    self.error = HOAError.from(error).localizedDescription
                }
            }
        }
    }
}
