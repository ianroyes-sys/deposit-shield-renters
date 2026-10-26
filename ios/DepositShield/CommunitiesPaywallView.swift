import SwiftUI
import StoreKit

/// Shown when a free-tier server limit is hit (FREE_VIOLATION_LIMIT_REACHED /
/// FREE_AREA_LIMIT_REACHED) or from an explicit "Upgrade" action.
struct CommunitiesPaywallView: View {
    let associationId: UUID
    var title: String = "Upgrade to Communities Pro"
    var description: String = "Unlimited violations, inspection areas, and enforcement history for your association \u{2014} monthly or yearly."
    var onUnlocked: () -> Void

    @StateObject private var store = HOASubscriptionManager()
    @Environment(\.dismiss) private var dismiss
    @State private var purchasingID: String?
    @State private var error: String?

    var body: some View {
        VStack(spacing: 22) {
            Capsule().fill(DS.ink.opacity(0.15)).frame(width: 40, height: 5).padding(.top, 10)

            VStack(spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 11, weight: .bold))
                    Text("COMMUNITIES PRO").tracking(0.6)
                }
                .font(DS.mono(11, weight: .semibold))
                .foregroundStyle(DS.brass)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(DS.brass50, in: Capsule())

                Text(title).font(DS.serif(23)).foregroundStyle(DS.ink).multilineTextAlignment(.center)
                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(DS.ink.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 12)

            if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(DS.clay).multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                if store.isLoadingProducts {
                    ProgressView().tint(DS.brass)
                } else if store.monthly == nil && store.yearly == nil {
                    InlineNotice(tone: DS.clay, background: DS.clay50, text: store.loadError ?? "Purchases aren't available right now.")
                } else {
                    if let yearly = store.yearly {
                        planButton(product: yearly, badge: "Best value")
                    }
                    if let monthly = store.monthly {
                        planButton(product: monthly, badge: nil)
                    }
                }

                #if DEBUG
                Button {
                    Task {
                        try? await HOADataStore.setAssociationPaid(associationId: associationId, plan: "debug-unlock")
                        await MainActor.run {
                            onUnlocked()
                            dismiss()
                        }
                    }
                } label: {
                    Text("DEV: Unlock free (DEBUG build)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.ink.opacity(0.4))
                }
                .buttonStyle(.plain)
                #endif

                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    Text("Not now").font(.system(size: 14, weight: .medium)).foregroundStyle(DS.ink.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .background(DS.paper.ignoresSafeArea())
    }

    private func planButton(product: Product, badge: String?) -> some View {
        Button {
            purchase(product)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(product.displayName).font(.system(size: 15, weight: .semibold))
                        if let badge {
                            Text(badge).font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(.white.opacity(0.25), in: Capsule())
                        }
                    }
                    Text(product.description).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.75)).lineLimit(2)
                }
                Spacer()
                if purchasingID == product.id {
                    ProgressView().tint(.white)
                } else {
                    Text(product.displayPrice).font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(LinearGradient(colors: [DS.brass, DS.brassLight], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(purchasingID != nil)
    }

    private func purchase(_ product: Product) {
        Haptics.tap()
        error = nil
        purchasingID = product.id
        Task {
            do {
                try await store.purchase(product, associationId: associationId)
                await MainActor.run {
                    purchasingID = nil
                    Haptics.success()
                    onUnlocked()
                    dismiss()
                }
            } catch StoreError.cancelled {
                await MainActor.run { purchasingID = nil }
            } catch {
                await MainActor.run {
                    purchasingID = nil
                    self.error = error.localizedDescription
                }
            }
        }
    }
}
