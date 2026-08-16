import { z } from "zod";

export const requiredDnsRecordSchema = z.object({
  record_type: z.string(),
  host: z.string(),
  value: z.string(),
  purpose: z.string(),
});
export type RequiredDnsRecord = z.infer<typeof requiredDnsRecordSchema>;

export const webDeploymentResponseSchema = z.object({
  id: z.string(),
  app_id: z.string(),
  environment_id: z.string(),
  release_id: z.string().nullable().optional(),
  target: z.enum(["preview", "production"]),
  url: z.string(),
  status: z.enum(["deploying", "live", "failed", "rolled_back"]),
  deployed_by_id: z.string(),
  created_at: z.string(),
});
export type WebDeploymentResponse = z.infer<typeof webDeploymentResponseSchema>;

export const customDomainResponseSchema = z.object({
  id: z.string(),
  app_id: z.string(),
  domain: z.string(),
  verification_token: z.string(),
  certificate_status: z.enum(["pending", "issuing", "active", "failed"]),
  certificate_expires_at: z.string().nullable().optional(),
  verified_at: z.string().nullable().optional(),
  failure_reason: z.string().nullable().optional(),
  required_records: z.array(requiredDnsRecordSchema).default([]),
});
export type CustomDomainResponse = z.infer<typeof customDomainResponseSchema>;

export const deployWebRequestSchema = z.object({
  app_id: z.string(),
  environment_id: z.string(),
  artifact_id: z.string(),
  release_id: z.string().nullable().optional(),
  target: z.enum(["preview", "production"]).default("preview"),
  git_branch: z.string().optional(),
  metadata: z.record(z.string(), z.unknown()).optional(),
});
export type DeployWebRequest = z.infer<typeof deployWebRequestSchema>;

export const createCustomDomainRequestSchema = z.object({
  app_id: z.string(),
  domain: z
    .string()
    .min(1, "Domain name is required")
    .regex(
      /^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$/,
      "Please enter a valid domain name (e.g. app.example.com)",
    ),
});
export type CreateCustomDomainRequest = z.infer<
  typeof createCustomDomainRequestSchema
>;
