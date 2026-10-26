import Link from "next/link";
import { forwardRef } from "react";

type Variant = "primary" | "secondary" | "ghost" | "danger";
type Size = "sm" | "md" | "lg";

const variantClasses: Record<Variant, string> = {
  primary:
    "bg-emerald text-white hover:bg-emerald-dark shadow-sm shadow-emerald/20",
  secondary:
    "bg-ink text-paper hover:bg-ink-700",
  ghost:
    "bg-transparent text-ink border border-ink-100 hover:border-brass hover:bg-brass-50",
  danger: "bg-clay text-white hover:bg-clay/90",
};

const sizeClasses: Record<Size, string> = {
  sm: "text-sm px-3 py-1.5 rounded-lg",
  md: "text-sm px-5 py-2.5 rounded-xl",
  lg: "text-base px-6 py-3.5 rounded-xl",
};

const base =
  "inline-flex items-center justify-center gap-2 font-medium transition-all duration-200 ease-out disabled:opacity-50 disabled:pointer-events-none active:scale-[0.98]";

interface ButtonOwnProps {
  variant?: Variant;
  size?: Size;
  className?: string;
}

export const Button = forwardRef<
  HTMLButtonElement,
  ButtonOwnProps & React.ButtonHTMLAttributes<HTMLButtonElement>
>(({ variant = "primary", size = "md", className = "", ...props }, ref) => (
  <button
    ref={ref}
    className={`${base} ${variantClasses[variant]} ${sizeClasses[size]} ${className}`}
    {...props}
  />
));
Button.displayName = "Button";

export function LinkButton({
  variant = "primary",
  size = "md",
  className = "",
  href,
  children,
  ...props
}: ButtonOwnProps & React.ComponentProps<typeof Link>) {
  return (
    <Link
      href={href}
      className={`${base} ${variantClasses[variant]} ${sizeClasses[size]} ${className}`}
      {...props}
    >
      {children}
    </Link>
  );
}
