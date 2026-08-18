import { z } from "zod";

export const appResponseSchema = z.object({
  id: z.string(),
  project_id: z.string(),
  organization_id: z.string(),
  name: z.string(),
  slug: z.string(),
  repository_url: z.string().nullable().optional(),
  default_branch: z.string(),
  icon_url: z.string().nullable().optional(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type AppResponse = z.infer<typeof appResponseSchema>;

export const appCreateRequestSchema = z.object({
  project_id: z.string().min(1, "Project is required"),
  name: z.string().min(1, "App name is required"),
  repository_url: z
    .string()
    .url("Invalid repository URL")
    .optional()
    .or(z.literal("")),
  default_branch: z.string().optional(),
});
export type AppCreateRequest = z.infer<typeof appCreateRequestSchema>;

export const appUpdateRequestSchema = z.object({
  name: z.string().optional(),
  repository_url: z
    .string()
    .url("Invalid repository URL")
    .optional()
    .nullable()
    .or(z.literal("")),
  default_branch: z.string().optional(),
});
export type AppUpdateRequest = z.infer<typeof appUpdateRequestSchema>;

export const appLinkRequestSchema = z.object({
  project_slug: z.string().min(1, "Project slug is required"),
  app_slug: z.string().min(1, "App slug is required"),
});
export type AppLinkRequest = z.infer<typeof appLinkRequestSchema>;
