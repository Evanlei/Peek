import { Download } from "lucide-react";
import { PrimaryButton } from "./Buttons";
import { CritterMark } from "./CritterMark";
import { Item, Stagger } from "./Reveal";
import { DOWNLOAD, INSTALL_HOOK, REPO } from "@/lib/links";

export function DownloadSection() {
  return (
    <section id="download" className="scroll-mt-24 px-4 pt-16 pb-20">
      <Stagger inView className="mx-auto max-w-2xl text-center">
        <Item>
          <div className="mx-auto grid size-20 place-items-center rounded-[22px] bg-neutral-950 shadow-[0_12px_30px_-12px_rgba(0,0,0,0.5)]">
            <CritterMark size={46} pose={{ lit: true }} />
          </div>
        </Item>
        <Item>
          <h2 className="mt-8 text-4xl font-bold tracking-tighter text-balance">Put your agents in the notch.</h2>
        </Item>
        <Item>
          <p className="mt-4 text-muted-foreground">macOS 14 or later · Apple silicon and Intel · Free and open source</p>
        </Item>
        <Item>
          <div className="mt-8 flex justify-center">
            <PrimaryButton href={DOWNLOAD}>
              <Download className="-ml-0.5 size-[18px]" strokeWidth={2.25} />
              Download Peek
            </PrimaryButton>
          </div>
        </Item>
        <Item>
          <ol className="mx-auto mt-12 max-w-xl space-y-4 text-left text-[15px]">
            <Step n={1} title="Unzip and move Peek to Applications.">
              Peek isn&apos;t notarized yet, so macOS will warn the first time you open it. Go to System Settings → Privacy &amp; Security
              and click <span className="font-medium text-neutral-800">Open Anyway</span>.
            </Step>
            <Step n={2} title="Turn on approvals (optional).">
              This adds one hook to <code className="font-mono text-[13px]">~/.claude/settings.json</code> and keeps a backup:
              <Code>{INSTALL_HOOK}</Code>
            </Step>
            <Step n={3} title="Start a Claude Code session.">
              Your agents show up next to the notch. Hover it to see the whole scene.
            </Step>
          </ol>
        </Item>
        <Item>
          <p className="mt-10 text-sm text-muted-foreground">
            Prefer to build it yourself?{" "}
            <a href={REPO} className="font-medium text-neutral-800 underline decoration-neutral-300 underline-offset-4 transition-[text-decoration-color] duration-150 ease-out hover:decoration-neutral-500">
              Clone the repo
            </a>{" "}
            and run <code className="whitespace-nowrap font-mono text-[13px]">make run</code>.
          </p>
        </Item>
      </Stagger>
    </section>
  );
}

function Step({ n, title, children }: { n: number; title: string; children: React.ReactNode }) {
  return (
    <li className="flex gap-4">
      <span className="grid size-6 shrink-0 place-items-center rounded-full bg-neutral-900 text-xs font-semibold text-white tabular-nums">{n}</span>
      <div className="min-w-0">
        <p className="font-semibold">{title}</p>
        <div className="mt-1 text-muted-foreground">{children}</div>
      </div>
    </li>
  );
}

function Code({ children }: { children: string }) {
  return (
    <pre className="mt-3 rounded-xl whitespace-pre-wrap break-all bg-neutral-950 px-4 py-3 font-mono text-[12.5px] leading-relaxed text-neutral-200">
      <code>{children}</code>
    </pre>
  );
}
