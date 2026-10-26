import Foundation
import Supabase

/// Observes the Supabase auth session so the rest of the app can react to
/// sign-in / sign-out without any screen owning the source of truth.
@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var session: Session?
    @Published private(set) var isLoading = true

    private var listenerTask: Task<Void, Never>?

    init() {
        listenerTask = Task { [weak self] in
            guard let self else { return }
            for await (_, session) in supabase.auth.authStateChanges {
                self.session = session
                self.isLoading = false
            }
        }
    }

    var isSignedIn: Bool { session != nil }
    var userEmail: String? { session?.user.email }
    var userID: UUID? { session?.user.id }
    var accessToken: String? { session?.accessToken }

    func signOut() async {
        try? await supabase.auth.signOut()
    }

    deinit {
        listenerTask?.cancel()
    }
}
