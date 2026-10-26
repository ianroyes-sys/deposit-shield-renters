"use client";

// SHA-256 fingerprint of a file/blob computed client-side via the Web Crypto
// API, before the bytes ever leave the device. This is what makes each photo
// tamper-evident: any modification after capture changes the hash.
export async function sha256Hex(blob: Blob): Promise<string> {
  const buffer = await blob.arrayBuffer();
  const digest = await crypto.subtle.digest("SHA-256", buffer);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
