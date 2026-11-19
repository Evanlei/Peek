import Image from "next/image";
import { Download } from "lucide-react";
import { PrimaryButton } from "./Buttons";
import { Item, Stagger } from "./Reveal";
import { DOWNLOAD_PAGE, REPO } from "@/lib/links";

export function DownloadSection() {
  return (
    <section id="download" className="scroll-mt-24 px-4 pt-16 pb-24">
      <Stagger inView className="mx-auto max-w-2xl text-center">
        <Item className="flex justify-center">
          <Image src="/peek-icon.png" alt="" width={112} height={112} className="-my-2" />
        </Item>
        <Item>
          <h2 className="mt-6 text-4xl font-bold tracking-tighter text-balance">Put your agents in the notch.</h2>
        </Item>
        <Item>
          <p className="mt-4 text-muted-foreground">macOS 14 or later · Apple silicon and Intel · Free and open source</p>
        </Item>
        <Item>
          <div className="mt-8 flex justify-center">
            <PrimaryButton href={DOWNLOAD_PAGE}>
              <Download className="-ml-0.5 size-[18px]" strokeWidth={2.25} />
              Download Peek
            </PrimaryButton>
          </div>
        </Item>
        <Item>
          <p className="mt-6 text-sm text-muted-foreground">
            Prefer to build it yourself?{" "}
            <a
              href={REPO}
              className="font-medium text-neutral-800 underline decoration-neutral-300 underline-offset-4 transition-[text-decoration-color] duration-150 ease-out hover:decoration-neutral-500"
            >
              Clone the repo
            </a>{" "}
            and run <code className="font-mono text-[13px] whitespace-nowrap">make run</code>.
          </p>
        </Item>
      </Stagger>
    </section>
  );
}
