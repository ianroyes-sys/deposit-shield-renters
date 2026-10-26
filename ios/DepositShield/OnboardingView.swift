import SwiftUI

/// Three swipeable cards on the ink-navy Ledger surface, ending in the
/// "Get started" CTA that hands off to the live web app.
struct OnboardingView: View {
    let onEnter: () -> Void

    @State private var index = 0
    @State private var showContent = false

    var body: some View {
        ZStack {
            DS.ink.ignoresSafeArea()
            LedgerBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("DEPOSIT SHIELD")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(3.6)
                        .foregroundStyle(DS.paper)
                    Spacer()
                    HashBadge(text: "SEALED")
                }
                .padding(.top, 8)
                .opacity(showContent ? 1 : 0)

                TabView(selection: $index) {
                    ForEach(Array(OnboardingData.cards.enumerated()), id: \.element.id) { i, card in
                        OnboardingCardView(card: card)
                            .tag(i)
                            .padding(.bottom, 8)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .indexViewStyle(.page(backgroundDisplayMode: .never))
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 22)

                // ledger-rule divider — dashed brass line motif from the web app
                LedgerRule()
                    .frame(height: 1)
                    .padding(.horizontal, 32)
                    .opacity(showContent ? 1 : 0)

                HStack(spacing: 6) {
                    ForEach(Array(OnboardingData.cards.enumerated()), id: \.offset) { i, _ in
                        Capsule()
                            .fill(i == index ? DS.emerald : DS.paper.opacity(0.22))
                            .frame(width: i == index ? 20 : 6, height: 4)
                            .animation(.easeInOut(duration: 0.35), value: index)
                    }
                }
                .padding(.top, 22)
                .opacity(showContent ? 1 : 0)

                Spacer(minLength: 20)

                VStack(spacing: 12) {
                    Button {
                        Haptics.tap()
                        if index < OnboardingData.cards.count - 1 {
                            withAnimation(.easeInOut) { index += 1 }
                        } else {
                            onEnter()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text(index < OnboardingData.cards.count - 1 ? "Continue" : "Get started")
                                .font(.system(size: 16, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            LinearGradient(colors: [DS.emeraldDark, DS.emerald],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Capsule()
                        )
                        .shadow(color: DS.emerald.opacity(0.35), radius: 22, y: 8)
                    }
                    .buttonStyle(.plain)

                    if index < OnboardingData.cards.count - 1 {
                        Button {
                            Haptics.tap()
                            onEnter()
                        } label: {
                            Text("Skip")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(DS.paper.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("No account needed to look around")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(0.3)
                            .foregroundStyle(DS.paper.opacity(0.4))
                    }
                }
                .padding(.bottom, 12)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 18)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.2)) { showContent = true }
        }
    }
}

// MARK: - Card

private struct OnboardingCardView: View {
    let card: OnboardingCard

    var body: some View {
        VStack(spacing: 0) {
            Text(card.kicker)
                .font(DS.mono(11, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(DS.brassLight)
                .padding(.top, 6)

            Spacer(minLength: 18)

            ArtifactView(kind: card.artifact)
                .frame(height: 190)

            Spacer(minLength: 22)

            (Text(card.headline + " ")
                .font(DS.serif(32))
                .foregroundStyle(DS.paper)
             + Text(card.emphasis)
                .font(DS.serif(32, italic: true))
                .foregroundStyle(DS.emerald))
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text(card.body)
                .font(.system(size: 14))
                .foregroundStyle(DS.paper.opacity(0.62))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 12)
                .padding(.horizontal, 8)

            Spacer(minLength: 4)
        }
    }
}

// MARK: - Artifacts (one per card)

private struct ArtifactView: View {
    let kind: OnboardingArtifact

    var body: some View {
        switch kind {
        case .seal: SealArtifact()
        case .hash: HashArtifact()
        case .comparison: ComparisonArtifact()
        }
    }
}

/// (a) A brass wax-seal shield, mirroring the app icon motif.
private struct SealArtifact: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(DS.emerald.opacity(0.14))
                .frame(width: 168, height: 168)
                .blur(radius: 26)

            Circle()
                .strokeBorder(DS.emerald, lineWidth: 2)
                .frame(width: 132, height: 132)
                .opacity(animate ? 1 : 0.4)
                .scaleEffect(animate ? 1 : 0.9)

            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 76, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [DS.brassLight, DS.brass],
                                   startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.15)) { animate = true }
        }
    }
}

/// (b) A hashed, timestamped evidence card — mono type doing the work.
private struct HashArtifact: View {
    @State private var reveal = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DS.ink800)
                    .frame(width: 108, height: 108)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(DS.brass.opacity(0.35), lineWidth: 1)
                    .frame(width: 108, height: 108)
                Image(systemName: "camera.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(DS.paper.opacity(0.85))
            }

            VStack(spacing: 6) {
                HashBadge(text: "a3f9•d1e2•88c4")
                Text(reveal ? "Jul 16, 2026 · 9:41 AM" : "verifying…")
                    .font(DS.mono(11))
                    .foregroundStyle(DS.paper.opacity(0.45))
                    .contentTransition(.opacity)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).delay(0.6)) { reveal = true }
        }
    }
}

/// (c) Move-in vs move-out mini frames resolving into an evidence packet.
private struct ComparisonArtifact: View {
    @State private var checked = false

    var body: some View {
        HStack(spacing: 16) {
            MiniFrame(label: "MOVE-IN", tint: DS.brass)
            Image(systemName: checked ? "checkmark.circle.fill" : "arrow.right")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(checked ? DS.emerald : DS.paper.opacity(0.4))
                .contentTransition(.symbolEffect(.replace))
            MiniFrame(label: "MOVE-OUT", tint: DS.emerald)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).delay(0.5)) { checked = true }
        }
    }

    private struct MiniFrame: View {
        let label: String
        let tint: Color
        var body: some View {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DS.ink800)
                    .frame(width: 88, height: 118)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(tint.opacity(0.45), lineWidth: 1.2)
                    )
                    .overlay(
                        Image(systemName: "photo.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(tint.opacity(0.6))
                    )
                Text(label)
                    .font(DS.mono(9, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(DS.paper.opacity(0.5))
            }
        }
    }
}

// MARK: - Shared chrome

private struct HashBadge: View {
    let text: String
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "number")
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(DS.mono(10, weight: .semibold))
        }
        .tracking(0.6)
        .foregroundStyle(DS.emerald)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(DS.emerald.opacity(0.14), in: Capsule())
    }
}

/// The dashed brass "ledger-rule" divider, ported from the web app's
/// `.ledger-rule` repeating-gradient motif.
struct LedgerRule: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let dash: CGFloat = 6
                var x: CGFloat = 0
                while x < geo.size.width {
                    path.move(to: CGPoint(x: x, y: geo.size.height / 2))
                    path.addLine(to: CGPoint(x: min(x + dash, geo.size.width), y: geo.size.height / 2))
                    x += dash * 2
                }
            }
            .stroke(DS.brass.opacity(0.5), lineWidth: 1)
        }
    }
}

/// Ambient ledger-paper texture: faint brass hairlines drifting on ink.
private struct LedgerBackground: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            Circle()
                .fill(DS.brass.opacity(0.08))
                .frame(width: 420, height: 420)
                .blur(radius: 100)
                .offset(x: drift ? 110 : 150, y: drift ? -260 : -300)
            Circle()
                .fill(DS.emerald.opacity(0.06))
                .frame(width: 380, height: 380)
                .blur(radius: 100)
                .offset(x: drift ? -140 : -110, y: drift ? 280 : 320)
        }
        .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: drift)
        .onAppear { drift = true }
    }
}
