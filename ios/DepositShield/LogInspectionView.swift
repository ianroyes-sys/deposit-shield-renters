import SwiftUI

struct LogInspectionView: View {
    let associationId: UUID
    let areaId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var condition: InspectionCondition = .good
    @State private var notes = ""
    @State private var logging = false
    @State private var error: String?
    @State private var inspection: Inspection?
    @State private var areaName = ""
    @State private var photoController: HOAPhotoCaptureController?
    @State private var generating = false
    @State private var shareURL: URL?

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    if inspection == nil {
                        LedgerCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Condition").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
                                Picker("Condition", selection: $condition) {
                                    ForEach(InspectionCondition.allCases, id: \.self) { c in Text(c.label).tag(c) }
                                }
                                .pickerStyle(.segmented)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Notes").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
                                    TextEditor(text: $notes)
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

                        LedgerButton(title: logging ? "Logging\u{2026}" : "Log inspection", isLoading: logging, disabled: logging) {
                            logInspection()
                        }
                    } else if let controller = photoController {
                        LedgerCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(areaName).font(DS.serif(18)).foregroundStyle(DS.ink)
                                    Spacer()
                                    ConditionPill(condition: condition)
                                }
                                if !notes.isEmpty {
                                    Text(notes).font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.65))
                                }
                            }
                        }

                        HOAPhotoCaptureSection(controller: controller, title: "Photos")

                        if let error {
                            Text(error).font(.system(size: 13)).foregroundStyle(DS.clay)
                        }

                        LedgerButton(title: generating ? "Generating report\u{2026}" : "Generate report & finish", isLoading: generating, disabled: generating) {
                            finish(controller: controller)
                        }
                        Button("Skip report, just finish") { dismiss() }
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.5))
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Log inspection")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAreaName() }
        .sheet(item: Binding(get: { shareURL.map(IdentifiableURL.init) }, set: { shareURL = $0?.url; if $0 == nil { dismiss() } })) { wrapped in
            ShareSheet(items: [wrapped.url])
        }
    }

    private func loadAreaName() async {
        if let areas = try? await HOADataStore.fetchInspectionAreas(associationId: associationId),
           let match = areas.first(where: { $0.id == areaId }) {
            areaName = match.name
        }
    }

    private func logInspection() {
        guard let userId = supabase.auth.currentUser?.id else {
            error = "Your session expired \u{2014} sign in again."
            return
        }
        error = nil
        logging = true
        Task {
            do {
                let created = try await HOADataStore.createInspection(associationId: associationId, areaId: areaId, performedBy: userId, condition: condition, notes: notes.isEmpty ? nil : notes)
                await MainActor.run {
                    logging = false
                    inspection = created
                    photoController = HOAPhotoCaptureController(associationId: associationId, parentType: .inspection, parentId: created.id)
                }
            } catch {
                await MainActor.run {
                    logging = false
                    self.error = HOAError.from(error).localizedDescription
                }
            }
        }
    }

    private func finish(controller: HOAPhotoCaptureController) {
        guard let inspection else { return }
        error = nil
        generating = true
        Task {
            do {
                let memberships = try await HOADataStore.fetchMemberships()
                guard let association = memberships.first(where: { $0.association_id == associationId })?.associations else {
                    throw HOAError.notFound
                }
                let reportPhotos = await HOAReportAssembler.reportPhotos(for: controller.photos)
                let entry = InspectionReportEntry(areaName: areaName, performedAt: inspection.performed_at, condition: condition, notes: notes.isEmpty ? nil : notes, photos: reportPhotos)
                let data = HOAPDFGenerator.inspectionReportPDF(association: association, title: areaName, entries: [entry])
                let (localURL, storagePath) = try await HOAReportAssembler.persist(data: data, associationId: associationId, category: "inspection", id: inspection.id)
                try await HOADataStore.setInspectionPDFPath(id: inspection.id, path: storagePath)
                await MainActor.run {
                    generating = false
                    shareURL = localURL
                }
            } catch {
                await MainActor.run {
                    generating = false
                    self.error = HOAError.from(error).localizedDescription
                }
            }
        }
    }
}

private struct ConditionPill: View {
    let condition: InspectionCondition
    private var color: Color {
        switch condition {
        case .good: return DS.emerald
        case .fair: return DS.brass
        case .attention: return DS.clay
        }
    }
    var body: some View {
        Text(condition.label).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 4).background(color.opacity(0.12), in: Capsule())
    }
}
