import { z } from "zod";

export const releaseArtifactSchema = z.object({
  id: z.string(),
  build_id: z.string(),
  organization_id: z.string(),
  platform: z.string(),
  kind: z.string(),
  file_name: z.string(),
  file_size: z.number(),
  checksum: z.string(),
  version: z.string(),
  build_number: z.number(),
  metadata: z.record(z.string(), z.unknown()).optional().default({}),
  download_url: z.string().optional().nullable(),
  created_at: z.string(),
});
export type ReleaseArtifact = z.infer<typeof releaseArtifactSchema>;

export const releaseResponseSchema = z.object({
  id: z.string(),
  app_id: z.string(),
  organization_id: z.string(),
  version: z.string(),
  build_number: z.number(),
  commit: z.string(),
  changelog: z.string().default(""),
  environment_id: z.string().optional().nullable(),
  status: z.enum([
    "draft",
    "pending_approval",
    "approved",
    "rolling_out",
    "released",
    "rolled_back",
    "expired",
  ]),
  platforms: z.array(z.string()).default([]),
  artifacts: z.array(releaseArtifactSchema).default([]),
  rollout_status: z.record(z.string(), z.unknown()).optional().default({}),
  created_by_id: z.string().optional().default("usr_dev"),
  created_at: z.string(),
  updated_at: z.string(),
});
export type ReleaseResponse = z.infer<typeof releaseResponseSchema>;

export const releaseCreateRequestSchema = z.object({
  app_id: z.string().min(1, "App ID is required"),
  version: z.string().min(1, "Release version is required"),
  build_number: z.number().int().positive("Build number must be positive"),
  commit: z.string().min(1, "Commit SHA is required"),
  changelog: z.string().optional(),
  environment_id: z.string().optional().nullable(),
  platforms: z.array(z.string()).min(1, "At least one platform is required"),
  artifact_ids: z.array(z.string()).default([]),
});
export type ReleaseCreateRequest = z.infer<typeof releaseCreateRequestSchema>;

export const releaseApproveRequestSchema = z.object({
  approved: z.boolean(),
  reason: z.string().optional(),
});
export type ReleaseApproveRequest = z.infer<typeof releaseApproveRequestSchema>;

export const releaseRollbackRequestSchema = z.object({
  reason: z.string().optional(),
});
export type ReleaseRollbackRequest = z.infer<
  typeof releaseRollbackRequestSchema
>;

export const releaseUpdateRequestSchema = z.object({
  changelog: z.string().optional(),
  rollout_status: z.record(z.string(), z.unknown()).optional(),
  status: z.string().optional(),
});
export type ReleaseUpdateRequest = z.infer<typeof releaseUpdateRequestSchema>;
