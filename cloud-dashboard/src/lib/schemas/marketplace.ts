import { z } from "zod";

export const templateResponseSchema = z.object({
  id: z.string(),
  organization_id: z.string(),
  name: z.string(),
  slug: z.string(),
  description: z.string().nullable().optional(),
  visibility: z.enum(["private", "public"]),
  status: z.enum(["draft", "published", "archived"]),
  is_free: z.boolean(),
  price_amount: z.number(),
  price_currency: z.string(),
  metadata: z.record(z.string(), z.unknown()).default({}),
  latest_version: z.string().nullable().optional(),
  versions_count: z.number().default(0),
  rating_count: z.number().default(0),
  rating_bayesian_milli: z.number().default(0),
  install_count: z.number().default(0),
  featured_type: z.enum(["none", "editorial", "paid"]).default("none"),
  is_featured: z.boolean().default(false),
  is_editorial_featured: z.boolean().default(false),
  is_paid_featured: z.boolean().default(false),
  featured_until: z.string().nullable().optional(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type TemplateResponse = z.infer<typeof templateResponseSchema>;

export const templateVersionSummarySchema = z.object({
  id: z.string(),
  version: z.string(),
  changelog: z.string().default(""),
  install_count: z.number().default(0),
  created_at: z.string(),
});
export type TemplateVersionSummaryResponse = z.infer<
  typeof templateVersionSummarySchema
>;

export const templateDetailResponseSchema = templateResponseSchema.extend({
  versions: z.array(templateVersionSummarySchema).default([]),
});
export type TemplateDetailResponse = z.infer<
  typeof templateDetailResponseSchema
>;

export const templateVersionResponseSchema = z.object({
  id: z.string(),
  template_id: z.string(),
  version: z.string(),
  changelog: z.string().default(""),
  manifest: z.record(z.string(), z.unknown()).default({}),
  readme: z.string().default(""),
  install_count: z.number().default(0),
  created_at: z.string(),
  updated_at: z.string(),
});
export type TemplateVersionResponse = z.infer<
  typeof templateVersionResponseSchema
>;

export const templateCreateRequestSchema = z.object({
  name: z.string().min(1, "Name is required"),
  description: z.string().optional(),
  visibility: z.enum(["private", "public"]).default("private"),
  is_free: z.boolean().default(true),
  price_amount: z.number().optional(),
  price_currency: z.string().default("usd"),
  metadata: z.record(z.string(), z.unknown()).optional(),
});
export type TemplateCreateRequest = z.infer<typeof templateCreateRequestSchema>;

export const templateUpdateRequestSchema = z.object({
  name: z.string().optional(),
  description: z.string().optional(),
  visibility: z.enum(["private", "public"]).optional(),
  status: z.enum(["draft", "published", "archived"]).optional(),
  is_free: z.boolean().optional(),
  price_amount: z.number().optional(),
  price_currency: z.string().optional(),
  metadata: z.record(z.string(), z.unknown()).optional(),
});
export type TemplateUpdateRequest = z.infer<typeof templateUpdateRequestSchema>;

export const templateVersionCreateRequestSchema = z.object({
  version: z.string().min(1, "Version is required"),
  changelog: z.string().optional(),
  manifest: z.record(z.string(), z.unknown()).optional(),
  readme: z.string().optional(),
});
export type TemplateVersionCreateRequest = z.infer<
  typeof templateVersionCreateRequestSchema
>;

export const purchaseTemplateRequestSchema = z.object({
  template_version_id: z.string().optional(),
  idempotency_key: z.string().optional(),
});
export type PurchaseTemplateRequest = z.infer<
  typeof purchaseTemplateRequestSchema
>;

export const purchaseResponseSchema = z.object({
  id: z.string(),
  buyer_organization_id: z.string(),
  template_id: z.string(),
  template_name: z.string(),
  template_version_id: z.string().nullable().optional(),
  seller_organization_id: z.string(),
  amount: z.number(),
  currency: z.string(),
  platform_fee: z.number(),
  seller_amount: z.number(),
  status: z.enum(["pending", "succeeded", "refunded", "failed"]),
  client_secret: z.string().nullable().optional(),
  created_at: z.string(),
});
export type PurchaseResponse = z.infer<typeof purchaseResponseSchema>;

export const refundPurchaseRequestSchema = z.object({
  reason: z.string().optional(),
});
export type RefundPurchaseRequest = z.infer<typeof refundPurchaseRequestSchema>;

export const refundResponseSchema = z.object({
  purchase_id: z.string(),
  stripe_refund_id: z.string(),
  amount: z.number(),
  currency: z.string(),
  status: z.string(),
});
export type RefundResponse = z.infer<typeof refundResponseSchema>;

export const reviewResponseSchema = z.object({
  id: z.string(),
  template_id: z.string(),
  buyer_organization_id: z.string(),
  rating: z.number().min(1).max(5),
  title: z.string().default(""),
  comment: z.string().default(""),
  status: z.enum(["published", "hidden", "archived"]),
  author_response: z.string().nullable().optional(),
  author_responded_at: z.string().nullable().optional(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type ReviewResponse = z.infer<typeof reviewResponseSchema>;

export const reviewCreateRequestSchema = z.object({
  rating: z.number().min(1).max(5),
  title: z.string().optional(),
  comment: z.string().optional(),
});
export type ReviewCreateRequest = z.infer<typeof reviewCreateRequestSchema>;

export const reviewAuthorReplyRequestSchema = z.object({
  response: z.string().min(1, "Response cannot be empty"),
});
export type ReviewAuthorReplyRequest = z.infer<
  typeof reviewAuthorReplyRequestSchema
>;

export const reviewReportRequestSchema = z.object({
  reason: z.string().min(1, "Reason is required"),
  details: z.string().optional(),
});
export type ReviewReportRequest = z.infer<typeof reviewReportRequestSchema>;

export const reviewReportResponseSchema = z.object({
  id: z.string(),
  review_id: z.string(),
  reporter_organization_id: z.string(),
  reason: z.string(),
  details: z.string(),
  status: z.string(),
  created_at: z.string(),
});
export type ReviewReportResponse = z.infer<typeof reviewReportResponseSchema>;
