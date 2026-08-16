"use client";

import { ComingSoonTab } from "@/components/shared/coming-soon-tab";

export default function AppEnvironmentsPage() {
  return (
    <ComingSoonTab
      title="Environments & Configurations"
      description="Define environment-specific variables, pinned SDK versions, and feature flags."
      plannedFeatures={[
        "Per-environment variable sheets with encryption",
        "Feature flags matrix with instant toggling",
        "Pinned Flutter/Dart SDK version management",
        "Environment clone and promotion pipeline",
      ]}
    />
  );
}
