"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { PaywallSheet } from "@/components/paywall-sheet";
import { useToast } from "@/components/toast";
import { devUnlockProperty } from "../actions";
import type { Phase } from "@/lib/types";

export function ReportClient({
  propertyId,
  isPaid,
  moveInDone,
  moveOutDone,
  hasLandlordEmail,
  stripeConfigured,
  resendConfigured,
}: {
  propertyId: string;
  isPaid: boolean;
  moveInDone: boolean;
  moveOutDone: boolean;
  hasLandlordEmail: boolean;
  stripeConfigured: boolean;
  resendConfigured: boolean;
}) {
  const { push } = useToast();
  const [kind, setKind] = useState<Phase>(moveOutDone ? "move_out" : "move_in");
  const [generating, setGenerating] = useState(false);
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState<{ reportId: string; url: string; watermarked: boolean } | null>(null);
  const [showPaywall, setShowPaywall] = useState(false);

  const canGenerate = kind === "move_in" ? true : moveOutDone;

  async function handleGenerate() {
    setGenerating(true);
    setResult(null);
    try {
      const res = await fetch("/api/reports", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ propertyId, kind }),
      });
      const data = await res.json();
      if (!res.ok) {
        push(data.error || "Could not generate report.", "error");
        return;
      }
      setResult(data);
    } catch {
      push("Could not generate report.", "error");
    } finally {
      setGenerating(false);
    }
  }

  async function handleSend() {
    if (!result) return;
    setSending(true);
    try {
      const res = await fetch("/api/reports/send", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ reportId: result.reportId }),
      });
      const data = await res.json();
      if (data.sent) {
        push("Report sent to your landlord.", "success");
      } else if (data.mailto) {
        window.open(data.mailto, "_blank");
        push("Email client opened — attach the downloaded PDF before sending.", "info");
      } else {
        push(data.error || "Could not send report.", "error");
      }
    } catch {
      push("Could not send report.", "error");
    } finally {
      setSending(false);
    }
  }

  return (
    <div>
      <div className="mb-6 flex gap-2">
        <button
          onClick={() => setKind("move_in")}
          className={`rounded-full px-4 py-1.5 text-sm font-medium transition-colors ${
            kind === "move_in" ? "bg-ink text-paper" : "bg-ink-100 text-ink/60 hover:bg-ink-100/70"
          }`}
        >
          Move-in
        </button>
        <button
          onClick={() => setKind("move_out")}
          disabled={!moveOutDone}
          className={`rounded-full px-4 py-1.5 text-sm font-medium transition-colors disabled:opacity-40 ${
            kind === "move_out" ? "bg-ink text-paper" : "bg-ink-100 text-ink/60 hover:bg-ink-100/70"
          }`}
        >
          Move-out
        </button>
      </div>

      <div className="rounded-2xl border border-ink-100 bg-white p-6">
        {!isPaid && (
          <div className="mb-5 rounded-xl border border-brass/30 bg-brass-50 px-4 py-3 text-sm text-ink/70">
            You&apos;ll get a <span className="font-semibold">watermarked preview</span>. Unlock Shield for
            the clean, downloadable version and landlord delivery.
          </div>
        )}

        <Button onClick={handleGenerate} disabled={generating || !canGenerate} size="lg" className="w-full">
          {generating ? "Generating…" : `Generate ${kind === "move_in" ? "move-in" : "move-out"} report`}
        </Button>

        {result && (
          <div className="mt-6 flex flex-col gap-3 rounded-xl border border-ink-100 bg-ink-50/50 p-4">
            <p className="text-sm text-ink/70">
              {result.watermarked ? "Watermarked preview ready." : "Report ready."}
            </p>
            <div className="flex flex-wrap gap-3">
              <a href={result.url} target="_blank" rel="noreferrer">
                <Button variant="secondary" size="md">View / download PDF</Button>
              </a>
              <Button
                variant="ghost"
                size="md"
                disabled={!isPaid || sending}
                onClick={() => (isPaid ? handleSend() : setShowPaywall(true))}
              >
                {sending ? "Sending…" : "Send to landlord"}
              </Button>
            </div>
            {isPaid && !hasLandlordEmail && (
              <p className="text-xs text-clay">Add a landlord email on this property to enable sending.</p>
            )}
            {isPaid && !resendConfigured && (
              <p className="text-xs text-ink/45">
                Email isn&apos;t connected — sending will open a prefilled email draft with the PDF link
                instead.
              </p>
            )}
          </div>
        )}
      </div>

      {showPaywall && (
        <PaywallSheet
          propertyId={propertyId}
          stripeConfigured={stripeConfigured}
          devUnlockAction={devUnlockProperty}
          onUnlocked={() => setShowPaywall(false)}
          onClose={() => setShowPaywall(false)}
        />
      )}
    </div>
  );
}
