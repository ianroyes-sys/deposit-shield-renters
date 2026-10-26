import Foundation

// Ported from src/lib/demand-letter.ts.
enum DemandLetter {
    static func lines(property: Property, law: StateDepositLaw?, tenantEmail: String) -> [String] {
        let address = [property.address_line1, property.address_line2]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        let deadlineDays = law?.returnDeadlineDays ?? 30
        let stateName = law?.name ?? "your state"

        var deadlineDate: String? = nil
        if let moveOut = property.move_out_completed_at, let d = Formatters.parseISODate(moveOut) {
            let deadline = Calendar.current.date(byAdding: .day, value: deadlineDays, to: d) ?? d
            deadlineDate = Formatters.date(deadline)
        }

        let landlordLine: String = {
            let name = property.landlord_name?.isEmpty == false ? property.landlord_name! : "Landlord / Property Manager"
            if let email = property.landlord_email, !email.isEmpty {
                return "To: \(name) (\(email))"
            }
            return "To: \(name)"
        }()

        let addressOrFallback = address.isEmpty ? (property.nickname ?? "rental property") : address
        let addressForBody = address.isEmpty ? "the above address" : address

        return [
            Formatters.date(Date()),
            landlordLine,
            "From: \(tenantEmail)",
            "Re: Return of security deposit — \(addressOrFallback)",
            "",
            "I am writing regarding the security deposit of \(Formatters.cents(property.deposit_amount_cents)) paid for the property at \(addressForBody).",
            "I moved out of the property\(property.move_out_completed_at != nil ? " on \(Formatters.date(property.move_out_completed_at))" : ""), and have documented photographs showing the condition of the property at both move-in and move-out, attached to this letter.",
            "Under \(stateName) law, landlords generally must return the security deposit (or an itemized statement of deductions) within \(deadlineDays) days of move-out\(deadlineDate != nil ? ", which by my calculation is on or before \(deadlineDate!)" : "").",
            "I am requesting the return of my full deposit, or an itemized, documented explanation of any proposed deductions, within that timeframe. If I do not receive a response, I intend to pursue this matter in small claims court.",
            "Please contact me at \(tenantEmail) to resolve this promptly.",
            "",
            "Sincerely,",
            tenantEmail,
        ]
    }

    static func smallClaimsChecklist(law: StateDepositLaw?) -> [String] {
        [
            "Confirm the exact date you returned keys / ended tenancy — this starts the deadline clock.",
            "Send your demand letter to the landlord's last known address and email, and keep proof of delivery (certified mail or email receipt).",
            "Wait the full statutory period before filing — most courts require you to have given the landlord a chance to respond.",
            "Locate your local small claims court (usually the county where the property is located).\(law != nil ? " Claims up to about \(law!.smallClaimsLimit) are typically eligible." : "")",
            "Gather your lease, this evidence packet, the demand letter, and any receipts for cleaning or repairs the landlord disputes.",
            "File your claim (often possible online or in person) and pay the small filing fee — this is usually reimbursed if you win.",
            "Bring printed copies of your photo evidence and this report to the hearing; some courts also accept a tablet or laptop.",
            "Attend the hearing and clearly walk the judge through the move-in vs. move-out comparison in this packet.",
        ]
    }
}
