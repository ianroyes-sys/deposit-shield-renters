import Foundation
import StoreKit

/// StoreKit 2 wrapper for the single "Shield" per-property unlock. Apple
/// 3.1.1 requires this digital unlock to go through IAP rather than Stripe —
/// this replaces the web app's Stripe checkout for the native app only.
@MainActor
final class StoreManager: ObservableObject {
    static let shieldUnlockID = "shield_unlock_17"

    @Published private(set) var product: Product?
    @Published private(set) var isLoadingProduct = true
    @Published private(set) var loadError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in await self?.listenForTransactions() }
        Task { [weak self] in await self?.loadProduct() }
    }

    func loadProduct() async {
        isLoadingProduct = true
        loadError = nil
        do {
            let products = try await Product.products(for: [Self.shieldUnlockID])
            product = products.first
            if product == nil {
                loadError = "This product isn't available yet. Check back soon."
            }
        } catch {
            loadError = "Purchases aren't available right now."
        }
        isLoadingProduct = false
    }

    /// Purchases the Shield unlock for one property and, once the transaction
    /// verifies, marks that property `is_paid` in Supabase.
    func purchase(propertyId: UUID) async throws {
        guard let product else { throw StoreError.noProduct }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            try await DataStore.setPaid(propertyId: propertyId, sessionId: "storekit-\(transaction.id)")
            await transaction.finish()
        case .userCancelled:
            throw StoreError.cancelled
        case .pending:
            throw StoreError.pending
        @unknown default:
            throw StoreError.unknown
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? Self.checkVerified(result) {
                await transaction.finish()
            }
        }
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.unverified
        case .verified(let safe): return safe
        }
    }

    deinit { updatesTask?.cancel() }
}

enum StoreError: LocalizedError {
    case noProduct, cancelled, pending, unverified, unknown

    var errorDescription: String? {
        switch self {
        case .noProduct: return "Purchases aren't available right now."
        case .cancelled: return "Purchase cancelled."
        case .pending: return "Purchase is pending approval — Shield will unlock once it clears."
        case .unverified: return "Could not verify this purchase."
        case .unknown: return "Something went wrong with the purchase."
        }
    }
}
