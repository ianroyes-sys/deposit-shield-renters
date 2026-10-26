import { Suspense } from "react";
import Link from "next/link";
import { LoginForm } from "./login-form";

export default function LoginPage() {
  return (
    <div className="flex min-h-screen flex-1">
      <div className="relative hidden w-1/2 flex-col justify-between bg-ink p-12 text-paper lg:flex">
        <div className="pointer-events-none absolute inset-0 opacity-[0.06]" style={{
          backgroundImage: "radial-gradient(circle at 30% 30%, white 1px, transparent 1px)",
          backgroundSize: "26px 26px",
        }} />
        <Link href="/" className="relative flex items-center gap-2 font-display text-lg font-semibold">
          <span className="flex h-7 w-7 items-center justify-center rounded-full bg-paper/10">
            <svg viewBox="0 0 24 24" className="h-4 w-4 fill-none stroke-brass stroke-2">
              <path d="M12 2 4 5v6c0 5 3.5 8.5 8 10 4.5-1.5 8-5 8-10V5l-8-3Z" />
            </svg>
          </span>
          Deposit Shield
        </Link>
        <div className="relative max-w-md">
          <p className="ledger-rule mb-6 w-16" />
          <p className="font-display text-2xl leading-snug">
            &ldquo;The photo you take on day one is the only proof that matters on day
            three hundred.&rdquo;
          </p>
          <p className="mt-4 text-sm text-paper/50">Every property, timestamped and hashed the moment you walk in.</p>
        </div>
        <p className="relative text-xs text-paper/40">Not legal advice. Documentation, not litigation.</p>
      </div>

      <div className="flex flex-1 flex-col items-center justify-center px-6 py-16">
        <div className="mb-10 flex flex-col items-center gap-2 text-center lg:hidden">
          <Link href="/" className="font-display text-xl font-semibold text-ink">Deposit Shield</Link>
        </div>
        <div className="mb-8 text-center">
          <h1 className="font-display text-2xl font-medium text-ink">Sign in or create an account</h1>
          <p className="mt-1 text-sm text-ink/50">One email, no password.</p>
        </div>
        <Suspense fallback={<div className="h-64 w-full max-w-sm animate-pulse rounded-2xl bg-ink-100/50" />}>
          <LoginForm />
        </Suspense>
      </div>
    </div>
  );
}
