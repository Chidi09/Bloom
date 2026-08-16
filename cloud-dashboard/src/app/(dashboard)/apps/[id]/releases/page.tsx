"use client";

import { ComingSoonTab } from "@/components/shared/coming-soon-tab";

export default function AppReleasesPage() {
  return (
    <ComingSoonTab
      title="Releases & Versioning"
      description="Manage version promotions, approval gates, markdown changelogs, and store rollouts."
      plannedFeatures={[
        "SemVer release tagging & changelog generation",
        "Role-gated approval workflows",
        "Instant rollback to previous stable versions",
        "Diff inspector between release builds",
      ]}
    />
  );
}
