// Reasonable, general-guidance figures for security deposit return rules by
// state. Reviewed 2026-07. NOT LEGAL ADVICE — always verify against current
// statute or a local attorney/tenant union before relying on these numbers.
export interface StateDepositLaw {
  code: string;
  name: string;
  returnDeadlineDays: number;
  itemizedStatementRequired: boolean;
  depositLimitNote: string;
  smallClaimsLimit: string;
  lastReviewed: string;
}

export const STATE_DEPOSIT_LAWS: StateDepositLaw[] = [
  { code: "AL", name: "Alabama", returnDeadlineDays: 35, itemizedStatementRequired: true, depositLimitNote: "1 month's rent (unfurnished)", smallClaimsLimit: "$6,000", lastReviewed: "2026-07" },
  { code: "AK", name: "Alaska", returnDeadlineDays: 14, itemizedStatementRequired: true, depositLimitNote: "2 months' rent if rent > $2,000/mo", smallClaimsLimit: "$10,000", lastReviewed: "2026-07" },
  { code: "AZ", name: "Arizona", returnDeadlineDays: 14, itemizedStatementRequired: true, depositLimitNote: "1.5 months' rent", smallClaimsLimit: "$3,500", lastReviewed: "2026-07" },
  { code: "AR", name: "Arkansas", returnDeadlineDays: 60, itemizedStatementRequired: true, depositLimitNote: "2 months' rent", smallClaimsLimit: "$5,000", lastReviewed: "2026-07" },
  { code: "CA", name: "California", returnDeadlineDays: 21, itemizedStatementRequired: true, depositLimitNote: "1 month's rent (unfurnished); AB 2801 (in force since 2025) requires landlord move-out photos, and move-in photos for tenancies starting Jul 1, 2025+", smallClaimsLimit: "$12,500", lastReviewed: "2026-07" },
  { code: "CO", name: "Colorado", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$7,500", lastReviewed: "2026-07" },
  { code: "CT", name: "Connecticut", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "2 months' rent (1 month if tenant 62+)", smallClaimsLimit: "$5,000", lastReviewed: "2026-07" },
  { code: "DE", name: "Delaware", returnDeadlineDays: 20, itemizedStatementRequired: true, depositLimitNote: "1 month's rent (leases 1yr+)", smallClaimsLimit: "$25,000", lastReviewed: "2026-07" },
  { code: "DC", name: "District of Columbia", returnDeadlineDays: 45, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$10,000", lastReviewed: "2026-07" },
  { code: "FL", name: "Florida", returnDeadlineDays: 15, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$8,000", lastReviewed: "2026-07" },
  { code: "GA", name: "Georgia", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$15,000", lastReviewed: "2026-07" },
  { code: "HI", name: "Hawaii", returnDeadlineDays: 14, itemizedStatementRequired: true, depositLimitNote: "1 month's rent", smallClaimsLimit: "$10,000", lastReviewed: "2026-07" },
  { code: "ID", name: "Idaho", returnDeadlineDays: 21, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$5,000", lastReviewed: "2026-07" },
  { code: "IL", name: "Illinois", returnDeadlineDays: 45, itemizedStatementRequired: true, depositLimitNote: "No statewide cap (Chicago: no cap, interest required)", smallClaimsLimit: "$10,000", lastReviewed: "2026-07" },
  { code: "IN", name: "Indiana", returnDeadlineDays: 45, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$8,000", lastReviewed: "2026-07" },
  { code: "IA", name: "Iowa", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "2 months' rent", smallClaimsLimit: "$6,500", lastReviewed: "2026-07" },
  { code: "KS", name: "Kansas", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "1 month (unfurnished) / 1.5 months (furnished)", smallClaimsLimit: "$4,000", lastReviewed: "2026-07" },
  { code: "KY", name: "Kentucky", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$2,500", lastReviewed: "2026-07" },
  { code: "LA", name: "Louisiana", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$5,000", lastReviewed: "2026-07" },
  { code: "ME", name: "Maine", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "2 months' rent", smallClaimsLimit: "$6,000", lastReviewed: "2026-07" },
  { code: "MD", name: "Maryland", returnDeadlineDays: 45, itemizedStatementRequired: true, depositLimitNote: "2 months' rent", smallClaimsLimit: "$5,000", lastReviewed: "2026-07" },
  { code: "MA", name: "Massachusetts", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "1 month's rent, interest required", smallClaimsLimit: "$7,000", lastReviewed: "2026-07" },
  { code: "MI", name: "Michigan", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "1.5 months' rent", smallClaimsLimit: "$7,000", lastReviewed: "2026-07" },
  { code: "MN", name: "Minnesota", returnDeadlineDays: 21, itemizedStatementRequired: true, depositLimitNote: "No statutory cap, interest required", smallClaimsLimit: "$15,000", lastReviewed: "2026-07" },
  { code: "MS", name: "Mississippi", returnDeadlineDays: 45, itemizedStatementRequired: false, depositLimitNote: "No statutory cap", smallClaimsLimit: "$3,500", lastReviewed: "2026-07" },
  { code: "MO", name: "Missouri", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "2 months' rent", smallClaimsLimit: "$5,000", lastReviewed: "2026-07" },
  { code: "MT", name: "Montana", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$7,000", lastReviewed: "2026-07" },
  { code: "NE", name: "Nebraska", returnDeadlineDays: 14, itemizedStatementRequired: true, depositLimitNote: "1 month's rent", smallClaimsLimit: "$3,900", lastReviewed: "2026-07" },
  { code: "NV", name: "Nevada", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "3 months' rent", smallClaimsLimit: "$10,000", lastReviewed: "2026-07" },
  { code: "NH", name: "New Hampshire", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "1 month's rent or $100, whichever is greater", smallClaimsLimit: "$10,000", lastReviewed: "2026-07" },
  { code: "NJ", name: "New Jersey", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "1.5 months' rent, interest required", smallClaimsLimit: "$5,000", lastReviewed: "2026-07" },
  { code: "NM", name: "New Mexico", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "1 month's rent (leases under 1yr)", smallClaimsLimit: "$10,000", lastReviewed: "2026-07" },
  { code: "NY", name: "New York", returnDeadlineDays: 14, itemizedStatementRequired: true, depositLimitNote: "1 month's rent", smallClaimsLimit: "$5,000", lastReviewed: "2026-07" },
  { code: "NC", name: "North Carolina", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "1.5-2 months' rent depending on lease term", smallClaimsLimit: "$10,000", lastReviewed: "2026-07" },
  { code: "ND", name: "North Dakota", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "1 month's rent (higher with pets)", smallClaimsLimit: "$15,000", lastReviewed: "2026-07" },
  { code: "OH", name: "Ohio", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$6,000", lastReviewed: "2026-07" },
  { code: "OK", name: "Oklahoma", returnDeadlineDays: 45, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$10,000", lastReviewed: "2026-07" },
  { code: "OR", name: "Oregon", returnDeadlineDays: 31, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$10,000", lastReviewed: "2026-07" },
  { code: "PA", name: "Pennsylvania", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "2 months' rent (year 1), 1 month after", smallClaimsLimit: "$12,000", lastReviewed: "2026-07" },
  { code: "RI", name: "Rhode Island", returnDeadlineDays: 20, itemizedStatementRequired: true, depositLimitNote: "1 month's rent", smallClaimsLimit: "$5,000", lastReviewed: "2026-07" },
  { code: "SC", name: "South Carolina", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$7,500", lastReviewed: "2026-07" },
  { code: "SD", name: "South Dakota", returnDeadlineDays: 14, itemizedStatementRequired: true, depositLimitNote: "1 month's rent (more if pets)", smallClaimsLimit: "$12,000", lastReviewed: "2026-07" },
  { code: "TN", name: "Tennessee", returnDeadlineDays: 30, itemizedStatementRequired: false, depositLimitNote: "No statutory cap", smallClaimsLimit: "$25,000", lastReviewed: "2026-07" },
  { code: "TX", name: "Texas", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$20,000", lastReviewed: "2026-07" },
  { code: "UT", name: "Utah", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$11,000", lastReviewed: "2026-07" },
  { code: "VT", name: "Vermont", returnDeadlineDays: 14, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$5,000", lastReviewed: "2026-07" },
  { code: "VA", name: "Virginia", returnDeadlineDays: 45, itemizedStatementRequired: true, depositLimitNote: "2 months' rent", smallClaimsLimit: "$5,000", lastReviewed: "2026-07" },
  { code: "WA", name: "Washington", returnDeadlineDays: 21, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$10,000", lastReviewed: "2026-07" },
  { code: "WV", name: "West Virginia", returnDeadlineDays: 45, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$10,000", lastReviewed: "2026-07" },
  { code: "WI", name: "Wisconsin", returnDeadlineDays: 21, itemizedStatementRequired: true, depositLimitNote: "No statutory cap", smallClaimsLimit: "$10,000", lastReviewed: "2026-07" },
  { code: "WY", name: "Wyoming", returnDeadlineDays: 30, itemizedStatementRequired: true, depositLimitNote: "No statutory cap (60 days if itemized deductions)", smallClaimsLimit: "$6,000", lastReviewed: "2026-07" },
];

export function getStateLaw(code: string | null | undefined): StateDepositLaw | undefined {
  if (!code) return undefined;
  return STATE_DEPOSIT_LAWS.find((s) => s.code === code.toUpperCase());
}
