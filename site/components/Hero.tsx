import { Download } from "lucide-react";
import { PrimaryButton, SecondaryButton } from "./Buttons";
import { GitHubIcon } from "./Icons";
import { Item, Stagger } from "./Reveal";
import { Laptop } from "./Laptop";
import { REPO } from "@/lib/links";

export function Hero() {
  return (
    <section className="relative px-4 pt-32 pb-16 sm:pt-40">
      <Stagger className="mx-auto flex max-w-3xl flex-col items-center text-center">
        <Item>
          <span className="inline-flex items-center gap-2 rounded-full bg-white px-3 py-1 text-[13px] font-medium text-neutral-600 shadow-[0_0_0_1px_rgba(0,0,0,0.06),0_1px_2px_rgba(0,0,0,0.04)]">
            <span className="size-1.5 rounded-full bg-[#33D66B]" />
            For Claude Code on macOS
          </span>
        </Item>
        <Item>
          <h1 className="mt-6 text-5xl font-bold tracking-tighter text-balance sm:text-6xl">
            Your agents, living in the notch.
          </h1>
        </Item>
        <Item>
          <p className="mx-auto mt-5 max-w-xl text-lg text-pretty text-muted-foreground">
            Peek turns each Claude Code session into a little character on your MacBook&apos;s notch. See what it&apos;s
            doing, how full its context is and what it costs, and approve permission requests without switching windows.
          </p>
        </Item>
        <Item>
          <div className="mt-8 flex flex-col items-center gap-3 sm:flex-row">
            <PrimaryButton href="#download">
              <Download className="-ml-0.5 size-[18px]" strokeWidth={2.25} />
              Download for macOS
            </PrimaryButton>
            <SecondaryButton href={REPO}>
              <GitHubIcon className="-ml-0.5 size-[17px]" />
              View on GitHub
            </SecondaryButton>
          </div>
        </Item>
        <Item>
          <p className="mt-4 text-[13px] text-muted-foreground">Free and open source · macOS 14 or later</p>
        </Item>
      </Stagger>
      <Stagger className="mx-auto mt-16 max-w-5xl">
        <Item>
          <Laptop />
        </Item>
        <Item>
          <p className="mt-6 text-center text-sm text-muted-foreground">
            A live recreation of Peek, running in your browser. Hover the notch, and answer a request when one shows up.
          </p>
        </Item>
      </Stagger>
    </section>
  );
}
