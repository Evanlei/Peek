import Link from "next/link";
import type { ReactNode } from "react";

// Press feedback: 0.96 over 150ms ease-out (better-ui). Hover styles are behind
// Tailwind 4's `hover:` variant, which only applies on hover-capable pointers.
const base =
  "inline-flex items-center justify-center gap-2 rounded-xl font-semibold whitespace-nowrap select-none " +
  "transition-[scale,background-color,box-shadow,color] duration-150 ease-out active:scale-[0.96] " +
  "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-neutral-400";

export function PrimaryButton({ href, children, size = "md" }: { href: string; children: ReactNode; size?: "sm" | "md" }) {
  return (
    <Link
      href={href}
      className={`${base} ${size === "sm" ? "h-8 px-3 text-[13px] rounded-lg" : "h-11 px-5 text-[15px]"} bg-neutral-900 text-white border border-transparent shadow-[0_1px_2px_rgba(0,0,0,0.12),0_4px_12px_-2px_rgba(0,0,0,0.18)] hover:bg-neutral-800`}
    >
      {children}
    </Link>
  );
}

/** jmo's soft gray gradient button, with a shadow ring instead of a border. */
export function SecondaryButton({ href, children }: { href: string; children: ReactNode }) {
  return (
    <Link
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className={`${base} h-11 px-5 text-[15px] text-neutral-700 bg-gradient-to-b from-white to-neutral-100 border border-transparent shadow-[0_0_0_1px_rgba(0,0,0,0.07),0_1px_2px_rgba(0,0,0,0.06)] hover:text-neutral-900 hover:shadow-[0_0_0_1px_rgba(0,0,0,0.1),0_2px_6px_rgba(0,0,0,0.08)]`}
    >
      {children}
    </Link>
  );
}
