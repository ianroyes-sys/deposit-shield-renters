import SwiftUI

/// The differentiator: an aggregated, per-category enforcement history that
/// proves even-handed rule enforcement (the defense against
/// selective-enforcement claims). No addresses or names — counts only, so
/// it's safe to show residents too.
struct ConsistencyLedgerView: View {
    let associationId: UUID
    let isBoard: Bool

    @State private var loadState: LoadState = .loading
    @State private var stats: [LedgerCategoryStat] = []
    @State private var association: Association?
    @State private var exporting = false
    @State private var shareURL: URL?
    @State private var error: String?

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            AsyncStateView(state: loadState, retry: { Task { await load() } }) {
                content
            }
        }
        .navigationTitle("Consistency Ledger")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: Binding(get: { shareURL.map(IdentifiableURL.init) }, set: { shareURL = $0?.url })) { wrapped in
            ShareSheet(items: [wrapped.url])
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Even enforcement, documented.").font(DS.serif(24)).foregroundStyle(DS.ink)
                    Text("The defense against selective-enforcement claims \u{2014} a consistent, timestamped record across every rule category.")
                        .font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.55)).lineSpacing(2)
                }

                if stats.allSatisfy({ $0.opened == 0 }) {
                    EmptyStateCard(icon: "chart.bar.doc.horizontal", title: "Nothing logged yet", description: "Once violations are opened, this ledger tracks how consistently each category is enforced.")
                } else {
                    VStack(spacing: 10) {
                        ForEach(stats.filter { $0.opened > 0 }, id: \.category) { stat in
                            LedgerCard(padding: 16) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(stat.category).font(.system(size: 15, weight: .semibold)).foregroundStyle(DS.ink)
                                    HStack(spacing: 18) {
                                        statBlock("Opened", "\(stat.opened)")
                                        statBlock("Notices", "\(stat.noticesSent)")
                                        statBlock("Resolved", "\(stat.resolved)")
                                        if let avg = stat.avgDaysToResolution {
                                            statBlock("Avg days", String(format: "%.1f", avg))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if isBoard {
                        if let error {
                            Text(error).font(.system(size: 13)).foregroundStyle(DS.clay)
                        }
                        LedgerButton(title: exporting ? "Preparing PDF\u{2026}" : "Export summary PDF", isLoading: exporting, disabled: exporting) {
                            Task { await export() }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func statBlock(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(DS.ink.opacity(0.4))
            Text(value).font(DS.mono(15, weight: .semibold)).foregroundStyle(DS.brass)
        }
    }

    private func load() async {
        loadState = .loading
        do {
            let memberships = try await HOADataStore.fetchMemberships()
            association = memberships.first { $0.association_id == associationId }?.associations

            let violations = try await HOADataStore.fetchViolations(associationId: associationId)
            let events = try await HOADataStore.fetchAllViolationEvents(associationId: associationId)
            stats = Self.computeStats(violations: violations, events: events)
            loadState = .loaded
        } catch {
            loadState = .failed("Couldn't load the ledger.\n\(HOAError.from(error).localizedDescription)")
        }
    }

    static func computeStats(violations: [Violation], events: [ViolationEvent]) -> [LedgerCategoryStat] {
        ViolationCategory.allCases.map { category in
            let inCategory = violations.filter { $0.category == category.rawValue }
            let ids = Set(inCategory.map(\.id))
            let noticeKinds: Set<ViolationEventKind> = [.courtesy_notice, .warning, .fine]
            let notices = events.filter { ids.contains($0.violation_id) && noticeKinds.contains($0.kind) }
            let resolved = inCategory.filter { $0.status == .resolved }
            let durations: [Double] = resolved.compactMap { v in
                guard let resolvedAt = v.resolved_at,
                      let opened = Formatters.parseISODate(v.opened_at),
                      let closed = Formatters.parseISODate(resolvedAt) else { return nil }
                return closed.timeIntervalSince(opened) / 86400
            }
            let avg = durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count)
            return LedgerCategoryStat(category: category.rawValue, opened: inCategory.count, noticesSent: notices.count, resolved: resolved.count, avgDaysToResolution: avg)
        }
    }

    private func export() async {
        guard let association else { return }
        error = nil
        exporting = true
        do {
            let data = HOAPDFGenerator.ledgerSummaryPDF(association: association, stats: stats.filter { $0.opened > 0 }, generatedDate: Formatters.date(Date()))
            let (localURL, _) = try await HOAReportAssembler.persist(data: data, associationId: associationId, category: "ledger", id: UUID())
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
