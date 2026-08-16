import { z } from "zod";

export const secretResponseSchema = z.object({
  id: z.string(),
  environment_id: z.string(),
  organization_id: z.string(),
  key: z.string(),
  is_json: z.boolean().default(false),
  version: z.number().int().default(1),
  updated_at: z.string(),
});
export type SecretResponse = z.infer<typeof secretResponseSchema>;

export const secretCreateRequestSchema = z.object({
  environment_id: z.string().min(1, "Environment is required"),
  key: z.string().min(1, "Key name is required"),
  value: z.string().min(1, "Secret value is required"),
  is_json: z.boolean().default(false),
});
export type SecretCreateRequest = z.infer<typeof secretCreateRequestSchema>;

export const secretUpdateRequestSchema = z.object({
  value: z.string().optional(),
  is_json: z.boolean().optional(),
});
export type SecretUpdateRequest = z.infer<typeof secretUpdateRequestSchema>;

export const secretRollbackRequestSchema = z.object({
  version: z.number().int().positive("Target version must be positive"),
});
export type SecretRollbackRequest = z.infer<typeof secretRollbackRequestSchema>;
