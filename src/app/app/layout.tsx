import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { isDevAuthBypass } from "@/lib/env";
import { SignOutButton } from "./sign-out-button";

export default async function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user && !isDevAuthBypass) {
    redirect("/login?next=/app");
  }

  return (
    <div className="flex min-h-screen flex-1 flex-col">
      <header className="sticky top-0 z-40 border-b border-ink-100 bg-paper/90 backdrop-blur-md">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-3.5">
          <Link href="/app" className="flex items-center gap-2 font-display text-lg font-semibold text-ink">
            <span className="flex h-7 w-7 items-center justify-center rounded-full bg-ink">
              <svg viewBox="0 0 24 24" className="h-4 w-4 fill-none stroke-brass stroke-2">
                <path d="M12 2 4 5v6c0 5 3.5 8.5 8 10 4.5-1.5 8-5 8-10V5l-8-3Z" />
              </svg>
            </span>
            Deposit Shield
          </Link>
          <nav className="flex items-center gap-5 text-sm font-medium text-ink/60">
            <Link href="/app" className="hover:text-ink">Dashboard</Link>
            <Link href="/app/settings" className="hover:text-ink">Settings</Link>
            <SignOutButton />
          </nav>
        </div>
      </header>
      <main className="mx-auto w-full max-w-6xl flex-1 px-6 py-10">{children}</main>
    </div>
  );
}
