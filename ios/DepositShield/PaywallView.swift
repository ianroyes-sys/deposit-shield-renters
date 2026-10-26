import SwiftUI

/// Ports components/paywall-sheet.tsx to a native StoreKit 2 sheet. The web
/// app's Stripe checkout is replaced entirely — Apple 3.1.1 requires this
/// digital unlock to happen via In-App Purchase.
struct PaywallView: View {
    let propertyId: UUID
    var title: String = "Unlock unlimited photos"
    var description: String = "You've hit the free limit of \(FreeTier.photoLimit) photos on this property. Unlock Shield, one time, to keep documenting with unlimited photos, the full report, and the evidence packet."
    var onUnlocked: () -> Void

    @StateObject private var store = StoreManager()
    @Environment(\.dismiss) private var dismiss
    @State private var purchasing = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 22) {
            Capsule().fill(DS.ink.opacity(0.15)).frame(width: 40, height: 5).padding(.top, 10)

            VStack(spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill").font(.system(size: 11, weight: .bold))
                    Text("SHIELD \u{b7} \(priceLabel) ONE TIME").tracking(0.6)
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
                if store.isLoadingProduct {
                    ProgressView().tint(DS.emerald)
                } else if store.product == nil {
                    InlineNotice(tone: DS.clay, background: DS.clay50, text: store.loadError ?? "Purchases aren't available right now.")
                } else {
                    LedgerButton(title: purchasing ? "Processing\u{2026}" : "Unlock for \(priceLabel)", isLoading: purchasing, disabled: purchasing) {
                        purchase()
                    }
                }

                #if DEBUG
                Button {
                    Task {
                        try? await DataStore.setPaid(propertyId: propertyId, sessionId: "debug-unlock")
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

    private var priceLabel: String { store.product?.displayPrice ?? "$17.99" }

    private func purchase() {
        Haptics.tap()
        error = nil
        purchasing = true
        Task {
            do {
                try await store.purchase(propertyId: propertyId)
                await MainActor.run {
                    purchasing = false
                    Haptics.success()
                    onUnlocked()
                    dismiss()
                }
            } catch StoreError.cancelled {
                await MainActor.run { purchasing = false }
            } catch {
                await MainActor.run {
                    purchasing = false
                    self.error = error.localizedDescription
                }
            }
        }
    }
}
