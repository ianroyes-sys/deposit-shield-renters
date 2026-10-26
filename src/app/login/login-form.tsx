"use client";

import { useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { Button } from "@/components/ui/button";
import { isSupabaseConfigured } from "@/lib/env";

type Stage = "email" | "sent" | "verifying";

export function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const next = searchParams.get("next") || "/app";
  const linkExpired = searchParams.get("error") === "link-expired";

  const [stage, setStage] = useState<Stage>("email");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(
    linkExpired ? "That link expired. Request a new one below." : null
  );
  const [loading, setLoading] = useState(false);

  if (!isSupabaseConfigured) {
    return (
      <div className="rounded-2xl border border-brass/40 bg-brass-50 p-6 text-sm text-ink/80">
        <p className="font-semibold text-brass">Connect Supabase to enable sign-in</p>
        <p className="mt-2 leading-relaxed">
          Set <code className="font-mono text-xs">NEXT_PUBLIC_SUPABASE_URL</code> and{" "}
          <code className="font-mono text-xs">NEXT_PUBLIC_SUPABASE_ANON_KEY</code> in your environment,
          then restart the app. See <code className="font-mono text-xs">.env.example</code>.
        </p>
      </div>
    );
  }

  async function handleSendCode(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    const supabase = createClient();
    const { error: otpError } = await supabase.auth.signInWithOtp({
      email,
      options: {
        emailRedirectTo: `${window.location.origin}/auth/confirm?next=${encodeURIComponent(next)}`,
      },
    });
    setLoading(false);
    if (otpError) {
      setError(otpError.message);
      return;
    }
    setStage("sent");
  }

  async function handleVerifyCode(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    const supabase = createClient();
    const { error: verifyError } = await supabase.auth.verifyOtp({
      email,
      token: code,
      type: "email",
    });
    setLoading(false);
    if (verifyError) {
      setError(verifyError.message);
      return;
    }
    router.push(next);
    router.refresh();
  }

  return (
    <div className="w-full max-w-sm">
      {stage === "email" && (
        <form onSubmit={handleSendCode} className="flex flex-col gap-4">
          <div>
            <label htmlFor="email" className="text-sm font-medium text-ink/70">
              Email address
            </label>
            <input
              id="email"
              type="email"
              required
              autoFocus
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@example.com"
              className="mt-1.5 w-full rounded-xl border border-ink-100 bg-white px-4 py-3 text-sm text-ink outline-none transition-colors focus:border-emerald"
            />
          </div>
          {error && <p className="text-sm text-clay">{error}</p>}
          <Button type="submit" disabled={loading} className="w-full" size="lg">
            {loading ? "Sending…" : "Continue with email"}
          </Button>
          <p className="text-center text-xs text-ink/45">
            No password needed. We&apos;ll email you a secure sign-in link and a backup code.
          </p>
        </form>
      )}

      {stage === "sent" && (
        <form onSubmit={handleVerifyCode} className="flex flex-col gap-4">
          <div className="rounded-xl border border-emerald/30 bg-emerald-50 px-4 py-3 text-sm text-emerald-dark">
            Check <span className="font-semibold">{email}</span> for a sign-in link, or enter the
            6-digit code below.
          </div>
          <div>
            <label htmlFor="code" className="text-sm font-medium text-ink/70">
              6-digit code
            </label>
            <input
              id="code"
              inputMode="numeric"
              autoFocus
              value={code}
              onChange={(e) => setCode(e.target.value)}
              placeholder="123456"
              className="mt-1.5 w-full rounded-xl border border-ink-100 bg-white px-4 py-3 text-center font-mono text-lg tracking-[0.3em] text-ink outline-none transition-colors focus:border-emerald"
            />
          </div>
          {error && <p className="text-sm text-clay">{error}</p>}
          <Button type="submit" disabled={loading || code.length < 6} className="w-full" size="lg">
            {loading ? "Verifying…" : "Verify & continue"}
          </Button>
          <button
            type="button"
            onClick={() => setStage("email")}
            className="text-center text-xs font-medium text-ink/50 hover:text-ink"
          >
            Use a different email
          </button>
        </form>
      )}
    </div>
  );
}
