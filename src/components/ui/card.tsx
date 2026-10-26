export function Card({
  className = "",
  children,
}: {
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <div
      className={`rounded-2xl border border-ink-100 bg-white/80 shadow-sm shadow-ink/5 backdrop-blur-sm ${className}`}
    >
      {children}
    </div>
  );
}

export function SealBadge({ label = "Hash verified" }: { label?: string }) {
  return (
    <span className="inline-flex items-center gap-1.5 rounded-full border border-brass/40 bg-brass-50 px-2.5 py-1 text-[11px] font-mono uppercase tracking-wide text-brass">
      <svg viewBox="0 0 24 24" className="h-3 w-3 fill-none stroke-brass stroke-2">
        <path d="M12 2 4 5v6c0 5 3.5 8.5 8 10 4.5-1.5 8-5 8-10V5l-8-3Z" />
        <path d="m9 12 2 2 4-4" />
      </svg>
      {label}
    </span>
  );
}

export function ConditionBadge({
  condition,
}: {
  condition: "good" | "fair" | "damaged";
}) {
  const styles = {
    good: "bg-emerald-50 text-emerald-dark border-emerald/30",
    fair: "bg-brass-50 text-brass border-brass/30",
    damaged: "bg-clay-50 text-clay border-clay/30",
  } as const;
  return (
    <span
      className={`inline-flex items-center rounded-full border px-2 py-0.5 text-[11px] font-medium capitalize ${styles[condition]}`}
    >
      {condition}
    </span>
  );
}
