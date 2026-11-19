import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { Navbar } from "@/components/Navbar";
import { Footer } from "@/components/Footer";
import { InstallSteps } from "@/components/InstallSteps";
import { Item, Stagger } from "@/components/Reveal";
import { StartDownload } from "@/components/StartDownload";
import { DOWNLOAD } from "@/lib/links";

export const metadata: Metadata = {
  title: "Downloading Peek",
  description: "Your download of Peek has started. Here's how to install it.",
};

export default function DownloadPage() {
  return (
    <>
      <StartDownload />
      <Navbar />
      <main className="px-4 pt-32 pb-20 sm:pt-40">
        <Stagger className="mx-auto max-w-xl">
          <Item className="flex justify-center">
            <Image src="/peek-icon.png" alt="" width={112} height={112} priority className="-my-2" />
          </Item>
          <Item>
            <h1 className="mt-6 text-center text-4xl font-bold tracking-tighter text-balance sm:text-5xl">
              Your download has started.
            </h1>
          </Item>
          <Item>
            <p className="mt-4 text-center text-muted-foreground">
              Didn&apos;t start?{" "}
              <a
                href={DOWNLOAD}
                className="font-medium text-neutral-800 underline decoration-neutral-300 underline-offset-4 transition-[text-decoration-color] duration-150 ease-out hover:decoration-neutral-500"
              >
                Download Peek.zip
              </a>
            </p>
          </Item>
          <Item>
            <div className="mt-14">
              <InstallSteps />
            </div>
          </Item>
          <Item>
            <div className="mt-14 flex justify-center">
              <Link
                href="/"
                className="inline-flex items-center gap-1.5 text-sm font-medium text-muted-foreground transition-[color] duration-150 ease-out hover:text-neutral-900"
              >
                <ArrowLeft className="size-4" strokeWidth={2} />
                Back to Peek
              </Link>
            </div>
          </Item>
        </Stagger>
      </main>
      <Footer />
    </>
  );
}
