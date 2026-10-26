// Central place to read environment variables with safe placeholder fallbacks
// so `npm run build` and local dev work with zero configuration. Feature areas
// check the `is*Configured` flags and render a "connect X" state instead of
// calling out to a real service when a flag is false.

const PLACEHOLDER_SUPABASE_URL = "https://placeholder.supabase.co";
const PLACEHOLDER_SUPABASE_ANON_KEY = "placeholder-anon-key";

export const env = {
  supabaseUrl: process.env.NEXT_PUBLIC_SUPABASE_URL || PLACEHOLDER_SUPABASE_URL,
  supabaseAnonKey:
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || PLACEHOLDER_SUPABASE_ANON_KEY,
  supabaseServiceRoleKey: process.env.SUPABASE_SECRET_KEY || "",
  stripeSecretKey: process.env.STRIPE_SECRET_KEY || "",
  stripeWebhookSecret: process.env.STRIPE_WEBHOOK_SECRET || "",
  appUrl: process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3000",
  resendApiKey: process.env.RESEND_API_KEY || "",
};

export const isSupabaseConfigured =
  !!process.env.NEXT_PUBLIC_SUPABASE_URL &&
  !!process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY &&
  process.env.NEXT_PUBLIC_SUPABASE_URL !== PLACEHOLDER_SUPABASE_URL;

// Dev-only escape hatch: when NEXT_PUBLIC_DEV_AUTH_BYPASS=true and we are NOT in
// production, the `/app` area renders without a real Supabase session so you can
// walk the UI locally before email login is wired up. Never true in prod.
export const isDevAuthBypass =
  process.env.NODE_ENV !== "production" &&
  process.env.NEXT_PUBLIC_DEV_AUTH_BYPASS === "true";

export const isServiceRoleConfigured = !!env.supabaseServiceRoleKey;
export const isStripeConfigured = !!env.stripeSecretKey;
export const isStripeWebhookConfigured = !!env.stripeWebhookSecret;
export const isResendConfigured = !!env.resendApiKey;

export const PROPERTY_PRICE_USD = 17;
export const FREE_ROOM_LIMIT = 1;
export const FREE_PHOTO_LIMIT = 10;
