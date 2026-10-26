"use client";

export interface Coords {
  lat: number;
  lng: number;
}

// Best-effort, non-blocking geolocation lookup. Never throws — callers get
// `null` on denial, timeout, or unsupported browsers and proceed without it.
export function getCoordsOnce(timeoutMs = 4000): Promise<Coords | null> {
  return new Promise((resolve) => {
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      resolve(null);
      return;
    }
    const timer = setTimeout(() => resolve(null), timeoutMs);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        clearTimeout(timer);
        resolve({ lat: pos.coords.latitude, lng: pos.coords.longitude });
      },
      () => {
        clearTimeout(timer);
        resolve(null);
      },
      { timeout: timeoutMs, maximumAge: 60_000 }
    );
  });
}
