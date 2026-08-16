import { z } from "zod";

export const gitConnectionResponseSchema = z.object({
  id: z.string(),
  organization_id: z.string(),
  provider: z.enum(["github", "gitlab", "bitbucket"]),
  installation_id: z.string(),
  metadata: z.record(z.string(), z.unknown()),
  created_at: z.string(),
});
export type GitConnectionResponse = z.infer<
  typeof gitConnectionResponseSchema
>;

export const gitConnectionCreateRequestSchema = z.object({
  provider: z.enum(["github", "gitlab", "bitbucket"]),
  installation_id: z.string().min(1, "Installation ID is required"),
  access_token: z.string().min(1, "Access token is required"),
  metadata: z.record(z.string(), z.unknown()).optional(),
});
export type GitConnectionCreateRequest = z.infer<
  typeof gitConnectionCreateRequestSchema
>;

export const repositoryResponseSchema = z.object({
  id: z.string(),
  full_name: z.string(),
  default_branch: z.string().default("main"),
  url: z.string().url(),
});
export type RepositoryResponse = z.infer<typeof repositoryResponseSchema>;

export const webhookResponseSchema = z.object({
  success: z.boolean(),
  message: z.string(),
  delivery_id: z.string().nullable().optional(),
});
export type WebhookResponse = z.infer<typeof webhookResponseSchema>;
