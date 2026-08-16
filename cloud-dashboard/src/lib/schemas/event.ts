import { z } from "zod";

// cloud-dashboard-frontend.md §21.1 (events app) / §21.4 (SSE contract).
export const eventSchema = z.object({
  event_type: z.string(),
  organization_id: z.string(),
  project_id: z.string().nullable(),
  app_id: z.string().nullable(),
  actor_id: z.string().nullable(),
  payload: z.record(z.string(), z.unknown()),
  created_at: z.coerce.date(),
});

export type BloomEvent = z.infer<typeof eventSchema>;
