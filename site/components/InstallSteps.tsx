import type { ReactNode } from "react";
import { INSTALL_HOOK } from "@/lib/links";

/** The three install steps, shown on the post-download page. */
export function InstallSteps() {
  return (
    <ol className="space-y-6 text-left text-[15px]">
      <Step n={1} title="Move Peek to Applications.">
        Open <Kbd>Peek.zip</Kbd> from your Downloads and drag Peek into the Applications folder.
      </Step>
      <Step n={2} title="Open it once.">
        Peek isn&apos;t notarized yet, so macOS blocks the first launch. Go to System Settings → Privacy &amp; Security, scroll
        down and click <span className="font-medium text-neutral-800">Open Anyway</span>. After that it opens normally.
      </Step>
      <Step n={3} title="Turn on approvals (optional).">
        To allow or deny requests from the notch, run this in Terminal. It adds one hook to{" "}
        <code className="font-mono text-[13px]">~/.claude/settings.json</code> and keeps a backup. It needs{" "}
        <code className="font-mono text-[13px]">jq</code>.
        <pre className="mt-3 rounded-xl bg-neutral-950 px-4 py-3 font-mono text-[12.5px] leading-relaxed break-all whitespace-pre-wrap text-neutral-200">
          <code>{INSTALL_HOOK}</code>
        </pre>
      </Step>
      <Step n={4} title="Start a Claude Code session.">
        Your agents show up next to the notch. Hover it to see the whole scene.
      </Step>
    </ol>
  );
}

function Step({ n, title, children }: { n: number; title: string; children: ReactNode }) {
  return (
    <li className="flex gap-4">
      <span className="grid size-6 shrink-0 place-items-center rounded-full bg-neutral-900 text-xs font-semibold text-white tabular-nums">
        {n}
      </span>
      <div className="min-w-0">
        <p className="font-semibold">{title}</p>
        <div className="mt-1 text-pretty text-muted-foreground">{children}</div>
      </div>
    </li>
  );
}

function Kbd({ children }: { children: ReactNode }) {
  return <span className="font-medium text-neutral-800">{children}</span>;
}
