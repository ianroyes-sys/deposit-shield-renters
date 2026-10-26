import SwiftUI

struct NewViolationView: View {
    let associationId: UUID
    @Binding var path: [CommunityRoute]

    @State private var category: ViolationCategory = .landscaping
    @State private var unitLabel = ""
    @State private var address = ""
    @State private var ruleReference = ""
    @State private var description = ""
    @State private var creating = false
    @State private var error: String?
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    LedgerCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Category").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                                ForEach(ViolationCategory.allCases) { cat in
                                    Button {
                                        Haptics.tap()
                                        category = cat
                                    } label: {
                                        Text(cat.rawValue)
                                            .font(.system(size: 12.5, weight: .medium))
                                            .foregroundStyle(category == cat ? .white : DS.ink.opacity(0.7))
                                            .padding(.vertical, 10)
                                            .frame(maxWidth: .infinity)
                                            .background(category == cat ? DS.brass : DS.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(DS.ink.opacity(category == cat ? 0 : 0.1)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            fieldRow("Unit / lot", "e.g. 14B", $unitLabel)
                            fieldRow("Address (optional)", "e.g. 14B Elmwood Ct", $address)
                            fieldRow("Rule reference", "e.g. CC&R 4.2", $ruleReference)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Description").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
                                TextEditor(text: $description)
                                    .frame(height: 100)
                                    .padding(8)
                                    .background(DS.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(DS.ink.opacity(0.1)))
                                    .font(.system(size: 14))
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
                            if creating { ProgressView().tint(.white).scaleEffect(0.85) }
                            Text(creating ? "Opening case\u{2026}" : "Open violation case")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [DS.brass, DS.brassLight], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(creating)

                    Text("Add evidence photos on the next screen \u{2014} hashed and timestamped the moment you capture them.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(DS.ink.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            }
        }
        .navigationTitle("New violation")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            CommunitiesPaywallView(associationId: associationId, title: "Upgrade to log more violations", description: "Free communities can track 2 open violations at a time. Upgrade to Communities Pro for unlimited enforcement tracking.") {
                showPaywall = false
                submit()
            }
        }
    }

    private func fieldRow(_ label: String, _ placeholder: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
            TextField(placeholder, text: text).ledgerFieldStyle()
        }
    }

    private func submit() {
        guard let userId = supabase.auth.currentUser?.id else {
            error = "Your session expired \u{2014} sign in again."
            return
        }
        error = nil
        creating = true
        Task {
            do {
                let violation = try await HOADataStore.createViolation(
                    associationId: associationId, createdBy: userId,
                    unitLabel: unitLabel.isEmpty ? nil : unitLabel,
                    address: address.isEmpty ? nil : address,
                    category: category.rawValue,
                    ruleReference: ruleReference.isEmpty ? nil : ruleReference,
                    description: description.isEmpty ? nil : description
                )
                await MainActor.run {
                    creating = false
                    path.removeLast()
                    path.append(.violationDetail(violation.id))
                }
            } catch {
                let mapped = HOAError.from(error)
                await MainActor.run {
                    creating = false
                    if mapped == .freeViolationLimit {
                        showPaywall = true
                    } else {
                        self.error = mapped.localizedDescription
                    }
                }
            }
        }
    }
}
