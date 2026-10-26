import SwiftUI

struct NewAnnouncementView: View {
    let associationId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var body_ = ""
    @State private var pinned = false
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
                                Text("Title").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
                                TextField("e.g. Pool hours changing for winter", text: $title).ledgerFieldStyle()
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Details").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
                                TextEditor(text: $body_)
                                    .frame(height: 120)
                                    .padding(8)
                                    .background(DS.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(DS.ink.opacity(0.1)))
                            }
                            Toggle(isOn: $pinned) {
                                Text("Pin to top").font(.system(size: 13.5)).foregroundStyle(DS.ink.opacity(0.7))
                            }
                            .tint(DS.brass)
                        }
                    }
                    if let error {
                        Text(error).font(.system(size: 13)).foregroundStyle(DS.clay)
                    }
                    LedgerButton(title: creating ? "Posting\u{2026}" : "Post announcement", isLoading: creating, disabled: creating || title.trimmingCharacters(in: .whitespaces).isEmpty) {
                        submit()
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("New announcement")
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
                _ = try await HOADataStore.createAnnouncement(associationId: associationId, author: userId, title: title, body: body_.isEmpty ? nil : body_, pinned: pinned)
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
