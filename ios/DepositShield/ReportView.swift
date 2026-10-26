import SwiftUI

/// Ports p/[id]/report/page.tsx + report-client.tsx to a native PDF pipeline:
/// UIGraphicsPDFRenderer builds the document on-device, it's uploaded to the
/// `reports` bucket, and the user gets a native share sheet.
struct ReportView: View {
    let propertyId: UUID

    @State private var loadState: LoadState = .loading
    @State private var property: Property?
    @State private var kind: Phase = .move_in
    @State private var generating = false
    @State private var result: (url: URL, watermarked: Bool)?
    @State private var shareURL: URL?
    @State private var error: String?
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
        .navigationTitle("Condition report")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showPaywall) {
            PaywallView(propertyId: propertyId) {
                Task { await load() }
            }
        }
        .sheet(item: Binding(get: { shareURL.map(IdentifiableURL.init) }, set: { shareURL = $0?.url })) { wrapped in
            ShareSheet(items: [wrapped.url])
        }
    }

    @ViewBuilder
    private func content(_ property: Property) -> some View {
        let moveOutDone = property.move_out_completed_at != nil

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("A professional PDF of your photo documentation, ready for your records or your landlord.")
                    .font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.55))

                HStack(spacing: 8) {
                    kindPill("Move-in", .move_in, enabled: true)
                    kindPill("Move-out", .move_out, enabled: moveOutDone)
                }

                LedgerCard {
                    VStack(alignment: .leading, spacing: 14) {
                        if !property.is_paid {
                            InlineNotice(text: "You'll get a watermarked preview. Unlock Shield for the clean, downloadable version.")
                        }

                        LedgerButton(title: generating ? "Generating\u{2026}" : "Generate \(kind == .move_in ? "move-in" : "move-out") report", isLoading: generating, disabled: generating) {
                            Task { await generate(property: property) }
                        }

                        if let error {
                            Text(error).font(.system(size: 13)).foregroundStyle(DS.clay)
                        }

                        if let result {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(result.watermarked ? "Watermarked preview ready." : "Report ready.")
                                    .font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.7))
                                HStack(spacing: 10) {
                                    Button {
                                        shareURL = result.url
                                    } label: {
                                        Text("Share / Save PDF").font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.ink)
                                            .padding(.horizontal, 14).padding(.vertical, 9)
                                            .background(DS.paper, in: Capsule())
                                            .overlay(Capsule().strokeBorder(DS.ink.opacity(0.15)))
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        if property.is_paid {
                                            sendToLandlord(property: property)
                                        } else {
                                            showPaywall = true
                                        }
                                    } label: {
                                        Text("Send to landlord").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                }
                                if property.is_paid && (property.landlord_email?.isEmpty ?? true) {
                                    Text("Add a landlord email on this property to enable sending.").font(.system(size: 11.5)).foregroundStyle(DS.clay)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func kindPill(_ label: String, _ value: Phase, enabled: Bool) -> some View {
        Button {
            guard enabled else { return }
            Haptics.tap()
            kind = value
            result = nil
        } label: {
            Text(label)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(kind == value ? .white : DS.ink.opacity(enabled ? 0.6 : 0.3))
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(kind == value ? DS.ink : DS.ink.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func load() async {
        loadState = .loading
        do {
            guard let p = try await DataStore.fetchProperty(propertyId: propertyId) else {
                loadState = .failed("This property could not be found.")
                return
            }
            property = p
            kind = p.move_out_completed_at != nil ? .move_out : .move_in
            loadState = .loaded
        } catch {
            loadState = .failed("Couldn't load this property.\n\(error.localizedDescription)")
        }
    }

    private func generate(property: Property) async {
        error = nil
        generating = true
        result = nil
        do {
            let detail = try await DataStore.fetchPropertyDetail(propertyId: propertyId)
            guard let detail else { throw DataStoreError.notFound }
            let law = StateDepositLaws.law(for: property.state)
            let watermark = !property.is_paid
            let reportRooms = try await ReportAssembler.rooms(detail: detail, phase: kind)
            let info = ReportAssembler.propertyInfo(property: property, tenantEmail: supabase.auth.currentUser?.email ?? "Tenant", law: law)

            let data = PDFReportGenerator.conditionReportPDF(
                title: kind == .move_in ? "Move-in condition report" : "Move-out condition report",
                phaseLabel: kind.label,
                property: info,
                rooms: reportRooms,
                watermark: watermark
            )

            let (localURL, storagePath) = try await ReportAssembler.persist(data: data, propertyId: propertyId, kind: kind == .move_in ? .move_in : .move_out)
            _ = try await DataStore.insertReport(propertyId: propertyId, kind: kind == .move_in ? .move_in : .move_out, storagePath: storagePath)

            await MainActor.run {
                result = (localURL, watermark)
                generating = false
            }
        } catch {
            await MainActor.run {
                generating = false
                self.error = error.localizedDescription
            }
        }
    }

    private func sendToLandlord(property: Property) {
        guard let email = property.landlord_email, !email.isEmpty, let url = result?.url else { return }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Condition report \u{2014} \(Formatters.propertyDisplayName(property))"),
            URLQueryItem(name: "body", value: "Attached is the condition report PDF from Deposit Shield. (Attach the file saved from the share sheet.)\n\n\(url.absoluteString)"),
        ]
        if let mailtoURL = components.url {
            UIApplication.shared.open(mailtoURL)
        }
    }
}

struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
