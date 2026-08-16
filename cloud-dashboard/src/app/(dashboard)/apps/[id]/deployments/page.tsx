"use client";

import { ComingSoonTab } from "@/components/shared/coming-soon-tab";

export default function AppDeploymentsPage() {
  return (
    <ComingSoonTab
      title="Store Deployments & OTA Updates"
      description="Automate mobile store submissions (TestFlight, Google Play internal track) and Shorebird OTA patch broadcasts."
      plannedFeatures={[
        "Apple TestFlight automatic upload & processing check",
        "Google Play Console track promotion",
        "Shorebird OTA live patching with zero-delay delivery",
        "One-click rollback of faulty OTA updates",
      ]}
    />
  );
}
