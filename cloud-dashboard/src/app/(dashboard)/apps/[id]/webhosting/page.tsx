"use client";

import { ComingSoonTab } from "@/components/shared/coming-soon-tab";

export default function AppWebHostingPage() {
  return (
    <ComingSoonTab
      title="Web Hosting & Domains"
      description="Deploy WASM and CanvasKit Flutter web builds with edge caching, automated SSL, and custom apex domains."
      plannedFeatures={[
        "Global edge CDN with automated HTTP/3 & Brotli",
        "Custom domain verification with DNS record generator",
        "Preview URL deployments per Git pull request",
        "Config-as-code redirects & custom headers editor",
      ]}
    />
  );
}
