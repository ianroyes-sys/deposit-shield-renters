"use client";

import { useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { compressImage } from "@/lib/client/image";
import { sha256Hex } from "@/lib/client/hash";
import { getCoordsOnce } from "@/lib/client/geolocation";
import { Button } from "@/components/ui/button";
import { ConditionBadge } from "@/components/ui/card";
import { PaywallSheet } from "@/components/paywall-sheet";
import { useToast } from "@/components/toast";
import { markPhaseComplete, deletePhoto, devUnlockProperty } from "../actions";
import type { Phase, PhotoCondition } from "@/lib/types";

interface PhotoData {
  id: string;
  storagePath: string;
  signedUrl: string;
  note: string | null;
  condition: PhotoCondition;
  sha256: string;
  capturedAt: string;
}

interface RoomData {
  id: string;
  name: string;
  photos: PhotoData[];
}

type UploadStatus = "compressing" | "hashing" | "uploading" | "done" | "error";

interface PendingUpload {
  tempId: string;
  roomId: string;
  status: UploadStatus;
  previewUrl: string;
  file: File;
  error?: string;
}

export function WalkthroughClient({
  propertyId,
  phase,
  isPaid,
  rooms: initialRooms,
  totalExistingPhotos,
  freePhotoLimit,
  stripeConfigured,
}: {
  propertyId: string;
  phase: Phase;
  isPaid: boolean;
  rooms: RoomData[];
  totalExistingPhotos: number;
  freePhotoLimit: number;
  stripeConfigured: boolean;
}) {
  const router = useRouter();
  const { push } = useToast();
  const [rooms, setRooms] = useState<RoomData[]>(initialRooms);
  const [roomIndex, setRoomIndex] = useState(0);
  const [pending, setPending] = useState<PendingUpload[]>([]);
  const [sessionUploaded, setSessionUploaded] = useState(0);
  const [showPaywall, setShowPaywall] = useState(false);
  const [showComplete, setShowComplete] = useState(false);
  const [finishing, setFinishing] = useState(false);
  const coordsRef = useRef<{ lat: number; lng: number } | null | undefined>(undefined);
  const touchStartX = useRef<number | null>(null);

  const cameraInputRef = useRef<HTMLInputElement>(null);
  const galleryInputRef = useRef<HTMLInputElement>(null);

  const room = rooms[roomIndex];
  const isLastRoom = roomIndex === rooms.length - 1;
  const totalUsed = totalExistingPhotos + sessionUploaded;
  const atLimit = !isPaid && totalUsed >= freePhotoLimit;

  const roomPending = pending.filter((p) => p.roomId === room.id);

  async function ensureCoords() {
    if (coordsRef.current === undefined) {
      coordsRef.current = await getCoordsOnce();
    }
    return coordsRef.current;
  }

  async function handleFiles(files: FileList | null) {
    if (!files || files.length === 0) return;
    if (atLimit) {
      setShowPaywall(true);
      return;
    }

    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      push("Your session expired — please sign in again.", "error");
      return;
    }

    const coords = await ensureCoords();
    const currentRoomId = room.id;

    for (const file of Array.from(files)) {
      if (!isPaid && totalExistingPhotos + sessionUploaded >= freePhotoLimit) {
        setShowPaywall(true);
        break;
      }

      const tempId = crypto.randomUUID();
      const previewUrl = URL.createObjectURL(file);
      setPending((prev) => [
        ...prev,
        { tempId, roomId: currentRoomId, status: "compressing", previewUrl, file },
      ]);

      await uploadOne({ tempId, roomId: currentRoomId, file, userId: user.id, coords });
    }
  }

  async function uploadOne({
    tempId,
    roomId,
    file,
    userId,
    coords,
  }: {
    tempId: string;
    roomId: string;
    file: File;
    userId: string;
    coords: { lat: number; lng: number } | null;
  }) {
    const supabase = createClient();
    try {
      const capturedAt = new Date().toISOString();
      const compressed = await compressImage(file);
      setPending((prev) => prev.map((p) => (p.tempId === tempId ? { ...p, status: "hashing" } : p)));

      const hash = await sha256Hex(compressed);
      const photoId = crypto.randomUUID();
      const storagePath = `${userId}/${propertyId}/${photoId}.jpg`;

      setPending((prev) => prev.map((p) => (p.tempId === tempId ? { ...p, status: "uploading" } : p)));

      const { error: uploadError } = await supabase.storage
        .from("photos")
        .upload(storagePath, compressed, { contentType: "image/jpeg", upsert: false });
      if (uploadError) throw uploadError;

      const { error: insertError } = await supabase.from("photos").insert({
        id: photoId,
        property_id: propertyId,
        room_id: roomId,
        user_id: userId,
        phase,
        storage_path: storagePath,
        sha256: hash,
        captured_at: capturedAt,
        lat: coords?.lat ?? null,
        lng: coords?.lng ?? null,
        condition: "good",
      });
      if (insertError) throw insertError;

      const previewUrl = URL.createObjectURL(compressed);
      setRooms((prev) =>
        prev.map((r) =>
          r.id === roomId
            ? {
                ...r,
                photos: [
                  ...r.photos,
                  {
                    id: photoId,
                    storagePath,
                    signedUrl: previewUrl,
                    note: null,
                    condition: "good",
                    sha256: hash,
                    capturedAt,
                  },
                ],
              }
            : r
        )
      );
      setSessionUploaded((n) => n + 1);
      setPending((prev) => prev.filter((p) => p.tempId !== tempId));
    } catch (e) {
      setPending((prev) =>
        prev.map((p) =>
          p.tempId === tempId
            ? { ...p, status: "error", error: e instanceof Error ? e.message : "Upload failed" }
            : p
        )
      );
    }
  }

  function retry(tempId: string) {
    const item = pending.find((p) => p.tempId === tempId);
    if (!item) return;
    setPending((prev) => prev.map((p) => (p.tempId === tempId ? { ...p, status: "compressing", error: undefined } : p)));
    (async () => {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;
      const coords = await ensureCoords();
      await uploadOne({ tempId, roomId: item.roomId, file: item.file, userId: user.id, coords });
    })();
  }

  function removePending(tempId: string) {
    setPending((prev) => prev.filter((p) => p.tempId !== tempId));
  }

  async function handleUpdatePhoto(photoId: string, updates: { note?: string; condition?: PhotoCondition }) {
    setRooms((prev) =>
      prev.map((r) => ({
        ...r,
        photos: r.photos.map((p) => (p.id === photoId ? { ...p, ...updates } : p)),
      }))
    );
    const supabase = createClient();
    await supabase.from("photos").update(updates).eq("id", photoId);
  }

  async function handleDelete(photoId: string, storagePath: string) {
    setRooms((prev) =>
      prev.map((r) => ({ ...r, photos: r.photos.filter((p) => p.id !== photoId) }))
    );
    try {
      await deletePhoto(propertyId, photoId, storagePath);
    } catch (e) {
      push(e instanceof Error ? e.message : "Could not delete photo.", "error");
    }
  }

  function goNext() {
    if (isLastRoom) {
      handleFinish();
    } else {
      setRoomIndex((i) => Math.min(i + 1, rooms.length - 1));
    }
  }

  function goPrev() {
    setRoomIndex((i) => Math.max(i - 1, 0));
  }

  async function handleFinish() {
    setFinishing(true);
    try {
      await markPhaseComplete(propertyId, phase);
      setShowComplete(true);
    } catch (e) {
      push(e instanceof Error ? e.message : "Could not complete walkthrough.", "error");
    } finally {
      setFinishing(false);
    }
  }

  const totalPhotosDocumented = useMemo(
    () => rooms.reduce((sum, r) => sum + r.photos.length, 0),
    [rooms]
  );

  if (showComplete) {
    return (
      <div className="flex min-h-[70vh] flex-col items-center justify-center px-6 text-center">
        <div className="relative flex h-24 w-24 items-center justify-center rounded-full bg-emerald-50">
          <div className="absolute inset-0 animate-ping rounded-full bg-emerald/20" />
          <svg viewBox="0 0 24 24" className="h-11 w-11 fill-none stroke-emerald stroke-2">
            <path d="M12 2 4 5v6c0 5 3.5 8.5 8 10 4.5-1.5 8-5 8-10V5l-8-3Z" />
            <path d="m9 12 2 2 4-4" />
          </svg>
        </div>
        <h1 className="mt-6 font-display text-3xl text-ink">
          {phase === "move_in" ? "Move-in" : "Move-out"} walkthrough complete
        </h1>
        <p className="mt-2 max-w-sm text-sm text-ink/60">
          {totalPhotosDocumented} photos hashed and timestamped across {rooms.length} rooms. Your record
          is locked in.
        </p>
        <div className="mt-8 flex flex-col gap-3 sm:flex-row">
          <Button size="lg" onClick={() => router.push(`/app/p/${propertyId}/report`)}>
            Generate report
          </Button>
          <Button size="lg" variant="ghost" onClick={() => router.push(`/app/p/${propertyId}`)}>
            Back to property
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div
      className="flex min-h-screen flex-col bg-paper"
      onTouchStart={(e) => (touchStartX.current = e.touches[0].clientX)}
      onTouchEnd={(e) => {
        if (touchStartX.current === null) return;
        const delta = e.changedTouches[0].clientX - touchStartX.current;
        if (Math.abs(delta) > 80) {
          if (delta < 0) goNext();
          else goPrev();
        }
        touchStartX.current = null;
      }}
    >
      <header className="sticky top-0 z-30 border-b border-ink-100 bg-paper/90 px-4 py-3 backdrop-blur-md">
        <div className="mx-auto flex max-w-2xl items-center justify-between">
          <button onClick={() => router.push(`/app/p/${propertyId}`)} className="text-sm text-ink/50 hover:text-ink">
            Exit
          </button>
          <p className="font-mono text-xs uppercase tracking-wide text-brass">
            {phase === "move_in" ? "Move-in" : "Move-out"} · Room {roomIndex + 1} of {rooms.length}
          </p>
          <span className="w-10" />
        </div>
        <div className="mx-auto mt-2 flex max-w-2xl gap-1">
          {rooms.map((r, i) => (
            <div key={r.id} className={`h-1 flex-1 rounded-full ${i <= roomIndex ? "bg-emerald" : "bg-ink-100"}`} />
          ))}
        </div>
      </header>

      <main className="mx-auto w-full max-w-2xl flex-1 px-4 py-6 pb-32">
        <h1 className="font-display text-2xl text-ink">{room.name}</h1>
        <p className="mt-1 text-sm text-ink/50">
          {room.photos.length + roomPending.length} photo{room.photos.length + roomPending.length === 1 ? "" : "s"} in this room
        </p>

        <div className="mt-5 grid grid-cols-2 gap-3 sm:grid-cols-3">
          {room.photos.map((photo) => (
            <PhotoCard key={photo.id} photo={photo} onUpdate={handleUpdatePhoto} onDelete={handleDelete} />
          ))}
          {roomPending.map((p) => (
            <div key={p.tempId} className="relative overflow-hidden rounded-xl border border-ink-100 bg-white">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={p.previewUrl} alt="" className="aspect-square w-full object-cover opacity-60" />
              <div className="absolute inset-0 flex flex-col items-center justify-center gap-2 bg-ink/30 text-center text-paper">
                {p.status === "error" ? (
                  <>
                    <span className="text-xs font-medium">Upload failed</span>
                    <div className="flex gap-2">
                      <button onClick={() => retry(p.tempId)} className="rounded-full bg-white/20 px-2.5 py-1 text-[11px] font-semibold backdrop-blur hover:bg-white/30">
                        Retry
                      </button>
                      <button onClick={() => removePending(p.tempId)} className="rounded-full bg-white/10 px-2.5 py-1 text-[11px] hover:bg-white/20">
                        Remove
                      </button>
                    </div>
                  </>
                ) : (
                  <>
                    <span className="h-5 w-5 animate-spin rounded-full border-2 border-paper/40 border-t-paper" />
                    <span className="text-[11px] font-medium capitalize">{p.status}…</span>
                  </>
                )}
              </div>
            </div>
          ))}

          <button
            onClick={() => (atLimit ? setShowPaywall(true) : cameraInputRef.current?.click())}
            className="flex aspect-square flex-col items-center justify-center gap-1.5 rounded-xl border-2 border-dashed border-ink-100 text-ink/40 transition-colors hover:border-emerald hover:text-emerald"
          >
            <svg viewBox="0 0 24 24" className="h-7 w-7 fill-none stroke-current stroke-1.5">
              <path d="M4 8a2 2 0 0 1 2-2h1l1-2h8l1 2h1a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2Z" />
              <circle cx="12" cy="13" r="3.5" />
            </svg>
            <span className="text-xs font-medium">Take photo</span>
          </button>
        </div>

        <button
          onClick={() => (atLimit ? setShowPaywall(true) : galleryInputRef.current?.click())}
          className="mt-4 text-sm font-medium text-emerald hover:text-emerald-dark"
        >
          + Add from library
        </button>

        <input
          ref={cameraInputRef}
          type="file"
          accept="image/*"
          capture="environment"
          className="hidden"
          onChange={(e) => {
            handleFiles(e.target.files);
            e.target.value = "";
          }}
        />
        <input
          ref={galleryInputRef}
          type="file"
          accept="image/*"
          multiple
          className="hidden"
          onChange={(e) => {
            handleFiles(e.target.files);
            e.target.value = "";
          }}
        />
      </main>

      <div className="fixed inset-x-0 bottom-0 z-30 border-t border-ink-100 bg-paper/95 px-4 py-3 backdrop-blur-md">
        <div className="mx-auto flex max-w-2xl items-center justify-between gap-3">
          <Button variant="ghost" size="lg" onClick={goPrev} disabled={roomIndex === 0}>
            Back
          </Button>
          <Button size="lg" className="flex-1" onClick={goNext} disabled={finishing}>
            {isLastRoom ? (finishing ? "Finishing…" : "Finish walkthrough") : "Next room"}
          </Button>
        </div>
      </div>

      {showPaywall && (
        <PaywallSheet
          propertyId={propertyId}
          stripeConfigured={stripeConfigured}
          devUnlockAction={devUnlockProperty}
          onUnlocked={() => {
            setShowPaywall(false);
            router.refresh();
          }}
          onClose={() => setShowPaywall(false)}
        />
      )}
    </div>
  );
}

function PhotoCard({
  photo,
  onUpdate,
  onDelete,
}: {
  photo: PhotoData;
  onUpdate: (id: string, updates: { note?: string; condition?: PhotoCondition }) => void;
  onDelete: (id: string, storagePath: string) => void;
}) {
  const [note, setNote] = useState(photo.note ?? "");

  return (
    <div className="group relative overflow-hidden rounded-xl border border-ink-100 bg-white">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={photo.signedUrl} alt="" className="aspect-square w-full object-cover" />
      <button
        onClick={() => onDelete(photo.id, photo.storagePath)}
        className="absolute right-1.5 top-1.5 flex h-6 w-6 items-center justify-center rounded-full bg-ink/60 text-xs text-paper opacity-0 backdrop-blur transition-opacity group-hover:opacity-100"
        aria-label="Delete photo"
      >
        ✕
      </button>
      <div className="space-y-1.5 p-2">
        <select
          value={photo.condition}
          onChange={(e) => onUpdate(photo.id, { condition: e.target.value as PhotoCondition })}
          className="w-full rounded-md border border-ink-100 bg-white px-1.5 py-1 text-[11px] capitalize"
        >
          <option value="good">Good</option>
          <option value="fair">Fair</option>
          <option value="damaged">Damaged</option>
        </select>
        <input
          value={note}
          onChange={(e) => setNote(e.target.value)}
          onBlur={() => onUpdate(photo.id, { note })}
          placeholder="Note (optional)"
          className="w-full rounded-md border border-ink-100 px-1.5 py-1 text-[11px] outline-none focus:border-emerald"
        />
        <ConditionBadge condition={photo.condition} />
      </div>
    </div>
  );
}
