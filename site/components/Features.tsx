"use client";

import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useLayoutEffect, useRef, useState, type ReactNode } from "react";
import { CritterMark } from "./CritterMark";
import { Item, Stagger } from "./Reveal";
import { SceneCanvas } from "./SceneCanvas";
import type { DemoAgent } from "@/lib/scene";

// Wallspace-style feature section: show the product in dark media tiles
// instead of icon + title + paragraph cards.

const ROOM: DemoAgent[] = [
  { id: "a", name: "peek · main", status: "working", action: "", context: 0.62, cost: 0.61, helpers: ["h1", "h2"] },
  { id: "b", name: "api-gateway", status: "needs", action: "", context: 0.41, cost: 0.37, helpers: [] },
  { id: "c", name: "ml-pipeline", status: "stuck", action: "", context: 0.86, cost: 0.25, helpers: [] },
  { id: "d", name: "landing-site", status: "idle", action: "", context: 0.18, cost: 0.19, helpers: [] },
];

export function Features() {
  return (
    <section className="px-4 py-20">
      <Stagger inView className="mx-auto max-w-5xl">
        <Item className="text-center">
          <p className="text-xs font-semibold tracking-[0.14em] text-peek uppercase">How it works</p>
          <h2 className="mt-3 text-4xl font-bold tracking-tighter text-balance">Everything at a glance.</h2>
          <p className="mx-auto mt-3 max-w-md text-pretty text-muted-foreground">
            Peek reads what Claude Code already writes on your Mac, and stays out of the way until you need it.
          </p>
        </Item>
        <div className="mt-12 grid gap-4 sm:grid-cols-2">
          <Item className="sm:col-span-2">
            <Tile
              title="Every session gets a desk."
              body="Project, branch, context window and cost come straight from Claude Code's local logs. Subagents tag along as sidekicks."
            >
              <Room />
            </Tile>
          </Item>
          <Item>
            <Tile title="Approve without switching windows." body="A permission request opens the notch on its own. Try it.">
              <Approval />
            </Tile>
          </Item>
          <Item>
            <Tile title="Light enough to forget." body="Native SpriteKit with cached sprites. It only animates fully while you're looking.">
              <div className="flex items-end justify-between gap-4 px-8 pb-8">
                <p className="text-[88px] leading-[0.85] font-bold tracking-tighter text-white tabular-nums">
                  2<span className="text-white/40">%</span>
                </p>
                <div className="pb-1 text-right">
                  <CritterMark size={44} pose={{ eyes: "sleep", bodyAlpha: 0.9 }} className="ml-auto" />
                  <p className="mt-3 text-[13px] font-medium text-white/45">CPU while collapsed</p>
                </div>
              </div>
            </Tile>
          </Item>
        </div>
      </Stagger>
    </section>
  );
}

function Tile({ title, body, children }: { title: string; body: string; children: ReactNode }) {
  return (
    <div className="flex h-full min-h-[300px] flex-col overflow-hidden rounded-[28px] bg-[#111113] shadow-[0_24px_48px_-24px_rgba(0,0,0,0.35)]">
      <div className="p-8 pb-6">
        <h3 className="text-xl font-semibold tracking-tight text-white">{title}</h3>
        <p className="mt-2 max-w-md text-[15px] leading-relaxed text-pretty text-white/50">{body}</p>
      </div>
      <div className="mt-auto">{children}</div>
    </div>
  );
}

/** The expanded diorama, one of every state, filling the tile's width. */
function Room() {
  const reduce = useReducedMotion() ?? false;
  const ref = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(0);
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const ro = new ResizeObserver(([e]) => setWidth(Math.round(e.contentRect.width)));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  const pixel = width < 520 ? 3 : 5;
  return (
    <div ref={ref} className="mx-8 mb-6" style={{ height: pixel * 28 }}>
      {width > 0 && (
        <SceneCanvas agents={ROOM} width={width} height={pixel * 28} pixel={pixel} mode="diorama" fps={30} reduceMotion={reduce} />
      )}
    </div>
  );
}

/** A working copy of the approval card. */
function Approval() {
  const [answer, setAnswer] = useState<"allow" | "deny" | null>(null);
  const reduce = useReducedMotion();
  const fade = reduce
    ? { initial: { opacity: 0 }, animate: { opacity: 1 }, exit: { opacity: 0 } }
    : {
        initial: { opacity: 0, filter: "blur(4px)", transform: "translateY(8px)" },
        animate: { opacity: 1, filter: "blur(0px)", transform: "translateY(0px)" },
        exit: { opacity: 0, filter: "blur(4px)", transform: "translateY(-8px)" },
      };
  return (
    <div className="px-6 pb-6">
      {/* Notch-shaped panel: 24 = 14 card + 10 inset */}
      <div className="relative rounded-[24px] bg-black p-2.5 pt-10">
        <div className="absolute top-[13px] left-1/2 size-[9px] -translate-x-1/2 rounded-full bg-[#0b0b0d] shadow-[inset_0_0_0_1px_rgba(255,255,255,0.08)]" />
        <div className="grid h-[42px]">
          <AnimatePresence mode="popLayout" initial={false}>
            {answer === null ? (
              <motion.div
                key="card"
                {...fade}
                transition={{ duration: 0.2, ease: [0.23, 1, 0.32, 1] }}
                className="flex items-center gap-2.5 rounded-[14px] bg-white/[0.06] py-[7px] pr-[7px] pl-3.5"
              >
                <div className="min-w-0 flex-1 leading-tight">
                  <div className="truncate text-[11px]">
                    <span className="font-semibold text-white/90">api-gateway</span>
                    <span className="text-white/45"> wants to run</span>
                  </div>
                  <div className="truncate font-mono text-[12px] text-white">npm run migrate</div>
                </div>
                <button
                  type="button"
                  onClick={() => setAnswer("deny")}
                  className="h-7 rounded-[7px] px-3 text-[12px] font-semibold text-white/60 transition-[scale,color] duration-150 ease-out hover:text-white/80 active:scale-[0.96]"
                >
                  Deny
                </button>
                <button
                  type="button"
                  onClick={() => setAnswer("allow")}
                  className="h-7 rounded-[7px] bg-white px-3 text-[12px] font-semibold text-black transition-[scale] duration-150 ease-out active:scale-[0.96]"
                >
                  Allow
                </button>
              </motion.div>
            ) : (
              <motion.button
                key="done"
                type="button"
                {...fade}
                transition={{ duration: 0.2, ease: [0.23, 1, 0.32, 1] }}
                onClick={() => setAnswer(null)}
                className="flex items-center gap-2 rounded-[14px] bg-white/[0.04] px-3.5 text-left text-[12px] font-medium text-white/70"
              >
                <span className={`size-1.5 shrink-0 rounded-full ${answer === "allow" ? "bg-[#33D66B]" : "bg-[#FF4D47]"}`} />
                <span className="flex-1 truncate">
                  {answer === "allow" ? "Allowed. api-gateway carries on." : "Denied. api-gateway tries another way."}
                </span>
                <span className="text-white/40">Again</span>
              </motion.button>
            )}
          </AnimatePresence>
        </div>
      </div>
    </div>
  );
}
