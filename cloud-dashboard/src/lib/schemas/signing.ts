import { z } from "zod";

export const keystoreMetadataSchema = z.object({
  kind: z.literal("keystore").default("keystore"),
  alias: z.string().min(1, "Key alias is required"),
});

export const certificateMetadataSchema = z.object({
  kind: z.literal("certificate").default("certificate"),
  fingerprint: z.string().min(1, "Certificate fingerprint is required"),
});

export const provisioningProfileMetadataSchema = z.object({
  kind: z.literal("provisioning_profile").default("provisioning_profile"),
  bundle_id: z.string().min(1, "Bundle ID is required"),
  uuid: z.string().min(1, "Profile UUID is required"),
});

export const apiKeyMetadataSchema = z.object({
  kind: z.literal("api_key").default("api_key"),
  key_id: z.string().min(1, "Key ID is required"),
  issuer_id: z.string().min(1, "Issuer ID is required"),
  team_id: z.string().min(1, "Team ID is required"),
});

export const signingIdentityMetadataSchema = z.discriminatedUnion("kind", [
  keystoreMetadataSchema,
  certificateMetadataSchema,
  provisioningProfileMetadataSchema,
  apiKeyMetadataSchema,
]);
export type SigningIdentityMetadata = z.infer<
  typeof signingIdentityMetadataSchema
>;

export const signingIdentityResponseSchema = z.object({
  id: z.string(),
  organization_id: z.string(),
  platform: z.enum(["android", "ios"]),
  name: z.string(),
  kind: z.enum(["keystore", "certificate", "provisioning_profile", "api_key"]),
  metadata: z.record(z.string(), z.unknown()),
  expires_at: z.string().optional().nullable(),
  is_expiring: z.boolean().default(false),
  created_at: z.string(),
});
export type SigningIdentityResponse = z.infer<
  typeof signingIdentityResponseSchema
>;

export const signingIdentityCreateRequestSchema = z.object({
  platform: z.enum(["android", "ios"]),
  name: z.string().min(1, "Identity name is required"),
  kind: z.enum(["keystore", "certificate", "provisioning_profile", "api_key"]),
  material: z.string().min(1, "Signing material / file content is required"),
  metadata: z.record(z.string(), z.unknown()),
  expires_at: z.string().optional().nullable(),
});
export type SigningIdentityCreateRequest = z.infer<
  typeof signingIdentityCreateRequestSchema
>;
