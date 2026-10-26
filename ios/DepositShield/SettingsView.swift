import SwiftUI

/// Ports app/settings/page.tsx + delete-account-button.tsx. Account deletion
/// calls the web app's existing bearer-token endpoint rather than duplicating
/// that (admin-key-gated) logic on-device.
struct SettingsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var confirmingDelete = false
    @State private var deleting = false
    @State private var deleteState: DeleteState = .idle

    private enum DeleteState: Equatable {
        case idle, pending, error(String)
    }

    var body: some View {
        ZStack {
            DS.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Settings").font(DS.serif(28)).foregroundStyle(DS.ink)
                    LedgerRuleDivider()

                    LedgerCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Signed in as").font(.system(size: 11.5)).foregroundStyle(DS.ink.opacity(0.45))
                            Text(session.userEmail ?? "\u{2014}").font(DS.mono(14)).foregroundStyle(DS.ink)
                            Button {
                                Haptics.tap()
                                Task { await session.signOut() }
                            } label: {
                                Text("Sign out")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(DS.ink)
                                    .padding(.horizontal, 18).padding(.vertical, 10)
                                    .background(DS.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(DS.brass.opacity(0.4)))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    LedgerCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Danger zone").font(DS.serif(18)).foregroundStyle(DS.ink)
                            Text("Deleting your account removes every property, photo, and report permanently.")
                                .font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.55))

                            switch deleteState {
                            case .idle where !confirmingDelete:
                                Button {
                                    Haptics.tap()
                                    confirmingDelete = true
                                } label: {
                                    Text("Delete account")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 18).padding(.vertical, 10)
                                        .background(DS.clay, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            case .pending:
                                InlineNotice(tone: DS.clay, background: DS.clay50, text: "Deletion pending \u{2014} we couldn't confirm this went through. Contact support if your account is still active tomorrow.")
                            case .error(let message):
                                InlineNotice(tone: DS.clay, background: DS.clay50, text: message)
                            default:
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("This permanently deletes every property, photo, and report. This cannot be undone.")
                                        .font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.8))
                                    HStack(spacing: 10) {
                                        Button {
                                            Haptics.tap()
                                            deleteAccount()
                                        } label: {
                                            HStack(spacing: 6) {
                                                if deleting { ProgressView().tint(.white).scaleEffect(0.8) }
                                                Text(deleting ? "Deleting\u{2026}" : "Yes, delete everything")
                                            }
                                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                            .padding(.horizontal, 14).padding(.vertical, 9)
                                            .background(DS.clay, in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(deleting)

                                        Button {
                                            Haptics.tap()
                                            confirmingDelete = false
                                        } label: {
                                            Text("Cancel").font(.system(size: 13, weight: .medium)).foregroundStyle(DS.ink.opacity(0.5))
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(deleting)
                                    }
                                }
                                .padding(12)
                                .background(DS.clay50, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func deleteAccount() {
        guard let token = session.accessToken else {
            deleteState = .error("Your session expired \u{2014} sign in again before deleting your account.")
            return
        }
        deleting = true
        Task {
            var request = URLRequest(url: SupabaseConfig.webAppURL.appendingPathComponent("api/account/delete"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                await MainActor.run {
                    deleting = false
                    if (200..<300).contains(statusCode) {
                        Task { await session.signOut() }
                    } else if let serverMessage = Self.errorMessage(from: data) {
                        // The endpoint answered with a real error (e.g. "Not signed in",
                        // or the service role isn't configured server-side) — show it
                        // verbatim rather than the ambiguous "pending" state.
                        deleteState = .error(serverMessage)
                    } else {
                        deleteState = .pending
                    }
                }
            } catch {
                await MainActor.run {
                    deleting = false
                    // A transport-level failure (offline, timeout) — the request may or
                    // may not have reached the server, so don't claim it definitely failed.
                    deleteState = .pending
                }
            }
        }
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = object["error"] as? String else { return nil }
        return message
    }
}
