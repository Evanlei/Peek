"use client";

import { useEffect, useRef } from "react";
import { DOWNLOAD } from "@/lib/links";

/**
 * Starts the download once the page has painted. GitHub serves the zip as an
 * attachment, so the browser stays on this page. The ref guards against
 * StrictMode running the effect twice in development.
 */
export function StartDownload() {
  const started = useRef(false);
  useEffect(() => {
    if (started.current) return;
    started.current = true;
    const t = setTimeout(() => window.location.assign(DOWNLOAD), 400);
    return () => clearTimeout(t);
  }, []);
  return null;
}
