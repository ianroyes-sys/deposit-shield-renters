import { NewPropertyForm } from "./new-property-form";

export default function NewPropertyPage() {
  return (
    <div>
      <div className="mb-8 text-center">
        <h1 className="font-display text-3xl text-ink">Add a property</h1>
        <p className="mt-1 text-sm text-ink/50">
          A few details now saves an argument over your deposit later.
        </p>
      </div>
      <NewPropertyForm />
    </div>
  );
}
