import { z } from "zod";

export const environmentConfigSchema = z.object({
  env_vars: z
    .array(z.object({ key: z.string(), value: z.string() }))
    .default([]),
  feature_flags: z
    .array(z.object({ key: z.string(), enabled: z.boolean() }))
    .default([]),
});

export const environmentResponseSchema = z.object({
  id: z.string(),
  app_id: z.string(),
  organization_id: z.string(),
  name: z.string(),
  slug: z.string(),
  build_profile: z.string().optional(),
  api_config: environmentConfigSchema
    .optional()
    .default({ env_vars: [], feature_flags: [] }),
  created_at: z.string(),
  updated_at: z.string().optional(),
});
export type EnvironmentResponse = z.infer<typeof environmentResponseSchema>;

export const environmentCreateRequestSchema = z.object({
  app_id: z.string().min(1, "App ID is required"),
  name: z.string().min(1, "Environment name is required"),
  slug: z.string().min(1, "Slug is required"),
  build_profile: z.string().optional(),
  api_config: environmentConfigSchema.optional(),
});
export type EnvironmentCreateRequest = z.infer<
  typeof environmentCreateRequestSchema
>;
