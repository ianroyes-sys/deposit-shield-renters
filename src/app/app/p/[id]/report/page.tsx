import { notFound } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getPropertyDetail } from "@/lib/queries";
import { isStripeConfigured, isResendConfigured } from "@/lib/env";
import { propertyDisplayName } from "@/lib/format";
import { ReportClient } from "./report-client";

export default async function ReportPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();
  const detail = await getPropertyDetail(supabase, id);
  if (!detail) notFound();

  const { property } = detail;

  return (
    <div className="mx-auto max-w-2xl">
      <Link href={`/app/p/${id}`} className="text-xs font-medium text-ink/40 hover:text-ink">
        ← {propertyDisplayName(property)}
      </Link>
      <h1 className="mt-2 font-display text-3xl text-ink">Condition report</h1>
      <p className="mt-1 text-sm text-ink/50">
        A professional PDF of your photo documentation, ready for your records or your landlord.
      </p>

      <div className="ledger-rule my-8" />

      <ReportClient
        propertyId={id}
        isPaid={property.is_paid}
        moveInDone={!!property.move_in_completed_at}
        moveOutDone={!!property.move_out_completed_at}
        hasLandlordEmail={!!property.landlord_email}
        stripeConfigured={isStripeConfigured}
        resendConfigured={isResendConfigured}
      />
    </div>
  );
}
