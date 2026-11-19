// Scene simulation + drawing, ported from Peek/SceneSim.swift and SceneCanvas.swift.
import { COLORS, basePose, cached, sprite, type Pose } from "./critter";

export type Status = "working" | "needs" | "stuck" | "idle";

export interface DemoAgent {
  id: string;
  name: string;
  status: Status;
  action: string;
  context: number; // 0..1
  cost: number;
  helpers: string[]; // sidekick ids
}

interface Actor {
  x: number;
  hop: number;
  facing: 1 | -1;
  target: number;
  pauseUntil: number;
  moving: boolean;
  typing: boolean;
  toDesk: boolean;
  phase: number;
}

export interface SceneOptions {
  width: number;
  height: number;
  pixel: number;
  mode: "strip" | "diorama";
  reduceMotion: boolean;
}

const rand = (a: number, b: number) => a + Math.random() * (b - a);

export class Scene {
  private actors = new Map<string, Actor>();
  private sidekicks = new Map<string, Actor>();
  private last: number | null = null;

  step(now: number, agents: DemoAgent[], o: SceneOptions) {
    const dt = Math.min(Math.max(now - (this.last ?? now), 0), 0.1);
    this.last = now;
    const p = o.pixel;

    agents.forEach((agent, i) => {
      const [lo, hi] = this.lane(i, agents.length, o);
      let a = this.actors.get(agent.id);
      if (!a) {
        const x = o.mode === "strip" ? lo : rand(lo, hi);
        a = { x, hop: 0, facing: 1, target: x, pauseUntil: 0, moving: false, typing: false, toDesk: true, phase: Math.random() * 100 };
        this.actors.set(agent.id, a);
      }
      a.x = Math.min(Math.max(a.x, lo), hi);
      a.moving = false;
      a.typing = false;
      a.hop = 0;
      const desk = o.mode === "diorama" ? lo + p * 2 : null;
      const tired = agent.context >= 0.8;

      if (agent.status === "working" && o.mode === "diorama" && !o.reduceMotion) {
        if (now < a.pauseUntil) {
          a.typing = desk === null || !a.toDesk;
          if (desk !== null && !a.toDesk) a.facing = desk + p * 9 > a.x ? 1 : -1;
        } else {
          const dx = a.target - a.x;
          if (Math.abs(dx) < 1) {
            const k = tired ? 1.7 : 1;
            if (desk !== null) {
              const atDesk = a.toDesk;
              a.pauseUntil = now + (atDesk ? rand(3, 6) : rand(0.8, 2)) * k;
              a.toDesk = !atDesk;
              a.target = a.toDesk ? desk : rand(lo, hi);
            }
          } else {
            const speed = ((tired ? 11 : 24) * p) / 3;
            a.x += Math.sign(dx) * Math.min(Math.abs(dx), speed * dt);
            a.facing = dx > 0 ? 1 : -1;
            a.moving = true;
          }
        }
      } else if (agent.status === "working") {
        a.typing = !o.reduceMotion;
      } else if (agent.status === "needs" && !o.reduceMotion) {
        const c = (now + a.phase) % 1;
        a.hop = c < 0.32 ? Math.sin((c / 0.32) * Math.PI) * p * 2 : 0;
      }

      if (o.mode === "diorama") {
        agent.helpers.forEach((id, j) => {
          let k = this.sidekicks.get(id);
          if (!k) {
            k = { ...a!, phase: Math.random() * 100 };
            this.sidekicks.set(id, k);
          }
          const gap = p * 7 + j * p * 6;
          let desired = a!.x - a!.facing * gap;
          if (desired < lo - p * 4 || desired > hi + p * 4) desired = a!.x + a!.facing * gap;
          const dx = desired - k.x;
          k.x = o.reduceMotion ? desired : k.x + dx * Math.min(1, dt * 3.2);
          k.moving = Math.abs(dx) > 1.2 && !o.reduceMotion;
          k.facing = k.moving ? (dx > 0 ? 1 : -1) : a!.facing;
          k.hop = k.moving ? Math.abs(Math.sin(now * 9 + k.phase)) * p * 0.5 : 0;
        });
      }
    });

    const alive = new Set(agents.map((a) => a.id));
    for (const id of this.actors.keys()) if (!alive.has(id)) this.actors.delete(id);
    const aliveHelpers = new Set(agents.flatMap((a) => a.helpers));
    for (const id of this.sidekicks.keys()) if (!aliveHelpers.has(id)) this.sidekicks.delete(id);
  }

  private lane(i: number, n: number, o: SceneOptions): [number, number] {
    if (o.mode === "strip") {
      const x = 10 + i * 20;
      return [x, x];
    }
    const slice = o.width / Math.max(n, 1);
    const margin = o.pixel * 7;
    const lo = i * slice + margin;
    return [lo, Math.max(lo, (i + 1) * slice - margin)];
  }

  draw(g: CanvasRenderingContext2D, agents: DemoAgent[], now: number, o: SceneOptions, dpr: number) {
    const p = o.pixel;
    const floor = o.mode === "strip" ? o.height - 4 : o.height - 4;
    g.clearRect(0, 0, o.width, o.height);
    g.imageSmoothingEnabled = false;
    const blit = (c: HTMLCanvasElement, x: number, y: number, alpha = 1) => {
      g.globalAlpha = alpha;
      g.drawImage(c, Math.round(x * 2) / 2, Math.round(y * 2) / 2, c.width / dpr, c.height / dpr);
      g.globalAlpha = 1;
    };

    if (o.mode === "diorama") {
      // floor
      const fl = cached(`floor-${o.width}`, o.width - 8, 1, dpr, (c) => {
        c.fillStyle = "rgba(255,255,255,0.09)";
        for (let x = 0; x < o.width - 8; x += 5) c.fillRect(x, 0, 2, 1);
      });
      blit(fl, 4, floor);
      // desks
      agents.forEach((agent, i) => {
        const [lo] = this.lane(i, agents.length, o);
        blit(desk(agent.status, now, p, dpr, o.reduceMotion), lo + p * 2 + p * 9 - p, floor - 11 * p);
      });
      // sidekicks
      for (const agent of agents) {
        for (const id of agent.helpers) {
          const k = this.sidekicks.get(id);
          if (!k) continue;
          const pose = basePose({ flipped: k.facing < 0, body: COLORS.sidekick, lit: agent.status === "working" });
          if (k.moving) pose.step = (Math.floor(now * 10 + k.phase) % 2) as 0 | 1;
          else if (agent.status === "working" && !o.reduceMotion) {
            pose.arms = Math.floor(now * 6 + k.phase) % 2 === 0 ? "typeA" : "typeB";
            pose.eyes = "focus";
          }
          if (!o.reduceMotion && (now + k.phase) % 4.1 < 0.12) pose.eyes = "blink";
          const sp = p * 0.6;
          blit(sprite(pose, sp, dpr), k.x - 6 * sp, floor - k.hop - 10 * sp);
        }
      }
    }

    agents.forEach((agent, i) => {
      const a = this.actors.get(agent.id);
      if (!a) return;
      const pose = poseFor(agent, a, now, o.reduceMotion);
      const feetY = floor - a.hop;
      if (o.mode === "strip" && agent.status === "needs") {
        const rad = 9 * p;
        const glow = cached(`glow-${rad}`, rad * 2, rad * 2, dpr, (c) => {
          const gr = c.createRadialGradient(rad, rad, 0, rad, rad, rad);
          gr.addColorStop(0, "rgba(255,181,41,0.55)");
          gr.addColorStop(1, "rgba(255,181,41,0)");
          c.fillStyle = gr;
          c.fillRect(0, 0, rad * 2, rad * 2);
        });
        blit(glow, a.x - rad, floor - 5 * p - rad);
      }
      blit(sprite(pose, p, dpr), a.x - 6 * p, feetY - 10 * p);
      if (o.mode === "strip") return;

      const headY = feetY - 10 * p;
      if (agent.status === "needs") blit(alert(p, dpr), a.x - alertW(p) / 2, headY - alertH(p) - p);
      if (agent.status === "stuck") blit(cloud(p, dpr, o.reduceMotion ? 0 : Math.floor(now * 5) % 2), a.x - 3.2 * p, headY - 4 * p);
      if (agent.status === "idle") {
        const c = o.reduceMotion ? 0.5 : (now % 2.4) / 2.4;
        g.globalAlpha = 0.7 * (1 - c * 0.8);
        g.fillStyle = "#fff";
        g.font = `700 ${Math.max(7, p * 3)}px ui-rounded, -apple-system, system-ui`;
        g.fillText("z", a.x + p * 4 + c * p * 2, headY - p - c * p * 5);
        g.globalAlpha = 1;
      }

      // name + context bar, kept inside the scene
      const top = headY - (agent.status === "working" ? 6 : 20);
      g.font = "600 10px -apple-system, BlinkMacSystemFont, system-ui, sans-serif";
      const tw = g.measureText(agent.name).width;
      const half = tw / 2 + 4;
      const lx = Math.min(Math.max(a.x, half), o.width - half);
      g.fillStyle = "rgba(255,255,255,0.85)";
      g.textAlign = "center";
      g.fillText(agent.name, lx, top - 6);
      g.textAlign = "start";
      const w = 34;
      g.fillStyle = "rgba(255,255,255,0.12)";
      roundRect(g, lx - w / 2, top - 3, w, 3, 1.5);
      g.fillStyle = ctxColor(agent.context);
      roundRect(g, lx - w / 2, top - 3, Math.max(3, w * agent.context), 3, 1.5);
      void i;
    });
  }
}

function poseFor(agent: DemoAgent, a: Actor, now: number, reduce: boolean): Pose {
  const pose = basePose({ flipped: a.facing < 0, sweat: agent.context >= 0.8 && agent.status !== "idle" });
  const blinking = !reduce && (now + a.phase) % 3.7 < 0.13;
  switch (agent.status) {
    case "working":
      if (a.moving) pose.step = (Math.floor(now * 8 + a.phase) % 2) as 0 | 1;
      if (a.typing) {
        pose.arms = Math.floor(now * 7 + a.phase) % 2 === 0 ? "typeA" : "typeB";
        pose.eyes = "focus";
      }
      if (agent.context >= 0.8) pose.eyes = "tired";
      if (blinking) pose.eyes = "blink";
      pose.lit = reduce || Math.floor(now * 3 + a.phase) % 3 !== 0;
      break;
    case "needs":
      pose.eyes = "wide";
      pose.flipped = false;
      pose.arms = reduce ? "waveUp" : Math.floor(now * 4) % 2 === 0 ? "waveUp" : "waveDown";
      pose.lit = true;
      break;
    case "stuck":
      pose.slump = true;
      pose.eyes = "cross";
      pose.body = COLORS.stuck;
      break;
    case "idle":
      pose.eyes = "sleep";
      pose.bodyAlpha = 0.75;
      break;
  }
  return pose;
}

export function ctxColor(f: number) {
  return f >= 0.9 ? "#FF5C4D" : f >= 0.8 ? "#FF9E40" : f >= 0.6 ? "#FFD159" : "#73D9F2";
}

function roundRect(g: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  g.beginPath();
  g.roundRect(x, y, w, h, r);
  g.fill();
}

const alertW = (p: number) => Math.max(9, p * 3.4);
const alertH = (p: number) => Math.max(11, p * 4);

function alert(p: number, dpr: number) {
  const w = alertW(p), h = alertH(p);
  return cached(`alert-${p}`, w, h, dpr, (c) => {
    c.fillStyle = COLORS.amber;
    c.beginPath();
    c.roundRect(0, 0, w, h, w / 2.5);
    c.fill();
    c.fillStyle = "rgba(0,0,0,0.85)";
    const bw = Math.max(1.6, w * 0.2);
    c.fillRect((w - bw) / 2, h * 0.18, bw, h * 0.42);
    c.fillRect((w - bw) / 2, h * 0.68, bw, bw);
  });
}

function cloud(p: number, dpr: number, frame: number) {
  const q = p * 0.8;
  return cached(`cloud-${p}-${frame}`, 8 * q, 6 * q, dpr, (c) => {
    c.fillStyle = "#9E9E9E";
    const shape = [[2, 0], [3, 0], [5, 0], [1, 1], [2, 1], [3, 1], [4, 1], [5, 1], [6, 1], [0, 2], [1, 2], [2, 2], [3, 2], [4, 2], [5, 2], [6, 2], [7, 2]];
    for (const [x, y] of shape) c.fillRect(x * q, y * q, q, q);
    c.fillStyle = "rgba(140,204,255,0.8)";
    for (let x = 1 + frame; x < 8; x += 2) c.fillRect(x * q, (4 + ((x + frame) % 2)) * q, q * 0.6, q);
  });
}

function desk(status: Status, now: number, p: number, dpr: number, reduce: boolean) {
  const frame = status === "working" ? (reduce ? 0 : Math.floor(now * 4) % 6) : status === "stuck" ? (reduce ? 0 : Math.floor(now * 2) % 2) : 0;
  return cached(`desk-${p}-${status}-${frame}`, 10 * p, 11 * p, dpr, (c) => {
    const r = (col: number, row: number, w: number, h: number, color: string) => {
      c.fillStyle = color;
      c.fillRect((col + 1) * p, (11 - row) * p, w * p, h * p);
    };
    r(-1, 5, 9, 1, "#474747");
    r(-1, 4, 1, 4, "rgba(71,71,71,0.8)");
    r(7, 4, 1, 4, "rgba(71,71,71,0.8)");
    r(1, 10, 6, 4, "#333");
    r(3.5, 6, 1, 1, "#333");
    const screen =
      status === "working" ? `rgba(115,204,255,${0.65 + 0.25 * Math.sin((frame / 6) * 2 * Math.PI)})`
      : status === "needs" ? COLORS.amber
      : status === "stuck" ? `rgba(255,77,71,${frame === 0 ? 0.9 : 0.5})`
      : "#1f1f1f";
    r(1.5, 9.5, 5, 3, screen);
    if (status === "working") {
      for (let i = 0; i < 2; i++) {
        const w = [3, 2, 4][((frame % 3) + i) % 3];
        r(2, 9 - i * 1.2, w * 0.8, 0.5, "rgba(255,255,255,0.55)");
      }
    }
  });
}
