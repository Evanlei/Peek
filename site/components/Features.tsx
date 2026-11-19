import { CritterMark } from "./CritterMark";
import { Item, Stagger } from "./Reveal";
import type { Pose } from "@/lib/critter";

const FEATURES: { title: string; body: string; pose: Partial<Pose> }[] = [
  {
    title: "Reads your real sessions",
    body: "Project, branch, context window and cost come straight from Claude Code's local logs. Subagents show up as sidekicks. Nothing leaves your Mac.",
    pose: { arms: "typeA", eyes: "focus", lit: true },
  },
  {
    title: "Approve from the notch",
    body: "A permission request opens the notch on its own. Click Allow or Deny and the agent carries on. Answer in the terminal instead and the card goes away.",
    pose: { arms: "waveUp", eyes: "wide", lit: true },
  },
  {
    title: "Light enough to forget",
    body: "SpriteKit and cached sprites keep it at about 2–3% CPU while collapsed. It only animates fully while you're looking.",
    pose: { eyes: "sleep", bodyAlpha: 0.85 },
  },
];

export function Features() {
  return (
    <section className="px-4 py-20">
      <Stagger inView className="mx-auto grid max-w-5xl gap-4 sm:grid-cols-3">
        {FEATURES.map((f) => (
          <Item key={f.title}>
            <div className="h-full rounded-2xl border border-transparent bg-white p-6 shadow-[0_0_0_1px_rgba(0,0,0,0.06),0_1px_2px_rgba(0,0,0,0.04),0_8px_24px_-12px_rgba(0,0,0,0.08)]">
              <div className="grid size-12 place-items-center rounded-xl bg-neutral-950">
                <CritterMark size={28} pose={f.pose} />
              </div>
              <h3 className="mt-5 text-[17px] font-semibold tracking-tight">{f.title}</h3>
              <p className="mt-2 text-[15px] leading-relaxed text-pretty text-muted-foreground">{f.body}</p>
            </div>
          </Item>
        ))}
      </Stagger>
    </section>
  );
}
