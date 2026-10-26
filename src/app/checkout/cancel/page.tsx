import { LinkButton } from "@/components/ui/button";

export default async function CheckoutCancelPage({
  searchParams,
}: {
  searchParams: Promise<{ property_id?: string }>;
}) {
  const { property_id: propertyId } = await searchParams;

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-paper px-6 text-center">
      <div className="flex h-20 w-20 items-center justify-center rounded-full bg-ink-100">
        <svg viewBox="0 0 24 24" className="h-10 w-10 fill-none stroke-ink/40 stroke-2">
          <path d="M6 6l12 12M18 6 6 18" />
        </svg>
      </div>
      <h1 className="mt-6 font-display text-3xl text-ink">Checkout canceled</h1>
      <p className="mt-2 max-w-sm text-sm text-ink/60">
        No charge was made. You can pick up where you left off any time.
      </p>
      <LinkButton href={propertyId ? `/app/p/${propertyId}` : "/app"} size="lg" className="mt-8">
        Back to property
      </LinkButton>
    </div>
  );
}
