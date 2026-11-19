"use client";

import { useEffect, useRef } from "react";
import { Scene, type DemoAgent } from "@/lib/scene";

/**
 * Canvas host for the pixel scene. Runs a capped-fps rAF loop and pauses when
 * offscreen or the tab is hidden — the web version of the app's CPU discipline.
 */
export function SceneCanvas({
  agents,
  width,
  height,
  pixel,
  mode,
  fps,
  reduceMotion,
}: {
  agents: DemoAgent[];
  width: number;
  height: number;
  pixel: number;
  mode: "strip" | "diorama";
  fps: number;
  reduceMotion: boolean;
}) {
  const ref = useRef<HTMLCanvasElement>(null);
  const agentsRef = useRef(agents);
  agentsRef.current = agents;
  const sceneRef = useRef<Scene | null>(null);
  if (!sceneRef.current) sceneRef.current = new Scene();

  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    const g = canvas.getContext("2d")!;
    g.setTransform(dpr, 0, 0, dpr, 0, 0);

    let raf = 0;
    let lastFrame = 0;
    let visible = true;
    const opts = { width, height, pixel, mode, reduceMotion };

    const frame = (t: number) => {
      raf = requestAnimationFrame(frame);
      if (!visible || document.hidden) return;
      if (t - lastFrame < 1000 / fps - 2) return;
      lastFrame = t;
      const now = t / 1000;
      sceneRef.current!.step(now, agentsRef.current, opts);
      sceneRef.current!.draw(g, agentsRef.current, now, opts, dpr);
    };
    raf = requestAnimationFrame(frame);

    const io = new IntersectionObserver(([e]) => (visible = e.isIntersecting));
    io.observe(canvas);
    return () => {
      cancelAnimationFrame(raf);
      io.disconnect();
    };
  }, [width, height, pixel, mode, fps, reduceMotion]);

  return <canvas ref={ref} style={{ width, height }} aria-hidden className="block" />;
}
