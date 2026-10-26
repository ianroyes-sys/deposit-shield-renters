import SwiftUI

struct ViolationDetailView: View {
    let violationId: UUID
    let associationId: UUID
    let isBoard: Bool

    @State private var loadState: LoadState = .loading
    @State private var violation: Violation?
    @State private var association: Association?
    @State private var events: [ViolationEvent] = []
    @StateObject private var photoController: HOAPhotoCaptureController
    @State private var escalating: ViolationEventKind?
    @State private var showFineSheet = false
    @State private var fineAmount = ""
    @State private var error: String?
    @State private var shareURL: URL?

    init(violationId: UUID, associationId: UUID, isBoard: Bool) {
        self.violationId = violationId
        self.associationId = associationId
        self.isBoard = isBoard
        _photoController = StateObject(wrappedValue: HOAPhotoCaptureController(associationId: associationId, parentType: .violation, parentId: violationId))
    }

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            AsyncStateView(state: loadState, retry: { Task { await load() } }) {
                if let violation {
                    content(violation)
                }
            }
        }
        .navigationTitle("Violation")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showFineSheet) {
            fineAmountSheet
        }
        .sheet(item: Binding(get: { shareURL.map(IdentifiableURL.init) }, set: { shareURL = $0?.url })) { wrapped in
            ShareSheet(items: [wrapped.url])
        }
    }

    @ViewBuilder
    private func content(_ violation: Violation) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                LedgerCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(violation.unit_label ?? violation.address ?? "Unit not set").font(DS.serif(22)).foregroundStyle(DS.ink)
                            Spacer()
                            StatusPill(label: violation.status.label, tone: violation.status.isClosed ? .success : .progress)
                        }
                        Text(violation.category).font(DS.mono(11, weight: .semibold)).foregroundStyle(DS.brass)
                        if let rule = violation.rule_reference, !rule.isEmpty {
                            Text("Rule: \(rule)").font(.system(size: 12.5)).foregroundStyle(DS.ink.opacity(0.55))
                        }
                        if let description = violation.description, !description.isEmpty {
                            Text(description).font(.system(size: 13.5)).foregroundStyle(DS.ink.opacity(0.7)).padding(.top, 4)
                        }
                        Text("Opened \(Formatters.dateTime(violation.opened_at))").font(.system(size: 11.5)).foregroundStyle(DS.ink.opacity(0.4))
                    }
                }

                // Violation evidence is a board-controlled workflow — residents can
                // view a case but shouldn't be able to attach their own "evidence"
                // photos to it (client-side gate; server RLS hardening tracked separately).
                HOAPhotoCaptureSection(controller: photoController, title: "Evidence", allowUpload: isBoard)

                if let error {
                    Text(error).font(.system(size: 13)).foregroundStyle(DS.clay)
                }

                if !violation.status.isClosed {
                    actionRow(violation)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Escalation timeline").font(DS.serif(18)).foregroundStyle(DS.ink)
                    if events.isEmpty {
                        Text("No notices sent yet.").font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.45))
                    } else {
                        ForEach(events) { event in
                            EventRow(event: event, onOpenPDF: {
                                if let path = event.pdf_path {
                                    Task {
                                        if let url = await DataStore.signedURL(bucket: "reports", path: path) {
                                            shareURL = url
                                        }
                                    }
                                }
                            })
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func actionRow(_ violation: Violation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Escalate").font(DS.serif(18)).foregroundStyle(DS.ink)
            VStack(spacing: 10) {
                switch violation.status {
                case .open:
                    escalateButton("Send courtesy notice", kind: .courtesy_notice, filled: true)
                case .courtesy_sent:
                    escalateButton("Send warning", kind: .warning, filled: true)
                case .warning_sent:
                    Button {
                        Haptics.tap()
                        showFineSheet = true
                    } label: {
                        escalateLabel("Issue fine", filled: true, loading: escalating == .fine)
                    }
                    .buttonStyle(.plain)
                    .disabled(escalating != nil)
                case .fine_issued, .resolved, .dismissed:
                    EmptyView()
                }

                HStack(spacing: 10) {
                    escalateButton("Resolve", kind: .resolved, filled: false, tint: DS.emerald)
                    escalateButton("Dismiss", kind: .dismissed, filled: false, tint: DS.clay)
                }
            }
        }
    }

    private func escalateButton(_ title: String, kind: ViolationEventKind, filled: Bool, tint: Color = DS.brass) -> some View {
        Button {
            Haptics.tap()
            Task { await escalate(kind: kind, fineAmountCents: nil) }
        } label: {
            escalateLabel(title, filled: filled, tint: tint, loading: escalating == kind)
        }
        .buttonStyle(.plain)
        .disabled(escalating != nil)
    }

    private func escalateLabel(_ title: String, filled: Bool, tint: Color = DS.brass, loading: Bool) -> some View {
        HStack(spacing: 6) {
            if loading { ProgressView().tint(filled ? .white : tint).scaleEffect(0.8) }
            Text(title)
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(filled ? .white : tint)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(filled ? tint : Color.white, in: Capsule())
        .overlay(Capsule().strokeBorder(filled ? Color.clear : tint.opacity(0.4)))
    }

    private var fineAmountSheet: some View {
        VStack(spacing: 20) {
            Capsule().fill(DS.ink.opacity(0.15)).frame(width: 40, height: 5).padding(.top, 10)
            Text("Issue a fine").font(DS.serif(20)).foregroundStyle(DS.ink)
            VStack(alignment: .leading, spacing: 6) {
                Text("Fine amount (USD)").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.7))
                TextField("100", text: $fineAmount).keyboardType(.decimalPad).ledgerFieldStyle()
            }
            LedgerButton(title: "Issue fine & generate notice") {
                let cents = Int((Double(fineAmount) ?? 0) * 100)
                showFineSheet = false
                Task { await escalate(kind: .fine, fineAmountCents: cents) }
            }
            Button("Cancel") { showFineSheet = false }
                .font(.system(size: 14, weight: .medium)).foregroundStyle(DS.ink.opacity(0.5))
        }
        .padding(24)
        .presentationDetents([.medium])
    }

    private func load() async {
        loadState = .loading
        do {
            violation = try await HOADataStore.fetchViolation(id: violationId)
            association = try await fetchAssociation()
            events = try await HOADataStore.fetchViolationEvents(violationId: violationId)
            await photoController.load()
            loadState = .loaded
        } catch {
            loadState = .failed("Couldn't load this violation.\n\(HOAError.from(error).localizedDescription)")
        }
    }

    private func fetchAssociation() async throws -> Association? {
        let memberships = try await HOADataStore.fetchMemberships()
        return memberships.first { $0.association_id == associationId }?.associations
    }

    private func escalate(kind: ViolationEventKind, fineAmountCents: Int?) async {
        guard let violation, let association, let userId = supabase.auth.currentUser?.id else { return }
        error = nil
        escalating = kind
        do {
            let reportPhotos = await HOAReportAssembler.reportPhotos(for: photoController.photos)
            let pdfData = HOAPDFGenerator.noticePDF(kind: kind, association: association, violation: violation, photos: reportPhotos, fineAmountCents: fineAmountCents, cureDeadlineDays: 14, note: nil)
            let (localURL, storagePath) = try await HOAReportAssembler.persist(data: pdfData, associationId: associationId, category: kind.rawValue, id: violation.id)

            try await HOADataStore.insertViolationEvent(violationId: violation.id, associationId: associationId, actor: userId, kind: kind, note: nil, fineAmountCents: fineAmountCents, pdfPath: storagePath)

            let newStatus: ViolationStatus
            switch kind {
            case .courtesy_notice: newStatus = .courtesy_sent
            case .warning: newStatus = .warning_sent
            case .fine: newStatus = .fine_issued
            case .resolved: newStatus = .resolved
            case .dismissed: newStatus = .dismissed
            case .comment: newStatus = violation.status
            }
            try await HOADataStore.updateViolationStatus(id: violation.id, status: newStatus)

            await MainActor.run {
                escalating = nil
                shareURL = localURL
            }
            await load()
        } catch {
            await MainActor.run {
                escalating = nil
                self.error = HOAError.from(error).localizedDescription
            }
        }
    }
}

private struct EventRow: View {
    let event: ViolationEvent
    let onOpenPDF: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(DS.brass).frame(width: 8, height: 8).padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.system(size: 13.5, weight: .medium)).foregroundStyle(DS.ink)
                Text(Formatters.dateTime(event.created_at)).font(.system(size: 11)).foregroundStyle(DS.ink.opacity(0.45))
                if let cents = event.fine_amount_cents {
                    Text(Formatters.cents(cents)).font(DS.mono(11.5)).foregroundStyle(DS.clay)
                }
                if event.pdf_path != nil {
                    Button("View notice PDF", action: onOpenPDF)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.brass)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var label: String {
        switch event.kind {
        case .courtesy_notice: return "Courtesy notice sent"
        case .warning: return "Warning sent"
        case .fine: return "Fine issued"
        case .resolved: return "Marked resolved"
        case .dismissed: return "Dismissed"
        case .comment: return "Comment"
        }
    }
}
