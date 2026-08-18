import { z } from "zod";

export const meResponseSchema = z.object({
  id: z.string(),
  email: z.string().email(),
  username: z.string(),
  display_name: z.string().nullable().optional(),
  avatar_url: z.string().nullable().optional(),
  timezone: z.string().default("UTC"),
});
export type MeResponse = z.infer<typeof meResponseSchema>;

export const apiTokenCreateRequestSchema = z.object({
  name: z.string().min(1, "Token name is required"),
  scopes: z.array(z.string()).optional(),
  expires_in_days: z.number().int().positive().nullable().optional(),
  organization_id: z.string().nullable().optional(),
});
export type ApiTokenCreateRequest = z.infer<typeof apiTokenCreateRequestSchema>;

export const apiTokenResponseSchema = z.object({
  id: z.string(),
  name: z.string(),
  token: z.string().nullable().optional(),
  scopes: z.array(z.string()).default(["*"]),
  expires_at: z.string().nullable().optional(),
  organization_id: z.string().nullable().optional(),
  last_used_at: z.string().nullable().optional(),
  created_at: z.string(),
});
export type ApiTokenResponse = z.infer<typeof apiTokenResponseSchema>;

export const updateProfileRequestSchema = z.object({
  display_name: z.string().optional(),
  avatar_url: z.string().optional().nullable(),
  timezone: z.string().optional(),
});
export type UpdateProfileRequest = z.infer<typeof updateProfileRequestSchema>;

export const changePasswordRequestSchema = z.object({
  current_password: z.string().min(1, "Current password is required"),
  new_password: z.string().min(8, "New password must be at least 8 characters"),
  confirm_password: z.string().min(8, "Confirm password must match"),
});
export type ChangePasswordRequest = z.infer<typeof changePasswordRequestSchema>;
