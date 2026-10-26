import Link from "next/link";
import { Reveal } from "@/components/reveal";
import { FaqAccordion } from "@/components/faq-accordion";
import { SealBadge } from "@/components/ui/card";
import { LinkButton } from "@/components/ui/button";

const steps = [
  {
    title: "Walk the room",
    body: "Guided, room-by-room capture on move-in day — camera or gallery, no app-store install required.",
  },
  {
    title: "We hash & timestamp",
    body: "Every photo gets a SHA-256 fingerprint and a capture timestamp the moment you shoot it, before it ever leaves your phone.",
  },
  {
    title: "Deliver the proof",
    body: "Generate a court-ready condition report, send it to your landlord, and keep the evidence packet for later.",
  },
];

const features = [
  {
    title: "Hash-verified photos",
    body: "Each photo is fingerprinted with SHA-256 on your device the instant it's captured — tamper-evident, not just timestamped.",
  },
  {
    title: "Court-ready PDF reports",
    body: "A professional condition report with per-room photo grids, notes, and a plain-English integrity appendix.",
  },
  {
    title: "50-state deadlines",
    body: "Know exactly how many days your landlord has to return your deposit, wherever you live.",
  },
  {
    title: "Move-out comparison",
    body: "Side-by-side move-in vs. move-out photos per room, with condition deltas highlighted automatically.",
  },
];

const faqs = [
  {
    question: "Is this legal advice?",
    answer:
      "No. Deposit Shield helps you document and organize evidence. It does not replace an attorney, and deadlines/limits shown are general guidance — always confirm with your state or a tenant rights organization.",
  },
  {
    question: "What is California AB 2801?",
    answer:
      "A California law, in force since 2025, requiring landlords to photograph rental units at move-out before deducting from a deposit — and at move-in for tenancies starting July 1, 2025 or later. Deposit Shield gives renters the same documentation power — and gives small landlords a simple way to comply.",
  },
  {
    question: "Do I need to install an app?",
    answer:
      "No. Deposit Shield runs in your phone's browser and can be added to your home screen like an app (PWA) — no App Store required.",
  },
  {
    question: "What happens to my photos?",
    answer:
      "Photos are stored privately per-property and are never public. Only you can generate signed links to view or download them.",
  },
  {
    question: "What's included for free?",
    answer:
      "One room, up to 10 photos, and a watermarked preview report — enough to see the product before you commit a property to it.",
  },
];

export default function LandingPage() {
  return (
    <div className="flex flex-1 flex-col">
      <header className="sticky top-0 z-40 border-b border-ink-100/60 bg-paper/80 backdrop-blur-md">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
          <Link href="/" className="flex items-center gap-2 font-display text-lg font-semibold tracking-tight text-ink">
            <span className="flex h-7 w-7 items-center justify-center rounded-full bg-ink text-paper">
              <svg viewBox="0 0 24 24" className="h-4 w-4 fill-none stroke-brass stroke-2">
                <path d="M12 2 4 5v6c0 5 3.5 8.5 8 10 4.5-1.5 8-5 8-10V5l-8-3Z" />
              </svg>
            </span>
            Deposit Shield
          </Link>
          <nav className="hidden items-center gap-8 text-sm font-medium text-ink/70 sm:flex">
            <a href="#how-it-works" className="hover:text-ink">How it works</a>
            <a href="#pricing" className="hover:text-ink">Pricing</a>
            <a href="#faq" className="hover:text-ink">FAQ</a>
          </nav>
          <div className="flex items-center gap-3">
            <Link href="/login" className="text-sm font-medium text-ink/70 hover:text-ink">
              Log in
            </Link>
            <LinkButton href="/login" size="sm">
              Protect my deposit
            </LinkButton>
          </div>
        </div>
      </header>

      <main className="flex-1">
        {/* Hero */}
        <section className="relative overflow-hidden bg-ink text-paper">
          <div className="pointer-events-none absolute inset-0 opacity-[0.07]" style={{
            backgroundImage:
              "radial-gradient(circle at 20% 20%, white 1px, transparent 1px)",
            backgroundSize: "28px 28px",
          }} />
          <div className="mx-auto max-w-6xl px-6 py-24 sm:py-32">
            <div className="flex flex-col items-start gap-6 animate-fade-up">
              <SealBadge label="AB 2801 · California · in force" />
              <h1 className="max-w-2xl font-display text-4xl font-medium leading-[1.08] tracking-tight sm:text-6xl">
                Your deposit. Documented. Protected.
              </h1>
              <p className="max-w-xl text-lg leading-relaxed text-paper/70">
                Timestamped, hash-verified photo evidence of your move-in and move-out condition —
                turned into a court-ready report in minutes, not a fight in small claims court.
              </p>
              <div className="flex flex-wrap items-center gap-4 pt-2">
                <LinkButton href="/login" size="lg">
                  Start documenting — free
                </LinkButton>
                <a href="#how-it-works" className="text-sm font-medium text-paper/70 underline underline-offset-4 hover:text-paper">
                  See how it works
                </a>
              </div>
            </div>
          </div>
        </section>

        {/* AB 2801 urgency banner */}
        <div className="border-b border-brass/30 bg-brass-50">
          <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-center gap-2 px-6 py-3 text-center text-sm text-ink/80">
            <span className="font-semibold text-brass">New for 2026:</span>
            California AB 2801 requires landlords to photograph rental units before and after tenancy — renters everywhere deserve the same proof.
          </div>
        </div>

        {/* How it works */}
        <section id="how-it-works" className="mx-auto max-w-6xl px-6 py-24">
          <Reveal>
            <p className="font-mono text-xs uppercase tracking-widest text-brass">How it works</p>
            <h2 className="mt-2 font-display text-3xl font-medium tracking-tight text-ink sm:text-4xl">
              Three steps between you and an airtight record.
            </h2>
          </Reveal>
          <div className="ledger-rule my-10" />
          <div className="grid gap-8 sm:grid-cols-3">
            {steps.map((step, i) => (
              <Reveal key={step.title} delay={i * 120}>
                <div className="flex flex-col gap-3">
                  <span className="font-display text-3xl text-brass">0{i + 1}</span>
                  <h3 className="font-display text-xl text-ink">{step.title}</h3>
                  <p className="text-sm leading-relaxed text-ink/60">{step.body}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </section>

        {/* Feature grid */}
        <section className="bg-ink-50/60 py-24">
          <div className="mx-auto max-w-6xl px-6">
            <Reveal>
              <p className="font-mono text-xs uppercase tracking-widest text-brass">What you get</p>
              <h2 className="mt-2 font-display text-3xl font-medium tracking-tight text-ink sm:text-4xl">
                Built like evidence, not a photo album.
              </h2>
            </Reveal>
            <div className="mt-12 grid gap-6 sm:grid-cols-2">
              {features.map((f, i) => (
                <Reveal key={f.title} delay={i * 100}>
                  <div className="h-full rounded-2xl border border-ink-100 bg-white p-6 transition-transform duration-200 hover:-translate-y-1">
                    <h3 className="font-display text-lg text-ink">{f.title}</h3>
                    <p className="mt-2 text-sm leading-relaxed text-ink/60">{f.body}</p>
                  </div>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        {/* Pricing */}
        <section id="pricing" className="mx-auto max-w-6xl px-6 py-24">
          <Reveal>
            <p className="font-mono text-xs uppercase tracking-widest text-brass">Pricing</p>
            <h2 className="mt-2 font-display text-3xl font-medium tracking-tight text-ink sm:text-4xl">
              One-time. Per property. No subscriptions.
            </h2>
          </Reveal>
          <div className="mt-12 grid gap-6 sm:grid-cols-2">
            <Reveal>
              <div className="flex h-full flex-col rounded-2xl border border-ink-100 bg-white p-8">
                <h3 className="font-display text-2xl text-ink">Free</h3>
                <p className="mt-1 text-sm text-ink/50">Try it on one room</p>
                <p className="mt-6 font-display text-4xl text-ink">$0</p>
                <ul className="mt-6 flex-1 space-y-3 text-sm text-ink/70">
                  <li>1 room</li>
                  <li>Up to 10 photos</li>
                  <li>Watermarked preview report</li>
                </ul>
                <LinkButton href="/login" variant="ghost" className="mt-8">
                  Start free
                </LinkButton>
              </div>
            </Reveal>
            <Reveal delay={100}>
              <div className="relative flex h-full flex-col rounded-2xl border-2 border-emerald bg-ink p-8 text-paper shadow-xl shadow-emerald/10">
                <span className="absolute -top-3 right-8 rounded-full bg-emerald px-3 py-1 text-xs font-semibold text-white">
                  Most protection
                </span>
                <h3 className="font-display text-2xl">Shield</h3>
                <p className="mt-1 text-sm text-paper/60">Per property, one-time</p>
                <p className="mt-6 font-display text-4xl">$17</p>
                <ul className="mt-6 flex-1 space-y-3 text-sm text-paper/80">
                  <li>Unlimited rooms &amp; photos</li>
                  <li>Full condition report, no watermark</li>
                  <li>Send report directly to your landlord</li>
                  <li>Move-out comparison</li>
                  <li>Small-claims evidence packet</li>
                </ul>
                <LinkButton href="/login" className="mt-8">
                  Protect this property
                </LinkButton>
              </div>
            </Reveal>
          </div>
        </section>

        {/* FAQ */}
        <section id="faq" className="mx-auto max-w-3xl px-6 py-24">
          <Reveal>
            <p className="text-center font-mono text-xs uppercase tracking-widest text-brass">FAQ</p>
            <h2 className="mt-2 text-center font-display text-3xl font-medium tracking-tight text-ink">
              Questions, answered plainly.
            </h2>
          </Reveal>
          <div className="mt-10">
            <FaqAccordion items={faqs} />
          </div>
        </section>
      </main>

      <footer className="border-t border-ink-100 bg-ink-50/50 py-12">
        <div className="mx-auto max-w-6xl px-6">
          <div className="flex flex-col items-start justify-between gap-6 sm:flex-row sm:items-center">
            <span className="font-display text-lg text-ink">Deposit Shield</span>
            <div className="flex gap-6 text-sm text-ink/60">
              <a href="#how-it-works" className="hover:text-ink">How it works</a>
              <a href="#pricing" className="hover:text-ink">Pricing</a>
              <Link href="/login" className="hover:text-ink">Log in</Link>
            </div>
          </div>
          <p className="mt-8 max-w-2xl text-xs leading-relaxed text-ink/50">
            Deposit Shield is a documentation and organization tool. It is not a law firm and does not
            provide legal advice. State deadlines, deposit limits, and small-claims figures are general
            guidance only — confirm current rules with your state housing authority or an attorney before
            relying on them.
          </p>
        </div>
      </footer>
    </div>
  );
}
