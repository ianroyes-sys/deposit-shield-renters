import SwiftUI

/// Native email one-time-passcode sign-in, ported from login-form.tsx.
/// No password — Supabase emails a 6-digit code (and a magic link) and the
/// global SessionStore's authStateChanges listener carries the app forward
/// the moment verification succeeds.
struct AuthView: View {
    private enum Stage { case email, sent }

    @State private var stage: Stage = .email
    @State private var email = ""
    @State private var code = ""
    @State private var error: String?
    @State private var loading = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 26) {
                    header

                    Group {
                        switch stage {
                        case .email: emailForm
                        case .sent: codeForm
                        }
                    }
                    .padding(24)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(DS.ink.opacity(0.08))
                    )
                }
                .padding(24)
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { fieldFocused = true }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(DS.emerald.opacity(0.12)).frame(width: 60, height: 60)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [DS.brassLight, DS.brass], startPoint: .top, endPoint: .bottom))
            }
            .padding(.top, 12)

            Text("Sign in to Deposit Shield")
                .font(DS.serif(24))
                .foregroundStyle(DS.ink)
            Text("No password needed — just a secure code emailed to you.")
                .font(.system(size: 13))
                .foregroundStyle(DS.ink.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }

    private var emailForm: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Email address")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DS.ink.opacity(0.7))
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($fieldFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(DS.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(fieldFocused ? DS.emerald : DS.ink.opacity(0.1), lineWidth: 1.4)
                    )
            }

            if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(DS.clay)
            }

            LedgerButton(title: loading ? "Sending\u{2026}" : "Continue with email", isLoading: loading, disabled: !isValidEmail || loading) {
                sendCode()
            }

            Text("We'll email you a secure sign-in link and a backup code.")
                .font(.system(size: 11.5))
                .foregroundStyle(DS.ink.opacity(0.4))
                .multilineTextAlignment(.center)
        }
    }

    private var codeForm: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "envelope.badge.fill")
                    .foregroundStyle(DS.emeraldDark)
                Text("Check ").foregroundStyle(DS.emeraldDark) +
                Text(email).fontWeight(.semibold).foregroundStyle(DS.emeraldDark) +
                Text(" for your sign-in link or 6-digit code.").foregroundStyle(DS.emeraldDark)
            }
            .font(.system(size: 13))
            .padding(12)
            .background(DS.emerald50, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("6-digit code")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DS.ink.opacity(0.7))
                TextField("123456", text: $code)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(DS.mono(20, weight: .semibold))
                    .tracking(6)
                    .focused($fieldFocused)
                    .padding(.vertical, 14)
                    .background(DS.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(fieldFocused ? DS.emerald : DS.ink.opacity(0.1), lineWidth: 1.4)
                    )
                    .onChange(of: code) { _, newValue in
                        code = String(newValue.filter(\.isNumber).prefix(6))
                    }
            }

            if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(DS.clay)
            }

            LedgerButton(title: loading ? "Verifying\u{2026}" : "Verify & continue", isLoading: loading, disabled: code.count < 6 || loading) {
                verifyCode()
            }

            Button {
                Haptics.tap()
                stage = .email
                code = ""
                error = nil
            } label: {
                Text("Use a different email")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DS.ink.opacity(0.5))
            }
        }
    }

    private var isValidEmail: Bool {
        email.contains("@") && email.contains(".") && email.count > 5
    }

    private func sendCode() {
        error = nil
        loading = true
        Task {
            do {
                try await supabase.auth.signInWithOTP(email: email)
                await MainActor.run {
                    loading = false
                    stage = .sent
                    fieldFocused = true
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.loading = false
                }
            }
        }
    }

    private func verifyCode() {
        error = nil
        loading = true
        Task {
            do {
                _ = try await supabase.auth.verifyOTP(email: email, token: code, type: .email)
                // SessionStore's authStateChanges listener carries the app into
                // the dashboard automatically once the session lands.
                await MainActor.run { loading = false }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.loading = false
                }
            }
        }
    }
}

/// Shared emerald gradient CTA used across the auth + onboarding flows.
struct LedgerButton: View {
    let title: String
    var isLoading: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.85)
                }
                Text(title).font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [DS.emeraldDark, DS.emerald], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Capsule()
            )
            .opacity(disabled ? 0.5 : 1)
            .shadow(color: DS.emerald.opacity(disabled ? 0 : 0.3), radius: 18, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
