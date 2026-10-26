import SwiftUI

// Shared Ledger-styled primitives used across the dashboard, property, and
// report screens — ports of ui/card.tsx and ui/skeleton.tsx.

/// Ports components/toast.tsx — a brief, self-dismissing inline banner for
/// non-blocking errors (upload/session hiccups) surfaced from anywhere in the app.
struct ToastOverlay: View {
    @Binding var message: String?

    var body: some View {
        VStack {
            Spacer()
            if let message {
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(DS.ink.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(nanoseconds: 3_500_000_000)
                            withAnimation { self.message = nil }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: message)
    }
}

extension View {
    func toastOverlay(_ message: Binding<String?>) -> some View {
        self.overlay(ToastOverlay(message: message))
    }
}

struct LedgerCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(DS.ink.opacity(0.08))
            )
    }
}

struct StatusPill: View {
    let label: String
    let tone: StatusTone

    private var colors: (fg: Color, bg: Color) {
        switch tone {
        case .neutral: return (DS.ink.opacity(0.6), DS.ink.opacity(0.08))
        case .progress: return (DS.brass, DS.brass50)
        case .success: return (DS.emeraldDark, DS.emerald50)
        case .brass: return (DS.brass, DS.brass50)
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(colors.fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(colors.bg, in: Capsule())
    }
}

struct ConditionBadge: View {
    let condition: PhotoCondition

    private var colors: (fg: Color, bg: Color, border: Color) {
        switch condition {
        case .good: return (DS.emeraldDark, DS.emerald50, DS.emerald.opacity(0.3))
        case .fair: return (DS.brass, DS.brass50, DS.brass.opacity(0.3))
        case .damaged: return (DS.clay, DS.clay50, DS.clay.opacity(0.3))
        }
    }

    var body: some View {
        Text(condition.label)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(colors.fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(colors.bg, in: Capsule())
            .overlay(Capsule().strokeBorder(colors.border))
    }
}

struct SealBadge: View {
    var label: String = "Hash verified"
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.shield.fill").font(.system(size: 10, weight: .bold))
            Text(label).font(DS.mono(11, weight: .semibold)).tracking(0.4)
        }
        .foregroundStyle(DS.brass)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(DS.brass50, in: Capsule())
        .overlay(Capsule().strokeBorder(DS.brass.opacity(0.4)))
    }
}

struct EmptyStateCard: View {
    var icon: String = "checkmark.shield"
    let title: String
    let description: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(DS.brass)
            VStack(spacing: 6) {
                Text(title).font(DS.serif(20)).foregroundStyle(DS.ink).multilineTextAlignment(.center)
                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(DS.ink.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            if let actionTitle, let action {
                Button {
                    Haptics.tap()
                    action()
                } label: {
                    Text(actionTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(colors: [DS.emeraldDark, DS.emerald], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 44)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(DS.ink.opacity(0.12), style: StrokeStyle(lineWidth: 1.4, dash: [5, 5]))
        )
    }
}

struct ProgressRingView: View {
    let value: Double
    var size: CGFloat = 56
    var strokeWidth: CGFloat = 5

    private var clamped: Double { max(0, min(100, value)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(DS.ink.opacity(0.08), lineWidth: strokeWidth)
            Circle()
                .trim(from: 0, to: clamped / 100)
                .stroke(DS.emerald, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: clamped)
            Text("\(Int(clamped.rounded()))%")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.ink)
        }
        .frame(width: size, height: size)
    }
}

struct LedgerRuleDivider: View {
    var body: some View {
        LedgerRule().frame(height: 1)
    }
}

/// Full-bleed inline banner (paywall hints, missing-config notices, etc).
struct InlineNotice: View {
    var tone: Color = DS.brass
    var background: Color = DS.brass50
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(DS.ink.opacity(0.75))
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(tone.opacity(0.35))
            )
    }
}

enum LoadState {
    case loading, loaded, failed(String)
}

/// Simple full-screen async-load wrapper: spinner -> content -> designed error with retry.
struct AsyncStateView<Content: View>: View {
    let state: LoadState
    var retry: (() -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        switch state {
        case .loading:
            VStack(spacing: 14) {
                ProgressView().tint(DS.emerald)
                Text("Loading\u{2026}").font(.system(size: 13)).foregroundStyle(DS.ink.opacity(0.4))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            content()
        case .failed(let message):
            VStack(spacing: 16) {
                Image(systemName: "wifi.slash").font(.system(size: 30)).foregroundStyle(DS.clay)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(DS.ink.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                if let retry {
                    Button {
                        Haptics.tap()
                        retry()
                    } label: {
                        Text("Try again")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 11)
                            .background(DS.emerald, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
