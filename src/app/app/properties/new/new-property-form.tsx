"use client";

import { useState, useTransition } from "react";
import { unstable_rethrow } from "next/navigation";
import { Button } from "@/components/ui/button";
import { STATE_DEPOSIT_LAWS } from "@/lib/state-deposit-laws";
import { DEFAULT_ROOM_NAMES } from "@/lib/types";
import { createProperty } from "./actions";
import { useToast } from "@/components/toast";

const steps = ["Address", "Deposit & lease", "Landlord", "Rooms"] as const;

export function NewPropertyForm() {
  const { push } = useToast();
  const [isPending, startTransition] = useTransition();
  const [step, setStep] = useState(0);
  const [error, setError] = useState<string | null>(null);

  const [nickname, setNickname] = useState("");
  const [addressLine1, setAddressLine1] = useState("");
  const [addressLine2, setAddressLine2] = useState("");
  const [city, setCity] = useState("");
  const [state, setState] = useState("");
  const [zip, setZip] = useState("");
  const [depositAmountDollars, setDepositAmountDollars] = useState("");
  const [leaseStart, setLeaseStart] = useState("");
  const [landlordName, setLandlordName] = useState("");
  const [landlordEmail, setLandlordEmail] = useState("");
  const [rooms, setRooms] = useState<string[]>([...DEFAULT_ROOM_NAMES]);
  const [newRoomName, setNewRoomName] = useState("");

  const selectedLaw = STATE_DEPOSIT_LAWS.find((s) => s.code === state);

  function next() {
    setError(null);
    if (step === 0 && !addressLine1.trim()) {
      setError("Add at least a street address.");
      return;
    }
    setStep((s) => Math.min(s + 1, steps.length - 1));
  }

  function back() {
    setError(null);
    setStep((s) => Math.max(s - 1, 0));
  }

  function updateRoom(i: number, value: string) {
    setRooms((r) => r.map((room, idx) => (idx === i ? value : room)));
  }

  function removeRoom(i: number) {
    setRooms((r) => r.filter((_, idx) => idx !== i));
  }

  function addRoom() {
    if (!newRoomName.trim()) return;
    setRooms((r) => [...r, newRoomName.trim()]);
    setNewRoomName("");
  }

  function handleSubmit() {
    setError(null);
    startTransition(async () => {
      try {
        await createProperty({
          nickname,
          addressLine1,
          addressLine2,
          city,
          state,
          zip,
          depositAmountDollars,
          leaseStart,
          landlordName,
          landlordEmail,
          rooms,
        });
      } catch (e) {
        unstable_rethrow(e);
        const message = e instanceof Error ? e.message : "Something went wrong.";
        setError(message);
        push(message, "error");
      }
    });
  }

  return (
    <div className="mx-auto max-w-xl">
      <div className="mb-8 flex items-center gap-2">
        {steps.map((label, i) => (
          <div key={label} className="flex flex-1 flex-col items-center gap-1.5">
            <div
              className={`h-1 w-full rounded-full transition-colors ${
                i <= step ? "bg-emerald" : "bg-ink-100"
              }`}
            />
            <span className={`text-[11px] font-medium ${i === step ? "text-ink" : "text-ink/40"}`}>
              {label}
            </span>
          </div>
        ))}
      </div>

      <div className="rounded-2xl border border-ink-100 bg-white p-6 sm:p-8">
        {step === 0 && (
          <div className="flex flex-col gap-4">
            <Field label="Nickname (optional)">
              <input value={nickname} onChange={(e) => setNickname(e.target.value)} placeholder="e.g. The Elmwood apartment" className={inputClass} />
            </Field>
            <Field label="Street address">
              <input value={addressLine1} onChange={(e) => setAddressLine1(e.target.value)} placeholder="123 Main St" className={inputClass} />
            </Field>
            <Field label="Apt / unit (optional)">
              <input value={addressLine2} onChange={(e) => setAddressLine2(e.target.value)} placeholder="Apt 4B" className={inputClass} />
            </Field>
            <div className="grid grid-cols-3 gap-3">
              <Field label="City" className="col-span-2">
                <input value={city} onChange={(e) => setCity(e.target.value)} className={inputClass} />
              </Field>
              <Field label="ZIP">
                <input value={zip} onChange={(e) => setZip(e.target.value)} className={inputClass} />
              </Field>
            </div>
            <Field label="State">
              <select value={state} onChange={(e) => setState(e.target.value)} className={inputClass}>
                <option value="">Select a state</option>
                {STATE_DEPOSIT_LAWS.map((s) => (
                  <option key={s.code} value={s.code}>{s.name}</option>
                ))}
              </select>
            </Field>
            {selectedLaw && (
              <div className="rounded-xl border border-brass/30 bg-brass-50 px-4 py-3 text-xs text-ink/70">
                In {selectedLaw.name}, landlords generally must return your deposit within{" "}
                <span className="font-semibold text-brass">{selectedLaw.returnDeadlineDays} days</span>.{" "}
                Not legal advice — verify with your state.
              </div>
            )}
          </div>
        )}

        {step === 1 && (
          <div className="flex flex-col gap-4">
            <Field label="Deposit amount (USD)">
              <input
                type="number"
                min="0"
                step="0.01"
                value={depositAmountDollars}
                onChange={(e) => setDepositAmountDollars(e.target.value)}
                placeholder="1500"
                className={inputClass}
              />
            </Field>
            <Field label="Lease start date">
              <input type="date" value={leaseStart} onChange={(e) => setLeaseStart(e.target.value)} className={inputClass} />
            </Field>
          </div>
        )}

        {step === 2 && (
          <div className="flex flex-col gap-4">
            <Field label="Landlord / property manager name">
              <input value={landlordName} onChange={(e) => setLandlordName(e.target.value)} className={inputClass} />
            </Field>
            <Field label="Landlord email">
              <input type="email" value={landlordEmail} onChange={(e) => setLandlordEmail(e.target.value)} placeholder="landlord@example.com" className={inputClass} />
            </Field>
            <p className="text-xs text-ink/45">
              Used later if you choose to send your condition report directly to your landlord.
            </p>
          </div>
        )}

        {step === 3 && (
          <div className="flex flex-col gap-3">
            <p className="text-sm text-ink/60">Edit, remove, or add rooms you&apos;ll photograph.</p>
            {rooms.map((room, i) => (
              <div key={i} className="flex items-center gap-2">
                <input value={room} onChange={(e) => updateRoom(i, e.target.value)} className={inputClass} />
                <button onClick={() => removeRoom(i)} className="rounded-lg border border-ink-100 px-2.5 py-2 text-ink/40 hover:border-clay hover:text-clay" aria-label="Remove room">
                  ✕
                </button>
              </div>
            ))}
            <div className="flex items-center gap-2 pt-1">
              <input
                value={newRoomName}
                onChange={(e) => setNewRoomName(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && (e.preventDefault(), addRoom())}
                placeholder="Add a room (e.g. Garage)"
                className={inputClass}
              />
              <Button type="button" variant="ghost" size="md" onClick={addRoom}>
                Add
              </Button>
            </div>
          </div>
        )}

        {error && <p className="mt-4 text-sm text-clay">{error}</p>}

        <div className="mt-8 flex items-center justify-between">
          <Button type="button" variant="ghost" onClick={back} disabled={step === 0}>
            Back
          </Button>
          {step < steps.length - 1 ? (
            <Button type="button" onClick={next}>
              Continue
            </Button>
          ) : (
            <Button type="button" onClick={handleSubmit} disabled={isPending}>
              {isPending ? "Creating…" : "Create property"}
            </Button>
          )}
        </div>
      </div>
    </div>
  );
}

const inputClass =
  "w-full rounded-xl border border-ink-100 bg-white px-4 py-2.5 text-sm text-ink outline-none transition-colors focus:border-emerald";

function Field({
  label,
  className = "",
  children,
}: {
  label: string;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <label className={`flex flex-col gap-1.5 ${className}`}>
      <span className="text-sm font-medium text-ink/70">{label}</span>
      {children}
    </label>
  );
}
