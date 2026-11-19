// The Peek character: a 12×11 pixel creature, ported 1:1 from Peek/Critter.swift.
// Each distinct pose is rasterized once into a small canvas and reused every frame.

export type Eyes = "open" | "blink" | "focus" | "wide" | "cross" | "tired" | "sleep";
export type Arms = "rest" | "typeA" | "typeB" | "waveUp" | "waveDown";

export interface Pose {
  step: 0 | 1 | null;
  eyes: Eyes;
  arms: Arms;
  slump: boolean;
  sweat: boolean;
  lit: boolean;
  flipped: boolean;
  body: string; // hex
  bodyAlpha?: number;
}

export const COLS = 12;
export const ROWS = 11;

export const COLORS = {
  orange: "#D97857",
  stuck: "#DB544C",
  sidekick: "#ED9E73",
  ink: "#291A14",
  blush: "#F79E8C",
  spark: "#FFDB73",
  sweat: "#8CCCFF",
  amber: "#FFB529",
  red: "#FF4D47",
  green: "#33D66B",
} as const;

export const basePose = (over: Partial<Pose> = {}): Pose => ({
  step: null,
  eyes: "open",
  arms: "rest",
  slump: false,
  sweat: false,
  lit: false,
  flipped: false,
  body: COLORS.orange,
  ...over,
});

const rgba = (hex: string, a = 1) => {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
};

/** Pixel list [col, row, cssColor] for a pose — same rules as the Swift version. */
export function pixels(pose: Pose): [number, number, string][] {
  const out: [number, number, string][] = [];
  const px = (c: number, r: number, color: string) =>
    out.push([pose.flipped ? COLS - 1 - c : c, r, color]);
  const ba = pose.bodyAlpha ?? 1;
  const body = rgba(pose.body, ba);
  const shade = rgba(pose.body, 0.78 * ba);
  const top = pose.slump ? 3 : 2;

  // Antenna
  if (pose.slump) {
    px(5, 2, body);
    px(6, 2, rgba(pose.body, 0.6 * ba));
  } else {
    px(5, 1, body);
    px(5, 0, pose.lit ? COLORS.spark : rgba(pose.body, 0.7 * ba));
  }

  // Body
  for (let c = 2; c <= 9; c++) px(c, top, body);
  for (let r = top + 1; r <= top + 5; r++) for (let c = 1; c <= 10; c++) px(c, r, body);
  for (let c = 2; c <= 9; c++) px(c, top + 6, shade);

  // Feet
  const feet = pose.slump ? [1, 2, 9, 10] : pose.step === 0 ? [1, 2, 7, 8] : pose.step === 1 ? [3, 4, 9, 10] : [2, 3, 8, 9];
  for (const c of feet) px(c, 9, shade);

  // Arms
  const armRow = top + 4;
  switch (pose.arms) {
    case "rest": px(0, armRow, body); px(11, armRow, body); break;
    case "typeA": px(0, armRow, body); px(11, armRow - 1, body); break;
    case "typeB": px(0, armRow - 1, body); px(11, armRow, body); break;
    case "waveUp": px(0, armRow, body); px(11, top, body); px(11, top - 1, body); break;
    case "waveDown": px(0, armRow, body); px(11, top + 1, body); px(11, top, body); break;
  }

  // Face
  const e = top + 2;
  const ink = COLORS.ink;
  switch (pose.eyes) {
    case "open": for (const r of [e, e + 1]) { px(3, r, ink); px(8, r, ink); } break;
    case "focus": for (const r of [e + 1, e + 2]) { px(3, r, ink); px(8, r, ink); } break;
    case "blink": case "sleep": for (const c of [2, 3, 8, 9]) px(c, e + 1, ink); break;
    case "wide":
      for (const r of [e, e + 1]) for (const c of [2, 3, 8, 9]) px(c, r, ink);
      px(5, e + 3, ink); px(6, e + 3, ink);
      break;
    case "cross":
      for (const [c, r] of [[2, e], [4, e], [3, e + 1], [2, e + 2], [4, e + 2], [7, e], [9, e], [8, e + 1], [7, e + 2], [9, e + 2]]) px(c, r, ink);
      break;
    case "tired":
      for (const c of [2, 3, 4, 7, 8, 9]) px(c, e + 1, ink);
      px(3, e + 2, ink); px(8, e + 2, ink);
      break;
  }
  if (["open", "focus", "wide", "blink"].includes(pose.eyes)) {
    px(1, e + 3, COLORS.blush); px(10, e + 3, COLORS.blush);
  }
  if (pose.sweat) { px(0, top, COLORS.sweat); px(0, top + 1, rgba(COLORS.sweat, 0.7)); }
  return out;
}

// ---- Rasterize-once cache -------------------------------------------------

const cache = new Map<string, HTMLCanvasElement>();

/** A crisp sprite canvas for this pose at `p` CSS px per pixel and the given DPR. */
export function sprite(pose: Pose, p: number, dpr: number): HTMLCanvasElement {
  const key = `${JSON.stringify(pose)}|${p}|${dpr}`;
  const hit = cache.get(key);
  if (hit) return hit;
  const c = document.createElement("canvas");
  c.width = Math.ceil(COLS * p * dpr);
  c.height = Math.ceil(ROWS * p * dpr);
  const g = c.getContext("2d")!;
  g.scale(dpr, dpr);
  for (const [col, row, color] of pixels(pose)) {
    g.fillStyle = color;
    g.fillRect(col * p, row * p, p, p);
  }
  cache.set(key, c);
  return c;
}

/** Generic rasterize-once helper for props (desks, bubbles, clouds). */
export function cached(key: string, w: number, h: number, dpr: number, draw: (g: CanvasRenderingContext2D) => void) {
  const k = `${key}|${dpr}`;
  const hit = cache.get(k);
  if (hit) return hit;
  const c = document.createElement("canvas");
  c.width = Math.max(1, Math.ceil(w * dpr));
  c.height = Math.max(1, Math.ceil(h * dpr));
  const g = c.getContext("2d")!;
  g.scale(dpr, dpr);
  draw(g);
  cache.set(k, c);
  return c;
}
