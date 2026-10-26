export function formatCents(cents: number | null | undefined): string {
  if (cents === null || cents === undefined) return "—";
  return (cents / 100).toLocaleString("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0,
  });
}

export function formatDate(input: string | null | undefined): string {
  if (!input) return "—";
  return new Date(input).toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export function formatDateTime(input: string | null | undefined): string {
  if (!input) return "—";
  return new Date(input).toLocaleString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

export function truncateHash(hash: string, chars = 10): string {
  if (hash.length <= chars * 2) return hash;
  return `${hash.slice(0, chars)}…${hash.slice(-chars)}`;
}

export function propertyDisplayName(p: {
  nickname: string | null;
  address_line1: string | null;
  city?: string | null;
}): string {
  return p.nickname || p.address_line1 || "Untitled property";
}
