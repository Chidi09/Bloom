import { z } from "zod";

export const deploymentResponseSchema = z.object({
  id: z.string(),
  release_id: z.string().optional().nullable(),
  artifact_id: z.string().optional().nullable(),
  environment_id: z.string(),
  organization_id: z.string(),
  platform: z.enum(["ios", "android", "web"]),
  target: z.string(),
  status: z.enum([
    "pending",
    "queued",
    "running",
    "processing",
    "ready",
    "live",
    "failed",
    "rolled_back",
  ]),
  external_id: z.string().optional().nullable(),
  external_url: z.string().optional().nullable(),
  preview_image_url: z.string().optional().nullable(),
  error_message: z.string().optional().nullable(),
  started_at: z.string().optional().nullable(),
  finished_at: z.string().optional().nullable(),
  created_by_id: z.string().optional().default("usr_dev"),
  created_at: z.string(),
  updated_at: z.string(),
  // UI enrichment helpers
  release_version: z.string().optional(),
  environment_name: z.string().optional(),
  duration_seconds: z.number().optional(),
});
export type DeploymentResponse = z.infer<typeof deploymentResponseSchema>;

export const deploymentCreateRequestSchema = z.object({
  release_id: z.string().optional().nullable(),
  artifact_id: z.string().optional().nullable(),
  environment_id: z.string().min(1, "Environment is required"),
  platform: z.enum(["ios", "android", "web"]),
  target: z.string().min(1, "Deployment target is required"),
});
export type DeploymentCreateRequest = z.infer<
  typeof deploymentCreateRequestSchema
>;
