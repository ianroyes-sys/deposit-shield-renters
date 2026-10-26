"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { PaywallSheet } from "@/components/paywall-sheet";
import { useToast } from "@/components/toast";
import { devUnlockProperty } from "../actions";

export function EvidenceClient({
  propertyId,
  isPaid,
  stripeConfigured,
}: {
  propertyId: string;
  isPaid: boolean;
  stripeConfigured: boolean;
}) {
  const router = useRouter();
  const { push } = useToast();
  const [generating, setGenerating] = useState(false);
  const [url, setUrl] = useState<string | null>(null);
  const [showPaywall, setShowPaywall] = useState(!isPaid);

  async function handleGenerate() {
    setGenerating(true);
    try {
      const res = await fetch("/api/reports", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ propertyId, kind: "evidence_packet" }),
      });
      const data = await res.json();
      if (!res.ok) {
        push(data.error || "Could not generate evidence packet.", "error");
        return;
      }
      setUrl(data.url);
    } catch {
      push("Could not generate evidence packet.", "error");
    } finally {
      setGenerating(false);
    }
  }

  return (
    <div>
      <div className="rounded-2xl border border-ink-100 bg-white p-6">
        <Button onClick={handleGenerate} disabled={!isPaid || generating} size="lg" className="w-full">
          {generating ? "Building packet…" : "Generate evidence packet"}
        </Button>
        {url && (
          <div className="mt-5 rounded-xl border border-ink-100 bg-ink-50/50 p-4">
            <p className="mb-3 text-sm text-ink/70">Your evidence packet is ready.</p>
            <a href={url} target="_blank" rel="noreferrer">
              <Button variant="secondary" size="md">View / download PDF</Button>
            </a>
          </div>
        )}
      </div>

      {showPaywall && (
        <PaywallSheet
          propertyId={propertyId}
          stripeConfigured={stripeConfigured}
          title="Evidence packets require Shield"
          description="Unlock this property for $17 one time to generate the combined move-in/move-out evidence packet with your demand letter and small-claims checklist."
          devUnlockAction={devUnlockProperty}
          onUnlocked={() => {
            setShowPaywall(false);
            router.refresh();
          }}
          onClose={() => setShowPaywall(false)}
        />
      )}
    </div>
  );
}
