import { Navbar } from "@/components/Navbar";
import { Hero } from "@/components/Hero";
import { DemoVideo } from "@/components/DemoVideo";
import { Features } from "@/components/Features";
import { DownloadSection } from "@/components/DownloadSection";
import { Footer } from "@/components/Footer";

export default function Page() {
  return (
    <>
      <Navbar />
      <main>
        <Hero />
        <DemoVideo />
        <Features />
        <DownloadSection />
      </main>
      <Footer />
    </>
  );
}
