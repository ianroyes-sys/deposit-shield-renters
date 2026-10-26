"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { useToast } from "@/components/toast";

export function DeleteAccountButton() {
  const router = useRouter();
  const { push } = useToast();
  const [confirming, setConfirming] = useState(false);
  const [loading, setLoading] = useState(false);

  async function handleDelete() {
    setLoading(true);
    try {
      const res = await fetch("/api/account/delete", { method: "POST" });
      const data = await res.json();
      if (!res.ok) {
        push(data.error || "Could not delete account.", "error");
        setLoading(false);
        return;
      }
      router.push("/");
      router.refresh();
    } catch {
      push("Could not delete account.", "error");
      setLoading(false);
    }
  }

  if (!confirming) {
    return (
      <Button variant="danger" size="md" onClick={() => setConfirming(true)}>
        Delete account
      </Button>
    );
  }

  return (
    <div className="rounded-xl border border-clay/30 bg-clay-50 p-4">
      <p className="text-sm text-ink/80">
        This permanently deletes every property, photo, and report. This cannot be undone.
      </p>
      <div className="mt-3 flex gap-2">
        <Button variant="danger" size="sm" onClick={handleDelete} disabled={loading}>
          {loading ? "Deleting…" : "Yes, delete everything"}
        </Button>
        <Button variant="ghost" size="sm" onClick={() => setConfirming(false)} disabled={loading}>
          Cancel
        </Button>
      </div>
    </div>
  );
}
