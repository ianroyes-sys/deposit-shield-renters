import { createServerClient } from "@supabase/ssr";
import { createClient as createSupabaseJsClient } from "@supabase/supabase-js";
import { cookies } from "next/headers";
import { env } from "@/lib/env";

// Server Component / Server Action / Route Handler client. Reads and writes
// the auth cookie via Next's async `cookies()` API (Next.js 15+).
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(env.supabaseUrl, env.supabaseAnonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options);
          }
        } catch {
          // Called from a Server Component — a proxy refreshing the session
          // handles cookie writes in that case, so this is safe to ignore.
        }
      },
    },
  });
}

// Service-role client for privileged server-only operations (account deletion,
// signed URL minting across RLS boundaries, Stripe webhook writes). Never
// import this into client code.
export function createServiceRoleClient() {
  return createSupabaseJsClient(env.supabaseUrl, env.supabaseServiceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
