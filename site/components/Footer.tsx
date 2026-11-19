import { CritterMark } from "./CritterMark";
import { REPO } from "@/lib/links";

export function Footer() {
  return (
    <footer className="px-4 pt-8 pb-12">
      <div className="mx-auto flex max-w-5xl flex-col items-center justify-between gap-3 border-t border-border pt-8 text-sm text-muted-foreground sm:flex-row">
        <span className="flex items-center gap-2">
          <CritterMark size={16} pose={{ eyes: "sleep" }} />
          Peek: an open-source notch app for Claude Code.
        </span>
        <a href={REPO} className="transition-[color] duration-150 ease-out hover:text-neutral-900">
          GitHub
        </a>
      </div>
    </footer>
  );
}
