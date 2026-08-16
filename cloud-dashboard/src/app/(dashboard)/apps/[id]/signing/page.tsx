"use client";

import { ComingSoonTab } from "@/components/shared/coming-soon-tab";

export default function AppSigningPage() {
  return (
    <ComingSoonTab
      title="Code Signing & Certificates"
      description="Manage iOS distribution certificates, provisioning profiles, Android keystores, and App Store Connect API keys."
      plannedFeatures={[
        "Automated Apple Developer portal provisioning syncing",
        "Encrypted Android release keystore vault",
        "Expiry alerts with automated renewal warnings",
        "Role-gated identity download permissions",
      ]}
    />
  );
}
