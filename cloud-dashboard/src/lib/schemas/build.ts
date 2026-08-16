import { z } from "zod";

export const buildStageResponseSchema = z.object({
  stage: z.string(),
  status: z.string(),
  started_at: z.string().nullable().optional(),
  finished_at: z.string().nullable().optional(),
  log_snippet: z.string().nullable().optional(),
});
export type BuildStageResponse = z.infer<typeof buildStageResponseSchema>;

export const buildResponseSchema = z.object({
  id: z.string(),
  app_id: z.string(),
  environment_id: z.string(),
  organization_id: z.string(),
  git_commit: z.string(),
  git_branch: z.string(),
  git_ref: z.string(),
  status: z.string(),
  platform: z.string(),
  build_profile: z.string(),
  flutter_version: z.string(),
  dart_version: z.string(),
  bloom_version: z.string(),
  flavor: z.string().nullable().optional(),
  started_at: z.string().nullable().optional(),
  finished_at: z.string().nullable().optional(),
  logs_url: z.string().nullable().optional(),
  stages: z.array(buildStageResponseSchema).default([]),
  created_at: z.string(),
  updated_at: z.string(),
  // UI helper fields
  build_number: z.number().optional(),
  app_name: z.string().optional(),
  author: z.string().optional(),
  duration_seconds: z.number().optional(),
  commit_hash: z.string().optional(),
  preview_url: z.string().nullable().optional(),
});
export type BuildResponse = z.infer<typeof buildResponseSchema>;

export const buildCreateRequestSchema = z.object({
  app_id: z.string().min(1, "App ID is required"),
  environment_id: z.string().min(1, "Environment is required"),
  platform: z.string().min(1, "Platform is required"),
  git_commit: z.string().optional(),
  git_branch: z.string().optional(),
  git_ref: z.string().optional(),
  build_profile: z.string().optional(),
  flutter_version: z.string().optional(),
  dart_version: z.string().optional(),
  bloom_version: z.string().optional(),
  flavor: z.string().optional(),
});
export type BuildCreateRequest = z.infer<typeof buildCreateRequestSchema>;

export const buildLogsResponseSchema = z.object({
  url: z.string(),
  expires_in_secs: z.number(),
});
export type BuildLogsResponse = z.infer<typeof buildLogsResponseSchema>;
