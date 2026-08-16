"use client";

import { ComingSoonTab } from "@/components/shared/coming-soon-tab";

export default function AppSecretsPage() {
  return (
    <ComingSoonTab
      title="Secrets & Key Management"
      description="Securely inject masked environment secrets into build and deployment pipelines."
      plannedFeatures={[
        "Zero-client plaintext caching with on-demand reveal",
        "Immutable version history with instant rollback",
        ".env file batch import & dry-run validator",
        "Fine-grained role-based secret access control",
      ]}
    />
  );
}
