import { getStateLaw } from "@/lib/state-deposit-laws";
import { formatDate } from "@/lib/format";

export function DeadlineCard({
  state,
  moveOutCompletedAt,
}: {
  state: string | null;
  moveOutCompletedAt: string | null;
}) {
  const law = getStateLaw(state);

  if (!law) {
    return (
      <div className="rounded-2xl border border-dashed border-ink-100 bg-white/60 p-5 text-sm text-ink/50">
        Add your state to see your deposit return deadline.
      </div>
    );
  }

  let deadlineDate: string | null = null;
  if (moveOutCompletedAt) {
    const d = new Date(moveOutCompletedAt);
    d.setDate(d.getDate() + law.returnDeadlineDays);
    deadlineDate = d.toISOString();
  }

  return (
    <div className="rounded-2xl border border-brass/30 bg-brass-50 p-5">
      <p className="font-mono text-[11px] uppercase tracking-wide text-brass">
        {law.name} deposit deadline
      </p>
      <p className="mt-1 font-display text-2xl text-ink">
        {law.returnDeadlineDays} days
      </p>
      <p className="mt-1 text-xs text-ink/60">
        {deadlineDate
          ? `Due back by ${formatDate(deadlineDate)} based on your move-out date.`
          : "Counted from your move-out date."}
      </p>
      {law.itemizedStatementRequired && (
        <p className="mt-2 text-xs text-ink/60">
          An itemized statement of deductions is generally required.
        </p>
      )}
      <p className="mt-3 text-[11px] text-ink/40">
        Not legal advice · reviewed {law.lastReviewed} · small-claims limit {law.smallClaimsLimit}
      </p>
    </div>
  );
}
