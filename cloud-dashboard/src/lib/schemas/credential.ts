import { z } from "zod";

export const appleCredentialMetadataSchema = z.object({
  provider: z.literal("apple").default("apple"),
  key_id: z.string().min(1, "Key ID is required"),
  issuer_id: z.string().min(1, "Issuer ID is required"),
  team_id: z.string().min(1, "Team ID is required"),
});

export const googlePlayCredentialMetadataSchema = z.object({
  provider: z.literal("google_play").default("google_play"),
  client_email: z.string().email("Valid client email is required"),
});

export const shorebirdCredentialMetadataSchema = z.object({
  provider: z.literal("shorebird").default("shorebird"),
  app_id: z.string().min(1, "Shorebird App ID is required"),
});

export const githubCredentialMetadataSchema = z.object({
  provider: z.literal("github").default("github"),
  installation_id: z.string().min(1, "Installation ID is required"),
});

export const gitlabCredentialMetadataSchema = z.object({
  provider: z.literal("gitlab").default("gitlab"),
  application_id: z.string().min(1, "Application ID is required"),
});

export const bitbucketCredentialMetadataSchema = z.object({
  provider: z.literal("bitbucket").default("bitbucket"),
  workspace: z.string().min(1, "Workspace slug is required"),
});

export const credentialMetadataSchema = z.discriminatedUnion("provider", [
  appleCredentialMetadataSchema,
  googlePlayCredentialMetadataSchema,
  shorebirdCredentialMetadataSchema,
  githubCredentialMetadataSchema,
  gitlabCredentialMetadataSchema,
  bitbucketCredentialMetadataSchema,
]);
export type CredentialMetadata = z.infer<typeof credentialMetadataSchema>;

export const credentialResponseSchema = z.object({
  id: z.string(),
  organization_id: z.string(),
  provider: z.enum([
    "apple",
    "google_play",
    "shorebird",
    "github",
    "gitlab",
    "bitbucket",
  ]),
  name: z.string(),
  metadata: z.record(z.string(), z.unknown()),
  expires_at: z.string().nullable().optional(),
  last_used_at: z.string().nullable().optional(),
  created_at: z.string(),
});
export type CredentialResponse = z.infer<typeof credentialResponseSchema>;

export const credentialCreateRequestSchema = z.object({
  provider: z.enum([
    "apple",
    "google_play",
    "shorebird",
    "github",
    "gitlab",
    "bitbucket",
  ]),
  name: z.string().min(1, "Credential name is required"),
  token: z.string().min(1, "Token or private key is required"),
  metadata: z.record(z.string(), z.unknown()),
  expires_at: z.string().nullable().optional(),
});
export type CredentialCreateRequest = z.infer<
  typeof credentialCreateRequestSchema
>;

export const credentialTestResponseSchema = z.object({
  id: z.string(),
  provider: z.string(),
  success: z.boolean(),
  message: z.string(),
});
export type CredentialTestResponse = z.infer<
  typeof credentialTestResponseSchema
>;
