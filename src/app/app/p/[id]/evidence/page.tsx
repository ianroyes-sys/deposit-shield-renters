import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getPropertyDetail } from "@/lib/queries";
import { getStateLaw } from "@/lib/state-deposit-laws";
import { isStripeConfigured } from "@/lib/env";
import { propertyDisplayName } from "@/lib/format";
import { buildDemandLetter, buildSmallClaimsChecklist } from "@/lib/demand-letter";
import { EvidenceClient } from "./evidence-client";

export default async function EvidencePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();
  const detail = await getPropertyDetail(supabase, id);
  if (!detail) notFound();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { property } = detail;
  const law = getStateLaw(property.state);
  const letterLines = buildDemandLetter(property, law, user?.email || "tenant@example.com");
  const checklistItems = buildSmallClaimsChecklist(law);

  return (
    <div className="mx-auto max-w-2xl">
      <Link href={`/app/p/${id}`} className="text-xs font-medium text-ink/40 hover:text-ink">
        ← {propertyDisplayName(property)}
      </Link>
      <h1 className="mt-2 font-display text-3xl text-ink">Evidence packet</h1>
      <p className="mt-1 text-sm text-ink/50">
        Move-in and move-out photos, your state&apos;s deadline, a draft demand letter, and a small-claims
        checklist — bundled into one PDF.
      </p>

      <div className="ledger-rule my-8" />

      <EvidenceClient propertyId={id} isPaid={property.is_paid} stripeConfigured={isStripeConfigured} />

      <div className="mt-10">
        <h2 className="mb-3 font-display text-lg text-ink">Demand letter preview</h2>
        <div className="rounded-2xl border border-ink-100 bg-white p-6 font-mono text-xs leading-relaxed text-ink/70">
          {letterLines.map((line, i) => (
            <p key={i} className={line === "" ? "h-3" : "mb-2"}>{line}</p>
          ))}
        </div>
      </div>

      <div className="mt-10">
        <h2 className="mb-3 font-display text-lg text-ink">Small-claims checklist</h2>
        <ul className="space-y-2 rounded-2xl border border-ink-100 bg-white p-6">
          {checklistItems.map((item, i) => (
            <li key={i} className="flex gap-3 text-sm text-ink/70">
              <span className="text-brass">☐</span>
              {item}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
