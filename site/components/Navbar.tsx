"use client";

import Link from "next/link";
import { motion } from "motion/react";
import { useEffect, useState } from "react";
import { CritterMark } from "./CritterMark";
import { GitHubIcon } from "./Icons";
import { PrimaryButton } from "./Buttons";
import { DOWNLOAD_PAGE, REPO } from "@/lib/links";

/** jmo's floating navbar: transparent at the top, a frosted bar once you scroll. */
export function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  useEffect(() => {
    let ticking = false;
    const onScroll = () => {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(() => {
        setScrolled(window.scrollY > 20);
        ticking = false;
      });
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header className="fixed inset-x-0 top-0 z-50 flex justify-center px-4 pt-3">
      <div className="relative flex h-12 w-full max-w-5xl items-center justify-between px-4">
        <motion.div
          className="absolute inset-0 rounded-2xl border border-transparent bg-white/75 shadow-[0_0_0_1px_rgba(0,0,0,0.06),0_8px_24px_-12px_rgba(0,0,0,0.15)] backdrop-blur-xl"
          initial={false}
          animate={{ opacity: scrolled ? 1 : 0 }}
          transition={{ duration: 0.2, ease: "easeOut" }}
        />
        <Link href="/" className="relative flex items-center gap-2 font-semibold tracking-tight">
          <CritterMark size={22} pose={{ lit: true }} />
          Peek
        </Link>
        <nav className="relative flex items-center gap-1.5">
          <Link
            href={REPO}
            target="_blank"
            rel="noopener noreferrer"
            aria-label="Peek on GitHub"
            className="grid size-8 place-items-center rounded-lg text-neutral-600 transition-[color,background-color] duration-150 ease-out hover:bg-black/[0.04] hover:text-neutral-900"
          >
            <GitHubIcon className="size-[18px]" />
          </Link>
          <PrimaryButton href={DOWNLOAD_PAGE} size="sm">Download</PrimaryButton>
        </nav>
      </div>
    </header>
  );
}
