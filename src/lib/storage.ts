import type { SupabaseClient } from "@supabase/supabase-js";

const SIGNED_URL_TTL_SECONDS = 60 * 60; // 1 hour

export async function getSignedUrl(
  supabase: SupabaseClient,
  bucket: "photos" | "reports",
  path: string
): Promise<string | null> {
  const { data, error } = await supabase.storage
    .from(bucket)
    .createSignedUrl(path, SIGNED_URL_TTL_SECONDS);
  if (error || !data) return null;
  return data.signedUrl;
}

export async function getSignedUrls(
  supabase: SupabaseClient,
  bucket: "photos" | "reports",
  paths: string[]
): Promise<Record<string, string>> {
  if (paths.length === 0) return {};
  const { data, error } = await supabase.storage
    .from(bucket)
    .createSignedUrls(paths, SIGNED_URL_TTL_SECONDS);
  if (error || !data) return {};
  const map: Record<string, string> = {};
  for (const item of data) {
    if (item.signedUrl && item.path) map[item.path] = item.signedUrl;
  }
  return map;
}

export function photoStoragePath(userId: string, propertyId: string, photoId: string): string {
  return `${userId}/${propertyId}/${photoId}.jpg`;
}

export function reportStoragePath(userId: string, propertyId: string, kind: string): string {
  return `${userId}/${propertyId}/${kind}-${Date.now()}.pdf`;
}
