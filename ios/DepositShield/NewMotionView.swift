import SwiftUI

struct NewMotionView: View {
    let associationId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var hasCloseDate = false
    @State private var closesAt = Date().addingTimeInterval(7 * 86400)
    @State private var creating = false
    @State private var error: String?

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    LedgerCard {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Motion").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
                                TextField("e.g. Approve 2027 landscaping contract", text: $title).ledgerFieldStyle()
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Description").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
                                TextEditor(text: $description)
                                    .frame(height: 100)
                                    .padding(8)
                                    .background(DS.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(DS.ink.opacity(0.1)))
                            }
                            Toggle(isOn: $hasCloseDate.animation()) {
                                Text("Set a closing date").font(.system(size: 13.5)).foregroundStyle(DS.ink.opacity(0.7))
                            }
                            .tint(DS.brass)
                            if hasCloseDate {
                                DatePicker("", selection: $closesAt, displayedComponents: [.date])
                                    .datePickerStyle(.graphical)
                                    .labelsHidden()
                            }
                        }
                    }
                    if let error {
                        Text(error).font(.system(size: 13)).foregroundStyle(DS.clay)
                    }
                    LedgerButton(title: creating ? "Opening\u{2026}" : "Open motion for a vote", isLoading: creating, disabled: creating || title.trimmingCharacters(in: .whitespaces).isEmpty) {
                        submit()
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("New motion")
        .navigationBarTitleDisplayMode(.inline)
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
                _ = try await HOADataStore.createMotion(associationId: associationId, createdBy: userId, title: title, description: description.isEmpty ? nil : description, closesAt: hasCloseDate ? Formatters.isoTimestamp(closesAt) : nil)
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
