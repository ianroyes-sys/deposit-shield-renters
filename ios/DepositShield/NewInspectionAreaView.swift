import SwiftUI

struct NewInspectionAreaView: View {
    let associationId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var cadenceDays = ""
    @State private var creating = false
    @State private var error: String?
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    LedgerCard {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Area name").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
                                TextField("e.g. Pool & clubhouse", text: $name).ledgerFieldStyle()
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Inspection cadence (days, optional)").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
                                TextField("e.g. 30", text: $cadenceDays).keyboardType(.numberPad).ledgerFieldStyle()
                            }
                        }
                    }
                    if let error {
                        Text(error).font(.system(size: 13)).foregroundStyle(DS.clay)
                    }
                    LedgerButton(title: creating ? "Adding\u{2026}" : "Add area", isLoading: creating, disabled: creating || name.trimmingCharacters(in: .whitespaces).isEmpty) {
                        submit()
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("New area")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            CommunitiesPaywallView(associationId: associationId, title: "Upgrade to add more areas", description: "Free communities can track 1 inspection area. Upgrade to Communities Pro for unlimited areas.") {
                showPaywall = false
                submit()
            }
        }
    }

    private func submit() {
        error = nil
        creating = true
        Task {
            do {
                _ = try await HOADataStore.createInspectionArea(associationId: associationId, name: name, cadenceDays: Int(cadenceDays), sort: 0)
                await MainActor.run {
                    creating = false
                    dismiss()
                }
            } catch {
                let mapped = HOAError.from(error)
                await MainActor.run {
                    creating = false
                    if mapped == .freeAreaLimit {
                        showPaywall = true
                    } else {
                        self.error = mapped.localizedDescription
                    }
                }
            }
        }
    }
}
