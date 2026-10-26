"use client";

import { useState, useTransition } from "react";
import { Button } from "@/components/ui/button";
import { useToast } from "@/components/toast";

export function PaywallSheet({
  propertyId,
  stripeConfigured,
  title = "Unlock unlimited photos",
  description = "You've hit the free limit of 10 photos on this property. Unlock Shield for $17, one time, to keep documenting with unlimited photos, the full report, and the evidence packet.",
  onUnlocked,
  onClose,
  devUnlockAction,
}: {
  propertyId: string;
  stripeConfigured: boolean;
  title?: string;
  description?: string;
  onUnlocked?: () => void;
  onClose?: () => void;
  devUnlockAction: (propertyId: string) => Promise<void>;
}) {
  const { push } = useToast();
  const [isPending, startTransition] = useTransition();
  const [checkoutLoading, setCheckoutLoading] = useState(false);

  function handleDevUnlock() {
    startTransition(async () => {
      try {
        await devUnlockAction(propertyId);
        push("Shield unlocked (dev mode).", "success");
        onUnlocked?.();
      } catch (e) {
        push(e instanceof Error ? e.message : "Could not unlock.", "error");
      }
    });
  }

  async function handleCheckout() {
    setCheckoutLoading(true);
    try {
      const res = await fetch("/api/checkout", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ propertyId }),
      });
      const data = await res.json();
      if (data.url) {
        window.location.href = data.url;
      } else {
        push(data.error || "Could not start checkout.", "error");
        setCheckoutLoading(false);
      }
    } catch {
      push("Could not start checkout.", "error");
      setCheckoutLoading(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-ink/40 backdrop-blur-sm sm:items-center">
      <div className="w-full max-w-md animate-fade-up rounded-t-3xl border border-ink-100 bg-white p-7 shadow-2xl sm:rounded-3xl">
        <div className="mx-auto mb-4 h-1 w-10 rounded-full bg-ink-100 sm:hidden" />
        <span className="inline-flex items-center rounded-full border border-brass/40 bg-brass-50 px-2.5 py-1 text-[11px] font-semibold uppercase tracking-wide text-brass">
          Shield · $17 one time
        </span>
        <h3 className="mt-3 font-display text-xl text-ink">{title}</h3>
        <p className="mt-2 text-sm leading-relaxed text-ink/60">{description}</p>

        <div className="mt-6 flex flex-col gap-2">
          {stripeConfigured ? (
            <Button onClick={handleCheckout} disabled={checkoutLoading} size="lg">
              {checkoutLoading ? "Redirecting…" : "Unlock for $17"}
            </Button>
          ) : (
            <Button onClick={handleDevUnlock} disabled={isPending} size="lg">
              {isPending ? "Unlocking…" : "DEV: Unlock free (no Stripe key set)"}
            </Button>
          )}
          <button onClick={onClose} className="mt-1 text-center text-sm font-medium text-ink/45 hover:text-ink">
            Not now
          </button>
        </div>
      </div>
    </div>
  );
}
