import SwiftUI

/// Ports p/[id]/evidence/page.tsx + evidence-client.tsx.
struct EvidenceView: View {
    let propertyId: UUID

    @State private var loadState: LoadState = .loading
    @State private var property: Property?
    @State private var letterLines: [String] = []
    @State private var checklistItems: [String] = []
    @State private var generating = false
    @State private var error: String?
    @State private var shareURL: URL?
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            AsyncStateView(state: loadState, retry: { Task { await load() } }) {
                if let property {
                    content(property)
                }
            }
        }
        .navigationTitle("Evidence packet")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showPaywall) {
            PaywallView(propertyId: propertyId, title: "Evidence packets require Shield", description: "Unlock this property one time to generate the combined move-in/move-out evidence packet with your demand letter and small-claims checklist.") {
                Task { await load() }
            }
        }
        .sheet(item: Binding(get: { shareURL.map(IdentifiableURL.init) }, set: { shareURL = $0?.url })) { wrapped in
            ShareSheet(items: [wrapped.url])
        }
    }

    @ViewBuilder
    private func content(_ property: Property) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Move-in and move-out photos, your state's deadline, a draft demand letter, and a small-claims checklist \u{2014} bundled into one PDF.")
                    .font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.55))

                LedgerCard {
                    VStack(alignment: .leading, spacing: 12) {
                        if !property.is_paid {
                            InlineNotice(tone: DS.clay, background: DS.clay50, text: "Evidence packets require Shield. Unlock this property to generate it.")
                        }
                        LedgerButton(title: generating ? "Building packet\u{2026}" : "Generate evidence packet", isLoading: generating, disabled: generating || !property.is_paid) {
                            Task { await generate(property: property) }
                        }
                        if !property.is_paid {
                            Button {
                                showPaywall = true
                            } label: {
                                Text("Unlock Shield").font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.brass)
                            }
                            .buttonStyle(.plain)
                        }
                        if let error {
                            Text(error).font(.system(size: 13)).foregroundStyle(DS.clay)
                        }
                        if shareURL != nil {
                            Text("Your evidence packet is ready.").font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.7))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Demand letter preview").font(DS.serif(18)).foregroundStyle(DS.ink)
                    LedgerCard {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(letterLines.enumerated()), id: \.offset) { _, line in
                                Text(line.isEmpty ? " " : line)
                                    .font(DS.mono(11.5))
                                    .foregroundStyle(DS.ink.opacity(0.7))
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Small-claims checklist").font(DS.serif(18)).foregroundStyle(DS.ink)
                    LedgerCard {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(checklistItems.enumerated()), id: \.offset) { _, item in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\u{2610}").foregroundStyle(DS.brass)
                                    Text(item).font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.7))
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func load() async {
        loadState = .loading
        do {
            guard let p = try await DataStore.fetchProperty(propertyId: propertyId) else {
                loadState = .failed("This property could not be found.")
                return
            }
            property = p
            let law = StateDepositLaws.law(for: p.state)
            let tenantEmail = supabase.auth.currentUser?.email ?? "tenant@example.com"
            letterLines = DemandLetter.lines(property: p, law: law, tenantEmail: tenantEmail)
            checklistItems = DemandLetter.smallClaimsChecklist(law: law)
            loadState = .loaded
        } catch {
            loadState = .failed("Couldn't load this property.\n\(error.localizedDescription)")
        }
    }

    private func generate(property: Property) async {
        guard property.is_paid else { showPaywall = true; return }
        error = nil
        generating = true
        do {
            guard let detail = try await DataStore.fetchPropertyDetail(propertyId: propertyId) else {
                throw DataStoreError.notFound
            }
            let law = StateDepositLaws.law(for: property.state)
            let tenantEmail = supabase.auth.currentUser?.email ?? "tenant@example.com"
            let info = ReportAssembler.propertyInfo(property: property, tenantEmail: tenantEmail, law: law)

            async let moveInRooms = ReportAssembler.rooms(detail: detail, phase: .move_in)
            async let moveOutRooms = ReportAssembler.rooms(detail: detail, phase: .move_out)

            var deadlineDateLabel: String? = nil
            if let moveOutAt = property.move_out_completed_at, let law, let d = Formatters.parseISODate(moveOutAt) {
                let deadline = Calendar.current.date(byAdding: .day, value: law.returnDeadlineDays, to: d) ?? d
                deadlineDateLabel = Formatters.date(deadline)
            }

            let data = PDFReportGenerator.evidencePacketPDF(
                property: info,
                moveInRooms: try await moveInRooms,
                moveOutRooms: try await moveOutRooms,
                stateName: law?.name ?? "your state",
                deadlineDays: law?.returnDeadlineDays ?? 30,
                itemizedRequired: law?.itemizedStatementRequired ?? true,
                smallClaimsLimit: law?.smallClaimsLimit ?? "varies by state",
                deadlineDateLabel: deadlineDateLabel,
                letterLines: letterLines,
                checklistItems: checklistItems
            )

            let (localURL, storagePath) = try await ReportAssembler.persist(data: data, propertyId: propertyId, kind: .evidence_packet)
            _ = try await DataStore.insertReport(propertyId: propertyId, kind: .evidence_packet, storagePath: storagePath)

            await MainActor.run {
                shareURL = localURL
                generating = false
            }
        } catch {
            await MainActor.run {
                generating = false
                self.error = error.localizedDescription
            }
        }
    }
}
