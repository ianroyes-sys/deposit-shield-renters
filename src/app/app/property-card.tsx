import Link from "next/link";
import type { PropertyWithStats } from "@/lib/queries";
import { getPropertyStatus } from "@/lib/queries";
import { formatCents, propertyDisplayName } from "@/lib/format";
import { Card } from "@/components/ui/card";

const toneStyles = {
  neutral: "bg-ink-100 text-ink/60",
  progress: "bg-brass-50 text-brass",
  success: "bg-emerald-50 text-emerald-dark",
  brass: "bg-brass-50 text-brass",
} as const;

export function PropertyCard({ property }: { property: PropertyWithStats }) {
  const status = getPropertyStatus(property);
  const totalPhotos = property.moveInPhotoCount + property.moveOutPhotoCount;

  return (
    <Link href={`/app/p/${property.id}`}>
      <Card className="group flex h-full flex-col gap-4 p-6 transition-all duration-200 hover:-translate-y-1 hover:shadow-md">
        <div className="flex items-start justify-between gap-3">
          <div>
            <h3 className="font-display text-lg text-ink">{propertyDisplayName(property)}</h3>
            <p className="mt-0.5 text-xs text-ink/50">
              {property.city && property.state ? `${property.city}, ${property.state}` : "Address pending"}
            </p>
          </div>
          {property.is_paid && (
            <span className="shrink-0 rounded-full border border-brass/40 bg-brass-50 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-brass">
              Shield
            </span>
          )}
        </div>

        <span className={`inline-flex w-fit items-center rounded-full px-2.5 py-1 text-xs font-medium ${toneStyles[status.tone]}`}>
          {status.label}
        </span>

        <div className="mt-auto flex items-center justify-between border-t border-ink-100 pt-4 text-sm">
          <div>
            <p className="text-ink/40 text-xs">Deposit</p>
            <p className="font-medium text-ink">{formatCents(property.deposit_amount_cents)}</p>
          </div>
          <div className="text-right">
            <p className="text-ink/40 text-xs">Photos</p>
            <p className="font-medium text-ink">{totalPhotos}</p>
          </div>
        </div>
      </Card>
    </Link>
  );
}
