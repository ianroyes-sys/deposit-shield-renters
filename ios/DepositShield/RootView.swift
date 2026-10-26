import SwiftUI

/// Onboarding -> auth -> app shell. Onboarding shows once; after that the
/// live Supabase session decides between the sign-in screen and the app.
struct RootView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @StateObject private var session = SessionStore()
    @State private var enteredOnboarding = false

    var body: some View {
        ZStack {
            if session.isLoading {
                SplashView()
                    .transition(.opacity)
            } else if !hasSeenOnboarding && !enteredOnboarding {
                OnboardingView {
                    hasSeenOnboarding = true
                    withAnimation(.easeInOut(duration: 0.6)) { enteredOnboarding = true }
                }
                .transition(.opacity)
            } else if session.isSignedIn {
                DashboardShell()
                    .environmentObject(session)
                    .transition(.opacity)
            } else {
                AuthView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: session.isLoading)
        .animation(.easeInOut(duration: 0.4), value: session.isSignedIn)
        .environmentObject(session)
    }
}

/// Brief branded splash shown only while the Supabase session is resolving
/// at cold launch (typically well under a second).
struct SplashView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            DS.ink.ignoresSafeArea()
            ZStack {
                Circle()
                    .strokeBorder(DS.emerald.opacity(0.35), lineWidth: 2)
                    .frame(width: 72, height: 72)
                    .scaleEffect(pulse ? 1.08 : 0.94)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [DS.brassLight, DS.brass], startPoint: .top, endPoint: .bottom))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
