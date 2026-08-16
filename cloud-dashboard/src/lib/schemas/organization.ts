import { z } from "zod";

export const organizationRoleEnum = z.enum([
  "Viewer",
  "Developer",
  "ReleaseManager",
  "Admin",
  "Owner",
]);
export type OrganizationRoleType = z.infer<typeof organizationRoleEnum>;

export const organizationResponseSchema = z.object({
  id: z.string(),
  name: z.string(),
  slug: z.string(),
  plan: z.string(),
  role: z.string(),
  created_at: z.string(),
});
export type OrganizationResponse = z.infer<typeof organizationResponseSchema>;

export const organizationCreateRequestSchema = z.object({
  name: z.string().min(1, "Organization name is required"),
});
export type OrganizationCreateRequest = z.infer<
  typeof organizationCreateRequestSchema
>;

export const organizationUpdateRequestSchema = z.object({
  name: z.string().optional(),
  billing_email: z.string().email("Invalid email").optional().or(z.literal("")),
});
export type OrganizationUpdateRequest = z.infer<
  typeof organizationUpdateRequestSchema
>;

export const membershipResponseSchema = z.object({
  id: z.string(),
  user_id: z.string(),
  email: z.string(),
  username: z.string(),
  role: z.string(),
  created_at: z.string(),
});
export type MembershipResponse = z.infer<typeof membershipResponseSchema>;

export const inviteRequestSchema = z.object({
  email: z.string().email("Invalid email address"),
  role: z.string(),
});
export type InviteRequest = z.infer<typeof inviteRequestSchema>;

export const inviteResponseSchema = z.object({
  id: z.string(),
  email: z.string(),
  role: z.string(),
  token: z.string(),
  expires_at: z.string(),
  created_at: z.string(),
});
export type InviteResponse = z.infer<typeof inviteResponseSchema>;

export const changeRoleRequestSchema = z.object({
  role: z.string(),
});
export type ChangeRoleRequest = z.infer<typeof changeRoleRequestSchema>;
