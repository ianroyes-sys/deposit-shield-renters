import Foundation
import StoreKit

/// StoreKit 2 wrapper for the Communities Pro subscription group (monthly +
/// yearly). Reuses the `StoreError` enum defined alongside the renter-mode
/// StoreManager.
@MainActor
final class HOASubscriptionManager: ObservableObject {
    static let monthlyID = "hoa_pro_monthly"
    static let yearlyID = "hoa_pro_yearly"

    @Published private(set) var monthly: Product?
    @Published private(set) var yearly: Product?
    @Published private(set) var isLoadingProducts = true
    @Published private(set) var loadError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in await self?.listenForTransactions() }
        Task { [weak self] in await self?.loadProducts() }
    }

    func loadProducts() async {
        isLoadingProducts = true
        loadError = nil
        do {
            let products = try await Product.products(for: [Self.monthlyID, Self.yearlyID])
            monthly = products.first { $0.id == Self.monthlyID }
            yearly = products.first { $0.id == Self.yearlyID }
            if monthly == nil && yearly == nil {
                loadError = "These plans aren't available yet. Check back soon."
            }
        } catch {
            loadError = "Purchases aren't available right now."
        }
        isLoadingProducts = false
    }

    /// Purchases a Communities Pro plan and, once the transaction verifies,
    /// marks the association `is_paid` in Supabase.
    func purchase(_ product: Product, associationId: UUID) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            try await HOADataStore.setAssociationPaid(associationId: associationId, plan: product.id)
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
