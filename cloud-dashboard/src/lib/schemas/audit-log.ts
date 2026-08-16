import { z } from "zod";

export const auditLogActorSchema = z.object({
  name: z.string(),
  email: z.string(),
});
export type AuditLogActor = z.infer<typeof auditLogActorSchema>;

export const auditLogEntrySchema = z.object({
  id: z.string(),
  organization_id: z.string(),
  actor: z.union([
    z.string(),
    z.object({
      name: z.string(),
      email: z.string(),
    }),
  ]),
  action: z.string(),
  resource_type: z.string(),
  resource_id: z.string(),
  before_snapshot: z.record(z.string(), z.unknown()).nullable().optional(),
  after_snapshot: z.record(z.string(), z.unknown()).nullable().optional(),
  ip_address: z.string(),
  created_at: z.string(),
});
export type AuditLogEntry = z.infer<typeof auditLogEntrySchema>;

export const auditLogListResponseSchema = z.object({
  count: z.number().optional(),
  page: z.number().optional(),
  total_pages: z.number().optional(),
  next_cursor: z.string().nullable().optional(),
  results: z.array(auditLogEntrySchema),
});
export type AuditLogListResponse = z.infer<typeof auditLogListResponseSchema>;
