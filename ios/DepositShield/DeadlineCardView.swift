import SwiftUI

/// Ports p/[id]/deadline-card.tsx.
struct DeadlineCardView: View {
    let state: String?
    let moveOutCompletedAt: String?

    private var law: StateDepositLaw? { StateDepositLaws.law(for: state) }

    var body: some View {
        if let law {
            LedgerCard(padding: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(law.name.uppercased()) DEPOSIT DEADLINE")
                        .font(DS.mono(10.5, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(DS.brass)
                    Text("\(law.returnDeadlineDays) days")
                        .font(DS.serif(24))
                        .foregroundStyle(DS.ink)
                    Text(deadlineDescription(law))
                        .font(.system(size: 12.5))
                        .foregroundStyle(DS.ink.opacity(0.6))
                    if law.itemizedStatementRequired {
                        Text("An itemized statement of deductions is generally required.")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.ink.opacity(0.55))
                    }
                    Text("Not legal advice \u{b7} reviewed \(law.lastReviewed) \u{b7} small-claims limit \(law.smallClaimsLimit)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(DS.ink.opacity(0.4))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(DS.brass.opacity(0.3))
            )
        } else {
            VStack(alignment: .leading) {
                Text("Add your state to see your deposit return deadline.")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.ink.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(DS.ink.opacity(0.12), style: StrokeStyle(lineWidth: 1.2, dash: [5, 5]))
            )
        }
    }

    private func deadlineDescription(_ law: StateDepositLaw) -> String {
        guard let moveOut = moveOutCompletedAt, let d = Formatters.parseISODate(moveOut) else {
            return "Counted from your move-out date."
        }
        let deadline = Calendar.current.date(byAdding: .day, value: law.returnDeadlineDays, to: d) ?? d
        return "Due back by \(Formatters.date(deadline)) based on your move-out date."
    }
}
