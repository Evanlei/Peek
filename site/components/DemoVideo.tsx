"use client";

import { useReducedMotion } from "motion/react";
import { Item, Stagger } from "./Reveal";

// A screen recording of the real app (debug build, PEEK_RECORD), composited
// over a plain desktop. Under reduced motion it waits for a click instead.
export function DemoVideo() {
  const reduce = useReducedMotion() ?? false;
  return (
    <section className="px-4 pt-8 pb-12">
      <Stagger inView className="mx-auto max-w-5xl">
        <Item className="text-center">
          <p className="text-xs font-semibold tracking-[0.14em] text-peek uppercase">See it in action</p>
          <h2 className="mt-3 text-4xl font-bold tracking-tighter text-balance">The real app, recorded.</h2>
          <p className="mx-auto mt-3 max-w-md text-pretty text-muted-foreground">
            Hover to see every session. When one needs permission, the notch opens on its own.
          </p>
        </Item>
        <Item>
          <div className="mt-12 overflow-hidden rounded-[28px] bg-[#3a3352] shadow-[0_24px_48px_-24px_rgba(0,0,0,0.45)]">
            <video
              key={reduce ? "still" : "play"}
              className="block aspect-[3/1] w-full"
              width={1800}
              height={600}
              poster="/demo/peek-demo-poster.jpg"
              autoPlay={!reduce}
              controls={reduce}
              loop
              muted
              playsInline
              preload="metadata"
              aria-label="Peek in the notch: hovering opens a room of pixel characters, then an approval request appears and is allowed."
            >
              <source src="/demo/peek-demo.webm" type="video/webm" />
              <source src="/demo/peek-demo.mp4" type="video/mp4" />
            </video>
          </div>
        </Item>
      </Stagger>
    </section>
  );
}
