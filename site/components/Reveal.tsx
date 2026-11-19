"use client";

import { motion, useReducedMotion, type Variants } from "motion/react";
import type { ReactNode } from "react";

// better-ui staged entrance: chunks 100ms apart, each opacity + 4px blur + 12px
// rise over 300ms ease-out. Under reduced motion: opacity only.
const EASE_OUT = [0.23, 1, 0.32, 1] as const;

export function Stagger({ children, className, inView = false }: { children: ReactNode; className?: string; inView?: boolean }) {
  const variants: Variants = { hidden: {}, show: { transition: { staggerChildren: 0.1 } } };
  return (
    <motion.div
      className={className}
      variants={variants}
      initial="hidden"
      {...(inView ? { whileInView: "show", viewport: { once: true, margin: "-80px" } } : { animate: "show" })}
    >
      {children}
    </motion.div>
  );
}

export function Item({ children, className }: { children: ReactNode; className?: string }) {
  const reduce = useReducedMotion();
  const variants: Variants = reduce
    ? { hidden: { opacity: 0 }, show: { opacity: 1, transition: { duration: 0.3 } } }
    : {
        hidden: { opacity: 0, filter: "blur(4px)", transform: "translateY(12px)" },
        show: { opacity: 1, filter: "blur(0px)", transform: "translateY(0px)", transition: { duration: 0.3, ease: EASE_OUT } },
      };
  return (
    <motion.div className={className} variants={variants}>
      {children}
    </motion.div>
  );
}
