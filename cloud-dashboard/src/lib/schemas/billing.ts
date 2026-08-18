import { z } from "zod";

export const featureEntitlementsSchema = z.object({
  testflight_deployments: z.boolean().default(false),
  google_play_deployments: z.boolean().default(false),
  web_hosting: z.boolean().default(false),
  shorebird: z.boolean().default(false),
  workflows: z.boolean().default(false),
  priority_support: z.boolean().default(false),
});
export type FeatureEntitlements = z.infer<typeof featureEntitlementsSchema>;

export const overagePricingSchema = z.object({
  enabled: z.boolean().default(false),
  build_minute_cents: z.number().default(0),
  storage_gb_cents: z.number().default(0),
  bandwidth_gb_cents: z.number().default(0),
});
export type OveragePricing = z.infer<typeof overagePricingSchema>;

export const entitlementsSchema = z.object({
  max_projects: z.number().default(0),
  max_apps: z.number().default(0),
  max_seats: z.number().default(0),
  build_minutes_monthly: z.number().default(0),
  artifact_storage_gb: z.number().default(0),
  web_bandwidth_gb: z.number().default(0),
  features: featureEntitlementsSchema.optional(),
  overage: overagePricingSchema.optional(),
});
export type Entitlements = z.infer<typeof entitlementsSchema>;

export const enforcementDecisionSchema = z.enum([
  "allow",
  "warn",
  "soft_block",
  "hard_lock",
]);
export type EnforcementDecision = z.infer<typeof enforcementDecisionSchema>;

export const planResponseSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable().optional(),
  price_minor: z.number(),
  currency: z.string(),
  entitlements: entitlementsSchema,
  active: z.boolean(),
  created_at: z.string(),
});
export type PlanResponse = z.infer<typeof planResponseSchema>;

export const subscriptionResponseSchema = z.object({
  id: z.string(),
  organization_id: z.string(),
  plan_id: z.string(),
  plan_name: z.string(),
  status: z.enum(["trialing", "active", "past_due", "locked", "cancelled"]),
  trial_ends_at: z.string().nullable().optional(),
  activated_at: z.string().nullable().optional(),
  current_period_start: z.string(),
  current_period_end: z.string(),
  provider_customer_id: z.string().nullable().optional(),
  provider_subscription_id: z.string().nullable().optional(),
  created_at: z.string(),
  updated_at: z.string(),
});
export type SubscriptionResponse = z.infer<typeof subscriptionResponseSchema>;

export const subscribeRequestSchema = z.object({
  plan_id: z.string().min(1, "Plan ID is required"),
  provider: z.string().optional(),
  callback_url: z.string().optional(),
});
export type SubscribeRequest = z.infer<typeof subscribeRequestSchema>;

export const subscribeResponseSchema = z.object({
  subscription: subscriptionResponseSchema,
  authorization_url: z.string().nullable().optional(),
  reference: z.string().nullable().optional(),
});
export type SubscribeResponse = z.infer<typeof subscribeResponseSchema>;

export const cancelSubscriptionRequestSchema = z.object({
  reason: z.string().optional(),
  immediately: z.boolean().optional(),
});
export type CancelSubscriptionRequest = z.infer<
  typeof cancelSubscriptionRequestSchema
>;

export const invoiceLineItemSchema = z.object({
  description: z.string(),
  kind: z.enum(["base_plan", "overage"]),
  quantity: z.number(),
  unit_price_cents: z.number(),
  amount_cents: z.number(),
});
export type InvoiceLineItem = z.infer<typeof invoiceLineItemSchema>;

export const invoiceResponseSchema = z.object({
  id: z.string(),
  subscription_id: z.string(),
  organization_id: z.string(),
  amount_cents: z.number(),
  status: z.enum(["draft", "sent", "paid", "overdue", "void"]),
  due_date: z.string(),
  paid_at: z.string().nullable().optional(),
  provider_invoice_id: z.string().nullable().optional(),
  created_at: z.string(),
  line_items: z.array(invoiceLineItemSchema).default([]),
});
export type InvoiceResponse = z.infer<typeof invoiceResponseSchema>;

export const usageEnforcementSummarySchema = z.object({
  overall_decision: enforcementDecisionSchema.default("allow"),
  build_minutes_decision: enforcementDecisionSchema.default("allow"),
  storage_decision: enforcementDecisionSchema.default("allow"),
  bandwidth_decision: enforcementDecisionSchema.default("allow"),
});
export type UsageEnforcementSummary = z.infer<
  typeof usageEnforcementSummarySchema
>;

export const usageOverageSummarySchema = z.object({
  enabled: z.boolean().default(false),
  build_minutes_over: z.number().default(0),
  storage_gb_over: z.number().default(0),
  bandwidth_gb_over: z.number().default(0),
  build_minutes_cost_cents: z.number().default(0),
  storage_cost_cents: z.number().default(0),
  bandwidth_cost_cents: z.number().default(0),
  total_cost_cents: z.number().default(0),
});
export type UsageOverageSummary = z.infer<typeof usageOverageSummarySchema>;

export const usageSummaryResponseSchema = z.object({
  organization_id: z.string(),
  plan_name: z.string(),
  current_period_start: z.string(),
  current_period_end: z.string(),
  build_minutes_used: z.number(),
  build_minutes_limit: z.number(),
  artifact_storage_gb_used: z.number(),
  artifact_storage_gb_limit: z.number(),
  web_bandwidth_gb_used: z.number(),
  web_bandwidth_gb_limit: z.number(),
  deploy_count: z.number(),
  enforcement: usageEnforcementSummarySchema.default({
    overall_decision: "allow",
    build_minutes_decision: "allow",
    storage_decision: "allow",
    bandwidth_decision: "allow",
  }),
  overage: usageOverageSummarySchema.default({
    enabled: false,
    build_minutes_over: 0,
    storage_gb_over: 0,
    bandwidth_gb_over: 0,
    build_minutes_cost_cents: 0,
    storage_cost_cents: 0,
    bandwidth_cost_cents: 0,
    total_cost_cents: 0,
  }),
});
export type UsageSummaryResponse = z.infer<typeof usageSummaryResponseSchema>;
