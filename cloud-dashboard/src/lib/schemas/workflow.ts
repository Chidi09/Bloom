import { z } from "zod";

export const workflowResponseSchema = z.object({
  id: z.string(),
  app_id: z.string(),
  organization_id: z.string(),
  name: z.string(),
  slug: z.string(),
  description: z.string().nullable().optional(),
  definition: z.string(),
  is_active: z.boolean(),
  created_by: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type WorkflowResponse = z.infer<typeof workflowResponseSchema>;

export const workflowCreateRequestSchema = z.object({
  app_id: z.string().min(1, "App is required"),
  name: z.string().min(1, "Name is required"),
  slug: z.string().min(1, "Slug is required"),
  description: z.string().optional(),
  definition: z.string().min(1, "Definition is required"),
  is_active: z.boolean().default(true),
});
export type WorkflowCreateRequest = z.infer<typeof workflowCreateRequestSchema>;

export const workflowRunStepResponseSchema = z.object({
  id: z.string(),
  step_order: z.number(),
  name: z.string(),
  step_kind: z.enum([
    "test",
    "build",
    "deploy_preview",
    "approval_gate",
    "deploy_production",
    "custom",
  ]),
  status: z.enum([
    "pending",
    "running",
    "blocked",
    "completed",
    "failed",
    "skipped",
  ]),
  requires_approval: z.boolean(),
  started_at: z.string().nullable().optional(),
  finished_at: z.string().nullable().optional(),
  log_snippet: z.string().nullable().optional(),
  metadata: z.record(z.string(), z.unknown()).default({}),
  created_at: z.string(),
});
export type WorkflowRunStepResponse = z.infer<
  typeof workflowRunStepResponseSchema
>;

export const workflowRunResponseSchema = z.object({
  id: z.string(),
  workflow_id: z.string(),
  organization_id: z.string(),
  git_commit: z.string(),
  git_branch: z.string(),
  git_ref: z.string(),
  status: z.enum([
    "pending",
    "running",
    "blocked",
    "success",
    "failed",
    "cancelled",
  ]),
  trigger_event: z.string(),
  started_at: z.string().nullable().optional(),
  finished_at: z.string().nullable().optional(),
  approved_by: z.string().nullable().optional(),
  approved_at: z.string().nullable().optional(),
  metadata: z.record(z.string(), z.unknown()).default({}),
  steps: z.array(workflowRunStepResponseSchema).default([]),
  created_by: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type WorkflowRunResponse = z.infer<typeof workflowRunResponseSchema>;

export const workflowRunCreateRequestSchema = z.object({
  git_commit: z.string().optional(),
  git_branch: z.string().optional(),
  git_ref: z.string().optional(),
  trigger_event: z.string().default("manual"),
});
export type WorkflowRunCreateRequest = z.infer<
  typeof workflowRunCreateRequestSchema
>;

export const workflowApproveRequestSchema = z.object({
  approved: z.boolean(),
  reason: z.string().optional(),
});
export type WorkflowApproveRequest = z.infer<
  typeof workflowApproveRequestSchema
>;
