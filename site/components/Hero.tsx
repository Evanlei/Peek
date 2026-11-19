import { Download } from "lucide-react";
import { PrimaryButton, SecondaryButton } from "./Buttons";
import { GitHubIcon } from "./Icons";
import { Item, Stagger } from "./Reveal";
import { Laptop } from "./Laptop";
import { DOWNLOAD_PAGE, REPO } from "@/lib/links";

export function Hero() {
  return (
    <section className="relative px-4 pt-32 pb-12 sm:pt-40">
      <Stagger className="mx-auto flex max-w-3xl flex-col items-center text-center">
        <Item>
          <h1 className="text-5xl font-bold tracking-tighter text-balance sm:text-6xl">
            Your agents, living in the notch.
          </h1>
        </Item>
        <Item>
          <p className="mx-auto mt-5 max-w-xl text-lg text-pretty text-muted-foreground">
            Each Claude Code session becomes a little character in your MacBook&apos;s notch. See what it&apos;s doing and
            what it costs, and approve its requests without leaving what you&apos;re working on.
          </p>
        </Item>
        <Item>
          <div className="mt-8 flex flex-col items-center gap-3 sm:flex-row">
            <PrimaryButton href={DOWNLOAD_PAGE}>
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
          <p className="mt-4 text-[13px] text-muted-foreground">Free and open source · For Claude Code on macOS 14+</p>
        </Item>
      </Stagger>
      <Stagger className="mx-auto mt-16 max-w-5xl">
        <Item>
          <Laptop />
        </Item>
        <Item>
          <p className="mt-6 text-center text-sm text-muted-foreground">
            A live recreation running in your browser. Hover the notch, and answer a request when one shows up.
          </p>
        </Item>
      </Stagger>
    </section>
  );
}
