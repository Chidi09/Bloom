import { z } from "zod";

export const projectResponseSchema = z.object({
  id: z.string(),
  organization_id: z.string(),
  name: z.string(),
  slug: z.string(),
  description: z.string().nullable().optional(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type ProjectResponse = z.infer<typeof projectResponseSchema>;

export const projectCreateRequestSchema = z.object({
  name: z.string().min(1, "Project name is required"),
  description: z.string().optional(),
});
export type ProjectCreateRequest = z.infer<typeof projectCreateRequestSchema>;

export const projectUpdateRequestSchema = z.object({
  name: z.string().optional(),
  description: z.string().optional().nullable(),
});
export type ProjectUpdateRequest = z.infer<typeof projectUpdateRequestSchema>;
