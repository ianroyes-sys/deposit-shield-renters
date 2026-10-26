import { createClient } from "@/lib/supabase/server";
import { getPropertiesWithStats } from "@/lib/queries";
import { PropertyCard } from "./property-card";
import { EmptyState } from "@/components/ui/skeleton";
import { LinkButton } from "@/components/ui/button";

export default async function DashboardPage() {
  const supabase = await createClient();
  const properties = await getPropertiesWithStats(supabase);

  return (
    <div>
      <div className="flex flex-col gap-1 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="font-display text-3xl text-ink">Your properties</h1>
          <p className="mt-1 text-sm text-ink/50">
            {properties.length === 0
              ? "Nothing documented yet."
              : `${properties.length} propert${properties.length === 1 ? "y" : "ies"} tracked.`}
          </p>
        </div>
        {properties.length > 0 && (
          <LinkButton href="/app/properties/new" size="md">
            + Add a property
          </LinkButton>
        )}
      </div>

      <div className="ledger-rule my-8" />

      {properties.length === 0 ? (
        <EmptyState
          icon={
            <svg viewBox="0 0 24 24" className="h-10 w-10 fill-none stroke-current stroke-1.5">
              <path d="M12 2 4 5v6c0 5 3.5 8.5 8 10 4.5-1.5 8-5 8-10V5l-8-3Z" />
              <path d="m9 12 2 2 4-4" />
            </svg>
          }
          title="Add your place — do this before you unpack"
          description="Document the condition of your rental before a single box comes inside. It takes about ten minutes and could save your deposit."
          action={
            <LinkButton href="/app/properties/new" size="lg">
              Add your property
            </LinkButton>
          }
        />
      ) : (
        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {properties.map((p) => (
            <PropertyCard key={p.id} property={p} />
          ))}
        </div>
      )}
    </div>
  );
}
