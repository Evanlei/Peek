"use client";

import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { SceneCanvas } from "./SceneCanvas";
import type { DemoAgent } from "@/lib/scene";

// ---- Geometry (matches the app: notch 185pt + 96pt wings) -----------------

const W = 540; // widest state; the shape is clipped down from this
const H = 178;
const SIZES = {
  collapsed: { w: 377, h: 32, r: 10 },
  alert: { w: 460, h: 90, r: 24 },
  expanded: { w: 540, h: 178, r: 24 },
} as const;
type Mode = keyof typeof SIZES;

// Springs from the app: noticeable in, no bounce out.
const OPEN = { type: "spring", duration: 0.38, bounce: 0.2 } as const;
const CLOSE = { type: "spring", duration: 0.28, bounce: 0 } as const;
const EASE_OUT = [0.23, 1, 0.32, 1] as const;

// ---- Demo data ------------------------------------------------------------

interface Request {
  id: number;
  agentId: string;
  tool: string;
  verb: string;
  detail: string;
}

const REQUESTS = [
  { tool: "Bash", verb: "wants to run", detail: "npm run migrate -- --force" },
  { tool: "Edit", verb: "wants to edit", detail: "src/config/production.ts" },
  { tool: "WebFetch", verb: "wants to fetch", detail: "registry.npmjs.org/left-pad" },
  { tool: "Bash", verb: "wants to run", detail: "rm -rf build/" },
];

const ACTIONS = [
  "Edit: NotchView.swift", "Bash: swift test", "Read: Router.swift", "Grep: func handle",
  "Edit: cache.ts", "Bash: git diff --stat", "Read: Hero.tsx", "Thinking…",
];

const INITIAL: DemoAgent[] = [
  { id: "a", name: "peek · main", status: "working", action: "Edit: NotchView.swift", context: 0.71, cost: 0.61, helpers: ["h1", "h2"] },
  { id: "b", name: "api-gateway", status: "working", action: "Bash: npm test", context: 0.44, cost: 0.37, helpers: [] },
  { id: "c", name: "landing-site", status: "working", action: "Read: Hero.tsx", context: 0.17, cost: 0.19, helpers: ["h3"] },
  { id: "d", name: "ml-pipeline", status: "stuck", action: "pytest failing: 3 errors (retry 4/4)", context: 0.88, cost: 0.25, helpers: [] },
];

const pick = <T,>(xs: readonly T[]) => xs[Math.floor(Math.random() * xs.length)];

function useDemo() {
  const [agents, setAgents] = useState(INITIAL);
  const agentsRef = useRef(agents);
  agentsRef.current = agents;
  const [request, setRequest] = useState<Request | null>(null);
  const nextReq = useRef(3.5); // seconds until the next request
  const reqId = useRef(0);
  const tick = useRef(0);

  useEffect(() => {
    const t = setInterval(() => {
      tick.current += 1;
      setAgents((prev) =>
        prev.map((a) => {
          if (a.status !== "working") return a;
          const tokens = 200 + Math.random() * 2200;
          let context = a.context + tokens / 400_000;
          if (context > 0.97) context = 0.3;
          return {
            ...a,
            cost: a.cost + (tokens * 9) / 1_000_000,
            context,
            action: Math.random() < 0.25 ? pick(ACTIONS) : a.action,
          };
        }),
      );
      // ml-pipeline gets unstuck and stuck again, so every state shows up.
      if (tick.current % 22 === 0) {
        setAgents((prev) => prev.map((a) => (a.id === "d" ? { ...a, status: a.status === "stuck" ? "working" : "stuck", action: a.status === "stuck" ? "Bash: pytest -x" : "pytest failing: 3 errors (retry 4/4)" } : a)));
      }
    }, 1200);
    return () => clearInterval(t);
  }, []);

  // Request scheduler: one at a time, a few seconds apart.
  useEffect(() => {
    if (request) return;
    const t = setTimeout(() => {
      // Read the latest agents from a ref: side effects inside a state updater
      // would run twice under StrictMode.
      const candidates = agentsRef.current.filter((a) => a.status === "working");
      if (!candidates.length) return;
      const target = pick(candidates);
      reqId.current += 1;
      setRequest({ id: reqId.current, agentId: target.id, ...pick(REQUESTS) });
      setAgents((prev) =>
        prev.map((a) => (a.id === target.id ? { ...a, status: "needs", action: "Waiting for permission", helpers: [] } : a)),
      );
      nextReq.current = 8;
    }, nextReq.current * 1000);
    return () => clearTimeout(t);
  }, [request]);

  const decide = useCallback(
    (allow: boolean) => {
      if (!request) return;
      setAgents((prev) =>
        prev.map((a) =>
          a.id === request.agentId
            ? { ...a, status: "working", action: allow ? `${request.tool}: ${request.detail}` : "Denied — trying another approach", helpers: INITIAL.find((i) => i.id === a.id)!.helpers }
            : a,
        ),
      );
      setRequest(null);
    },
    [request],
  );

  return { agents, request, decide };
}

// ---- Component ------------------------------------------------------------

export function NotchDemo() {
  const reduce = useReducedMotion() ?? false;
  const { agents, request, decide } = useDemo();
  const [hovered, setHovered] = useState(false);
  const [touched, setTouched] = useState(false);
  const leaveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // While a request waits, the card stays put: no hover-expand moving Allow away.
  const alerting = request !== null && !hovered;
  const mode: Mode = hovered ? "expanded" : alerting ? "alert" : "collapsed";
  const s = SIZES[mode];
  const inset = (W - s.w) / 2;
  const transition = mode === "collapsed" ? CLOSE : OPEN;
  const t = reduce ? { duration: 0 } : transition;

  const enter = () => {
    if (leaveTimer.current) clearTimeout(leaveTimer.current);
    setTouched(true);
    if (!alerting || hovered) setHovered(true);
  };
  const leave = () => {
    leaveTimer.current = setTimeout(() => setHovered(false), 180);
  };

  const total = agents.reduce((n, a) => n + a.cost, 0);
  const working = agents.find((a) => a.status === "working");
  const helpers = agents.reduce((n, a) => n + a.helpers.length, 0);
  const requester = request ? agents.find((a) => a.id === request.agentId) : undefined;

  return (
    <div className="relative mx-auto" style={{ width: W, height: H }}>
      {/* Ears: the concave flare where the notch meets the bezel */}
      <motion.div
        className="absolute top-0 left-0 size-2"
        style={{ background: "radial-gradient(circle at 0 100%, transparent 8px, #000 8.5px)" }}
        initial={false}
        animate={{ transform: `translateX(${inset - 8}px)` }}
        transition={t}
      />
      <motion.div
        className="absolute top-0 right-0 size-2"
        style={{ background: "radial-gradient(circle at 100% 100%, transparent 8px, #000 8.5px)" }}
        initial={false}
        animate={{ transform: `translateX(${-(inset - 8)}px)` }}
        transition={t}
      />

      <motion.div
        role="group"
        aria-label="Peek notch demo. Hover or tap to open."
        className="absolute inset-0 bg-black text-white"
        initial={false}
        animate={{ clipPath: `inset(0px ${inset}px ${H - s.h}px ${inset}px round 0px 0px ${s.r}px ${s.r}px)` }}
        transition={t}
        onPointerEnter={(e) => e.pointerType === "mouse" && enter()}
        onPointerLeave={(e) => e.pointerType === "mouse" && leave()}
        onClick={(e) => {
          if ((e.target as HTMLElement).closest("button")) return;
          setTouched(true);
          if (!alerting || hovered) setHovered((h) => !h);
        }}
      >
        {/* Camera — this is the notch, after all */}
        <div className="absolute top-[11px] left-1/2 size-[9px] -translate-x-1/2 rounded-full bg-[#0b0b0d] shadow-[inset_0_0_0_1px_rgba(255,255,255,0.06)]">
          <div className="absolute top-[2px] left-[2px] size-[3px] rounded-full bg-[#1d2333]" />
        </div>

        {/* Header: left wing + right wing */}
        <motion.div
          className="absolute top-0 left-0 flex h-8 items-center"
          initial={false}
          animate={{ transform: `translateX(${inset + (mode === "expanded" ? 16 : 8)}px)` }}
          transition={t}
        >
          <AnimatePresence initial={false} mode="popLayout">
            {mode === "expanded" ? (
              <motion.span
                key="summary"
                className="text-[11.5px] font-semibold text-white/70"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0, transition: { duration: 0.12 } }}
              >
                {agents.length} agents{helpers > 0 && ` · ${helpers} ${helpers === 1 ? "helper" : "helpers"}`}
              </motion.span>
            ) : (
              <motion.div key="strip" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0, transition: { duration: 0.12 } }}>
                <SceneCanvas
                  agents={agents}
                  width={agents.length * 20 + 8}
                  height={32}
                  pixel={1.5}
                  mode="strip"
                  fps={request ? 12 : 4}
                  reduceMotion={reduce}
                />
              </motion.div>
            )}
          </AnimatePresence>
        </motion.div>
        <motion.div
          className="absolute top-0 right-0 flex h-8 items-center text-[13px] font-semibold tabular-nums"
          initial={false}
          animate={{ transform: `translateX(${-(inset + (mode === "expanded" ? 16 : 10))}px)` }}
          transition={t}
        >
          {/* Changes every second: instant, no rolling digits. */}${total.toFixed(2)}
        </motion.div>

        {/* Expanded: the diorama + footer */}
        <AnimatePresence>
          {mode === "expanded" && (
            <motion.div
              key="expanded"
              className="absolute top-8 left-[10px] w-[520px]"
              initial={reduce ? { opacity: 0 } : { opacity: 0, filter: "blur(4px)", transform: "translateY(-6px) scale(0.98)" }}
              animate={{ opacity: 1, filter: "blur(0px)", transform: "translateY(0px) scale(1)", transition: { duration: 0.3, ease: EASE_OUT, delay: 0.05 } }}
              exit={{ opacity: 0, transition: { duration: 0.12, ease: "easeOut" } }}
            >
              <SceneCanvas agents={agents} width={520} height={88} pixel={3.5} mode="diorama" fps={30} reduceMotion={reduce} />
              <div className="mt-1.5 h-[42px]">
                <AnimatePresence mode="popLayout" initial={false}>
                  {request && requester ? (
                    <Card key={request.id} name={requester.name} request={request} onDecide={decide} reduce={reduce} />
                  ) : (
                    <motion.div
                      key="ticker"
                      className="flex h-[42px] items-center gap-2 rounded-[14px] bg-white/[0.04] px-3.5 text-[11.5px] font-medium text-white/70"
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      exit={{ opacity: 0, transition: { duration: 0.12 } }}
                    >
                      <span className="size-1.5 shrink-0 rounded-full bg-[#33D66B]" />
                      <span className="truncate">
                        {working ? `${working.name}  ·  ${working.action}` : "All clear — nothing needs you"}
                      </span>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Alert: auto-peek with just the approval card */}
        <AnimatePresence>
          {mode === "alert" && request && requester && (
            <motion.div key="alert" className="absolute top-[38px] left-[50px] w-[440px]">
              <Card name={requester.name} request={request} onDecide={decide} reduce={reduce} />
            </motion.div>
          )}
        </AnimatePresence>
      </motion.div>

      {/* First-visit hint */}
      <AnimatePresence>
        {!touched && (
          <motion.div
            className="pointer-events-none absolute left-1/2 top-[52px] -translate-x-1/2 rounded-full bg-white/70 px-3 py-1 text-xs font-medium text-neutral-700 shadow-[0_1px_2px_rgba(0,0,0,0.06),0_4px_12px_rgba(0,0,0,0.08)] backdrop-blur"
            initial={{ opacity: 0 }}
            animate={{ opacity: mode === "collapsed" ? 1 : 0, transition: { delay: 0.6, duration: 0.3 } }}
            exit={{ opacity: 0, transition: { duration: 0.15 } }}
          >
            ↑ Hover the notch
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

/** Approval card: one sentence, the command, two buttons. Radii: 14 = 7 + 7 inset. */
function Card({
  name,
  request,
  onDecide,
  reduce,
}: {
  name: string;
  request: Request;
  onDecide: (allow: boolean) => void;
  reduce: boolean;
}) {
  return (
    <motion.div
      className="flex h-[42px] items-center gap-2.5 rounded-[14px] bg-white/[0.05] py-[7px] pr-[7px] pl-3.5"
      initial={reduce ? { opacity: 0 } : { opacity: 0, filter: "blur(4px)", transform: "translateY(12px)" }}
      animate={{ opacity: 1, filter: "blur(0px)", transform: "translateY(0px)", transition: { duration: 0.3, ease: EASE_OUT } }}
      exit={reduce ? { opacity: 0 } : { opacity: 0, filter: "blur(4px)", transform: "translateY(-12px)", transition: { duration: 0.15, ease: "easeOut" } }}
    >
      <div className="min-w-0 flex-1 leading-tight">
        <div className="truncate text-[11px]">
          <span className="font-semibold text-white/90">{name}</span>
          <span className="text-white/45"> {request.verb}</span>
        </div>
        <div className="truncate font-mono text-[12px] text-white">{request.detail}</div>
      </div>
      <button
        type="button"
        onClick={() => onDecide(false)}
        className="h-7 rounded-[7px] px-3 text-[12px] font-semibold text-white/60 transition-[scale,color] duration-150 ease-out hover:text-white/80 active:scale-[0.96]"
      >
        Deny
      </button>
      <button
        type="button"
        onClick={() => onDecide(true)}
        className="h-7 rounded-[7px] bg-white px-3 text-[12px] font-semibold text-black transition-[scale,opacity] duration-150 ease-out active:scale-[0.96] active:opacity-85"
      >
        Allow
      </button>
    </motion.div>
  );
}

/** Scales the fixed-size demo stage down to fit narrow screens. */
export function useFitScale(designWidth: number) {
  const ref = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(1);
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const ro = new ResizeObserver(([e]) => setScale(Math.min(1, e.contentRect.width / designWidth)));
    ro.observe(el);
    return () => ro.disconnect();
  }, [designWidth]);
  return { ref, scale };
}
