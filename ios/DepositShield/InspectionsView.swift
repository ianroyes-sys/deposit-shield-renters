import SwiftUI

struct InspectionsView: View {
    let associationId: UUID
    let isBoard: Bool
    @Binding var path: [CommunityRoute]

    @State private var loadState: LoadState = .loading
    @State private var areas: [InspectionArea] = []
    @State private var inspections: [Inspection] = []
    @State private var association: Association?
    @State private var exporting = false
    @State private var shareURL: URL?
    @State private var error: String?

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            AsyncStateView(state: loadState, retry: { Task { await load() } }) {
                if areas.isEmpty {
                    EmptyStateCard(icon: "checkmark.rectangle.stack", title: "No inspection areas yet", description: "Add common areas (pool, clubhouse, landscaping) to start a cadence of documented walk-throughs.", actionTitle: isBoard ? "Add an area" : nil, action: isBoard ? { path.append(.newInspectionArea) } : nil)
                        .padding(20)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            if let error {
                                Text(error).font(.system(size: 13)).foregroundStyle(DS.clay)
                            }
                            ForEach(areas) { area in
                                AreaRow(area: area, lastInspection: lastInspection(for: area), onLog: { path.append(.logInspection(areaId: area.id)) })
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationTitle("Inspections")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isBoard {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Add area") { path.append(.newInspectionArea) }
                        Button("Export full report") { Task { await exportAll() } }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill").foregroundStyle(DS.brass)
                    }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: Binding(get: { shareURL.map(IdentifiableURL.init) }, set: { shareURL = $0?.url })) { wrapped in
            ShareSheet(items: [wrapped.url])
        }
    }

    private func lastInspection(for area: InspectionArea) -> Inspection? {
        inspections.filter { $0.area_id == area.id }.max { ($0.performed_at) < ($1.performed_at) }
    }

    private func load() async {
        loadState = .loading
        do {
            let memberships = try await HOADataStore.fetchMemberships()
            association = memberships.first { $0.association_id == associationId }?.associations
            areas = try await HOADataStore.fetchInspectionAreas(associationId: associationId)
            inspections = try await HOADataStore.fetchInspections(associationId: associationId)
            loadState = .loaded
        } catch {
            loadState = .failed("Couldn't load inspections.\n\(HOAError.from(error).localizedDescription)")
        }
    }

    private func exportAll() async {
        guard let association else { return }
        exporting = true
        error = nil
        do {
            var entries: [InspectionReportEntry] = []
            for area in areas {
                let areaInspections = inspections.filter { $0.area_id == area.id }.sorted { $0.performed_at > $1.performed_at }
                for inspection in areaInspections {
                    let photos = try await HOADataStore.fetchHOAPhotos(parentType: .inspection, parentId: inspection.id)
                    let reportPhotos = await HOAReportAssembler.reportPhotos(for: photos)
                    entries.append(InspectionReportEntry(areaName: area.name, performedAt: inspection.performed_at, condition: inspection.condition, notes: inspection.notes, photos: reportPhotos))
                }
            }
            let data = HOAPDFGenerator.inspectionReportPDF(association: association, title: "Full-association inspection report", entries: entries)
            let (localURL, _) = try await HOAReportAssembler.persist(data: data, associationId: associationId, category: "inspection-report", id: UUID())
            await MainActor.run {
                exporting = false
                shareURL = localURL
            }
        } catch {
            await MainActor.run {
                exporting = false
                self.error = HOAError.from(error).localizedDescription
            }
        }
    }
}

private struct AreaRow: View {
    let area: InspectionArea
    let lastInspection: Inspection?
    let onLog: () -> Void

    private var dueLabel: (text: String, tone: Color)? {
        guard let cadence = area.cadence_days else { return nil }
        guard let last = lastInspection, let lastDate = Formatters.parseISODate(last.performed_at) else {
            return ("Never inspected", DS.clay)
        }
        let due = Calendar.current.date(byAdding: .day, value: cadence, to: lastDate) ?? lastDate
        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: due).day ?? 0
        if daysUntil < 0 { return ("Overdue by \(-daysUntil) day\(daysUntil == -1 ? "" : "s")", DS.clay) }
        if daysUntil <= 3 { return ("Due in \(daysUntil) day\(daysUntil == 1 ? "" : "s")", DS.brass) }
        return ("Due \(Formatters.date(due))", DS.ink.opacity(0.5))
    }

    var body: some View {
        LedgerCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(area.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(DS.ink)
                        if let cadence = area.cadence_days {
                            Text("Every \(cadence) days").font(.system(size: 11.5)).foregroundStyle(DS.ink.opacity(0.45))
                        }
                    }
                    Spacer()
                    if let inspection = lastInspection {
                        ConditionTag(condition: inspection.condition)
                    }
                }
                if let last = lastInspection {
                    Text("Last inspected \(Formatters.date(last.performed_at))").font(.system(size: 12)).foregroundStyle(DS.ink.opacity(0.5))
                }
                if let due = dueLabel {
                    Text(due.text).font(.system(size: 12, weight: .medium)).foregroundStyle(due.tone)
                }
                Button(action: onLog) {
                    Text("Log inspection")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(DS.brass, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ConditionTag: View {
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
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}
