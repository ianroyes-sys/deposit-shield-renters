import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { LinkButton } from "@/components/ui/button";

export default async function CheckoutSuccessPage({
  searchParams,
}: {
  searchParams: Promise<{ property_id?: string }>;
}) {
  const { property_id: propertyId } = await searchParams;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (user && propertyId) {
    // Belt-and-suspenders: mark paid immediately client-side of the redirect
    // in case the async Stripe webhook hasn't landed yet. The webhook remains
    // the source of truth and will no-op if this already ran.
    await supabase
      .from("properties")
      .update({ is_paid: true })
      .eq("id", propertyId)
      .eq("user_id", user.id);
  }

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-paper px-6 text-center">
      <div className="flex h-20 w-20 items-center justify-center rounded-full bg-emerald-50">
        <svg viewBox="0 0 24 24" className="h-10 w-10 fill-none stroke-emerald stroke-2">
          <path d="M12 2 4 5v6c0 5 3.5 8.5 8 10 4.5-1.5 8-5 8-10V5l-8-3Z" />
          <path d="m9 12 2 2 4-4" />
        </svg>
      </div>
      <h1 className="mt-6 font-display text-3xl text-ink">Shield unlocked</h1>
      <p className="mt-2 max-w-sm text-sm text-ink/60">
        This property now has unlimited photos, the full condition report, and the evidence packet.
      </p>
      <LinkButton
        href={propertyId ? `/app/p/${propertyId}` : "/app"}
        size="lg"
        className="mt-8"
      >
        Back to property
      </LinkButton>
      <Link href="/app" className="mt-3 text-sm text-ink/45 hover:text-ink">
        Go to dashboard
      </Link>
    </div>
  );
}
