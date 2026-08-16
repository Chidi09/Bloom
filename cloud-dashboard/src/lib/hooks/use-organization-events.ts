"use client";

import { useEffect } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { env } from "@/lib/env";
import { useAuthStore } from "@/stores/auth-store";
import { eventSchema } from "@/lib/schemas/event";
import { queryKeys } from "@/lib/api/query-keys";

// cloud-dashboard-frontend.md §21.4 — auth must already be resolved (token present) before this
// opens the connection; heartbeat frames arrive interleaved and are safely ignored by JSON.parse
// failing (any non-event message just gets skipped below, not treated as an error).
const INVALIDATIONS: Record<
  string,
  (e: { app_id: string | null; organization_id: string }) => unknown[]
> = {
  "build.": (e) => (e.app_id ? [...queryKeys.builds(e.app_id)] : []),
  "release.": (e) => (e.app_id ? [...queryKeys.releases(e.app_id)] : []),
  "deployment.": (e) => (e.app_id ? [...queryKeys.deployments(e.app_id)] : []),
  "webhosting.": (e) =>
    e.app_id ? [...queryKeys.webDeployments(e.app_id)] : [],
  "billing.": (e) => [...queryKeys.billingSubscription(e.organization_id)],
};

export function useOrganizationEvents(organizationId: string | null) {
  const queryClient = useQueryClient();
  const accessToken = useAuthStore((s) => s.accessToken);

  useEffect(() => {
    if (!organizationId || !accessToken) return;

    const url = new URL(`${env.NEXT_PUBLIC_API_URL}/api/v1/events/stream`);
    url.searchParams.set("organization_id", organizationId);
    // EventSource can't set headers, so the API must accept a token query param for this
    // endpoint or rely on the httpOnly session cookie — confirm against the backend's actual
    // SSE auth path before wiring this up against a live server.
    const es = new EventSource(url.toString(), { withCredentials: true });

    es.onmessage = (event) => {
      const parsed = eventSchema.safeParse(JSON.parse(event.data));
      if (!parsed.success) return; // heartbeat or unrecognized frame — connection-alive signal only

      for (const [prefix, deriveKey] of Object.entries(INVALIDATIONS)) {
        if (parsed.data.event_type.startsWith(prefix)) {
          queryClient.invalidateQueries({ queryKey: deriveKey(parsed.data) });
        }
      }
    };

    return () => es.close();
  }, [organizationId, accessToken, queryClient]);
}
