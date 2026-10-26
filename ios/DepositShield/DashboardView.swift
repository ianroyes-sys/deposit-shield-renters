import SwiftUI

/// Ports app/page.tsx + property-card.tsx.
struct DashboardView: View {
    @Binding var path: [AppRoute]

    @State private var state: LoadState = .loading
    @State private var properties: [PropertyWithStats] = []

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            content
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("DEPOSIT SHIELD")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2.6)
                    .foregroundStyle(DS.ink.opacity(0.7))
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView().tint(DS.emerald)
        case .failed(let message):
            AsyncStateView(state: .failed(message), retry: { Task { await load() } }) { EmptyView() }
        case .loaded:
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    LedgerRuleDivider().padding(.vertical, 24)

                    if properties.isEmpty {
                        EmptyStateCard(
                            icon: "checkmark.shield",
                            title: "Add your place \u{2014} do this before you unpack",
                            description: "Document the condition of your rental before a single box comes inside. It takes about ten minutes and could save your deposit.",
                            actionTitle: "Add your property"
                        ) {
                            path.append(.newProperty)
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 14)], spacing: 14) {
                            ForEach(properties) { p in
                                Button {
                                    Haptics.tap()
                                    path.append(.property(p.id))
                                } label: {
                                    PropertyCardView(property: p)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your properties").font(DS.serif(28)).foregroundStyle(DS.ink)
                Text(properties.isEmpty ? "Nothing documented yet." : "\(properties.count) propert\(properties.count == 1 ? "y" : "ies") tracked.")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.ink.opacity(0.5))
            }
            Spacer()
            if !properties.isEmpty {
                Button {
                    Haptics.tap()
                    path.append(.newProperty)
                } label: {
                    Text("+ Add")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(DS.emerald, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func load() async {
        if case .loading = state {} else { state = .loading }
        do {
            properties = try await DataStore.fetchPropertiesWithStats()
            state = .loaded
        } catch {
            state = .failed("Couldn't load your properties.\n\(error.localizedDescription)")
        }
    }
}

struct PropertyCardView: View {
    let property: PropertyWithStats
    private var status: PropertyStatusInfo { propertyStatus(property) }

    var body: some View {
        LedgerCard(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Formatters.propertyDisplayName(property.property))
                            .font(DS.serif(17))
                            .foregroundStyle(DS.ink)
                            .lineLimit(1)
                        Text(cityStateLabel)
                            .font(.system(size: 11.5))
                            .foregroundStyle(DS.ink.opacity(0.5))
                            .lineLimit(1)
                    }
                    Spacer()
                    if property.property.is_paid {
                        StatusPill(label: "Shield", tone: .brass)
                    }
                }

                StatusPill(label: status.label, tone: status.tone)

                Divider().overlay(DS.ink.opacity(0.08))

                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Deposit").font(.system(size: 10.5)).foregroundStyle(DS.ink.opacity(0.4))
                        Text(Formatters.cents(property.property.deposit_amount_cents))
                            .font(.system(size: 14, weight: .medium)).foregroundStyle(DS.ink)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Photos").font(.system(size: 10.5)).foregroundStyle(DS.ink.opacity(0.4))
                        Text("\(property.moveInPhotoCount + property.moveOutPhotoCount)")
                            .font(.system(size: 14, weight: .medium)).foregroundStyle(DS.ink)
                    }
                }
            }
        }
    }

    private var cityStateLabel: String {
        if let city = property.property.city, let state = property.property.state, !city.isEmpty, !state.isEmpty {
            return "\(city), \(state)"
        }
        return "Address pending"
    }
}
