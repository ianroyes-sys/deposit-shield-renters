import Foundation

// Ported 1:1 from src/lib/state-deposit-laws.ts. Reasonable, general-guidance
// figures — reviewed 2026-07. NOT LEGAL ADVICE.
struct StateDepositLaw: Identifiable, Hashable {
    var code: String
    var name: String
    var returnDeadlineDays: Int
    var itemizedStatementRequired: Bool
    var depositLimitNote: String
    var smallClaimsLimit: String
    var lastReviewed: String

    var id: String { code }
}

enum StateDepositLaws {
    static let all: [StateDepositLaw] = [
        .init(code: "AL", name: "Alabama", returnDeadlineDays: 35, itemizedStatementRequired: true, depositLimitNote: "1 month's rent (unfurnished)", smallClaimsLimit: "$6,000", lastReviewed: "2026-07"),
        .init(code: "AK", name: "Alaska", returnDeadlineDays: 14, itemizedStatementRequired: true, depositLimitNote: "2 months' rent if rent > $2,000/mo", smallClaimsLimit: "$10,000", lastReviewed: "2026-07"),
        .init(code: "AZ", name: "Arizona", returnDeadlineDays: 14, itemizedStatementRequired: true, depositLimitNote: "1.5 months' rent", smallClaimsLimit: "$3,500", lastReviewed: "2026-07"),
        .init(code: "AR", name: "Arkansas", returnDeadlineDays: 60, itemizedStatementRequired: true, depositLimitNote: "2 months' rent", smallClaimsLimit: "$5,000", lastReviewed: "2026-07"),
        .init(code: "CA", name: "California", returnDeadlineDays: 21, itemizedStatementRequired: true, depositLimitNote: "1 month's rent (unfurnished); AB 2801 (2026) requires move-in/move-out photo documentation", smallClaimsLimit: "$12,500", lastReviewed: "2026-07"),
        .init(code: "CO", name: "Colorado", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$7,500", lastReviewed: "2026-07"),
        .init(code: "CT", name: "Connecticut", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "2 months' rent (1 month if tenant 62+)", smallClaimsLimit: "$5,000", lastReviewed: "2026-07"),
        .init(code: "DE", name: "Delaware", returnDeadlineDays: 20, itemizedStatementRequired: true, depositLimitNote: "1 month's rent (leases 1yr+)", smallClaimsLimit: "$25,000", lastReviewed: "2026-07"),
        .init(code: "DC", name: "District of Columbia", returnDeadlineDays: 45, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$10,000", lastReviewed: "2026-07"),
        .init(code: "FL", name: "Florida", returnDeadlineDays: 15, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$8,000", lastReviewed: "2026-07"),
        .init(code: "GA", name: "Georgia", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$15,000", lastReviewed: "2026-07"),
        .init(code: "HI", name: "Hawaii", returnDeadlineDays: 14, itemizedStatementRequired: true, depositLimitNote: "1 month's rent", smallClaimsLimit: "$10,000", lastReviewed: "2026-07"),
        .init(code: "ID", name: "Idaho", returnDeadlineDays: 21, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$5,000", lastReviewed: "2026-07"),
        .init(code: "IL", name: "Illinois", returnDeadlineDays: 45, itemizedStatementRequired: true, depositLimitNote: "No statewide cap (Chicago: no cap, interest required)", smallClaimsLimit: "$10,000", lastReviewed: "2026-07"),
        .init(code: "IN", name: "Indiana", returnDeadlineDays: 45, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$8,000", lastReviewed: "2026-07"),
        .init(code: "IA", name: "Iowa", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "2 months' rent", smallClaimsLimit: "$6,500", lastReviewed: "2026-07"),
        .init(code: "KS", name: "Kansas", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "1 month (unfurnished) / 1.5 months (furnished)", smallClaimsLimit: "$4,000", lastReviewed: "2026-07"),
        .init(code: "KY", name: "Kentucky", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$2,500", lastReviewed: "2026-07"),
        .init(code: "LA", name: "Louisiana", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$5,000", lastReviewed: "2026-07"),
        .init(code: "ME", name: "Maine", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "2 months' rent", smallClaimsLimit: "$6,000", lastReviewed: "2026-07"),
        .init(code: "MD", name: "Maryland", returnDeadlineDays: 45, itemizedStatementRequired: true, depositLimitNote: "2 months' rent", smallClaimsLimit: "$5,000", lastReviewed: "2026-07"),
        .init(code: "MA", name: "Massachusetts", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "1 month's rent, interest required", smallClaimsLimit: "$7,000", lastReviewed: "2026-07"),
        .init(code: "MI", name: "Michigan", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "1.5 months' rent", smallClaimsLimit: "$7,000", lastReviewed: "2026-07"),
        .init(code: "MN", name: "Minnesota", returnDeadlineDays: 21, itemizedStatementRequired: true, depositLimitNote: "No statutory cap, interest required", smallClaimsLimit: "$15,000", lastReviewed: "2026-07"),
        .init(code: "MS", name: "Mississippi", returnDeadlineDays: 45, itemizedStatementRequired: false, depositLimitNote: "No statutory cap", smallClaimsLimit: "$3,500", lastReviewed: "2026-07"),
        .init(code: "MO", name: "Missouri", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "2 months' rent", smallClaimsLimit: "$5,000", lastReviewed: "2026-07"),
        .init(code: "MT", name: "Montana", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$7,000", lastReviewed: "2026-07"),
        .init(code: "NE", name: "Nebraska", returnDeadlineDays: 14, itemizedStatementRequired: true, depositLimitNote: "1 month's rent", smallClaimsLimit: "$3,900", lastReviewed: "2026-07"),
        .init(code: "NV", name: "Nevada", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "3 months' rent", smallClaimsLimit: "$10,000", lastReviewed: "2026-07"),
        .init(code: "NH", name: "New Hampshire", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "1 month's rent or $100, whichever is greater", smallClaimsLimit: "$10,000", lastReviewed: "2026-07"),
        .init(code: "NJ", name: "New Jersey", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "1.5 months' rent, interest required", smallClaimsLimit: "$5,000", lastReviewed: "2026-07"),
        .init(code: "NM", name: "New Mexico", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "1 month's rent (leases under 1yr)", smallClaimsLimit: "$10,000", lastReviewed: "2026-07"),
        .init(code: "NY", name: "New York", returnDeadlineDays: 14, itemizedStatementRequired: true, depositLimitNote: "1 month's rent", smallClaimsLimit: "$5,000", lastReviewed: "2026-07"),
        .init(code: "NC", name: "North Carolina", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "1.5-2 months' rent depending on lease term", smallClaimsLimit: "$10,000", lastReviewed: "2026-07"),
        .init(code: "ND", name: "North Dakota", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "1 month's rent (higher with pets)", smallClaimsLimit: "$15,000", lastReviewed: "2026-07"),
        .init(code: "OH", name: "Ohio", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$6,000", lastReviewed: "2026-07"),
        .init(code: "OK", name: "Oklahoma", returnDeadlineDays: 45, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$10,000", lastReviewed: "2026-07"),
        .init(code: "OR", name: "Oregon", returnDeadlineDays: 31, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$10,000", lastReviewed: "2026-07"),
        .init(code: "PA", name: "Pennsylvania", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "2 months' rent (year 1), 1 month after", smallClaimsLimit: "$12,000", lastReviewed: "2026-07"),
        .init(code: "RI", name: "Rhode Island", returnDeadlineDays: 20, itemizedStatementRequired: true, depositLimitNote: "1 month's rent", smallClaimsLimit: "$5,000", lastReviewed: "2026-07"),
        .init(code: "SC", name: "South Carolina", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$7,500", lastReviewed: "2026-07"),
        .init(code: "SD", name: "South Dakota", returnDeadlineDays: 14, itemizedStatementRequired: true, depositLimitNote: "1 month's rent (more if pets)", smallClaimsLimit: "$12,000", lastReviewed: "2026-07"),
        .init(code: "TN", name: "Tennessee", returnDeadlineDays: 30, itemizedStatementRequired: false, depositLimitNote: "No statutory cap", smallClaimsLimit: "$25,000", lastReviewed: "2026-07"),
        .init(code: "TX", name: "Texas", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$20,000", lastReviewed: "2026-07"),
        .init(code: "UT", name: "Utah", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$11,000", lastReviewed: "2026-07"),
        .init(code: "VT", name: "Vermont", returnDeadlineDays: 14, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$5,000", lastReviewed: "2026-07"),
        .init(code: "VA", name: "Virginia", returnDeadlineDays: 45, itemizedStatementRequired: true, depositLimitNote: "2 months' rent", smallClaimsLimit: "$5,000", lastReviewed: "2026-07"),
        .init(code: "WA", name: "Washington", returnDeadlineDays: 21, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$10,000", lastReviewed: "2026-07"),
        .init(code: "WV", name: "West Virginia", returnDeadlineDays: 45, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$10,000", lastReviewed: "2026-07"),
        .init(code: "WI", name: "Wisconsin", returnDeadlineDays: 21, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$10,000", lastReviewed: "2026-07"),
        .init(code: "WY", name: "Wyoming", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap (60 days if itemized deductions)", smallClaimsLimit: "$6,000", lastReviewed: "2026-07"),
    ]

    static func law(for code: String?) -> StateDepositLaw? {
        guard let code, !code.isEmpty else { return nil }
        return all.first { $0.code == code.uppercased() }
    }
}
