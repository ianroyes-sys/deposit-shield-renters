import SwiftUI

struct NewARCRequestView: View {
    let associationId: UUID
    let membership: MembershipRow

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var creating = false
    @State private var error: String?
    @State private var request: ARCRequest?
    @State private var photoController: HOAPhotoCaptureController?

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    if request == nil {
                        LedgerCard {
                            VStack(alignment: .leading, spacing: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("What are you requesting?").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
                                    TextField("e.g. Repaint front door, install fence", text: $title).ledgerFieldStyle()
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Details").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
                                    TextEditor(text: $description)
                                        .frame(height: 100)
                                        .padding(8)
                                        .background(DS.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(DS.ink.opacity(0.1)))
                                }
                            }
                        }
                        if let error {
                            Text(error).font(.system(size: 13)).foregroundStyle(DS.clay)
                        }
                        LedgerButton(title: creating ? "Submitting\u{2026}" : "Submit request", isLoading: creating, disabled: creating || title.trimmingCharacters(in: .whitespaces).isEmpty) {
                            submit()
                        }
                    } else if let controller = photoController {
                        LedgerCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Request submitted").font(DS.serif(18)).foregroundStyle(DS.ink)
                                Text("Attach photos (site plans, reference images) if helpful \u{2014} optional.").font(.system(size: 12.5)).foregroundStyle(DS.ink.opacity(0.5))
                            }
                        }
                        HOAPhotoCaptureSection(controller: controller, title: "Reference photos")
                        Button("Done") { dismiss() }
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(DS.emerald, in: Capsule())
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("New ARC request")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        error = nil
        creating = true
        Task {
            do {
                let created = try await HOADataStore.createARCRequest(associationId: associationId, requester: membership.user_id, unitLabel: membership.unit_label, title: title, description: description.isEmpty ? nil : description)
                await MainActor.run {
                    creating = false
                    request = created
                    photoController = HOAPhotoCaptureController(associationId: associationId, parentType: .arc, parentId: created.id)
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
