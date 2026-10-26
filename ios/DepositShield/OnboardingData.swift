import SwiftUI

/// The three onboarding beats — mirrors the web app's own pitch, in order.
struct OnboardingCard: Identifiable {
    let id = UUID()
    let kicker: String
    let headline: String
    let emphasis: String
    let body: String
    let artifact: OnboardingArtifact
}

enum OnboardingArtifact {
    case seal          // (a) shield / wax-seal
    case hash          // (b) hash-verified evidence explainer
    case comparison     // (c) move-in vs move-out + evidence packet
}

enum OnboardingData {
    static let cards: [OnboardingCard] = [
        OnboardingCard(
            kicker: "DEPOSIT SHIELD",
            headline: "Your deposit.\nDocumented.",
            emphasis: "Protected.",
            body: "Every unit you move into gets a sealed, timestamped record — so your security deposit has a paper trail from day one.",
            artifact: .seal
        ),
        OnboardingCard(
            kicker: "EVIDENCE",
            headline: "Photos that\nhold up",
            emphasis: "in court.",
            body: "Each photo is hashed and timestamped the instant you take it — a fingerprint no one can quietly edit or backdate.",
            artifact: .hash
        ),
        OnboardingCard(
            kicker: "MOVE-OUT",
            headline: "Move out\nwith",
            emphasis: "proof.",
            body: "Move-in and move-out are compared automatically. Walk into any dispute with a court-ready evidence packet, not a memory.",
            artifact: .comparison
        ),
    ]
}
