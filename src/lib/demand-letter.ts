import { formatCents, formatDate } from "@/lib/format";
import type { Property } from "@/lib/types";
import type { StateDepositLaw } from "@/lib/state-deposit-laws";

export function buildDemandLetter(property: Property, law: StateDepositLaw | undefined, tenantEmail: string): string[] {
  const address = [property.address_line1, property.address_line2].filter(Boolean).join(", ");
  const deadlineDays = law?.returnDeadlineDays ?? 30;
  const stateName = law?.name ?? "your state";
  let deadlineDate: string | null = null;
  if (property.move_out_completed_at) {
    const d = new Date(property.move_out_completed_at);
    d.setDate(d.getDate() + deadlineDays);
    deadlineDate = formatDate(d.toISOString());
  }

  return [
    `${formatDate(new Date().toISOString())}`,
    `To: ${property.landlord_name || "Landlord / Property Manager"}${property.landlord_email ? ` (${property.landlord_email})` : ""}`,
    `From: ${tenantEmail}`,
    `Re: Return of security deposit — ${address || property.nickname || "rental property"}`,
    ``,
    `I am writing regarding the security deposit of ${formatCents(property.deposit_amount_cents)} paid for the property at ${address || "the above address"}.`,
    `I moved out of the property${property.move_out_completed_at ? ` on ${formatDate(property.move_out_completed_at)}` : ""}, and have documented photographs showing the condition of the property at both move-in and move-out, attached to this letter.`,
    `Under ${stateName} law, landlords generally must return the security deposit (or an itemized statement of deductions) within ${deadlineDays} days of move-out${deadlineDate ? `, which by my calculation is on or before ${deadlineDate}` : ""}.`,
    `I am requesting the return of my full deposit, or an itemized, documented explanation of any proposed deductions, within that timeframe. If I do not receive a response, I intend to pursue this matter in small claims court.`,
    `Please contact me at ${tenantEmail} to resolve this promptly.`,
    ``,
    `Sincerely,`,
    `${tenantEmail}`,
  ];
}

export function buildSmallClaimsChecklist(law: StateDepositLaw | undefined): string[] {
  return [
    "Confirm the exact date you returned keys / ended tenancy — this starts the deadline clock.",
    `Send your demand letter to the landlord's last known address and email, and keep proof of delivery (certified mail or email receipt).`,
    "Wait the full statutory period before filing — most courts require you to have given the landlord a chance to respond.",
    `Locate your local small claims court (usually the county where the property is located). ${law ? `Claims up to about ${law.smallClaimsLimit} are typically eligible.` : ""}`,
    "Gather your lease, this evidence packet, the demand letter, and any receipts for cleaning or repairs the landlord disputes.",
    "File your claim (often possible online or in person) and pay the small filing fee — this is usually reimbursed if you win.",
    "Bring printed copies of your photo evidence and this report to the hearing; some courts also accept a tablet or laptop.",
    "Attend the hearing and clearly walk the judge through the move-in vs. move-out comparison in this packet.",
  ];
}
