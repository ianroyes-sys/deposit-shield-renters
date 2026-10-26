import type { RoomWithPhotos } from "@/lib/queries";
import type { Phase } from "@/lib/types";

export function RoomChecklist({
  rooms,
  activePhase,
  thumbnails,
}: {
  rooms: RoomWithPhotos[];
  activePhase: Phase;
  thumbnails: Record<string, string>;
}) {
  if (rooms.length === 0) {
    return (
      <div className="rounded-2xl border border-dashed border-ink-100 bg-white/60 p-6 text-center text-sm text-ink/50">
        No rooms yet.
      </div>
    );
  }

  return (
    <div className="grid gap-3 sm:grid-cols-2">
      {rooms.map((room) => {
        const photos = activePhase === "move_in" ? room.moveInPhotos : room.moveOutPhotos;
        const thumb = photos[0] ? thumbnails[photos[0].storage_path] : undefined;
        const done = photos.length > 0;
        return (
          <div
            key={room.id}
            className="flex items-center gap-3 rounded-xl border border-ink-100 bg-white p-3"
          >
            <div className="h-14 w-14 shrink-0 overflow-hidden rounded-lg bg-ink-50">
              {thumb ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={thumb} alt={room.name} className="h-full w-full object-cover" />
              ) : (
                <div className="flex h-full w-full items-center justify-center text-ink-100">
                  <svg viewBox="0 0 24 24" className="h-6 w-6 fill-none stroke-current stroke-1.5">
                    <path d="M4 16l4-4a2 2 0 0 1 3 0l5 5" />
                    <circle cx="9" cy="9" r="1.5" />
                    <rect x="3" y="4" width="18" height="16" rx="2" />
                  </svg>
                </div>
              )}
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium text-ink">{room.name}</p>
              <p className="text-xs text-ink/45">{photos.length} photo{photos.length === 1 ? "" : "s"}</p>
            </div>
            <span
              className={`h-2.5 w-2.5 shrink-0 rounded-full ${done ? "bg-emerald" : "bg-ink-100"}`}
              aria-label={done ? "documented" : "not documented"}
            />
          </div>
        );
      })}
    </div>
  );
}
