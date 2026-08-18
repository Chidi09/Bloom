"use client";

import { useEffect, useState } from "react";

const MOCKING_ENABLED = process.env.NEXT_PUBLIC_API_MOCKING === "enabled";

let workerPromise: Promise<void> | null = null;

async function enableMocking(): Promise<void> {
  if (!MOCKING_ENABLED) return;
  if (!workerPromise) {
    workerPromise = import("@/mocks/browser").then(async ({ worker }) => {
      await worker.start({ onUnhandledRequest: "bypass" });
    });
  }
  return workerPromise;
}

export function MswProvider({ children }: { children: React.ReactNode }) {
  // When mocking is enabled, hold rendering (and therefore every child
  // component's data-fetching effects) until the MSW service worker has
  // actually registered and is intercepting requests. Without this gate,
  // the app's initial fetches race ahead of worker.start() and fall
  // through to the real (mock-less) network, surfacing as 502s.
  const [ready, setReady] = useState(!MOCKING_ENABLED);

  useEffect(() => {
    if (!MOCKING_ENABLED) return;
    enableMocking()
      .then(() => setReady(true))
      .catch((err: unknown) => {
        console.error("Failed to start MSW worker:", err);
        setReady(true);
      });
  }, []);

  if (!ready) return null;
  return <>{children}</>;
}
