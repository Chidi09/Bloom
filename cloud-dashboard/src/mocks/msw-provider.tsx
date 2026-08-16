"use client";

import { useEffect } from "react";

let workerPromise: Promise<void> | null = null;

async function enableMocking(): Promise<void> {
  if (process.env.NEXT_PUBLIC_API_MOCKING !== "enabled") return;
  if (!workerPromise) {
    workerPromise = import("@/mocks/browser")
      .then(({ worker }) => worker.start({ onUnhandledRequest: "bypass" }))
      .then(() => undefined)
      .catch((err: unknown) => {
        console.error("Failed to start MSW worker:", err);
      });
  }
  return workerPromise;
}

export function MswProvider({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    enableMocking();
  }, []);

  return <>{children}</>;
}
