"use client";

import { ComingSoonTab } from "@/components/shared/coming-soon-tab";

export default function AppObservabilityPage() {
  return (
    <ComingSoonTab
      title="Observability & Crash Analytics"
      description="Track crash-free user sessions, symbolicated stack traces, and real-time performance telemetry across release channels."
      plannedFeatures={[
        "Crash-free session rate over time with deploy markers",
        "Automated dSYM and ProGuard deobfuscation",
        "Real-user session KPIs (crashes, active users, latency)",
        "Release regression anomaly alerts",
      ]}
    />
  );
}
