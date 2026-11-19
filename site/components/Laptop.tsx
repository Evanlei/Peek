"use client";

import { BatteryFull, Search, Wifi } from "lucide-react";
import { NotchDemo, useFitScale } from "./NotchDemo";

const STAGE_W = 1000;
const STAGE_H = 336;
const MIN_SCALE = 0.6;
const EDGE_FADE = "linear-gradient(to right, transparent, black 12%, black 88%, transparent)";

/** A MacBook screen mock hosting the live notch demo; scales down on narrow screens. */
export function Laptop() {
  const { ref, scale: fit } = useFitScale(STAGE_W);
  // On phones, don't shrink past 0.6: crop the laptop's sides instead, centred on the notch.
  const scale = Math.max(fit, MIN_SCALE);
  const offset = ((fit - scale) * STAGE_W) / 2;
  return (
    <div
      ref={ref}
      className="w-full overflow-x-clip"
      style={{ height: STAGE_H * scale, maskImage: fit < MIN_SCALE ? EDGE_FADE : undefined }}
    >
      <div
        className="origin-top-left"
        style={{ width: STAGE_W, height: STAGE_H, transform: `translateX(${offset}px) scale(${scale})` }}
      >
        {/* Bezel 22 = screen 12 + 10 padding (concentric) */}
        <div className="mx-auto w-[920px] rounded-[22px] bg-[#0d0d0f] p-[10px] shadow-[0_0_0_1px_rgba(0,0,0,0.25),0_30px_60px_-20px_rgba(30,20,60,0.45),0_12px_24px_-12px_rgba(0,0,0,0.3)]">
          <div className="relative h-[300px] overflow-hidden rounded-[12px]" style={{ background: WALLPAPER }}>
            <MenuBar />
            <div className="absolute top-0 left-1/2 -translate-x-1/2">
              <NotchDemo />
            </div>
          </div>
        </div>
        {/* Base */}
        <div className="mx-auto h-[14px] w-[1000px] rounded-b-[14px] bg-gradient-to-b from-[#d9d9de] to-[#a9a9b0] shadow-[0_8px_16px_-8px_rgba(0,0,0,0.35)]">
          <div className="mx-auto h-[6px] w-[140px] rounded-b-[8px] bg-[#bdbdc4]" />
        </div>
      </div>
    </div>
  );
}

const WALLPAPER = [
  "radial-gradient(60% 80% at 12% 90%, rgba(247,184,154,0.95) 0%, transparent 60%)",
  "radial-gradient(55% 70% at 88% 18%, rgba(159,181,255,0.9) 0%, transparent 62%)",
  "radial-gradient(50% 60% at 62% 95%, rgba(201,166,255,0.8) 0%, transparent 60%)",
  "linear-gradient(160deg, #2a2c50 0%, #5d4675 55%, #8a5a6e 100%)",
].join(", ");

function MenuBar() {
  return (
    <div className="absolute inset-x-0 top-0 flex h-8 items-center justify-between bg-black/10 px-4 text-[13px] text-white/90 backdrop-blur-md">
      <div className="flex items-center gap-4">
        <span className="font-semibold">Terminal</span>
        <span>Shell</span>
        <span>Edit</span>
        <span>View</span>
      </div>
      <div className="flex items-center gap-3.5">
        <BatteryFull className="size-4" strokeWidth={1.75} />
        <Wifi className="size-4" strokeWidth={1.75} />
        <Search className="size-[14px]" strokeWidth={2} />
        <span className="tabular-nums">Tue 9:41</span>
      </div>
    </div>
  );
}
