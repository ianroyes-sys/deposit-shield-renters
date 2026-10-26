import { createClient } from "@/lib/supabase/server";
import { SignOutButton } from "../sign-out-button";
import { DeleteAccountButton } from "./delete-account-button";

export default async function SettingsPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <div className="mx-auto max-w-xl">
      <h1 className="font-display text-3xl text-ink">Settings</h1>
      <div className="ledger-rule my-8" />

      <div className="rounded-2xl border border-ink-100 bg-white p-6">
        <p className="text-xs text-ink/45">Signed in as</p>
        <p className="mt-1 font-mono text-sm text-ink">{user?.email}</p>
        <div className="mt-5">
          <SignOutButton className="inline-flex items-center justify-center rounded-xl border border-ink-100 px-5 py-2.5 text-sm font-medium text-ink transition-colors hover:border-brass hover:bg-brass-50" />
        </div>
      </div>

      <div className="mt-8 rounded-2xl border border-clay/20 bg-white p-6">
        <h2 className="font-display text-lg text-ink">Danger zone</h2>
        <p className="mt-1 text-sm text-ink/50">
          Deleting your account removes every property, photo, and report permanently.
        </p>
        <div className="mt-4">
          <DeleteAccountButton />
        </div>
      </div>
    </div>
  );
}
