import { Navbar } from "@/components/Navbar";
import { Hero } from "@/components/Hero";
import { Features } from "@/components/Features";
import { DownloadSection } from "@/components/DownloadSection";
import { Footer } from "@/components/Footer";

export default function Page() {
  return (
    <>
      <Navbar />
      <main>
        <Hero />
        <Features />
        <DownloadSection />
      </main>
      <Footer />
    </>
  );
}
