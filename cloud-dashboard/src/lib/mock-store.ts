import { BuildStageResponse } from "./schemas/build";
import { ReleaseArtifact } from "./schemas/release";
import type { FrameworkId } from "./frameworks";

export interface MockUser {
  id: string;
  email: string;
  username: string;
  display_name: string | null;
  avatar_url: string | null;
  timezone: string;
}

export interface MockOrganization {
  id: string;
  name: string;
  slug: string;
  plan: string;
  role: string;
  billing_email?: string | null;
  created_at: string;
}

export interface MockMembership {
  id: string;
  organization_id: string;
  user_id: string;
  email: string;
  username: string;
  role: string;
  created_at: string;
}

export interface MockProject {
  id: string;
  organization_id: string;
  name: string;
  slug: string;
  description: string | null;
  created_at: string;
  updated_at: string;
}

export interface MockApp {
  id: string;
  project_id: string;
  organization_id: string;
  name: string;
  slug: string;
  framework: FrameworkId;
  platforms: string[];
  repository_url: string | null;
  default_branch: string;
  /** Extracted from the app's build artifact (iOS/Android launcher icon or web favicon). Null until a build has produced one. */
  icon_url?: string | null;
  latest_release?: string;
  crash_free_rate?: number;
  created_at: string;
  updated_at: string;
}

export interface MockUsageSummary {
  organization_id: string;
  plan_name: string;
  current_period_start: string;
  current_period_end: string;
  build_minutes_used: number;
  build_minutes_limit: number;
  artifact_storage_gb_used: number;
  artifact_storage_gb_limit: number;
  web_bandwidth_gb_used: number;
  web_bandwidth_gb_limit: number;
  deploy_count: number;
}

export interface MockEnvironment {
  id: string;
  app_id: string;
  organization_id: string;
  name: string;
  slug: string;
  build_profile?: string;
  flutter_version?: string | null;
  dart_version?: string | null;
  bloom_version?: string | null;
  flavor?: string | null;
  api_config: {
    env_vars: { key: string; value: string }[];
    feature_flags: { key: string; enabled: boolean }[];
  };
  created_at: string;
  updated_at?: string;
}

export interface MockSecret {
  id: string;
  environment_id: string;
  organization_id: string;
  key: string;
  value?: string; // encrypted/internal only in real backend
  is_json: boolean;
  version: number;
  history?: { version: number; updated_at: string }[];
  updated_at: string;
}

export interface MockSigningIdentity {
  id: string;
  organization_id: string;
  platform: "android" | "ios";
  name: string;
  kind: "keystore" | "certificate" | "provisioning_profile" | "api_key";
  material?: string;
  metadata: Record<string, unknown>;
  expires_at?: string | null;
  is_expiring: boolean;
  created_at: string;
}

export interface MockRelease {
  id: string;
  app_id: string;
  organization_id: string;
  version: string;
  build_number: number;
  commit: string;
  changelog: string;
  environment_id?: string | null;
  status:
    | "draft"
    | "pending_approval"
    | "approved"
    | "rolling_out"
    | "released"
    | "rolled_back"
    | "expired";
  platforms: string[];
  artifacts: ReleaseArtifact[];
  rollout_status: Record<string, unknown>;
  created_by_id: string;
  created_at: string;
  updated_at: string;
}

export interface MockDeployment {
  id: string;
  release_id?: string | null;
  artifact_id?: string | null;
  environment_id: string;
  organization_id: string;
  platform: "ios" | "android" | "web";
  target: string;
  status:
    | "pending"
    | "queued"
    | "running"
    | "processing"
    | "ready"
    | "live"
    | "failed"
    | "rolled_back";
  external_id?: string | null;
  external_url?: string | null;
  preview_image_url?: string | null;
  error_message?: string | null;
  started_at?: string | null;
  finished_at?: string | null;
  created_by_id: string;
  created_at: string;
  updated_at: string;
  // UI helpers
  release_version?: string;
  environment_name?: string;
  duration_seconds?: number;
}

export interface MockBuild {
  id: string;
  app_id: string;
  environment_id: string;
  organization_id: string;
  git_commit: string;
  git_branch: string;
  git_ref: string;
  status: "queued" | "running" | "success" | "failed" | "cancelled" | "pending";
  platform: string;
  build_profile: string;
  flutter_version: string;
  dart_version: string;
  bloom_version: string;
  flavor?: string | null;
  started_at?: string | null;
  finished_at?: string | null;
  logs_url?: string | null;
  stages: BuildStageResponse[];
  created_at: string;
  updated_at: string;
  // UI helper fields
  app_name?: string;
  build_number?: number;
  commit_message?: string;
  author?: string;
  commit_hash?: string;
  preview_url?: string | null;
  duration_seconds?: number;
}

export interface MockWebDeployment {
  id: string;
  app_id: string;
  environment_id: string;
  release_id: string | null;
  target: "preview" | "production";
  url: string;
  status: "deploying" | "live" | "failed" | "rolled_back";
  deployed_by_id: string;
  created_at: string;
}

export interface MockRequiredDnsRecord {
  record_type: string;
  host: string;
  value: string;
  purpose: string;
}

export interface MockCustomDomain {
  id: string;
  app_id: string;
  domain: string;
  verification_token: string;
  certificate_status: "pending" | "issuing" | "active" | "failed";
  certificate_expires_at?: string | null;
  verified_at?: string | null;
  failure_reason?: string | null;
  required_records: MockRequiredDnsRecord[];
}

export interface MockPlatformHealth {
  platform: string;
  target: string;
  crash_free_rate?: number | null;
  sessions?: number | null;
  crashes?: number | null;
  status: "healthy" | "warning" | "degraded" | "unknown";
}

export interface MockReleaseHealth {
  release_id: string;
  overall_crash_free_rate?: number | null;
  platforms: MockPlatformHealth[];
}

export interface MockEnvironmentStatus {
  environment: string;
  platform: string;
  release_id?: string | null;
  version?: string | null;
  build_number?: number | null;
  status: string;
  crash_free_rate?: number | null;
}

export interface MockAppStatus {
  app_id: string;
  environments: MockEnvironmentStatus[];
}

export interface MockApiToken {
  id: string;
  name: string;
  token?: string | null;
  scopes?: string[];
  expires_at?: string | null;
  organization_id?: string | null;
  last_used_at?: string | null;
  created_at: string;
}

export interface MockCredential {
  id: string;
  organization_id: string;
  provider:
    "apple" | "google_play" | "shorebird" | "github" | "gitlab" | "bitbucket";
  name: string;
  metadata: Record<string, unknown>;
  expires_at?: string | null;
  last_used_at?: string | null;
  created_at: string;
}

export interface MockGitConnection {
  id: string;
  organization_id: string;
  provider: "github" | "gitlab" | "bitbucket";
  installation_id: string;
  metadata: Record<string, unknown>;
  created_at: string;
}

export interface MockGitRepository {
  id: string;
  connection_id: string;
  full_name: string;
  default_branch: string;
  url: string;
}

export interface MockWorkflow {
  id: string;
  app_id: string;
  organization_id: string;
  name: string;
  slug: string;
  description: string | null;
  definition: string;
  is_active: boolean;
  created_by: string;
  created_at: string;
  updated_at: string;
}

export interface MockWorkflowRunStep {
  id: string;
  step_order: number;
  name: string;
  step_kind:
    | "test"
    | "build"
    | "deploy_preview"
    | "approval_gate"
    | "deploy_production"
    | "custom";
  status:
    "pending" | "running" | "blocked" | "completed" | "failed" | "skipped";
  requires_approval: boolean;
  started_at?: string | null;
  finished_at?: string | null;
  log_snippet?: string | null;
  metadata: Record<string, unknown>;
  created_at: string;
}

export interface MockWorkflowRun {
  id: string;
  workflow_id: string;
  organization_id: string;
  git_commit: string;
  git_branch: string;
  git_ref: string;
  status:
    "pending" | "running" | "blocked" | "success" | "failed" | "cancelled";
  trigger_event: string;
  started_at?: string | null;
  finished_at?: string | null;
  approved_by?: string | null;
  approved_at?: string | null;
  metadata: Record<string, unknown>;
  steps: MockWorkflowRunStep[];
  created_by: string;
  created_at: string;
  updated_at: string;
}

export interface MockAuditLogEntry {
  id: string;
  organization_id: string;
  actor: { name: string; email: string } | string;
  action: string;
  resource_type: string;
  resource_id: string;
  before_snapshot: Record<string, unknown> | null;
  after_snapshot: Record<string, unknown> | null;
  ip_address: string;
  created_at: string;
}

export interface MockPlan {
  id: string;
  name: string;
  description: string | null;
  price_minor: number;
  currency: string;
  entitlements: {
    max_projects: number;
    max_apps: number;
    max_seats: number;
    build_minutes_monthly: number;
    artifact_storage_gb: number;
    web_bandwidth_gb: number;
    features: {
      testflight_deployments: boolean;
      google_play_deployments: boolean;
      web_hosting: boolean;
      shorebird: boolean;
      workflows: boolean;
      priority_support: boolean;
    };
    overage: {
      enabled: boolean;
      build_minute_cents: number;
      storage_gb_cents: number;
      bandwidth_gb_cents: number;
    };
  };
  active: boolean;
  created_at: string;
}

export interface MockSubscription {
  id: string;
  organization_id: string;
  plan_id: string;
  plan_name: string;
  status: "trialing" | "active" | "past_due" | "locked" | "cancelled";
  trial_ends_at: string | null;
  activated_at: string | null;
  current_period_start: string;
  current_period_end: string;
  provider_customer_id: string | null;
  provider_subscription_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface MockSellerAccount {
  id: string;
  organization_id: string;
  stripe_account_id: string;
  payouts_enabled: boolean;
  charges_enabled: boolean;
  details_submitted: boolean;
  default_currency: string | null;
  last_payouts_checked_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface MockInvoiceLineItem {
  description: string;
  kind: "base_plan" | "overage";
  quantity: number;
  unit_price_cents: number;
  amount_cents: number;
}

export interface MockInvoice {
  id: string;
  subscription_id: string;
  organization_id: string;
  amount_cents: number;
  status: "draft" | "sent" | "paid" | "overdue" | "void";
  due_date: string;
  paid_at?: string | null;
  provider_invoice_id?: string | null;
  created_at: string;
  line_items: MockInvoiceLineItem[];
}

export interface MockTemplate {
  id: string;
  organization_id: string;
  name: string;
  slug: string;
  description: string | null;
  visibility: "private" | "public";
  status: "draft" | "published" | "archived";
  is_free: boolean;
  price_amount: number;
  price_currency: string;
  metadata: Record<string, unknown>;
  latest_version?: string | null;
  versions_count: number;
  rating_count: number;
  rating_bayesian_milli: number;
  install_count: number;
  featured_type: "none" | "editorial" | "paid";
  is_featured: boolean;
  is_editorial_featured: boolean;
  is_paid_featured: boolean;
  featured_until?: string | null;
  created_at: string;
  updated_at: string;
}

export interface MockTemplateVersion {
  id: string;
  template_id: string;
  version: string;
  changelog: string;
  manifest: Record<string, unknown>;
  readme: string;
  install_count: number;
  created_at: string;
  updated_at: string;
}

export interface MockPurchase {
  id: string;
  buyer_organization_id: string;
  template_id: string;
  template_name: string;
  template_version_id?: string | null;
  seller_organization_id: string;
  amount: number;
  currency: string;
  platform_fee: number;
  seller_amount: number;
  status: "pending" | "succeeded" | "refunded" | "failed";
  client_secret?: string | null;
  created_at: string;
}

export interface MockReview {
  id: string;
  template_id: string;
  buyer_organization_id: string;
  rating: number;
  title: string;
  comment: string;
  status: "published" | "hidden" | "archived";
  author_response?: string | null;
  author_responded_at?: string | null;
  created_at: string;
  updated_at: string;
}

export interface MockReviewReport {
  id: string;
  review_id: string;
  reporter_organization_id: string;
  reason: string;
  details: string;
  status: string;
  created_at: string;
}

class MockDataStore {
  public currentUser: MockUser = {
    id: "00000000-0000-0000-0000-000000000001",
    email: "dev@bloom.dev",
    username: "dev",
    display_name: "Bloom Developer",
    avatar_url: null,
    timezone: "UTC",
  };

  public usage: MockUsageSummary = {
    organization_id: "00000000-0000-0000-0000-000000000010",
    plan_name: "pro",
    current_period_start: new Date(Date.now() - 86400000 * 15).toISOString(),
    current_period_end: new Date(Date.now() + 86400000 * 15).toISOString(),
    build_minutes_used: 245,
    build_minutes_limit: 1000,
    artifact_storage_gb_used: 1.2,
    artifact_storage_gb_limit: 5.0,
    web_bandwidth_gb_used: 7.13,
    web_bandwidth_gb_limit: 50.0,
    deploy_count: 28,
  };

  public organizations: MockOrganization[] = [
    {
      id: "00000000-0000-0000-0000-000000000010",
      name: "Bloom Labs",
      slug: "bloom-labs",
      plan: "pro",
      role: "Owner",
      billing_email: "billing@bloom.dev",
      created_at: new Date(Date.now() - 86400000 * 30).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000011",
      name: "Acme Mobile",
      slug: "acme-mobile",
      plan: "free",
      role: "Developer",
      billing_email: "finance@acme.com",
      created_at: new Date(Date.now() - 86400000 * 10).toISOString(),
    },
  ];

  public memberships: MockMembership[] = [
    {
      id: "mem_001",
      organization_id: "00000000-0000-0000-0000-000000000010",
      user_id: "00000000-0000-0000-0000-000000000001",
      email: "dev@bloom.dev",
      username: "dev",
      role: "Owner",
      created_at: new Date(Date.now() - 86400000 * 30).toISOString(),
    },
    {
      id: "mem_002",
      organization_id: "00000000-0000-0000-0000-000000000010",
      user_id: "00000000-0000-0000-0000-000000000002",
      email: "chidi@bloom.dev",
      username: "chidi09",
      role: "Admin",
      created_at: new Date(Date.now() - 86400000 * 20).toISOString(),
    },
    {
      id: "mem_003",
      organization_id: "00000000-0000-0000-0000-000000000010",
      user_id: "00000000-0000-0000-0000-000000000003",
      email: "alex@partner.io",
      username: "alex_dev",
      role: "Developer",
      created_at: new Date(Date.now() - 86400000 * 5).toISOString(),
    },
  ];

  public projects: MockProject[] = [
    {
      id: "00000000-0000-0000-0000-000000000020",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "Mobile Suite",
      slug: "mobile-suite",
      description:
        "Core Bloom Framework mobile applications and companion tools",
      created_at: new Date(Date.now() - 86400000 * 25).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 2).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000021",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "Web Platforms",
      slug: "web-platforms",
      description: "Next-gen web hosting and dashboard portals",
      created_at: new Date(Date.now() - 86400000 * 15).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 1).toISOString(),
    },
  ];

  public apps: MockApp[] = [
    {
      id: "00000000-0000-0000-0000-000000000030",
      project_id: "00000000-0000-0000-0000-000000000020",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "bloom_wallet",
      slug: "bloom-wallet",
      framework: "bloom",
      platforms: ["ios", "android", "web"],
      repository_url: "https://github.com/bloom-labs/wallet",
      default_branch: "main",
      latest_release: "v1.4.2",
      crash_free_rate: 99.8,
      created_at: new Date(Date.now() - 86400000 * 20).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 1).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000031",
      project_id: "00000000-0000-0000-0000-000000000020",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "flutter_dashboard",
      slug: "flutter-dashboard",
      framework: "flutter",
      platforms: ["web", "android"],
      repository_url: "https://github.com/bloom-labs/analytics",
      default_branch: "main",
      latest_release: "v2.0.0-rc.1",
      crash_free_rate: 99.9,
      created_at: new Date(Date.now() - 86400000 * 12).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 2).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000032",
      project_id: "00000000-0000-0000-0000-000000000021",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "bloom_web_portal",
      slug: "bloom-web-portal",
      framework: "bloom",
      platforms: ["web"],
      repository_url: "https://github.com/bloom-labs/portal",
      default_branch: "main",
      latest_release: "v0.9.0",
      crash_free_rate: 100.0,
      created_at: new Date(Date.now() - 86400000 * 8).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 1).toISOString(),
    },
  ];

  public environments: MockEnvironment[] = [
    {
      id: "00000000-0000-0000-0000-000000000040",
      app_id: "00000000-0000-0000-0000-000000000030",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "Production",
      slug: "production",
      build_profile: "release",
      flutter_version: "3.27.0",
      dart_version: "3.6.0",
      bloom_version: "0.8.2",
      flavor: "prod",
      api_config: {
        env_vars: [
          { key: "API_URL", value: "https://api.bloom.dev" },
          { key: "REGION", value: "us-east-1" },
          { key: "STRIPE_PUBLISHABLE_KEY", value: "pk_live_••••••••" },
          { key: "SUPABASE_URL", value: "https://xzqrt.supabase.co" },
          { key: "SUPABASE_ANON_KEY", value: "ey••••••••" },
          { key: "SENTRY_DSN", value: "https://••••@o1.ingest.sentry.io/1" },
          { key: "POSTHOG_HOST", value: "https://app.posthog.com" },
          { key: "FIREBASE_PROJECT_ID", value: "bloom-prod-4f2a1" },
        ],
        feature_flags: [
          { key: "enable_biometrics", enabled: true },
          { key: "dark_mode_default", enabled: true },
        ],
      },
      created_at: new Date(Date.now() - 86400000 * 20).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 2).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000041",
      app_id: "00000000-0000-0000-0000-000000000030",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "Staging",
      slug: "staging",
      build_profile: "debug",
      flutter_version: "3.27.0",
      dart_version: "3.6.0",
      bloom_version: "0.8.2",
      flavor: "staging",
      api_config: {
        env_vars: [
          { key: "API_URL", value: "https://staging-api.bloom.dev" },
          { key: "DEBUG_LOGGING", value: "true" },
          { key: "STRIPE_TEST_SECRET_KEY", value: "sk_test_••••••••" },
          { key: "PAYSTACK_PUBLIC_KEY", value: "pk_test_••••••••" },
          { key: "TWILIO_ACCOUNT_SID", value: "AC••••••••" },
          { key: "MIXPANEL_TOKEN", value: "••••••••" },
        ],
        feature_flags: [
          { key: "enable_biometrics", enabled: false },
          { key: "beta_testing_hub", enabled: true },
        ],
      },
      created_at: new Date(Date.now() - 86400000 * 18).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 3).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000042",
      app_id: "00000000-0000-0000-0000-000000000031",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "Production",
      slug: "production",
      build_profile: "release",
      flutter_version: "3.27.0",
      dart_version: "3.6.0",
      api_config: {
        env_vars: [
          { key: "METRICS_ENDPOINT", value: "https://telemetry.bloom.dev" },
          { key: "SEGMENT_WRITE_KEY", value: "••••••••" },
          { key: "ALGOLIA_APP_ID", value: "BL00M9F2" },
          { key: "ALGOLIA_SEARCH_KEY", value: "••••••••" },
          { key: "SENDGRID_API_KEY", value: "SG.••••••••" },
        ],
        feature_flags: [{ key: "live_dashboards", enabled: true }],
      },
      created_at: new Date(Date.now() - 86400000 * 12).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 2).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000043",
      app_id: "00000000-0000-0000-0000-000000000032",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "Production",
      slug: "production",
      build_profile: "release",
      api_config: {
        env_vars: [
          { key: "PORTAL_API_BASE", value: "https://api.bloom.dev/portal" },
          { key: "CDN_HOST", value: "cdn.bloom.dev" },
          { key: "RESEND_API_KEY", value: "re_••••••••" },
          { key: "CLOUDINARY_CLOUD_NAME", value: "bloom-cloud" },
          { key: "OPENAI_API_KEY", value: "sk-••••••••" },
        ],
        feature_flags: [{ key: "new_pricing_page", enabled: true }],
      },
      created_at: new Date(Date.now() - 86400000 * 8).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 1).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000044",
      app_id: "00000000-0000-0000-0000-000000000032",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "Preview",
      slug: "preview",
      build_profile: "debug",
      api_config: {
        env_vars: [
          {
            key: "PORTAL_API_BASE",
            value: "https://staging-api.bloom.dev/portal",
          },
          { key: "PLAID_CLIENT_ID", value: "••••••••" },
          { key: "AUTH0_DOMAIN", value: "bloom-preview.auth0.com" },
        ],
        feature_flags: [{ key: "new_pricing_page", enabled: true }],
      },
      created_at: new Date(Date.now() - 86400000 * 7).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 1).toISOString(),
    },
  ];

  public secrets: MockSecret[] = [
    {
      id: "00000000-0000-0000-0000-000000000060",
      environment_id: "00000000-0000-0000-0000-000000000040",
      organization_id: "00000000-0000-0000-0000-000000000010",
      key: "STRIPE_SECRET_KEY",
      is_json: false,
      version: 3,
      history: [
        {
          version: 1,
          updated_at: new Date(Date.now() - 86400000 * 15).toISOString(),
        },
        {
          version: 2,
          updated_at: new Date(Date.now() - 86400000 * 5).toISOString(),
        },
        {
          version: 3,
          updated_at: new Date(Date.now() - 86400000 * 1).toISOString(),
        },
      ],
      updated_at: new Date(Date.now() - 86400000 * 1).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000061",
      environment_id: "00000000-0000-0000-0000-000000000040",
      organization_id: "00000000-0000-0000-0000-000000000010",
      key: "SENTRY_AUTH_TOKEN",
      is_json: false,
      version: 1,
      history: [
        {
          version: 1,
          updated_at: new Date(Date.now() - 86400000 * 18).toISOString(),
        },
      ],
      updated_at: new Date(Date.now() - 86400000 * 18).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000062",
      environment_id: "00000000-0000-0000-0000-000000000040",
      organization_id: "00000000-0000-0000-0000-000000000010",
      key: "FIREBASE_SERVICE_ACCOUNT",
      is_json: true,
      version: 2,
      history: [
        {
          version: 1,
          updated_at: new Date(Date.now() - 86400000 * 10).toISOString(),
        },
        {
          version: 2,
          updated_at: new Date(Date.now() - 86400000 * 4).toISOString(),
        },
      ],
      updated_at: new Date(Date.now() - 86400000 * 4).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000063",
      environment_id: "00000000-0000-0000-0000-000000000041",
      organization_id: "00000000-0000-0000-0000-000000000010",
      key: "STRIPE_TEST_SECRET_KEY",
      is_json: false,
      version: 1,
      history: [
        {
          version: 1,
          updated_at: new Date(Date.now() - 86400000 * 17).toISOString(),
        },
      ],
      updated_at: new Date(Date.now() - 86400000 * 17).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000064",
      environment_id: "00000000-0000-0000-0000-000000000042",
      organization_id: "00000000-0000-0000-0000-000000000010",
      key: "TELEMETRY_API_SECRET",
      is_json: false,
      version: 1,
      history: [
        {
          version: 1,
          updated_at: new Date(Date.now() - 86400000 * 10).toISOString(),
        },
      ],
      updated_at: new Date(Date.now() - 86400000 * 10).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000065",
      environment_id: "00000000-0000-0000-0000-000000000040",
      organization_id: "00000000-0000-0000-0000-000000000010",
      key: "PAYSTACK_SECRET_KEY",
      is_json: false,
      version: 1,
      history: [
        {
          version: 1,
          updated_at: new Date(Date.now() - 86400000 * 6).toISOString(),
        },
      ],
      updated_at: new Date(Date.now() - 86400000 * 6).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000066",
      environment_id: "00000000-0000-0000-0000-000000000040",
      organization_id: "00000000-0000-0000-0000-000000000010",
      key: "TWILIO_AUTH_TOKEN",
      is_json: false,
      version: 1,
      history: [
        {
          version: 1,
          updated_at: new Date(Date.now() - 86400000 * 9).toISOString(),
        },
      ],
      updated_at: new Date(Date.now() - 86400000 * 9).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000067",
      environment_id: "00000000-0000-0000-0000-000000000041",
      organization_id: "00000000-0000-0000-0000-000000000010",
      key: "RESEND_API_KEY",
      is_json: false,
      version: 1,
      history: [
        {
          version: 1,
          updated_at: new Date(Date.now() - 86400000 * 2).toISOString(),
        },
      ],
      updated_at: new Date(Date.now() - 86400000 * 2).toISOString(),
    },
  ];

  public signingIdentities: MockSigningIdentity[] = [
    {
      id: "00000000-0000-0000-0000-000000000070",
      organization_id: "00000000-0000-0000-0000-000000000010",
      platform: "android",
      name: "Bloom Production Keystore",
      kind: "keystore",
      metadata: {
        alias: "bloom-wallet-release",
      },
      expires_at: new Date(Date.now() + 86400000 * 365 * 5).toISOString(),
      is_expiring: false,
      created_at: new Date(Date.now() - 86400000 * 30).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000071",
      organization_id: "00000000-0000-0000-0000-000000000010",
      platform: "ios",
      name: "Apple Distribution Certificate 2026",
      kind: "certificate",
      metadata: {
        fingerprint: "E7:9F:42:A8:10:BC:88:51:99:32:04:1E:55:7A:B3:01",
      },
      expires_at: new Date(Date.now() + 86400000 * 20).toISOString(), // expiring in 20 days (warning test)
      is_expiring: true,
      created_at: new Date(Date.now() - 86400000 * 345).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000072",
      organization_id: "00000000-0000-0000-0000-000000000010",
      platform: "ios",
      name: "Bloom Wallet App Store Profile",
      kind: "provisioning_profile",
      metadata: {
        bundle_id: "dev.bloom.wallet",
        uuid: "57246542-96fe-1a63-e053-0824d011072a",
      },
      expires_at: new Date(Date.now() + 86400000 * 180).toISOString(),
      is_expiring: false,
      created_at: new Date(Date.now() - 86400000 * 25).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000073",
      organization_id: "00000000-0000-0000-0000-000000000010",
      platform: "ios",
      name: "App Store Connect API Key (CI Automation)",
      kind: "api_key",
      metadata: {
        key_id: "2X9R4HXF34",
        issuer_id: "69a6de75-7e0b-47e3-e053-5b8c7c11a4d1",
        team_id: "A1B2C3D4E5",
      },
      expires_at: null,
      is_expiring: false,
      created_at: new Date(Date.now() - 86400000 * 60).toISOString(),
    },
  ];

  public releases: MockRelease[] = [
    {
      id: "00000000-0000-0000-0000-000000000080",
      app_id: "00000000-0000-0000-0000-000000000030",
      organization_id: "00000000-0000-0000-0000-000000000010",
      version: "v1.4.2",
      build_number: 142,
      commit: "a4f89d1c92b842918e901f4871e8a9f029410ef1",
      changelog:
        "### Features\n- Added reactive signals state management for offline sync\n- Improved biometric authentication responsiveness\n\n### Bug Fixes\n- Resolved token expiration refresh loop in background workers",
      environment_id: "00000000-0000-0000-0000-000000000040",
      status: "released",
      platforms: ["ios", "android", "web"],
      artifacts: [
        {
          id: "art_001",
          build_id: "00000000-0000-0000-0000-000000000050",
          organization_id: "00000000-0000-0000-0000-000000000010",
          platform: "ios",
          kind: "ipa",
          file_name: "bloom-wallet-1.4.2.ipa",
          file_size: 42800000,
          checksum: "3f8e91...",
          version: "v1.4.2",
          build_number: 142,
          metadata: {},
          download_url: "https://storage.bloom.dev/artifacts/wallet-1.4.2.ipa",
          created_at: new Date(
            Date.now() - 1000 * 60 * 60 * 24 * 2,
          ).toISOString(),
        },
        {
          id: "art_002",
          build_id: "00000000-0000-0000-0000-000000000050",
          organization_id: "00000000-0000-0000-0000-000000000010",
          platform: "android",
          kind: "aab",
          file_name: "bloom-wallet-1.4.2.aab",
          file_size: 38200000,
          checksum: "8a1c44...",
          version: "v1.4.2",
          build_number: 142,
          metadata: {},
          download_url: "https://storage.bloom.dev/artifacts/wallet-1.4.2.aab",
          created_at: new Date(
            Date.now() - 1000 * 60 * 60 * 24 * 2,
          ).toISOString(),
        },
      ],
      rollout_status: {
        ios: 100,
        android: 100,
        web: 100,
      },
      created_by_id: "00000000-0000-0000-0000-000000000001",
      created_at: new Date(Date.now() - 86400000 * 2).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 1).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000081",
      app_id: "00000000-0000-0000-0000-000000000030",
      organization_id: "00000000-0000-0000-0000-000000000010",
      version: "v1.5.0-rc.1",
      build_number: 143,
      commit: "96b528a402a7210e7b4198129841bbce821094da",
      changelog:
        "### Release Candidate 1.5.0\n- Next-generation wallet redesign with AMOLED card surfaces\n- Shorebird OTA patch engine integration",
      environment_id: "00000000-0000-0000-0000-000000000041",
      status: "pending_approval",
      platforms: ["ios", "android"],
      artifacts: [],
      rollout_status: {
        ios: 0,
        android: 0,
      },
      created_by_id: "00000000-0000-0000-0000-000000000002",
      created_at: new Date(Date.now() - 1000 * 60 * 60 * 4).toISOString(),
      updated_at: new Date(Date.now() - 1000 * 60 * 60 * 4).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000082",
      app_id: "00000000-0000-0000-0000-000000000030",
      organization_id: "00000000-0000-0000-0000-000000000010",
      version: "v1.4.1",
      build_number: 140,
      commit: "71e8a9f029410ef1a4f89d1c92b842918e901f48",
      changelog: "Hotfix patch for network reconnects",
      environment_id: "00000000-0000-0000-0000-000000000040",
      status: "rolled_back",
      platforms: ["ios", "android"],
      artifacts: [],
      rollout_status: {
        ios: 0,
        android: 0,
      },
      created_by_id: "00000000-0000-0000-0000-000000000001",
      created_at: new Date(Date.now() - 86400000 * 10).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 8).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000083",
      app_id: "00000000-0000-0000-0000-000000000031",
      organization_id: "00000000-0000-0000-0000-000000000010",
      version: "v2.0.0-rc.1",
      build_number: 88,
      commit: "7bc32f9184019280194810294819028491028491",
      changelog: "Major Flutter 3.27 dashboard rewrite with responsive charts",
      environment_id: "00000000-0000-0000-0000-000000000042",
      status: "approved",
      platforms: ["web", "android"],
      artifacts: [],
      rollout_status: {
        web: 50,
        android: 25,
      },
      created_by_id: "00000000-0000-0000-0000-000000000001",
      created_at: new Date(Date.now() - 86400000 * 1).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 1).toISOString(),
    },
  ];

  public deployments: MockDeployment[] = [
    {
      id: "00000000-0000-0000-0000-000000000090",
      release_id: "00000000-0000-0000-0000-000000000080",
      artifact_id: "art_001",
      environment_id: "00000000-0000-0000-0000-000000000040",
      organization_id: "00000000-0000-0000-0000-000000000010",
      platform: "ios",
      target: "testflight",
      status: "live",
      external_id: "tf_build_142_99",
      external_url:
        "https://appstoreconnect.apple.com/apps/1684920/testflight/ios",
      preview_image_url: "https://picsum.photos/seed/bloom-dep-ios-142/400/800",
      error_message: null,
      started_at: new Date(Date.now() - 86400000 * 2).toISOString(),
      finished_at: new Date(
        Date.now() - 86400000 * 2 + 1000 * 180,
      ).toISOString(),
      created_by_id: "00000000-0000-0000-0000-000000000001",
      created_at: new Date(Date.now() - 86400000 * 2).toISOString(),
      updated_at: new Date(
        Date.now() - 86400000 * 2 + 1000 * 180,
      ).toISOString(),
      release_version: "v1.4.2",
      environment_name: "Production",
      duration_seconds: 180,
    },
    {
      id: "00000000-0000-0000-0000-000000000091",
      release_id: "00000000-0000-0000-0000-000000000080",
      artifact_id: "art_002",
      environment_id: "00000000-0000-0000-0000-000000000040",
      organization_id: "00000000-0000-0000-0000-000000000010",
      platform: "android",
      target: "internal",
      status: "live",
      external_id: "gp_track_internal_142",
      external_url:
        "https://play.google.com/console/developers/app/internal-testing",
      preview_image_url:
        "https://picsum.photos/seed/bloom-dep-android-142/400/800",
      error_message: null,
      started_at: new Date(Date.now() - 86400000 * 2).toISOString(),
      finished_at: new Date(
        Date.now() - 86400000 * 2 + 1000 * 120,
      ).toISOString(),
      created_by_id: "00000000-0000-0000-0000-000000000001",
      created_at: new Date(Date.now() - 86400000 * 2).toISOString(),
      updated_at: new Date(
        Date.now() - 86400000 * 2 + 1000 * 120,
      ).toISOString(),
      release_version: "v1.4.2",
      environment_name: "Production",
      duration_seconds: 120,
    },
    {
      id: "00000000-0000-0000-0000-000000000092",
      release_id: "00000000-0000-0000-0000-000000000080",
      artifact_id: null,
      environment_id: "00000000-0000-0000-0000-000000000040",
      organization_id: "00000000-0000-0000-0000-000000000010",
      platform: "web",
      target: "production",
      status: "live",
      external_id: "wh_deploy_wallet_prod",
      external_url: "https://wallet.bloom.dev",
      preview_image_url: "https://picsum.photos/seed/bloom-dep-web-142/800/500",
      error_message: null,
      started_at: new Date(Date.now() - 86400000 * 2).toISOString(),
      finished_at: new Date(
        Date.now() - 86400000 * 2 + 1000 * 45,
      ).toISOString(),
      created_by_id: "00000000-0000-0000-0000-000000000001",
      created_at: new Date(Date.now() - 86400000 * 2).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 2 + 1000 * 45).toISOString(),
      release_version: "v1.4.2",
      environment_name: "Production",
      duration_seconds: 45,
    },
    {
      id: "00000000-0000-0000-0000-000000000093",
      release_id: "00000000-0000-0000-0000-000000000081",
      artifact_id: null,
      environment_id: "00000000-0000-0000-0000-000000000041",
      organization_id: "00000000-0000-0000-0000-000000000010",
      platform: "ios",
      target: "testflight",
      status: "processing",
      external_id: "tf_build_143_01",
      external_url:
        "https://appstoreconnect.apple.com/apps/1684920/testflight/ios",
      preview_image_url: null,
      error_message: null,
      started_at: new Date(Date.now() - 1000 * 60 * 15).toISOString(),
      finished_at: null,
      created_by_id: "00000000-0000-0000-0000-000000000002",
      created_at: new Date(Date.now() - 1000 * 60 * 15).toISOString(),
      updated_at: new Date(Date.now() - 1000 * 60 * 10).toISOString(),
      release_version: "v1.5.0-rc.1",
      environment_name: "Staging",
      duration_seconds: 900,
    },
  ];

  public builds: MockBuild[] = [
    {
      id: "00000000-0000-0000-0000-000000000050",
      app_id: "00000000-0000-0000-0000-000000000030",
      environment_id: "00000000-0000-0000-0000-000000000040",
      organization_id: "00000000-0000-0000-0000-000000000010",
      git_commit: "a4f89d1c92b842918e901f4871e8a9f029410ef1",
      git_branch: "main",
      git_ref: "refs/heads/main",
      status: "success",
      platform: "all",
      build_profile: "release",
      flutter_version: "3.27.0",
      dart_version: "3.6.0",
      bloom_version: "0.8.2",
      flavor: null,
      started_at: new Date(Date.now() - 1000 * 60 * 20).toISOString(),
      finished_at: new Date(Date.now() - 1000 * 60 * 18).toISOString(),
      logs_url: "logs/builds/bld_101.log",
      stages: [
        {
          stage: "checkout",
          status: "completed",
          started_at: new Date(Date.now() - 1000 * 60 * 20).toISOString(),
          finished_at: new Date(Date.now() - 1000 * 60 * 19.8).toISOString(),
          log_snippet: "Cloning repository...\nChecked out main (a4f89d1)",
        },
        {
          stage: "setup_env",
          status: "completed",
          started_at: new Date(Date.now() - 1000 * 60 * 19.8).toISOString(),
          finished_at: new Date(Date.now() - 1000 * 60 * 19.2).toISOString(),
          log_snippet: "Setting up Flutter 3.27.0 & Dart 3.6.0",
        },
        {
          stage: "install_deps",
          status: "completed",
          started_at: new Date(Date.now() - 1000 * 60 * 19.2).toISOString(),
          finished_at: new Date(Date.now() - 1000 * 60 * 18.7).toISOString(),
          log_snippet:
            "Resolving dependencies with bloom pub get... 42 packages resolved.",
        },
        {
          stage: "compile",
          status: "completed",
          started_at: new Date(Date.now() - 1000 * 60 * 18.7).toISOString(),
          finished_at: new Date(Date.now() - 1000 * 60 * 18.1).toISOString(),
          log_snippet:
            "Compiling targets (iOS, Android, Web)... Generated IPA, APK, and WASM web bundle.",
        },
        {
          stage: "artifact_upload",
          status: "completed",
          started_at: new Date(Date.now() - 1000 * 60 * 18.1).toISOString(),
          finished_at: new Date(Date.now() - 1000 * 60 * 18).toISOString(),
          log_snippet:
            "Uploaded 3 artifacts to Bloom Cloud storage. Build complete in 120s.",
        },
      ],
      created_at: new Date(Date.now() - 1000 * 60 * 20).toISOString(),
      updated_at: new Date(Date.now() - 1000 * 60 * 18).toISOString(),
      app_name: "bloom_wallet",
      build_number: 142,
      commit_message:
        "feat(mobile): add signals reactive state and offline sync queue",
      author: "chidi09",
      commit_hash: "a4f89d1",
      preview_url: "wallet.bloom.dev",
      duration_seconds: 120,
    },
    {
      id: "00000000-0000-0000-0000-000000000051",
      app_id: "00000000-0000-0000-0000-000000000030",
      environment_id: "00000000-0000-0000-0000-000000000041",
      organization_id: "00000000-0000-0000-0000-000000000010",
      git_commit: "96b528a402a7210e7b4198129841bbce821094da",
      git_branch: "fix/auth-flow",
      git_ref: "refs/heads/fix/auth-flow",
      status: "running",
      platform: "ios",
      build_profile: "debug",
      flutter_version: "3.27.0",
      dart_version: "3.6.0",
      bloom_version: "0.8.2",
      flavor: null,
      started_at: new Date(Date.now() - 1000 * 45).toISOString(),
      finished_at: null,
      logs_url: null,
      stages: [
        {
          stage: "checkout",
          status: "completed",
          started_at: new Date(Date.now() - 1000 * 45).toISOString(),
          finished_at: new Date(Date.now() - 1000 * 40).toISOString(),
          log_snippet: "Checked out fix/auth-flow (96b528a)",
        },
        {
          stage: "setup_env",
          status: "completed",
          started_at: new Date(Date.now() - 1000 * 40).toISOString(),
          finished_at: new Date(Date.now() - 1000 * 30).toISOString(),
          log_snippet: "Loaded iOS build tools and provisioning profile",
        },
        {
          stage: "compile",
          status: "running",
          started_at: new Date(Date.now() - 1000 * 30).toISOString(),
          finished_at: null,
          log_snippet: "Running flutter build ios --debug --no-codesign...",
        },
      ],
      created_at: new Date(Date.now() - 1000 * 45).toISOString(),
      updated_at: new Date(Date.now() - 1000 * 10).toISOString(),
      app_name: "bloom_wallet",
      build_number: 143,
      commit_message: "fix(auth): update session token refresh retry handler",
      author: "chidi09",
      commit_hash: "96b528a",
      preview_url: null,
      duration_seconds: 45,
    },
    {
      id: "00000000-0000-0000-0000-000000000052",
      app_id: "00000000-0000-0000-0000-000000000031",
      environment_id: "00000000-0000-0000-0000-000000000042",
      organization_id: "00000000-0000-0000-0000-000000000010",
      git_commit: "7bc32f918401928019481029481029481028491",
      git_branch: "feat/charts",
      git_ref: "refs/heads/feat/charts",
      status: "success",
      platform: "web",
      build_profile: "release",
      flutter_version: "3.27.0",
      dart_version: "3.6.0",
      bloom_version: "0.8.2",
      flavor: null,
      started_at: new Date(Date.now() - 1000 * 60 * 120).toISOString(),
      finished_at: new Date(Date.now() - 1000 * 60 * 118).toISOString(),
      logs_url: "logs/builds/bld_103.log",
      stages: [
        {
          stage: "checkout",
          status: "completed",
          started_at: new Date(Date.now() - 1000 * 60 * 120).toISOString(),
          finished_at: new Date(Date.now() - 1000 * 60 * 119.5).toISOString(),
          log_snippet: "Checked out feat/charts",
        },
        {
          stage: "compile",
          status: "completed",
          started_at: new Date(Date.now() - 1000 * 60 * 119.5).toISOString(),
          finished_at: new Date(Date.now() - 1000 * 60 * 118.2).toISOString(),
          log_snippet: "Building Flutter Web release artifact...",
        },
        {
          stage: "artifact_upload",
          status: "completed",
          started_at: new Date(Date.now() - 1000 * 60 * 118.2).toISOString(),
          finished_at: new Date(Date.now() - 1000 * 60 * 118).toISOString(),
          log_snippet: "Deployed to preview environment",
        },
      ],
      created_at: new Date(Date.now() - 1000 * 60 * 120).toISOString(),
      updated_at: new Date(Date.now() - 1000 * 60 * 118).toISOString(),
      app_name: "flutter_dashboard",
      build_number: 88,
      commit_message:
        "fix(web): improve chart rendering performance and memory allocation",
      author: "dev",
      commit_hash: "7bc32f9",
      preview_url: "analytics.bloom.dev",
      duration_seconds: 90,
    },
    {
      id: "00000000-0000-0000-0000-000000000053",
      app_id: "00000000-0000-0000-0000-000000000030",
      environment_id: "00000000-0000-0000-0000-000000000040",
      organization_id: "00000000-0000-0000-0000-000000000010",
      git_commit: "5e1029ab48f72019481029481029481028491a",
      git_branch: "main",
      git_ref: "refs/heads/main",
      status: "failed",
      platform: "android",
      build_profile: "release",
      flutter_version: "3.27.0",
      dart_version: "3.6.0",
      bloom_version: "0.8.2",
      flavor: null,
      started_at: new Date(Date.now() - 86400000 * 1).toISOString(),
      finished_at: new Date(
        Date.now() - 86400000 * 1 + 1000 * 60 * 2,
      ).toISOString(),
      logs_url: "logs/builds/bld_099.log",
      stages: [
        {
          stage: "checkout",
          status: "completed",
          started_at: new Date(Date.now() - 86400000 * 1).toISOString(),
          finished_at: new Date(
            Date.now() - 86400000 * 1 + 1000 * 15,
          ).toISOString(),
          log_snippet: "Checked out main (5e1029a)",
        },
        {
          stage: "install_deps",
          status: "completed",
          started_at: new Date(
            Date.now() - 86400000 * 1 + 1000 * 15,
          ).toISOString(),
          finished_at: new Date(
            Date.now() - 86400000 * 1 + 1000 * 45,
          ).toISOString(),
          log_snippet: "Resolving dependencies... 44 packages resolved.",
        },
        {
          stage: "compile",
          status: "failed",
          started_at: new Date(
            Date.now() - 86400000 * 1 + 1000 * 45,
          ).toISOString(),
          finished_at: new Date(
            Date.now() - 86400000 * 1 + 1000 * 120,
          ).toISOString(),
          log_snippet:
            "FAILURE: Build failed with an exception.\n> Task :app:compileFlutterBuildRelease FAILED\nExecution failed: signing config 'release' not found for keystore alias 'bloom-wallet-release'.",
        },
      ],
      created_at: new Date(Date.now() - 86400000 * 1).toISOString(),
      updated_at: new Date(
        Date.now() - 86400000 * 1 + 1000 * 120,
      ).toISOString(),
      app_name: "bloom_wallet",
      build_number: 141,
      commit_message: "chore(android): bump target SDK to 35",
      author: "alex_dev",
      commit_hash: "5e1029a",
      preview_url: null,
      duration_seconds: 120,
    },
    {
      id: "00000000-0000-0000-0000-000000000054",
      app_id: "00000000-0000-0000-0000-000000000030",
      environment_id: "00000000-0000-0000-0000-000000000041",
      organization_id: "00000000-0000-0000-0000-000000000010",
      git_commit: "c81f4e29018abf72910294810294810294810ff",
      git_branch: "chore/deps-bump",
      git_ref: "refs/heads/chore/deps-bump",
      status: "cancelled",
      platform: "all",
      build_profile: "debug",
      flutter_version: "3.27.0",
      dart_version: "3.6.0",
      bloom_version: "0.8.2",
      flavor: null,
      started_at: new Date(Date.now() - 86400000 * 3).toISOString(),
      finished_at: new Date(
        Date.now() - 86400000 * 3 + 1000 * 20,
      ).toISOString(),
      logs_url: null,
      stages: [
        {
          stage: "checkout",
          status: "completed",
          started_at: new Date(Date.now() - 86400000 * 3).toISOString(),
          finished_at: new Date(
            Date.now() - 86400000 * 3 + 1000 * 12,
          ).toISOString(),
          log_snippet: "Checked out chore/deps-bump (c81f4e2)",
        },
        {
          stage: "setup_env",
          status: "cancelled",
          started_at: new Date(
            Date.now() - 86400000 * 3 + 1000 * 12,
          ).toISOString(),
          finished_at: new Date(
            Date.now() - 86400000 * 3 + 1000 * 20,
          ).toISOString(),
          log_snippet: "Build cancelled by chidi09.",
        },
      ],
      created_at: new Date(Date.now() - 86400000 * 3).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 3 + 1000 * 20).toISOString(),
      app_name: "bloom_wallet",
      build_number: 139,
      commit_message: "chore(deps): bump signals & shorebird packages",
      author: "chidi09",
      commit_hash: "c81f4e2",
      preview_url: null,
      duration_seconds: 20,
    },
    {
      id: "00000000-0000-0000-0000-000000000055",
      app_id: "00000000-0000-0000-0000-000000000031",
      environment_id: "00000000-0000-0000-0000-000000000042",
      organization_id: "00000000-0000-0000-0000-000000000010",
      git_commit: "1a2b3c4d5e6f7089abcdef1234567890abcdef12",
      git_branch: "main",
      git_ref: "refs/heads/main",
      status: "queued",
      platform: "web",
      build_profile: "release",
      flutter_version: "3.27.0",
      dart_version: "3.6.0",
      bloom_version: "0.8.2",
      flavor: null,
      started_at: null,
      finished_at: null,
      logs_url: null,
      stages: [],
      created_at: new Date(Date.now() - 1000 * 30).toISOString(),
      updated_at: new Date(Date.now() - 1000 * 30).toISOString(),
      app_name: "flutter_dashboard",
      build_number: 89,
      commit_message: "docs: update README with new chart API examples",
      author: "dev",
      commit_hash: "1a2b3c4",
      preview_url: null,
      duration_seconds: 0,
    },
  ];

  public registerUser(email: string, username: string): MockUser {
    this.currentUser = {
      id: `usr_${Date.now()}`,
      email,
      username,
      display_name: username,
      avatar_url: null,
      timezone: "UTC",
    };
    return this.currentUser;
  }

  // Organizations
  public createOrganization(name: string): MockOrganization {
    const slug = name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/(^-|-$)/g, "");
    const id = `00000000-0000-0000-0000-${Math.random().toString(16).slice(2, 14).padEnd(12, "0")}`;
    const org: MockOrganization = {
      id,
      name,
      slug: slug || `org-${Date.now()}`,
      plan: "free",
      role: "Owner",
      billing_email: `billing@${slug || "org"}.dev`,
      created_at: new Date().toISOString(),
    };
    this.organizations.unshift(org);
    this.memberships.unshift({
      id: `mem_${Date.now()}`,
      organization_id: org.id,
      user_id: this.currentUser.id,
      email: this.currentUser.email,
      username: this.currentUser.username,
      role: "Owner",
      created_at: new Date().toISOString(),
    });
    return org;
  }

  public getOrganization(id: string): MockOrganization | undefined {
    return this.organizations.find((o) => o.id === id || o.slug === id);
  }

  public updateOrganization(
    id: string,
    data: { name?: string; billing_email?: string },
  ): MockOrganization | null {
    const org = this.organizations.find((o) => o.id === id || o.slug === id);
    if (!org) return null;
    if (data.name !== undefined) {
      org.name = data.name;
      org.slug = data.name
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/(^-|-$)/g, "");
    }
    if (data.billing_email !== undefined)
      org.billing_email = data.billing_email;
    return org;
  }

  public deleteOrganization(id: string): boolean {
    const idx = this.organizations.findIndex(
      (o) => o.id === id || o.slug === id,
    );
    if (idx === -1) return false;
    const orgId = this.organizations[idx].id;
    this.organizations.splice(idx, 1);
    this.memberships = this.memberships.filter(
      (m) => m.organization_id !== orgId,
    );
    this.projects = this.projects.filter((p) => p.organization_id !== orgId);
    this.apps = this.apps.filter((a) => a.organization_id !== orgId);
    return true;
  }

  // Memberships
  public getMembers(orgId: string): MockMembership[] {
    return this.memberships.filter((m) => m.organization_id === orgId);
  }

  public inviteMember(
    orgId: string,
    email: string,
    role: string,
  ): MockMembership {
    const username = email.split("@")[0] || "member";
    const mem: MockMembership = {
      id: `mem_${Date.now()}`,
      organization_id: orgId,
      user_id: `usr_${Date.now()}`,
      email,
      username,
      role,
      created_at: new Date().toISOString(),
    };
    this.memberships.push(mem);
    return mem;
  }

  public changeMemberRole(
    orgId: string,
    memberId: string,
    role: string,
  ): MockMembership | null {
    const mem = this.memberships.find(
      (m) =>
        m.organization_id === orgId &&
        (m.id === memberId || m.user_id === memberId),
    );
    if (!mem) return null;
    mem.role = role;
    return mem;
  }

  public removeMember(orgId: string, memberId: string): boolean {
    const idx = this.memberships.findIndex(
      (m) =>
        m.organization_id === orgId &&
        (m.id === memberId || m.user_id === memberId),
    );
    if (idx === -1) return false;
    this.memberships.splice(idx, 1);
    return true;
  }

  // Projects
  public createProject(
    orgId: string,
    name: string,
    description?: string,
  ): MockProject {
    const slug = name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/(^-|-$)/g, "");
    const id = `00000000-0000-0000-0000-${Math.random().toString(16).slice(2, 14).padEnd(12, "0")}`;
    const project: MockProject = {
      id,
      organization_id: orgId,
      name,
      slug: slug || `prj-${Date.now()}`,
      description: description ?? null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    this.projects.unshift(project);
    return project;
  }

  public getProject(id: string): MockProject | undefined {
    return this.projects.find((p) => p.id === id || p.slug === id);
  }

  public updateProject(
    id: string,
    data: { name?: string; description?: string | null },
  ): MockProject | null {
    const prj = this.projects.find((p) => p.id === id || p.slug === id);
    if (!prj) return null;
    if (data.name !== undefined) {
      prj.name = data.name;
      prj.slug = data.name
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/(^-|-$)/g, "");
    }
    if (data.description !== undefined) prj.description = data.description;
    prj.updated_at = new Date().toISOString();
    return prj;
  }

  public deleteProject(id: string): boolean {
    const idx = this.projects.findIndex((p) => p.id === id || p.slug === id);
    if (idx === -1) return false;
    const prjId = this.projects[idx].id;
    this.projects.splice(idx, 1);
    this.apps = this.apps.filter((a) => a.project_id !== prjId);
    return true;
  }

  // Apps
  public createApp(
    projectId: string,
    orgId: string,
    name: string,
    repositoryUrl?: string,
    defaultBranch: string = "main",
    framework: FrameworkId = "bloom",
    platforms: string[] = ["ios", "android", "web"],
  ): MockApp {
    const slug = name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/(^-|-$)/g, "");
    const id = `00000000-0000-0000-0000-${Math.random().toString(16).slice(2, 14).padEnd(12, "0")}`;
    const app: MockApp = {
      id,
      project_id: projectId,
      organization_id: orgId,
      name,
      slug: slug || `app-${Date.now()}`,
      framework,
      platforms,
      repository_url: repositoryUrl ?? null,
      default_branch: defaultBranch,
      latest_release: "v0.1.0",
      crash_free_rate: 100.0,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    this.apps.unshift(app);

    // Auto-create Production environment for convenience
    this.createEnvironment(app.id, orgId, "Production", "production");
    return app;
  }

  public linkApp(projectSlug: string, appSlug: string): MockApp {
    const project =
      this.projects.find(
        (p) => p.slug === projectSlug || p.id === projectSlug,
      ) || this.projects[0];
    const existing = this.apps.find((a) => a.slug === appSlug);
    if (existing) return existing;
    return this.createApp(
      project.id,
      project.organization_id,
      appSlug,
      `https://github.com/bloom-labs/${appSlug}`,
    );
  }

  public getApp(id: string): MockApp | undefined {
    return this.apps.find((a) => a.id === id || a.slug === id);
  }

  public updateApp(
    id: string,
    data: {
      name?: string;
      repository_url?: string | null;
      default_branch?: string;
    },
  ): MockApp | null {
    const app = this.apps.find((a) => a.id === id || a.slug === id);
    if (!app) return null;
    if (data.name !== undefined) {
      app.name = data.name;
      app.slug = data.name
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/(^-|-$)/g, "");
    }
    if (data.repository_url !== undefined)
      app.repository_url = data.repository_url;
    if (data.default_branch !== undefined)
      app.default_branch = data.default_branch;
    app.updated_at = new Date().toISOString();
    return app;
  }

  public deleteApp(id: string): boolean {
    const idx = this.apps.findIndex((a) => a.id === id || a.slug === id);
    if (idx === -1) return false;
    const appId = this.apps[idx].id;
    this.apps.splice(idx, 1);
    this.builds = this.builds.filter((b) => b.app_id !== appId);
    this.environments = this.environments.filter((e) => e.app_id !== appId);
    this.releases = this.releases.filter((r) => r.app_id !== appId);
    return true;
  }

  // Environments
  public createEnvironment(
    appId: string,
    orgId: string,
    name: string,
    slug: string,
    buildProfile: string = "release",
    apiConfig: {
      env_vars?: { key: string; value: string }[];
      feature_flags?: { key: string; enabled: boolean }[];
    } = {},
    sdkVersions: {
      flutter_version?: string | null;
      dart_version?: string | null;
      bloom_version?: string | null;
      flavor?: string | null;
    } = {},
  ): MockEnvironment {
    const id = `00000000-0000-0000-0000-${Math.random().toString(16).slice(2, 14).padEnd(12, "0")}`;
    const env: MockEnvironment = {
      id,
      app_id: appId,
      organization_id: orgId,
      name,
      slug,
      build_profile: buildProfile,
      flutter_version: sdkVersions.flutter_version ?? null,
      dart_version: sdkVersions.dart_version ?? null,
      bloom_version: sdkVersions.bloom_version ?? null,
      flavor: sdkVersions.flavor ?? null,
      api_config: {
        env_vars: apiConfig.env_vars ?? [],
        feature_flags: apiConfig.feature_flags ?? [],
      },
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    this.environments.unshift(env);
    return env;
  }

  public updateEnvironment(
    id: string,
    data: {
      name?: string;
      build_profile?: string;
      flutter_version?: string | null;
      dart_version?: string | null;
      bloom_version?: string | null;
      flavor?: string | null;
      api_config?: {
        env_vars?: { key: string; value: string }[];
        feature_flags?: { key: string; enabled: boolean }[];
      };
    },
  ): MockEnvironment | null {
    const env = this.environments.find((e) => e.id === id);
    if (!env) return null;
    if (data.name !== undefined) env.name = data.name;
    if (data.build_profile !== undefined)
      env.build_profile = data.build_profile;
    if (data.flutter_version !== undefined)
      env.flutter_version = data.flutter_version;
    if (data.dart_version !== undefined) env.dart_version = data.dart_version;
    if (data.bloom_version !== undefined)
      env.bloom_version = data.bloom_version;
    if (data.flavor !== undefined) env.flavor = data.flavor;
    if (data.api_config !== undefined) {
      env.api_config = {
        env_vars: data.api_config.env_vars ?? env.api_config.env_vars,
        feature_flags:
          data.api_config.feature_flags ?? env.api_config.feature_flags,
      };
    }
    env.updated_at = new Date().toISOString();
    return env;
  }

  public deleteEnvironment(id: string): boolean {
    const idx = this.environments.findIndex((e) => e.id === id);
    if (idx === -1) return false;
    this.environments.splice(idx, 1);
    this.secrets = this.secrets.filter((s) => s.environment_id !== id);
    return true;
  }

  // Secrets
  public getSecrets(environmentId: string): MockSecret[] {
    return this.secrets.filter((s) => s.environment_id === environmentId);
  }

  public createOrUpdateSecret(
    environmentId: string,
    orgId: string,
    key: string,
    value: string,
    isJson: boolean = false,
  ): MockSecret {
    const existing = this.secrets.find(
      (s) => s.environment_id === environmentId && s.key === key,
    );
    if (existing) {
      existing.is_json = isJson;
      existing.value = value;
      existing.version += 1;
      existing.updated_at = new Date().toISOString();
      if (!existing.history) existing.history = [];
      existing.history.unshift({
        version: existing.version,
        updated_at: existing.updated_at,
      });
      return existing;
    }

    const id = `00000000-0000-0000-0000-${Math.random().toString(16).slice(2, 14).padEnd(12, "0")}`;
    const newSec: MockSecret = {
      id,
      environment_id: environmentId,
      organization_id: orgId,
      key,
      value,
      is_json: isJson,
      version: 1,
      history: [{ version: 1, updated_at: new Date().toISOString() }],
      updated_at: new Date().toISOString(),
    };
    this.secrets.unshift(newSec);
    return newSec;
  }

  public updateSecret(
    id: string,
    value?: string,
    isJson?: boolean,
  ): MockSecret | null {
    const sec = this.secrets.find((s) => s.id === id);
    if (!sec) return null;
    if (value !== undefined) {
      sec.value = value;
      sec.version += 1;
      if (!sec.history) sec.history = [];
      sec.history.unshift({
        version: sec.version,
        updated_at: new Date().toISOString(),
      });
    }
    if (isJson !== undefined) sec.is_json = isJson;
    sec.updated_at = new Date().toISOString();
    return sec;
  }

  public rollbackSecret(id: string, targetVersion: number): MockSecret | null {
    const sec = this.secrets.find((s) => s.id === id);
    if (!sec) return null;
    sec.version = targetVersion;
    sec.updated_at = new Date().toISOString();
    if (!sec.history) sec.history = [];
    sec.history.unshift({
      version: targetVersion,
      updated_at: sec.updated_at,
    });
    return sec;
  }

  public deleteSecret(id: string): boolean {
    const idx = this.secrets.findIndex((s) => s.id === id);
    if (idx === -1) return false;
    this.secrets.splice(idx, 1);
    return true;
  }

  // Signing Identities
  public getSigningIdentities(orgId: string): MockSigningIdentity[] {
    return this.signingIdentities.filter(
      (s) => s.organization_id === orgId || !orgId,
    );
  }

  public createSigningIdentity(
    orgId: string,
    platform: "android" | "ios",
    name: string,
    kind: "keystore" | "certificate" | "provisioning_profile" | "api_key",
    material: string,
    metadata: Record<string, unknown>,
    expiresAt?: string | null,
  ): MockSigningIdentity {
    const id = `00000000-0000-0000-0000-${Math.random().toString(16).slice(2, 14).padEnd(12, "0")}`;
    const identity: MockSigningIdentity = {
      id,
      organization_id: orgId,
      platform,
      name,
      kind,
      material,
      metadata,
      expires_at: expiresAt ?? null,
      is_expiring: false,
      created_at: new Date().toISOString(),
    };
    this.signingIdentities.unshift(identity);
    return identity;
  }

  public getSigningIdentity(id: string): MockSigningIdentity | undefined {
    return this.signingIdentities.find((s) => s.id === id);
  }

  public deleteSigningIdentity(id: string): boolean {
    const idx = this.signingIdentities.findIndex((s) => s.id === id);
    if (idx === -1) return false;
    this.signingIdentities.splice(idx, 1);
    return true;
  }

  // Releases
  public getReleases(appId: string): MockRelease[] {
    return this.releases.filter((r) => r.app_id === appId);
  }

  public getRelease(id: string): MockRelease | undefined {
    return this.releases.find((r) => r.id === id);
  }

  public createRelease(
    appId: string,
    orgId: string,
    version: string,
    buildNumber: number,
    commit: string,
    changelog: string = "",
    environmentId?: string | null,
    platforms: string[] = ["ios", "android", "web"],
    artifactIds: string[] = [],
  ): MockRelease {
    const id = `00000000-0000-0000-0000-${Math.random().toString(16).slice(2, 14).padEnd(12, "0")}`;
    const rel: MockRelease = {
      id,
      app_id: appId,
      organization_id: orgId,
      version,
      build_number: buildNumber,
      commit,
      changelog,
      environment_id: environmentId ?? null,
      status: "pending_approval",
      platforms,
      artifacts: artifactIds.map((artId) => ({
        id: artId,
        build_id: `bld_${buildNumber}`,
        organization_id: orgId,
        platform: "ios",
        kind: "ipa",
        file_name: `app-${version}.ipa`,
        file_size: 42000000,
        checksum: "sha256...",
        version,
        build_number: buildNumber,
        metadata: {},
        download_url: null,
        created_at: new Date().toISOString(),
      })),
      rollout_status: {
        ios: 0,
        android: 0,
        web: 0,
      },
      created_by_id: this.currentUser.id,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    this.releases.unshift(rel);

    // Update app's latest_release
    const app = this.apps.find((a) => a.id === appId);
    if (app) app.latest_release = version;

    return rel;
  }

  public updateRelease(
    id: string,
    data: {
      changelog?: string;
      rollout_status?: Record<string, unknown>;
      status?: string;
    },
  ): MockRelease | null {
    const rel = this.releases.find((r) => r.id === id);
    if (!rel) return null;
    if (data.changelog !== undefined) rel.changelog = data.changelog;
    if (data.rollout_status !== undefined)
      rel.rollout_status = data.rollout_status;
    if (data.status !== undefined)
      rel.status = data.status as MockRelease["status"];
    rel.updated_at = new Date().toISOString();
    return rel;
  }

  public approveRelease(
    id: string,
    approved: boolean,
    _reason?: string,
  ): MockRelease | null {
    const rel = this.releases.find((r) => r.id === id);
    if (!rel) return null;
    rel.status = approved ? "approved" : "draft";
    rel.updated_at = new Date().toISOString();
    return rel;
  }

  public rollbackRelease(id: string, _reason?: string): MockRelease | null {
    const rel = this.releases.find((r) => r.id === id);
    if (!rel) return null;
    rel.status = "rolled_back";
    rel.updated_at = new Date().toISOString();
    return rel;
  }

  // Deployments
  public getDeployments(
    appId?: string,
    environmentId?: string,
    releaseId?: string,
  ): MockDeployment[] {
    let list = this.deployments;
    if (environmentId) {
      list = list.filter((d) => d.environment_id === environmentId);
    }
    if (releaseId) {
      list = list.filter((d) => d.release_id === releaseId);
    }
    if (appId) {
      // Find all environments of this app
      const envIds = new Set(
        this.environments.filter((e) => e.app_id === appId).map((e) => e.id),
      );
      list = list.filter((d) => envIds.has(d.environment_id));
    }
    return list;
  }

  public getDeployment(id: string): MockDeployment | undefined {
    return this.deployments.find((d) => d.id === id);
  }

  public createDeployment(
    orgId: string,
    environmentId: string,
    platform: "ios" | "android" | "web",
    target: string,
    releaseId?: string | null,
    artifactId?: string | null,
  ): MockDeployment {
    const id = `00000000-0000-0000-0000-${Math.random().toString(16).slice(2, 14).padEnd(12, "0")}`;
    const rel = releaseId
      ? this.releases.find((r) => r.id === releaseId)
      : null;
    const env = this.environments.find((e) => e.id === environmentId);

    const dep: MockDeployment = {
      id,
      release_id: releaseId ?? null,
      artifact_id: artifactId ?? null,
      environment_id: environmentId,
      organization_id: orgId,
      platform,
      target,
      status: "running",
      external_id: `${platform}_deploy_${Date.now()}`,
      external_url:
        platform === "web"
          ? "https://preview.bloom.dev"
          : platform === "ios"
            ? "https://appstoreconnect.apple.com"
            : "https://play.google.com/console",
      preview_image_url: null,
      error_message: null,
      started_at: new Date().toISOString(),
      finished_at: null,
      created_by_id: this.currentUser.id,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      release_version: rel?.version ?? "v1.0.0",
      environment_name: env?.name ?? "Production",
      duration_seconds: 30,
    };
    this.deployments.unshift(dep);
    return dep;
  }

  public rollbackDeployment(id: string): MockDeployment | null {
    const dep = this.deployments.find((d) => d.id === id);
    if (!dep) return null;
    dep.status = "rolled_back";
    dep.updated_at = new Date().toISOString();
    return dep;
  }

  // Builds
  public createBuild(
    appId: string,
    environmentId: string,
    platform: string,
    gitBranch?: string,
    gitCommit?: string,
  ): MockBuild {
    const app = this.apps.find((a) => a.id === appId);
    const branch = gitBranch || app?.default_branch || "main";
    const commit = gitCommit || Math.random().toString(36).slice(2, 9);
    const id = `00000000-0000-0000-0000-${Math.random().toString(16).slice(2, 14).padEnd(12, "0")}`;
    const buildCount = this.builds.filter((b) => b.app_id === appId).length;

    const build: MockBuild = {
      id,
      app_id: appId,
      environment_id: environmentId,
      organization_id:
        app?.organization_id || "00000000-0000-0000-0000-000000000010",
      git_commit: commit,
      git_branch: branch,
      git_ref: `refs/heads/${branch}`,
      status: "running",
      platform,
      build_profile: "release",
      flutter_version: "3.27.0",
      dart_version: "3.6.0",
      bloom_version: "0.8.2",
      flavor: null,
      started_at: new Date().toISOString(),
      finished_at: null,
      logs_url: null,
      stages: [
        {
          stage: "checkout",
          status: "completed",
          started_at: new Date().toISOString(),
          finished_at: new Date().toISOString(),
          log_snippet: `Checked out ${branch} (${commit})`,
        },
        {
          stage: "setup_env",
          status: "completed",
          started_at: new Date().toISOString(),
          finished_at: new Date().toISOString(),
          log_snippet: "Resolved environment dependencies",
        },
        {
          stage: "install_deps",
          status: "running",
          started_at: new Date().toISOString(),
          finished_at: null,
          log_snippet: "Running \"flutter pub get\" / \"bloom pub get\"...",
        },
        {
          stage: "compile",
          status: "pending",
          started_at: null,
          finished_at: null,
          log_snippet: null,
        },
        {
          stage: "artifact_upload",
          status: "pending",
          started_at: null,
          finished_at: null,
          log_snippet: null,
        },
      ],
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      app_name: app?.name ?? "app",
      build_number: buildCount + 1,
      commit_message: "Manual cloud build triggered from Bloom dashboard",
      author: this.currentUser.username,
      commit_hash: commit.slice(0, 7),
      preview_url: null,
      duration_seconds: 15,
    };
    this.builds.unshift(build);
    return build;
  }

  // Seconds a single build stage / workflow step takes to "complete" in the
  // simulation. Progression is derived lazily from elapsed wall-clock time
  // on every read, so it works without background timers and stays correct
  // across reloads, polling, or multiple tabs.
  private static readonly BUILD_STAGE_MS = 4000;
  private static readonly WORKFLOW_STEP_MS = 5000;

  private progressBuildInPlace(build: MockBuild): void {
    if (["success", "failed", "cancelled"].includes(build.status)) return;
    const stages = build.stages;
    for (let i = 0; i < stages.length; i++) {
      const stage = stages[i];
      if (["completed", "failed", "skipped"].includes(stage.status)) continue;
      if (stage.status === "pending") break;
      if (stage.status !== "running") break;

      const startedMs = stage.started_at
        ? new Date(stage.started_at).getTime()
        : Date.now();
      if (Date.now() - startedMs < MockDataStore.BUILD_STAGE_MS) break;

      const finishTime = new Date(startedMs + MockDataStore.BUILD_STAGE_MS);
      stage.status = "completed";
      stage.finished_at = finishTime.toISOString();
      if (!stage.log_snippet) {
        stage.log_snippet = `${stage.stage} completed successfully.`;
      }

      const next = stages[i + 1];
      if (next) {
        next.status = "running";
        next.started_at = finishTime.toISOString();
        next.log_snippet =
          next.log_snippet || `Running stage: ${next.stage}...`;
      } else {
        build.status = "success";
        build.finished_at = finishTime.toISOString();
        build.duration_seconds = build.started_at
          ? Math.round(
              (finishTime.getTime() - new Date(build.started_at).getTime()) /
                1000,
            )
          : build.duration_seconds;
      }
      build.updated_at = new Date().toISOString();
    }
  }

  private progressWorkflowRunInPlace(run: MockWorkflowRun): void {
    if (["success", "failed", "cancelled"].includes(run.status)) return;
    const steps = run.steps;
    for (let i = 0; i < steps.length; i++) {
      const step = steps[i];
      if (["completed", "failed", "skipped"].includes(step.status)) continue;
      if (step.status === "pending" || step.status === "blocked") break;
      if (step.status !== "running") break;

      if (step.step_kind === "approval_gate") {
        step.status = "blocked";
        step.log_snippet =
          "[APPROVAL REQUIRED] Execution paused at this gate. Awaiting a manual decision from an authorized Release Manager or Admin.";
        run.status = "blocked";
        run.updated_at = new Date().toISOString();
        break;
      }

      const startedMs = step.started_at
        ? new Date(step.started_at).getTime()
        : Date.now();
      if (Date.now() - startedMs < MockDataStore.WORKFLOW_STEP_MS) break;

      const finishTime = new Date(startedMs + MockDataStore.WORKFLOW_STEP_MS);
      step.status = "completed";
      step.finished_at = finishTime.toISOString();
      if (!step.log_snippet) {
        step.log_snippet = `${step.name} completed successfully.`;
      }

      const next = steps[i + 1];
      if (next) {
        next.started_at = finishTime.toISOString();
        if (next.step_kind === "approval_gate") {
          next.status = "blocked";
          next.log_snippet =
            "[APPROVAL REQUIRED] Execution paused at this gate. Awaiting a manual decision from an authorized Release Manager or Admin.";
          run.status = "blocked";
          run.updated_at = new Date().toISOString();
          break;
        }
        next.status = "running";
        next.log_snippet = next.log_snippet || `Running: ${next.name}...`;
      } else {
        run.status = "success";
        run.finished_at = finishTime.toISOString();
      }
      run.updated_at = new Date().toISOString();
    }
  }

  public getBuild(id: string): MockBuild | undefined {
    const build = this.builds.find((b) => b.id === id);
    if (build) this.progressBuildInPlace(build);
    return build;
  }

  public listBuilds(appId?: string): MockBuild[] {
    const results = appId
      ? this.builds.filter((b) => b.app_id === appId)
      : this.builds;
    for (const b of results) this.progressBuildInPlace(b);
    return results;
  }

  public cancelBuild(id: string): MockBuild | null {
    const b = this.builds.find((item) => item.id === id);
    if (!b) return null;
    b.status = "cancelled";
    b.finished_at = new Date().toISOString();
    b.updated_at = new Date().toISOString();
    return b;
  }

  // Web Hosting
  public webDeployments: MockWebDeployment[] = [
    {
      id: "webdep_001",
      app_id: "00000000-0000-0000-0000-000000000030",
      environment_id: "00000000-0000-0000-0000-000000000040",
      release_id: "rel_001",
      target: "production",
      url: "https://bloom-wallet-prod.bloom.site",
      status: "live",
      deployed_by_id: "00000000-0000-0000-0000-000000000001",
      created_at: new Date(Date.now() - 86400000 * 2).toISOString(),
    },
    {
      id: "webdep_002",
      app_id: "00000000-0000-0000-0000-000000000030",
      environment_id: "00000000-0000-0000-0000-000000000041",
      release_id: "rel_002",
      target: "preview",
      url: "https://bloom-wallet-feat-ux.preview.bloom.site",
      status: "live",
      deployed_by_id: "00000000-0000-0000-0000-000000000002",
      created_at: new Date(Date.now() - 3600000 * 5).toISOString(),
    },
    {
      id: "webdep_003",
      app_id: "00000000-0000-0000-0000-000000000030",
      environment_id: "00000000-0000-0000-0000-000000000040",
      release_id: "rel_003",
      target: "production",
      url: "https://bloom-wallet-v1-4-1.bloom.site",
      status: "rolled_back",
      deployed_by_id: "00000000-0000-0000-0000-000000000001",
      created_at: new Date(Date.now() - 86400000 * 10).toISOString(),
    },
    {
      id: "webdep_004",
      app_id: "00000000-0000-0000-0000-000000000032",
      environment_id: "00000000-0000-0000-0000-000000000040",
      release_id: null,
      target: "production",
      url: "https://portal.bloom.site",
      status: "live",
      deployed_by_id: "00000000-0000-0000-0000-000000000001",
      created_at: new Date(Date.now() - 86400000 * 4).toISOString(),
    },
  ];

  public customDomains: MockCustomDomain[] = [
    {
      id: "dom_001",
      app_id: "00000000-0000-0000-0000-000000000030",
      domain: "wallet.bloom.dev",
      verification_token: "bloom_verify_98f4e2a1b7c0",
      certificate_status: "active",
      certificate_expires_at: new Date(
        Date.now() + 86400000 * 85,
      ).toISOString(),
      verified_at: new Date(Date.now() - 86400000 * 20).toISOString(),
      failure_reason: null,
      required_records: [
        {
          record_type: "CNAME",
          host: "wallet",
          value: "cname.bloom.site",
          purpose: "Traffic routing & edge CDN",
        },
        {
          record_type: "TXT",
          host: "_bloom-challenge.wallet",
          value: "bloom_verify_98f4e2a1b7c0",
          purpose: "Domain ownership verification",
        },
      ],
    },
    {
      id: "dom_002",
      app_id: "00000000-0000-0000-0000-000000000030",
      domain: "app.bloomwallet.io",
      verification_token: "bloom_verify_42a8b9c1d0e3",
      certificate_status: "pending",
      certificate_expires_at: null,
      verified_at: null,
      failure_reason: null,
      required_records: [
        {
          record_type: "CNAME",
          host: "app",
          value: "cname.bloom.site",
          purpose: "Traffic routing & edge CDN",
        },
        {
          record_type: "TXT",
          host: "_bloom-challenge.app",
          value: "bloom_verify_42a8b9c1d0e3",
          purpose: "Domain ownership verification",
        },
      ],
    },
  ];

  public getWebDeployments(appId?: string): MockWebDeployment[] {
    if (!appId) return this.webDeployments;
    return this.webDeployments.filter((d) => d.app_id === appId);
  }

  public getWebDeployment(id: string): MockWebDeployment | undefined {
    return this.webDeployments.find((d) => d.id === id);
  }

  public createWebDeployment(
    appId: string,
    environmentId: string,
    artifactId: string,
    target: "preview" | "production",
    releaseId?: string | null,
    gitBranch?: string,
  ): MockWebDeployment {
    const id = `webdep_${Math.random().toString(16).slice(2, 10)}`;
    const branchSlug = (gitBranch || "main").replace(/[^a-zA-Z0-9-]/g, "-");
    const url =
      target === "production"
        ? `https://${appId.slice(0, 8)}.bloom.site`
        : `https://${appId.slice(0, 8)}-${branchSlug}.preview.bloom.site`;

    const dep: MockWebDeployment = {
      id,
      app_id: appId,
      environment_id: environmentId,
      release_id: releaseId ?? null,
      target,
      url,
      status: "live",
      deployed_by_id: this.currentUser.id,
      created_at: new Date().toISOString(),
    };
    this.webDeployments.unshift(dep);
    return dep;
  }

  public rollbackWebDeployment(id: string): MockWebDeployment | null {
    const dep = this.webDeployments.find((d) => d.id === id);
    if (!dep) return null;
    dep.status = "rolled_back";
    return dep;
  }

  public getCustomDomains(appId?: string): MockCustomDomain[] {
    if (!appId) return this.customDomains;
    return this.customDomains.filter((d) => d.app_id === appId);
  }

  public getCustomDomain(id: string): MockCustomDomain | undefined {
    return this.customDomains.find((d) => d.id === id);
  }

  public createCustomDomain(appId: string, domain: string): MockCustomDomain {
    const id = `dom_${Math.random().toString(16).slice(2, 10)}`;
    const token = `bloom_verify_${Math.random().toString(16).slice(2, 14)}`;
    const subHost = domain.split(".")[0] || "@";

    const customDomain: MockCustomDomain = {
      id,
      app_id: appId,
      domain,
      verification_token: token,
      certificate_status: "pending",
      certificate_expires_at: null,
      verified_at: null,
      failure_reason: null,
      required_records: [
        {
          record_type: "CNAME",
          host: subHost,
          value: "cname.bloom.site",
          purpose: "Traffic routing & edge CDN",
        },
        {
          record_type: "TXT",
          host: `_bloom-challenge.${subHost}`,
          value: token,
          purpose: "Domain ownership verification",
        },
      ],
    };
    this.customDomains.unshift(customDomain);
    return customDomain;
  }

  public verifyCustomDomain(id: string): MockCustomDomain | null {
    const dom = this.customDomains.find((d) => d.id === id);
    if (!dom) return null;
    dom.certificate_status = "active";
    dom.verified_at = new Date().toISOString();
    dom.certificate_expires_at = new Date(
      Date.now() + 86400000 * 90,
    ).toISOString();
    dom.failure_reason = null;
    return dom;
  }

  public deleteCustomDomain(id: string): boolean {
    const idx = this.customDomains.findIndex((d) => d.id === id);
    if (idx === -1) return false;
    this.customDomains.splice(idx, 1);
    return true;
  }

  // Observability
  public getAppStatus(appId: string): MockAppStatus {
    return {
      app_id: appId,
      environments: [
        {
          environment: "production",
          platform: "ios",
          release_id: "rel_001",
          version: "v1.4.2",
          build_number: 42,
          status: "healthy",
          crash_free_rate: 0.998,
        },
        {
          environment: "production",
          platform: "android",
          release_id: "rel_001",
          version: "v1.4.2",
          build_number: 42,
          status: "healthy",
          crash_free_rate: 0.996,
        },
        {
          environment: "production",
          platform: "web",
          release_id: "rel_001",
          version: "v1.4.2",
          build_number: 42,
          status: "healthy",
          crash_free_rate: 1.0,
        },
        {
          environment: "staging",
          platform: "ios",
          release_id: "rel_002",
          version: "v1.4.3-beta",
          build_number: 45,
          status: "healthy",
          crash_free_rate: 0.991,
        },
      ],
    };
  }

  public getAppHealth(_appId: string): MockReleaseHealth {
    return {
      release_id: "rel_latest",
      overall_crash_free_rate: 0.998,
      platforms: [
        {
          platform: "ios",
          target: "app_store",
          crash_free_rate: 0.998,
          sessions: 42580,
          crashes: 85,
          status: "healthy",
        },
        {
          platform: "android",
          target: "google_play",
          crash_free_rate: 0.996,
          sessions: 38920,
          crashes: 155,
          status: "healthy",
        },
        {
          platform: "web",
          target: "web_hosting",
          crash_free_rate: 1.0,
          sessions: 14200,
          crashes: 0,
          status: "healthy",
        },
      ],
    };
  }

  public getReleaseHealth(releaseId: string): MockReleaseHealth {
    return {
      release_id: releaseId,
      overall_crash_free_rate: 0.997,
      platforms: [
        {
          platform: "ios",
          target: "app_store",
          crash_free_rate: 0.998,
          sessions: 18200,
          crashes: 36,
          status: "healthy",
        },
        {
          platform: "android",
          target: "google_play",
          crash_free_rate: 0.995,
          sessions: 15400,
          crashes: 77,
          status: "healthy",
        },
      ],
    };
  }

  // API Tokens
  public apiTokens: MockApiToken[] = [
    {
      id: "tok_001",
      name: "CLI Token - MacBook Pro M3",
      scopes: ["*"],
      expires_at: null,
      organization_id: null,
      last_used_at: new Date(Date.now() - 3600000 * 2).toISOString(),
      created_at: new Date(Date.now() - 86400000 * 14).toISOString(),
    },
    {
      id: "tok_002",
      name: "GitHub Actions Deploy Key",
      scopes: ["builds:write", "deployments:write"],
      expires_at: new Date(Date.now() + 86400000 * 60).toISOString(),
      organization_id: "org-acme-corp",
      last_used_at: new Date(Date.now() - 86400000 * 1).toISOString(),
      created_at: new Date(Date.now() - 86400000 * 30).toISOString(),
    },
    {
      id: "tok_003",
      name: "Legacy CI Key (Expired)",
      scopes: ["builds:read"],
      expires_at: new Date(Date.now() - 86400000 * 5).toISOString(),
      organization_id: null,
      last_used_at: new Date(Date.now() - 86400000 * 10).toISOString(),
      created_at: new Date(Date.now() - 86400000 * 95).toISOString(),
    },
  ];

  public getApiTokens(): MockApiToken[] {
    return this.apiTokens;
  }

  public createApiToken(
    name: string,
    scopes?: string[],
    expires_in_days?: number | null,
    organization_id?: string | null,
  ): {
    tokenRecord: MockApiToken;
    rawToken: string;
  } {
    const id = `tok_${Math.random().toString(16).slice(2, 10)}`;
    const randomChars = Array.from({ length: 43 }, () =>
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".charAt(
        Math.floor(Math.random() * 64)
      )
    ).join("");
    const rawToken = `bloom_pat_${randomChars}`;
    const expires_at =
      expires_in_days && expires_in_days > 0
        ? new Date(Date.now() + expires_in_days * 86400000).toISOString()
        : null;
    const tokenRecord: MockApiToken = {
      id,
      name,
      token: rawToken,
      scopes: scopes && scopes.length > 0 ? scopes : ["*"],
      expires_at,
      organization_id: organization_id || null,
      last_used_at: null,
      created_at: new Date().toISOString(),
    };
    this.apiTokens.unshift(tokenRecord);
    return { tokenRecord, rawToken };
  }

  public revokeApiToken(id: string): boolean {
    const idx = this.apiTokens.findIndex((t) => t.id === id);
    if (idx === -1) return false;
    this.apiTokens.splice(idx, 1);
    return true;
  }

  public updateUserProfile(data: {
    display_name?: string;
    avatar_url?: string | null;
    timezone?: string;
  }): MockUser {
    if (data.display_name !== undefined)
      this.currentUser.display_name = data.display_name;
    if (data.avatar_url !== undefined)
      this.currentUser.avatar_url = data.avatar_url;
    if (data.timezone !== undefined) this.currentUser.timezone = data.timezone;
    return this.currentUser;
  }

  // Credentials
  public credentials: MockCredential[] = [
    {
      id: "cred_apple_01",
      organization_id: "00000000-0000-0000-0000-000000000010",
      provider: "apple",
      name: "Bloom App Store Connect API Key",
      metadata: {
        provider: "apple",
        key_id: "2X9R4HXF34",
        issuer_id: "57246542-96fe-1a63-e053-0824d011072a",
        team_id: "A3B8C9D0E1",
      },
      expires_at: new Date(Date.now() + 86400000 * 180).toISOString(),
      last_used_at: new Date(Date.now() - 86400000 * 2).toISOString(),
      created_at: new Date(Date.now() - 86400000 * 60).toISOString(),
    },
    {
      id: "cred_google_01",
      organization_id: "00000000-0000-0000-0000-000000000010",
      provider: "google_play",
      name: "Google Play Console Service Account",
      metadata: {
        provider: "google_play",
        client_email:
          "play-deployer@bloom-mobile-suite.iam.gserviceaccount.com",
      },
      expires_at: null,
      last_used_at: new Date(Date.now() - 86400000 * 3).toISOString(),
      created_at: new Date(Date.now() - 86400000 * 50).toISOString(),
    },
    {
      id: "cred_shorebird_01",
      organization_id: "00000000-0000-0000-0000-000000000010",
      provider: "shorebird",
      name: "Shorebird CodePush Integration",
      metadata: {
        provider: "shorebird",
        app_id: "8c7f6b5a-4d3e-2a1b-0c9d-8e7f6a5b4c3d",
      },
      expires_at: null,
      last_used_at: new Date(Date.now() - 3600000 * 18).toISOString(),
      created_at: new Date(Date.now() - 86400000 * 40).toISOString(),
    },
    {
      id: "cred_github_01",
      organization_id: "00000000-0000-0000-0000-000000000010",
      provider: "github",
      name: "GitHub App CI Integration",
      metadata: {
        provider: "github",
        installation_id: "54829104",
      },
      expires_at: null,
      last_used_at: new Date(Date.now() - 3600000 * 4).toISOString(),
      created_at: new Date(Date.now() - 86400000 * 45).toISOString(),
    },
  ];

  public getCredentials(orgId?: string): MockCredential[] {
    if (!orgId) return this.credentials;
    return this.credentials.filter((c) => c.organization_id === orgId);
  }

  public getCredential(id: string): MockCredential | undefined {
    return this.credentials.find((c) => c.id === id);
  }

  public createCredential(
    orgId: string,
    data: {
      provider: MockCredential["provider"];
      name: string;
      metadata: Record<string, unknown>;
      expires_at?: string | null;
    },
  ): MockCredential {
    const id = `cred_${Math.random().toString(16).slice(2, 10)}`;
    const cred: MockCredential = {
      id,
      organization_id: orgId,
      provider: data.provider,
      name: data.name,
      metadata: data.metadata,
      expires_at: data.expires_at ?? null,
      last_used_at: null,
      created_at: new Date().toISOString(),
    };
    this.credentials.unshift(cred);
    return cred;
  }

  public testCredential(id: string): {
    success: boolean;
    message: string;
    provider: string;
  } {
    const cred = this.credentials.find((c) => c.id === id);
    if (!cred)
      return {
        success: false,
        message: "Credential not found",
        provider: "unknown",
      };
    cred.last_used_at = new Date().toISOString();
    return {
      success: true,
      message: `Successfully authenticated with ${cred.provider.replace("_", " ")} API.`,
      provider: cred.provider,
    };
  }

  public deleteCredential(id: string): boolean {
    const idx = this.credentials.findIndex((c) => c.id === id);
    if (idx === -1) return false;
    this.credentials.splice(idx, 1);
    return true;
  }

  // Git Connections
  public gitConnections: MockGitConnection[] = [
    {
      id: "gitconn_001",
      organization_id: "00000000-0000-0000-0000-000000000010",
      provider: "github",
      installation_id: "54829104",
      metadata: {
        account_name: "bloom-labs",
        account_type: "Organization",
        avatar_url: "https://github.com/bloom-labs.png",
        repositories_count: 3,
      },
      created_at: new Date(Date.now() - 86400000 * 30).toISOString(),
    },
    {
      id: "gitconn_002",
      organization_id: "00000000-0000-0000-0000-000000000010",
      provider: "gitlab",
      installation_id: "gl_app_992144",
      metadata: {
        account_name: "bloom-enterprise",
        account_type: "Group",
        repositories_count: 1,
      },
      created_at: new Date(Date.now() - 86400000 * 15).toISOString(),
    },
  ];

  public gitRepositories: MockGitRepository[] = [
    {
      id: "repo_001",
      connection_id: "gitconn_001",
      full_name: "bloom-labs/wallet",
      default_branch: "main",
      url: "https://github.com/bloom-labs/wallet",
    },
    {
      id: "repo_002",
      connection_id: "gitconn_001",
      full_name: "bloom-labs/analytics",
      default_branch: "main",
      url: "https://github.com/bloom-labs/analytics",
    },
    {
      id: "repo_003",
      connection_id: "gitconn_001",
      full_name: "bloom-labs/portal",
      default_branch: "main",
      url: "https://github.com/bloom-labs/portal",
    },
    {
      id: "repo_004",
      connection_id: "gitconn_002",
      full_name: "bloom-enterprise/core-kernel",
      default_branch: "master",
      url: "https://gitlab.com/bloom-enterprise/core-kernel",
    },
  ];

  public getGitConnections(orgId?: string): MockGitConnection[] {
    if (!orgId) return this.gitConnections;
    return this.gitConnections.filter((c) => c.organization_id === orgId);
  }

  public getGitConnection(id: string): MockGitConnection | undefined {
    return this.gitConnections.find((c) => c.id === id);
  }

  public createGitConnection(
    orgId: string,
    data: {
      provider: "github" | "gitlab" | "bitbucket";
      installation_id: string;
      metadata?: Record<string, unknown>;
    },
  ): MockGitConnection {
    const id = `gitconn_${Math.random().toString(16).slice(2, 10)}`;
    const conn: MockGitConnection = {
      id,
      organization_id: orgId,
      provider: data.provider,
      installation_id: data.installation_id,
      metadata: data.metadata || {
        account_name: `connected-${data.provider}-account`,
        repositories_count: 2,
      },
      created_at: new Date().toISOString(),
    };
    this.gitConnections.unshift(conn);

    // Auto seed 2 repositories for this new connection
    this.gitRepositories.push(
      {
        id: `repo_${Math.random().toString(16).slice(2, 8)}`,
        connection_id: id,
        full_name: `${conn.metadata.account_name || "org"}/mobile-app`,
        default_branch: "main",
        url: `https://${data.provider}.com/${conn.metadata.account_name || "org"}/mobile-app`,
      },
      {
        id: `repo_${Math.random().toString(16).slice(2, 8)}`,
        connection_id: id,
        full_name: `${conn.metadata.account_name || "org"}/web-client`,
        default_branch: "main",
        url: `https://${data.provider}.com/${conn.metadata.account_name || "org"}/web-client`,
      },
    );

    return conn;
  }

  public deleteGitConnection(id: string): boolean {
    const idx = this.gitConnections.findIndex((c) => c.id === id);
    if (idx === -1) return false;
    this.gitConnections.splice(idx, 1);
    this.gitRepositories = this.gitRepositories.filter(
      (r) => r.connection_id !== id,
    );
    return true;
  }

  public getGitRepositories(connectionId: string): MockGitRepository[] {
    return this.gitRepositories.filter((r) => r.connection_id === connectionId);
  }

  // Workflows mock data & methods
  public workflows: MockWorkflow[] = [
    {
      id: "wf_001",
      app_id: "app_001",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "Release & Deploy Pipeline",
      slug: "release-pipeline",
      description:
        "Full CI/CD pipeline including tests, multiplatform compilation, approval gate, and store delivery.",
      definition: `name: Release & Deploy Pipeline
on:
  push:
    branches: [main]
jobs:
  test:
    name: Run Unit & Widget Tests
    kind: test
    run: flutter test --coverage

  build:
    name: Compile Android & iOS Artifacts
    needs: [test]
    kind: build
    platforms: [android, ios]

  approval:
    name: Production Release Gate
    needs: [build]
    kind: approval_gate
    requires_approval: true

  deploy:
    name: Deploy to App Store & Google Play
    needs: [approval]
    kind: deploy_production
    targets: [testflight, play_store]`,
      is_active: true,
      created_by: "00000000-0000-0000-0000-000000000001",
      created_at: new Date(Date.now() - 86400000 * 30).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 2).toISOString(),
    },
    {
      id: "wf_002",
      app_id: "app_001",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "Nightly Integration Suite",
      slug: "nightly-integration-suite",
      description:
        "Runs end-to-end integration tests on simulated devices nightly.",
      definition: `name: Nightly Integration Suite
on:
  schedule:
    cron: "0 2 * * *"
jobs:
  integration_test:
    name: Integration Testing
    kind: test
    run: flutter test integration_test/app_test.dart`,
      is_active: true,
      created_by: "00000000-0000-0000-0000-000000000001",
      created_at: new Date(Date.now() - 86400000 * 20).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 5).toISOString(),
    },
    {
      id: "wf_003",
      app_id: "app_002",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "Flutter Web Preview",
      slug: "flutter-web-preview",
      description:
        "Builds web distribution and deploys to preview URL on pull request.",
      definition: `name: Flutter Web Preview
on:
  pull_request:
    branches: [main]
jobs:
  build_web:
    name: Build Web Output
    kind: build
    platform: web
  preview:
    name: Deploy to Web Preview
    needs: [build_web]
    kind: deploy_preview`,
      is_active: false,
      created_by: "00000000-0000-0000-0000-000000000001",
      created_at: new Date(Date.now() - 86400000 * 10).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 1).toISOString(),
    },
  ];

  public workflowRuns: MockWorkflowRun[] = [
    {
      id: "wfr_001",
      workflow_id: "wf_001",
      organization_id: "00000000-0000-0000-0000-000000000010",
      git_commit: "7f2b1a9c4d8e5f1b0a2c3d4e5f6a7b8c9d0e1f2a",
      git_branch: "main",
      git_ref: "refs/heads/main",
      status: "blocked",
      trigger_event: "manual",
      started_at: new Date(Date.now() - 1000 * 60 * 12).toISOString(),
      finished_at: null,
      approved_by: null,
      approved_at: null,
      metadata: { runner: "bloom-hosted-linux-arm64", priority: "high" },
      steps: [
        {
          id: "step_001",
          step_order: 1,
          name: "Run Unit & Widget Tests",
          step_kind: "test",
          status: "completed",
          requires_approval: false,
          started_at: new Date(Date.now() - 1000 * 60 * 12).toISOString(),
          finished_at: new Date(Date.now() - 1000 * 60 * 10).toISOString(),
          log_snippet: `Running "flutter pub get" in /workspace...
Resolved dependencies (0.8s).
Running "flutter test --coverage"...
00:01 +1: test/widget_test.dart: App smoke test
00:03 +14: test/unit/auth_test.dart: Auth token refresh flow
00:05 +32: test/unit/store_test.dart: Cache invalidation checks
00:06 +48: All 48 tests passed!
Coverage generated at coverage/lcov.info (94.2% statement coverage).`,
          metadata: { test_count: 48, passed: 48, failed: 0 },
          created_at: new Date(Date.now() - 1000 * 60 * 12).toISOString(),
        },
        {
          id: "step_002",
          step_order: 2,
          name: "Compile Android & iOS Artifacts",
          step_kind: "build",
          status: "completed",
          requires_approval: false,
          started_at: new Date(Date.now() - 1000 * 60 * 10).toISOString(),
          finished_at: new Date(Date.now() - 1000 * 60 * 4).toISOString(),
          log_snippet: `Compiling release bundle for android (arm64-v8a, armeabi-v7a, x86_64)...
Running Gradle task ':app:bundleRelease'...
✓ Built build/app/outputs/bundle/release/app-release.aab (28.4MB).
Compiling release IPA for iOS...
✓ Built build/ios/ipa/BloomApp.ipa (34.2MB).
Codesigning verified with distribution certificate.`,
          metadata: { android_size_mb: 28.4, ios_size_mb: 34.2 },
          created_at: new Date(Date.now() - 1000 * 60 * 10).toISOString(),
        },
        {
          id: "step_003",
          step_order: 3,
          name: "Production Release Gate",
          step_kind: "approval_gate",
          status: "blocked",
          requires_approval: true,
          started_at: new Date(Date.now() - 1000 * 60 * 4).toISOString(),
          finished_at: null,
          log_snippet: `[APPROVAL REQUIRED]
Execution paused at production release gate.
Target destinations: App Store (TestFlight), Google Play (Production Track).
Awaiting manual decision from an authorized Release Manager or Admin.`,
          metadata: { gate_type: "production_rollout", timeout_hours: 24 },
          created_at: new Date(Date.now() - 1000 * 60 * 4).toISOString(),
        },
        {
          id: "step_004",
          step_order: 4,
          name: "Deploy to App Store & Google Play",
          step_kind: "deploy_production",
          status: "pending",
          requires_approval: false,
          started_at: null,
          finished_at: null,
          log_snippet: null,
          metadata: {},
          created_at: new Date(Date.now() - 1000 * 60 * 4).toISOString(),
        },
      ],
      created_by: "00000000-0000-0000-0000-000000000001",
      created_at: new Date(Date.now() - 1000 * 60 * 12).toISOString(),
      updated_at: new Date(Date.now() - 1000 * 60 * 4).toISOString(),
    },
    {
      id: "wfr_002",
      workflow_id: "wf_001",
      organization_id: "00000000-0000-0000-0000-000000000010",
      git_commit: "93e8cc1a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e",
      git_branch: "main",
      git_ref: "refs/heads/main",
      status: "success",
      trigger_event: "push",
      started_at: new Date(Date.now() - 86400000 * 2).toISOString(),
      finished_at: new Date(
        Date.now() - 86400000 * 2 + 1000 * 60 * 15,
      ).toISOString(),
      approved_by: "dev@bloom.dev",
      approved_at: new Date(
        Date.now() - 86400000 * 2 + 1000 * 60 * 8,
      ).toISOString(),
      metadata: { runner: "bloom-hosted-linux-arm64" },
      steps: [
        {
          id: "step_010",
          step_order: 1,
          name: "Run Unit & Widget Tests",
          step_kind: "test",
          status: "completed",
          requires_approval: false,
          started_at: new Date(Date.now() - 86400000 * 2).toISOString(),
          finished_at: new Date(
            Date.now() - 86400000 * 2 + 1000 * 60 * 2,
          ).toISOString(),
          log_snippet: "All 48 tests passed successfully.",
          metadata: {},
          created_at: new Date(Date.now() - 86400000 * 2).toISOString(),
        },
        {
          id: "step_011",
          step_order: 2,
          name: "Compile Android & iOS Artifacts",
          step_kind: "build",
          status: "completed",
          requires_approval: false,
          started_at: new Date(
            Date.now() - 86400000 * 2 + 1000 * 60 * 2,
          ).toISOString(),
          finished_at: new Date(
            Date.now() - 86400000 * 2 + 1000 * 60 * 8,
          ).toISOString(),
          log_snippet: "Artifacts compiled and signed successfully.",
          metadata: {},
          created_at: new Date(
            Date.now() - 86400000 * 2 + 1000 * 60 * 2,
          ).toISOString(),
        },
        {
          id: "step_012",
          step_order: 3,
          name: "Production Release Gate",
          step_kind: "approval_gate",
          status: "completed",
          requires_approval: true,
          started_at: new Date(
            Date.now() - 86400000 * 2 + 1000 * 60 * 8,
          ).toISOString(),
          finished_at: new Date(
            Date.now() - 86400000 * 2 + 1000 * 60 * 9,
          ).toISOString(),
          log_snippet:
            "Approved by dev@bloom.dev (Reason: verified QA regression suite).",
          metadata: {},
          created_at: new Date(
            Date.now() - 86400000 * 2 + 1000 * 60 * 8,
          ).toISOString(),
        },
        {
          id: "step_013",
          step_order: 4,
          name: "Deploy to App Store & Google Play",
          step_kind: "deploy_production",
          status: "completed",
          requires_approval: false,
          started_at: new Date(
            Date.now() - 86400000 * 2 + 1000 * 60 * 9,
          ).toISOString(),
          finished_at: new Date(
            Date.now() - 86400000 * 2 + 1000 * 60 * 15,
          ).toISOString(),
          log_snippet:
            "Uploaded build #14 to TestFlight and Google Play track 'internal'.",
          metadata: {},
          created_at: new Date(
            Date.now() - 86400000 * 2 + 1000 * 60 * 9,
          ).toISOString(),
        },
      ],
      created_by: "00000000-0000-0000-0000-000000000001",
      created_at: new Date(Date.now() - 86400000 * 2).toISOString(),
      updated_at: new Date(
        Date.now() - 86400000 * 2 + 1000 * 60 * 15,
      ).toISOString(),
    },
    {
      id: "wfr_003",
      workflow_id: "wf_002",
      organization_id: "00000000-0000-0000-0000-000000000010",
      git_commit: "4410ad2c3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b",
      git_branch: "develop",
      git_ref: "refs/heads/develop",
      status: "failed",
      trigger_event: "schedule",
      started_at: new Date(Date.now() - 86400000 * 3).toISOString(),
      finished_at: new Date(
        Date.now() - 86400000 * 3 + 1000 * 60 * 3,
      ).toISOString(),
      approved_by: null,
      approved_at: null,
      metadata: {},
      steps: [
        {
          id: "step_020",
          step_order: 1,
          name: "Integration Testing",
          step_kind: "test",
          status: "failed",
          requires_approval: false,
          started_at: new Date(Date.now() - 86400000 * 3).toISOString(),
          finished_at: new Date(
            Date.now() - 86400000 * 3 + 1000 * 60 * 3,
          ).toISOString(),
          log_snippet: `Launching integration test suite on device emulator...
00:15 +0: test/integration/checkout_flow_test.dart: Complete cart checkout
EXCEPTION: TimeoutException after 0:00:30.000000: Test timed out waiting for element 'Pay Now'.
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞═════════════════════════════════
The following TestFailure was thrown running a test:
Expected: found 1 matching candidate widget
  Actual: found 0 matching candidate widgets
════════════════════════════════════════════════════════════════════════════════`,
          metadata: { failure_count: 1 },
          created_at: new Date(Date.now() - 86400000 * 3).toISOString(),
        },
      ],
      created_by: "system",
      created_at: new Date(Date.now() - 86400000 * 3).toISOString(),
      updated_at: new Date(
        Date.now() - 86400000 * 3 + 1000 * 60 * 3,
      ).toISOString(),
    },
  ];

  public getWorkflows(appId?: string, orgId?: string): MockWorkflow[] {
    let list = this.workflows;
    if (appId) list = list.filter((w) => w.app_id === appId);
    if (orgId) list = list.filter((w) => w.organization_id === orgId);
    return list;
  }

  public getWorkflow(id: string): MockWorkflow | undefined {
    return this.workflows.find((w) => w.id === id);
  }

  public createWorkflow(
    appId: string,
    orgId: string,
    data: {
      name: string;
      slug: string;
      description?: string;
      definition: string;
      is_active?: boolean;
    },
  ): MockWorkflow {
    const id = `wf_${Math.random().toString(16).slice(2, 8)}`;
    const wf: MockWorkflow = {
      id,
      app_id: appId,
      organization_id: orgId,
      name: data.name,
      slug: data.slug,
      description: data.description || null,
      definition: data.definition,
      is_active: data.is_active ?? true,
      created_by: this.currentUser.id,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    this.workflows.unshift(wf);
    return wf;
  }

  public updateWorkflow(
    id: string,
    data: Partial<MockWorkflow>,
  ): MockWorkflow | undefined {
    const wf = this.workflows.find((w) => w.id === id);
    if (!wf) return undefined;
    Object.assign(wf, data, { updated_at: new Date().toISOString() });
    return wf;
  }

  public getWorkflowRuns(workflowId: string): MockWorkflowRun[] {
    const results = this.workflowRuns.filter(
      (r) => r.workflow_id === workflowId,
    );
    for (const r of results) this.progressWorkflowRunInPlace(r);
    return results;
  }

  public getWorkflowRun(id: string): MockWorkflowRun | undefined {
    const run = this.workflowRuns.find((r) => r.id === id);
    if (run) this.progressWorkflowRunInPlace(run);
    return run;
  }

  public createWorkflowRun(
    workflowId: string,
    data: {
      git_commit?: string;
      git_branch?: string;
      git_ref?: string;
      trigger_event?: string;
    },
  ): MockWorkflowRun {
    const wf = this.getWorkflow(workflowId);
    const id = `wfr_${Math.random().toString(16).slice(2, 8)}`;
    const run: MockWorkflowRun = {
      id,
      workflow_id: workflowId,
      organization_id:
        wf?.organization_id || "00000000-0000-0000-0000-000000000010",
      git_commit:
        data.git_commit ||
        "a" +
          Math.random().toString(16).slice(2, 10) +
          "b" +
          Math.random().toString(16).slice(2, 10),
      git_branch: data.git_branch || "main",
      git_ref: data.git_ref || `refs/heads/${data.git_branch || "main"}`,
      status: "running",
      trigger_event: data.trigger_event || "manual",
      started_at: new Date().toISOString(),
      finished_at: null,
      approved_by: null,
      approved_at: null,
      metadata: {},
      steps: [
        {
          id: `step_${Math.random().toString(16).slice(2, 8)}`,
          step_order: 1,
          name: "Unit & Widget Tests",
          step_kind: "test",
          status: "running",
          requires_approval: false,
          started_at: new Date().toISOString(),
          finished_at: null,
          log_snippet: "Running test suites...",
          metadata: {},
          created_at: new Date().toISOString(),
        },
        {
          id: `step_${Math.random().toString(16).slice(2, 8)}`,
          step_order: 2,
          name: "Build Pipeline",
          step_kind: "build",
          status: "pending",
          requires_approval: false,
          started_at: null,
          finished_at: null,
          log_snippet: null,
          metadata: {},
          created_at: new Date().toISOString(),
        },
        {
          id: `step_${Math.random().toString(16).slice(2, 8)}`,
          step_order: 3,
          name: "Approval Gate",
          step_kind: "approval_gate",
          status: "pending",
          requires_approval: true,
          started_at: null,
          finished_at: null,
          log_snippet: null,
          metadata: {},
          created_at: new Date().toISOString(),
        },
      ],
      created_by: this.currentUser.id,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    this.workflowRuns.unshift(run);
    return run;
  }

  public approveWorkflowRun(
    runId: string,
    approved: boolean,
    reason?: string,
  ): MockWorkflowRun | undefined {
    const run = this.getWorkflowRun(runId);
    if (!run) return undefined;

    const blockedStep = run.steps.find(
      (s) => s.step_kind === "approval_gate" && s.status === "blocked",
    );
    if (blockedStep) {
      blockedStep.status = approved ? "completed" : "failed";
      blockedStep.finished_at = new Date().toISOString();
      blockedStep.log_snippet = approved
        ? `[APPROVED] Execution resumed by ${this.currentUser.email}.${reason ? ` Reason: ${reason}` : ""}`
        : `[REJECTED] Terminated by ${this.currentUser.email}.${reason ? ` Reason: ${reason}` : ""}`;
    }

    run.status = approved ? "running" : "failed";
    run.approved_by = this.currentUser.email;
    run.approved_at = new Date().toISOString();
    run.updated_at = new Date().toISOString();

    if (approved) {
      // simulate subsequent steps executing
      const nextPending = run.steps.find((s) => s.status === "pending");
      if (nextPending) {
        nextPending.status = "running";
        nextPending.started_at = new Date().toISOString();
      }
    }

    return run;
  }

  // Audit Logs mock data & methods
  public auditLogs: MockAuditLogEntry[] = [
    {
      id: "audit_001",
      organization_id: "00000000-0000-0000-0000-000000000010",
      actor: { name: "Bloom Developer", email: "dev@bloom.dev" },
      action: "secret.created",
      resource_type: "secret",
      resource_id: "sec_prod_api_key",
      before_snapshot: null,
      after_snapshot: {
        key: "SUPABASE_SERVICE_ROLE_KEY",
        environment_id: "env_prod_001",
        value: "[REDACTED]",
        version: 1,
      },
      ip_address: "192.168.1.42",
      created_at: new Date(Date.now() - 1000 * 60 * 25).toISOString(),
    },
    {
      id: "audit_002",
      organization_id: "00000000-0000-0000-0000-000000000010",
      actor: { name: "Chidi Developer", email: "chidi@bloom.dev" },
      action: "workflow.approved",
      resource_type: "workflow_run",
      resource_id: "wfr_002",
      before_snapshot: { status: "blocked", requires_approval: true },
      after_snapshot: {
        status: "approved",
        approved_by: "chidi@bloom.dev",
        gate: "Production Release Gate",
      },
      ip_address: "172.56.21.9",
      created_at: new Date(Date.now() - 1000 * 60 * 120).toISOString(),
    },
    {
      id: "audit_003",
      organization_id: "00000000-0000-0000-0000-000000000010",
      actor: { name: "Bloom Developer", email: "dev@bloom.dev" },
      action: "signing_identity.created",
      resource_type: "signing_identity",
      resource_id: "sig_ios_dist_2026",
      before_snapshot: null,
      after_snapshot: {
        platform: "ios",
        kind: "certificate",
        name: "Apple Distribution 2026",
        fingerprint: "SHA256:9f:3b:4e:[REDACTED]",
        expires_at: "2027-08-01T00:00:00Z",
      },
      ip_address: "192.168.1.42",
      created_at: new Date(Date.now() - 86400000 * 1).toISOString(),
    },
    {
      id: "audit_004",
      organization_id: "00000000-0000-0000-0000-000000000010",
      actor: { name: "Chidi Developer", email: "chidi@bloom.dev" },
      action: "secret.updated",
      resource_type: "secret",
      resource_id: "sec_prod_db_url",
      before_snapshot: {
        key: "DATABASE_URL",
        value: "[REDACTED]",
        version: 2,
      },
      after_snapshot: {
        key: "DATABASE_URL",
        value: "[REDACTED]",
        version: 3,
      },
      ip_address: "172.56.21.9",
      created_at: new Date(Date.now() - 86400000 * 2).toISOString(),
    },
    {
      id: "audit_005",
      organization_id: "00000000-0000-0000-0000-000000000010",
      actor: { name: "Bloom Developer", email: "dev@bloom.dev" },
      action: "member.invited",
      resource_type: "organization_member",
      resource_id: "mem_sarah_09",
      before_snapshot: null,
      after_snapshot: {
        email: "sarah.chen@bloom.dev",
        role: "Developer",
        organization_id: "00000000-0000-0000-0000-000000000010",
      },
      ip_address: "192.168.1.42",
      created_at: new Date(Date.now() - 86400000 * 4).toISOString(),
    },
    {
      id: "audit_006",
      organization_id: "00000000-0000-0000-0000-000000000010",
      actor: { name: "Billing Webhook", email: "system@billing.bloom.dev" },
      action: "billing.invoice_paid",
      resource_type: "invoice",
      resource_id: "inv_001",
      before_snapshot: { status: "sent", amount_cents: 2900 },
      after_snapshot: {
        status: "paid",
        amount_cents: 2900,
        paid_at: "2026-08-01T10:00:00Z",
      },
      ip_address: "52.14.88.201",
      created_at: new Date(Date.now() - 86400000 * 15).toISOString(),
    },
  ];

  public getAuditLogs(
    orgId?: string,
    filters?: { action?: string; actor?: string; from?: string; to?: string },
  ): MockAuditLogEntry[] {
    let logs = this.auditLogs;
    if (orgId) logs = logs.filter((l) => l.organization_id === orgId);
    if (filters?.action && filters.action !== "all") {
      logs = logs.filter((l) =>
        l.action.toLowerCase().includes(filters.action!.toLowerCase()),
      );
    }
    if (filters?.actor) {
      const q = filters.actor.toLowerCase();
      logs = logs.filter((l) => {
        const actorName =
          typeof l.actor === "string"
            ? l.actor
            : `${l.actor.name} ${l.actor.email}`;
        return actorName.toLowerCase().includes(q);
      });
    }
    if (filters?.from) {
      const fromTime = new Date(filters.from).getTime();
      logs = logs.filter((l) => new Date(l.created_at).getTime() >= fromTime);
    }
    if (filters?.to) {
      const toTime = new Date(filters.to).getTime();
      logs = logs.filter((l) => new Date(l.created_at).getTime() <= toTime);
    }
    return logs;
  }

  // Billing mock data & methods
  public plans: MockPlan[] = [
    {
      id: "plan_free",
      name: "free",
      description:
        "For hobbyists and individual developers starting out with Flutter cloud builds.",
      price_minor: 0,
      currency: "USD",
      entitlements: {
        max_projects: 3,
        max_apps: 5,
        max_seats: 2,
        build_minutes_monthly: 500,
        artifact_storage_gb: 5,
        web_bandwidth_gb: 10,
        features: {
          testflight_deployments: false,
          google_play_deployments: false,
          web_hosting: true,
          shorebird: false,
          workflows: true,
          priority_support: false,
        },
        overage: {
          enabled: false,
          build_minute_cents: 0,
          storage_gb_cents: 0,
          bandwidth_gb_cents: 0,
        },
      },
      active: true,
      created_at: new Date(Date.now() - 86400000 * 180).toISOString(),
    },
    {
      id: "plan_pro",
      name: "pro",
      description:
        "For professional teams automating multiplatform mobile & web releases with higher concurrency.",
      price_minor: 2900,
      currency: "USD",
      entitlements: {
        max_projects: 20,
        max_apps: 50,
        max_seats: 10,
        build_minutes_monthly: 5000,
        artifact_storage_gb: 50,
        web_bandwidth_gb: 100,
        features: {
          testflight_deployments: true,
          google_play_deployments: true,
          web_hosting: true,
          shorebird: true,
          workflows: true,
          priority_support: true,
        },
        overage: {
          enabled: true,
          build_minute_cents: 2,
          storage_gb_cents: 15,
          bandwidth_gb_cents: 10,
        },
      },
      active: true,
      created_at: new Date(Date.now() - 86400000 * 180).toISOString(),
    },
    {
      id: "plan_enterprise",
      name: "enterprise",
      description:
        "Dedicated infrastructure, unlimited concurrency, custom SLA, and priority support for large orgs.",
      price_minor: 29900,
      currency: "USD",
      entitlements: {
        max_projects: 100,
        max_apps: 500,
        max_seats: 100,
        build_minutes_monthly: 50000,
        artifact_storage_gb: 500,
        web_bandwidth_gb: 1000,
        features: {
          testflight_deployments: true,
          google_play_deployments: true,
          web_hosting: true,
          shorebird: true,
          workflows: true,
          priority_support: true,
        },
        overage: {
          enabled: true,
          build_minute_cents: 1,
          storage_gb_cents: 8,
          bandwidth_gb_cents: 5,
        },
      },
      active: true,
      created_at: new Date(Date.now() - 86400000 * 180).toISOString(),
    },
  ];

  public sellerAccounts: Record<string, MockSellerAccount> = {};

  public subscriptions: Record<string, MockSubscription> = {
    "00000000-0000-0000-0000-000000000010": {
      id: "sub_001",
      organization_id: "00000000-0000-0000-0000-000000000010",
      plan_id: "plan_pro",
      plan_name: "pro",
      status: "active",
      trial_ends_at: null,
      activated_at: new Date(Date.now() - 86400000 * 45).toISOString(),
      current_period_start: new Date(Date.now() - 86400000 * 15).toISOString(),
      current_period_end: new Date(Date.now() + 86400000 * 15).toISOString(),
      provider_customer_id: "cus_mock_99201",
      provider_subscription_id: "sub_mock_88123",
      created_at: new Date(Date.now() - 86400000 * 45).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 15).toISOString(),
    },
  };

  public invoices: MockInvoice[] = [
    {
      id: "inv_001",
      subscription_id: "sub_001",
      organization_id: "00000000-0000-0000-0000-000000000010",
      amount_cents: 4384,
      status: "paid",
      due_date: "2026-08-01",
      paid_at: "2026-08-01T10:00:00Z",
      provider_invoice_id: "in_1Pm9K02eZvKYlo2CL",
      created_at: "2026-08-01T08:00:00Z",
      line_items: [
        {
          description: "Pro plan — monthly subscription",
          kind: "base_plan",
          quantity: 1,
          unit_price_cents: 2900,
          amount_cents: 2900,
        },
        {
          description: "Build minutes overage (840 min over 5,000)",
          kind: "overage",
          quantity: 840,
          unit_price_cents: 2,
          amount_cents: 1680,
        },
        {
          description: "Artifact storage overage (0 GB over 50 GB)",
          kind: "overage",
          quantity: 0,
          unit_price_cents: 15,
          amount_cents: 0,
        },
        {
          description: "Web bandwidth overage (0 GB over 100 GB)",
          kind: "overage",
          quantity: 0,
          unit_price_cents: 10,
          amount_cents: 0,
        },
      ],
    },
    {
      id: "inv_002",
      subscription_id: "sub_001",
      organization_id: "00000000-0000-0000-0000-000000000010",
      amount_cents: 2900,
      status: "paid",
      due_date: "2026-07-01",
      paid_at: "2026-07-01T10:00:00Z",
      provider_invoice_id: "in_1Pj7Y82eZvKYlo2CK",
      created_at: "2026-07-01T08:00:00Z",
      line_items: [
        {
          description: "Pro plan — monthly subscription",
          kind: "base_plan",
          quantity: 1,
          unit_price_cents: 2900,
          amount_cents: 2900,
        },
      ],
    },
    {
      id: "inv_003",
      subscription_id: "sub_001",
      organization_id: "00000000-0000-0000-0000-000000000010",
      amount_cents: 2900,
      status: "paid",
      due_date: "2026-06-01",
      paid_at: "2026-06-01T10:00:00Z",
      provider_invoice_id: "in_1Ph5X62eZvKYlo2CJ",
      created_at: "2026-06-01T08:00:00Z",
      line_items: [
        {
          description: "Pro plan — monthly subscription",
          kind: "base_plan",
          quantity: 1,
          unit_price_cents: 2900,
          amount_cents: 2900,
        },
      ],
    },
  ];

  public getBillingPlans(): MockPlan[] {
    return this.plans;
  }

  public getSubscription(orgId: string): MockSubscription {
    if (this.subscriptions[orgId]) {
      return this.subscriptions[orgId];
    }
    const newSub: MockSubscription = {
      id: `sub_${Math.random().toString(16).slice(2, 8)}`,
      organization_id: orgId,
      plan_id: "plan_free",
      plan_name: "free",
      status: "active",
      trial_ends_at: null,
      activated_at: new Date().toISOString(),
      current_period_start: new Date().toISOString(),
      current_period_end: new Date(Date.now() + 86400000 * 30).toISOString(),
      provider_customer_id: null,
      provider_subscription_id: null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    this.subscriptions[orgId] = newSub;
    return newSub;
  }

  public subscribe(
    orgId: string,
    planId: string,
    _provider?: string,
    _callbackUrl?: string,
  ): {
    subscription: MockSubscription;
    authorization_url?: string;
    reference?: string;
  } {
    const plan =
      this.plans.find((p) => p.id === planId || p.name === planId) ||
      this.plans[1];
    const sub = this.getSubscription(orgId);
    sub.plan_id = plan.id;
    sub.plan_name = plan.name;
    sub.status = "active";
    sub.updated_at = new Date().toISOString();

    const isPaid = plan.price_minor > 0;
    return {
      subscription: sub,
      authorization_url: isPaid
        ? `https://checkout.stripe.com/pay/cs_test_${Math.random().toString(16).slice(2, 12)}`
        : undefined,
      reference: `ref_${Math.random().toString(16).slice(2, 10)}`,
    };
  }

  public cancelSubscription(
    orgId: string,
    reason?: string,
    immediately?: boolean,
  ): MockSubscription {
    const sub = this.getSubscription(orgId);
    sub.status = immediately ? "cancelled" : "active";
    sub.updated_at = new Date().toISOString();
    return sub;
  }

  public getSellerAccount(orgId: string): MockSellerAccount | null {
    return this.sellerAccounts[orgId] || null;
  }

  public createSellerOnboarding(
    orgId: string,
    _refreshUrl: string,
    _returnUrl: string,
  ): { url: string; expires_at: number } {
    if (!this.sellerAccounts[orgId]) {
      this.sellerAccounts[orgId] = {
        id: `seller_${Math.random().toString(16).slice(2, 8)}`,
        organization_id: orgId,
        stripe_account_id: `acct_${Math.random().toString(16).slice(2, 12)}`,
        payouts_enabled: false,
        charges_enabled: false,
        details_submitted: false,
        default_currency: null,
        last_payouts_checked_at: null,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };
    }
    return {
      url: `https://connect.stripe.com/setup/s/${Math.random().toString(16).slice(2, 14)}`,
      expires_at: Math.floor(Date.now() / 1000) + 3600,
    };
  }

  public refreshSellerStatus(orgId: string): MockSellerAccount | null {
    const acct = this.sellerAccounts[orgId];
    if (!acct) return null;
    acct.details_submitted = true;
    acct.charges_enabled = true;
    acct.payouts_enabled = true;
    acct.default_currency = "usd";
    acct.last_payouts_checked_at = new Date().toISOString();
    acct.updated_at = new Date().toISOString();
    return acct;
  }

  public getInvoices(orgId: string): MockInvoice[] {
    return this.invoices.filter((i) => i.organization_id === orgId);
  }

  public getUsageSummary(orgId: string) {
    const subscription = this.getSubscription(orgId);
    const plan =
      this.plans.find((p) => p.id === subscription.plan_id) ?? this.plans[0];

    const build_minutes_used = 5840;
    const build_minutes_limit = plan.entitlements.build_minutes_monthly;
    const artifact_storage_gb_used = 14;
    const artifact_storage_gb_limit = plan.entitlements.artifact_storage_gb;
    const web_bandwidth_gb_used = 28;
    const web_bandwidth_gb_limit = plan.entitlements.web_bandwidth_gb;

    const overageRates = plan.entitlements.overage;
    const build_minutes_over = Math.max(
      0,
      build_minutes_used - build_minutes_limit,
    );
    const storage_gb_over = Math.max(
      0,
      artifact_storage_gb_used - artifact_storage_gb_limit,
    );
    const bandwidth_gb_over = Math.max(
      0,
      web_bandwidth_gb_used - web_bandwidth_gb_limit,
    );
    const anyOver =
      build_minutes_over > 0 || storage_gb_over > 0 || bandwidth_gb_over > 0;

    const build_minutes_cost_cents =
      build_minutes_over * overageRates.build_minute_cents;
    const storage_cost_cents = storage_gb_over * overageRates.storage_gb_cents;
    const bandwidth_cost_cents =
      bandwidth_gb_over * overageRates.bandwidth_gb_cents;

    const decisionFor = (
      over: number,
    ): "allow" | "warn" | "soft_block" | "hard_lock" => {
      if (over <= 0) return "allow";
      return overageRates.enabled ? "allow" : "hard_lock";
    };

    return {
      organization_id: orgId,
      plan_name: subscription.plan_name,
      current_period_start: new Date(Date.now() - 86400000 * 15).toISOString(),
      current_period_end: new Date(Date.now() + 86400000 * 15).toISOString(),
      build_minutes_used,
      build_minutes_limit,
      artifact_storage_gb_used,
      artifact_storage_gb_limit,
      web_bandwidth_gb_used,
      web_bandwidth_gb_limit,
      deploy_count: 36,
      enforcement: {
        overall_decision: decisionFor(
          Math.max(build_minutes_over, storage_gb_over, bandwidth_gb_over),
        ),
        build_minutes_decision: decisionFor(build_minutes_over),
        storage_decision: decisionFor(storage_gb_over),
        bandwidth_decision: decisionFor(bandwidth_gb_over),
      },
      overage: {
        enabled: overageRates.enabled && anyOver,
        build_minutes_over,
        storage_gb_over,
        bandwidth_gb_over,
        build_minutes_cost_cents,
        storage_cost_cents,
        bandwidth_cost_cents,
        total_cost_cents: overageRates.enabled
          ? build_minutes_cost_cents + storage_cost_cents + bandwidth_cost_cents
          : 0,
      },
    };
  }

  // Marketplace & Templates mock data & methods
  public templates: MockTemplate[] = [
    {
      id: "tmpl_001",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "Flutter Supabase SaaS Starter",
      slug: "flutter-supabase-saas-starter",
      description:
        "Production-ready fullstack Flutter kit with Supabase Auth, Row-Level Security, multi-tenant workspace isolation, and automated webhosting pipelines.",
      visibility: "public",
      status: "published",
      is_free: true,
      price_amount: 0,
      price_currency: "usd",
      metadata: {
        category: "saas",
        platforms: ["ios", "android", "web", "desktop"],
        tags: ["supabase", "auth", "state_management", "riverpod"],
        icon_provider: "supabase",
      },
      latest_version: "1.4.0",
      versions_count: 4,
      rating_count: 42,
      rating_bayesian_milli: 4850,
      install_count: 1840,
      featured_type: "editorial",
      is_featured: true,
      is_editorial_featured: true,
      is_paid_featured: false,
      created_at: new Date(Date.now() - 86400000 * 90).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 3).toISOString(),
    },
    {
      id: "tmpl_002",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "E-Commerce Mobile & Web Suite",
      slug: "ecommerce-mobile-web-suite",
      description:
        "Complete Flutter storefront with Stripe payment sheets, dynamic product filtering, cart state, order tracking, and inventory webhooks.",
      visibility: "public",
      status: "published",
      is_free: false,
      price_amount: 4900,
      price_currency: "usd",
      metadata: {
        category: "ecommerce",
        platforms: ["ios", "android", "web"],
        tags: ["stripe", "cart", "catalog", "checkout"],
        icon_provider: "vercel",
      },
      latest_version: "2.1.0",
      versions_count: 5,
      rating_count: 29,
      rating_bayesian_milli: 4620,
      install_count: 520,
      featured_type: "paid",
      is_featured: true,
      is_editorial_featured: false,
      is_paid_featured: true,
      created_at: new Date(Date.now() - 86400000 * 60).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 6).toISOString(),
    },
    {
      id: "tmpl_003",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "Fintech Banking & Crypto Wallet",
      slug: "fintech-banking-crypto-wallet",
      description:
        "Bank-grade Flutter client template with biometric FaceID authentication, hardware enclave signing, and animated transaction charts.",
      visibility: "public",
      status: "published",
      is_free: false,
      price_amount: 8900,
      price_currency: "usd",
      metadata: {
        category: "fintech",
        platforms: ["ios", "android"],
        tags: ["biometrics", "charts", "security", "wallet"],
        icon_provider: "fastly",
      },
      latest_version: "1.0.2",
      versions_count: 2,
      rating_count: 18,
      rating_bayesian_milli: 4910,
      install_count: 240,
      featured_type: "none",
      is_featured: false,
      is_editorial_featured: false,
      is_paid_featured: false,
      created_at: new Date(Date.now() - 86400000 * 40).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 10).toISOString(),
    },
    {
      id: "tmpl_004",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "Bloom Cloud-Native App Scaffold",
      slug: "bloom-cloud-native-scaffold",
      description:
        "Official starter template pre-wired with Bloom Cloud CI/CD workflows, Shorebird code push, and automated store signing.",
      visibility: "public",
      status: "published",
      is_free: true,
      price_amount: 0,
      price_currency: "usd",
      metadata: {
        category: "devtool",
        platforms: ["ios", "android", "web", "desktop"],
        tags: ["bloom", "cicd", "shorebird", "workflows"],
        icon_provider: "github",
      },
      latest_version: "1.1.0",
      versions_count: 3,
      rating_count: 64,
      rating_bayesian_milli: 4940,
      install_count: 3100,
      featured_type: "editorial",
      is_featured: true,
      is_editorial_featured: true,
      is_paid_featured: false,
      created_at: new Date(Date.now() - 86400000 * 120).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 1).toISOString(),
    },
    {
      id: "tmpl_005",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "Stripe Payments & Subscriptions Kit",
      slug: "stripe-payments-subscriptions-kit",
      description:
        "Drop-in Flutter payment sheets, subscription billing, invoices, and webhook-driven entitlement sync powered by Stripe.",
      visibility: "public",
      status: "published",
      is_free: false,
      price_amount: 5900,
      price_currency: "usd",
      metadata: {
        category: "payments",
        platforms: ["ios", "android", "web"],
        tags: ["stripe", "billing", "subscriptions", "webhooks"],
        icon_provider: "stripe",
      },
      latest_version: "1.2.0",
      versions_count: 3,
      rating_count: 21,
      rating_bayesian_milli: 4780,
      install_count: 410,
      featured_type: "paid",
      is_featured: false,
      is_editorial_featured: false,
      is_paid_featured: true,
      created_at: new Date(Date.now() - 86400000 * 30).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 4).toISOString(),
    },
    {
      id: "tmpl_006",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "Resend Transactional Email Starter",
      slug: "resend-transactional-email-starter",
      description:
        "Wire up welcome emails, password resets, and receipts from your Flutter backend using Resend's API, with retry-safe queued sends.",
      visibility: "public",
      status: "published",
      is_free: true,
      price_amount: 0,
      price_currency: "usd",
      metadata: {
        category: "devtool",
        platforms: ["ios", "android", "web", "desktop"],
        tags: ["resend", "email", "notifications", "transactional"],
        icon_provider: "resend",
      },
      latest_version: "1.0.1",
      versions_count: 2,
      rating_count: 9,
      rating_bayesian_milli: 4530,
      install_count: 165,
      featured_type: "none",
      is_featured: false,
      is_editorial_featured: false,
      is_paid_featured: false,
      created_at: new Date(Date.now() - 86400000 * 18).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 2).toISOString(),
    },
    {
      id: "tmpl_007",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "Bloom UI Starter Template",
      slug: "bloom-ui-starter-template",
      description:
        "Fresh Bloom project pre-wired with the full Bloom UI component library, all 8 style presets, dark mode, and a themed onboarding + dashboard shell.",
      visibility: "public",
      status: "published",
      is_free: true,
      price_amount: 0,
      price_currency: "usd",
      metadata: {
        category: "starter",
        platforms: ["ios", "android", "web", "desktop"],
        tags: ["bloom", "bloom_ui", "design_system", "starter"],
        icon_provider: "bloom",
      },
      latest_version: "1.3.0",
      versions_count: 4,
      rating_count: 37,
      rating_bayesian_milli: 4890,
      install_count: 1260,
      featured_type: "editorial",
      is_featured: true,
      is_editorial_featured: true,
      is_paid_featured: false,
      created_at: new Date(Date.now() - 86400000 * 75).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 5).toISOString(),
    },
  ];

  public templateVersions: MockTemplateVersion[] = [
    {
      id: "ver_001",
      template_id: "tmpl_001",
      version: "1.4.0",
      changelog:
        "Added Supabase Realtime channel support and Flutter 3.24 upgrade.",
      manifest: {
        min_flutter: "3.24.0",
        dependencies: ["supabase_flutter", "flutter_riverpod"],
      },
      readme: `# Flutter Supabase SaaS Starter

A robust boilerplate for launching cross-platform apps with serverless auth and database.

## Quickstart
\`\`\`bash
bloom create my_app --template flutter-supabase-saas-starter
cd my_app
bloom dev
\`\`\`
Then fill in your Supabase keys as environment secrets in Bloom Cloud (or a local \`.env\` for offline development).
`,
      install_count: 820,
      created_at: new Date(Date.now() - 86400000 * 10).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 10).toISOString(),
    },
    {
      id: "ver_002",
      template_id: "tmpl_001",
      version: "1.3.0",
      changelog: "Initial public release with OAuth login (Google & Apple).",
      manifest: { min_flutter: "3.22.0" },
      readme: "# Flutter Supabase SaaS Starter v1.3.0",
      install_count: 1020,
      created_at: new Date(Date.now() - 86400000 * 40).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 40).toISOString(),
    },
    {
      id: "ver_003",
      template_id: "tmpl_002",
      version: "2.1.0",
      changelog: "Apple Pay & Google Pay direct checkout integrations.",
      manifest: {
        min_flutter: "3.24.0",
        dependencies: ["flutter_stripe", "bloc"],
      },
      readme:
        "# E-Commerce Mobile & Web Suite\n\nFull payment and cart management system.",
      install_count: 520,
      created_at: new Date(Date.now() - 86400000 * 6).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 6).toISOString(),
    },
    {
      id: "ver_004",
      template_id: "tmpl_005",
      version: "1.2.0",
      changelog:
        "Added subscription proration handling and invoice PDF export.",
      manifest: {
        min_flutter: "3.24.0",
        dependencies: ["flutter_stripe", "webhook_listener"],
      },
      readme: `# Stripe Payments & Subscriptions Kit

Drop-in payment sheets, subscription billing, and webhook-driven entitlement sync.

## Quickstart
\`\`\`bash
bloom create my_app --template stripe-payments-subscriptions-kit
cd my_app
bloom dev
\`\`\`
Then add your Stripe secret key to the app's Secrets vault in Bloom Cloud and point your webhook endpoint at \`/webhooks/stripe\`.
`,
      install_count: 180,
      created_at: new Date(Date.now() - 86400000 * 4).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 4).toISOString(),
    },
    {
      id: "ver_005",
      template_id: "tmpl_006",
      version: "1.0.1",
      changelog: "Fixed retry backoff timing for queued sends.",
      manifest: {
        min_flutter: "3.22.0",
        dependencies: ["resend_dart"],
      },
      readme:
        "# Resend Transactional Email Starter\n\nWelcome emails, password resets, and receipts with retry-safe queued sends.",
      install_count: 90,
      created_at: new Date(Date.now() - 86400000 * 2).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 2).toISOString(),
    },
    {
      id: "ver_006",
      template_id: "tmpl_007",
      version: "1.3.0",
      changelog: "Upgraded to Bloom UI 0.1.0 with all 8 style presets.",
      manifest: {
        min_flutter: "3.24.0",
        dependencies: ["bloom_ui"],
      },
      readme: `# Bloom UI Starter Template

A fresh Bloom project scaffolded with \`bloom create\`, with Bloom UI's primitives already installed under \`lib/bloom_ui/\` and a style preset pre-selected — no separate \`bloom ui init\` step needed.

## Quickstart
\`\`\`bash
bloom create my_app --template bloom-ui-starter-template
cd my_app
bloom dev
\`\`\`
That's it — \`bloom dev\` detects the Bloom project and its \`bloom.yaml\` automatically and launches the interactive dev server with hot reload.

Need more primitives later? Add them individually:
\`\`\`bash
bloom ui add button card dialog chart
\`\`\`
`,
      install_count: 640,
      created_at: new Date(Date.now() - 86400000 * 5).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 5).toISOString(),
    },
  ];

  public templateReviews: MockReview[] = [
    {
      id: "rev_001",
      template_id: "tmpl_001",
      buyer_organization_id: "org_acme_corp",
      rating: 5,
      title: "Saved our team weeks of auth setup",
      comment:
        "The Supabase integration is clean, and the Riverpod architecture is very easy to extend.",
      status: "published",
      author_response:
        "Thank you for the kind feedback! We will be releasing a Stripe billing extension next week.",
      author_responded_at: new Date(Date.now() - 86400000 * 2).toISOString(),
      created_at: new Date(Date.now() - 86400000 * 5).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 2).toISOString(),
    },
    {
      id: "rev_002",
      template_id: "tmpl_001",
      buyer_organization_id: "org_pulse_mobile",
      rating: 5,
      title: "Flawless on iOS and Web",
      comment:
        "Worked straight out of the box with Bloom Web Hosting preview deployments.",
      status: "published",
      author_response: null,
      author_responded_at: null,
      created_at: new Date(Date.now() - 86400000 * 12).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 12).toISOString(),
    },
    {
      id: "rev_003",
      template_id: "tmpl_002",
      buyer_organization_id: "org_retail_plus",
      rating: 4,
      title: "Great checkout flow, minor docs typo",
      comment:
        "The Stripe payment sheet implementation is solid. Docs could mention the required iOS pod setup more clearly.",
      status: "published",
      author_response:
        "Thanks! Updated the README in version 2.1.0 to clarify Podfile configurations.",
      author_responded_at: new Date(Date.now() - 86400000 * 4).toISOString(),
      created_at: new Date(Date.now() - 86400000 * 7).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 4).toISOString(),
    },
    {
      id: "rev_004",
      template_id: "tmpl_005",
      buyer_organization_id: "org_retail_plus",
      rating: 5,
      title: "Subscription billing done right",
      comment:
        "Webhook entitlement sync just worked. Saved us from writing our own Stripe reconciliation logic.",
      status: "published",
      author_response: null,
      author_responded_at: null,
      created_at: new Date(Date.now() - 86400000 * 3).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 3).toISOString(),
    },
    {
      id: "rev_005",
      template_id: "tmpl_007",
      buyer_organization_id: "org_acme_corp",
      rating: 5,
      title: "Best way to start a Bloom project",
      comment:
        "All 8 presets look great out of the box, and dark mode just worked with zero config.",
      status: "published",
      author_response: "Glad it's working well for you!",
      author_responded_at: new Date(Date.now() - 86400000 * 1).toISOString(),
      created_at: new Date(Date.now() - 86400000 * 3).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 1).toISOString(),
    },
  ];

  public templatePurchases: MockPurchase[] = [
    {
      id: "purch_001",
      buyer_organization_id: "00000000-0000-0000-0000-000000000010",
      template_id: "tmpl_002",
      template_name: "E-Commerce Mobile & Web Suite",
      template_version_id: "ver_003",
      seller_organization_id: "org_bloom_partners",
      amount: 4900,
      currency: "usd",
      platform_fee: 490,
      seller_amount: 4410,
      status: "succeeded",
      client_secret: null,
      created_at: new Date(Date.now() - 86400000 * 8).toISOString(),
    },
  ];

  public reviewReports: MockReviewReport[] = [];

  public getMarketplaceTemplates(
    search?: string,
    category?: string,
  ): MockTemplate[] {
    let list = this.templates.filter(
      (t) => t.status === "published" && t.visibility === "public",
    );
    if (search) {
      const q = search.toLowerCase();
      list = list.filter(
        (t) =>
          t.name.toLowerCase().includes(q) ||
          (t.description || "").toLowerCase().includes(q),
      );
    }
    if (category && category !== "all") {
      list = list.filter((t) => {
        const cat = (t.metadata as { category?: string })?.category;
        return cat === category;
      });
    }
    return list;
  }

  public getMarketplaceTemplate(id: string) {
    const tmpl = this.templates.find((t) => t.id === id || t.slug === id);
    if (!tmpl) return undefined;
    const versions = this.templateVersions
      .filter((v) => v.template_id === tmpl.id)
      .map((v) => ({
        id: v.id,
        version: v.version,
        changelog: v.changelog,
        install_count: v.install_count,
        created_at: v.created_at,
      }));
    return { ...tmpl, versions };
  }

  public getMarketplaceTemplateVersion(
    templateId: string,
    versionId: string,
  ): MockTemplateVersion | undefined {
    return this.templateVersions.find(
      (v) =>
        v.template_id === templateId &&
        (v.id === versionId || v.version === versionId),
    );
  }

  public purchaseTemplate(
    buyerOrgId: string,
    templateId: string,
    versionId?: string,
    _idempotencyKey?: string,
  ): MockPurchase {
    const tmpl = this.templates.find((t) => t.id === templateId);
    const amount = tmpl?.price_amount || 0;
    const platformFee = Math.round(amount * 0.1);
    const sellerAmount = amount - platformFee;

    const purchase: MockPurchase = {
      id: `purch_${Math.random().toString(16).slice(2, 8)}`,
      buyer_organization_id: buyerOrgId,
      template_id: templateId,
      template_name: tmpl?.name || "Template",
      template_version_id: versionId || null,
      seller_organization_id:
        tmpl?.organization_id || "00000000-0000-0000-0000-000000000010",
      amount,
      currency: tmpl?.price_currency || "usd",
      platform_fee: platformFee,
      seller_amount: sellerAmount,
      status: amount === 0 ? "succeeded" : "pending",
      client_secret:
        amount > 0
          ? `pi_test_${Math.random().toString(16).slice(2, 10)}_secret_${Math.random().toString(16).slice(2, 10)}`
          : null,
      created_at: new Date().toISOString(),
    };
    this.templatePurchases.unshift(purchase);
    return purchase;
  }

  public getTemplateReviews(templateId: string): MockReview[] {
    return this.templateReviews.filter(
      (r) => r.template_id === templateId && r.status === "published",
    );
  }

  public createTemplateReview(
    templateId: string,
    buyerOrgId: string,
    data: { rating: number; title?: string; comment?: string },
  ): MockReview {
    const review: MockReview = {
      id: `rev_${Math.random().toString(16).slice(2, 8)}`,
      template_id: templateId,
      buyer_organization_id: buyerOrgId,
      rating: data.rating,
      title: data.title || "",
      comment: data.comment || "",
      status: "published",
      author_response: null,
      author_responded_at: null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    this.templateReviews.unshift(review);

    // recalculate ratings
    const all = this.templateReviews.filter(
      (r) => r.template_id === templateId,
    );
    const tmpl = this.templates.find((t) => t.id === templateId);
    if (tmpl) {
      tmpl.rating_count = all.length;
      const sum = all.reduce((acc, cur) => acc + cur.rating, 0);
      tmpl.rating_bayesian_milli = Math.round((sum / all.length) * 1000);
    }

    return review;
  }

  public replyTemplateReview(
    reviewId: string,
    responseText: string,
  ): MockReview | undefined {
    const rev = this.templateReviews.find((r) => r.id === reviewId);
    if (!rev) return undefined;
    rev.author_response = responseText;
    rev.author_responded_at = new Date().toISOString();
    rev.updated_at = new Date().toISOString();
    return rev;
  }

  public reportTemplateReview(
    reviewId: string,
    reporterOrgId: string,
    reason: string,
    details?: string,
  ): MockReviewReport {
    const report: MockReviewReport = {
      id: `rep_${Math.random().toString(16).slice(2, 8)}`,
      review_id: reviewId,
      reporter_organization_id: reporterOrgId,
      reason,
      details: details || "",
      status: "pending",
      created_at: new Date().toISOString(),
    };
    this.reviewReports.push(report);
    return report;
  }

  public getPurchases(
    buyerOrgId: string,
    _cursor?: string,
  ): { results: MockPurchase[]; next_cursor: string | null } {
    const list = this.templatePurchases.filter(
      (p) => p.buyer_organization_id === buyerOrgId,
    );
    return {
      results: list,
      next_cursor: null,
    };
  }

  public refundPurchase(purchaseId: string, _reason?: string) {
    const purch = this.templatePurchases.find((p) => p.id === purchaseId);
    if (purch) {
      purch.status = "refunded";
    }
    return {
      purchase_id: purchaseId,
      stripe_refund_id: `re_${Math.random().toString(16).slice(2, 10)}`,
      amount: purch?.amount || 0,
      currency: purch?.currency || "usd",
      status: "succeeded",
    };
  }

  public getOrgTemplates(orgId: string): MockTemplate[] {
    return this.templates.filter((t) => t.organization_id === orgId);
  }

  public createOrgTemplate(
    orgId: string,
    data: Partial<MockTemplate>,
  ): MockTemplate {
    const id = `tmpl_${Math.random().toString(16).slice(2, 8)}`;
    const tmpl: MockTemplate = {
      id,
      organization_id: orgId,
      name: data.name || "Untitled Template",
      slug: (data.name || "untitled").toLowerCase().replace(/[^a-z0-9]+/g, "-"),
      description: data.description || null,
      visibility: data.visibility || "private",
      status: "draft",
      is_free: data.is_free ?? true,
      price_amount: data.price_amount || 0,
      price_currency: data.price_currency || "usd",
      metadata: data.metadata || {},
      latest_version: null,
      versions_count: 0,
      rating_count: 0,
      rating_bayesian_milli: 0,
      install_count: 0,
      featured_type: "none",
      is_featured: false,
      is_editorial_featured: false,
      is_paid_featured: false,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    this.templates.unshift(tmpl);
    return tmpl;
  }

  public updateOrgTemplate(
    id: string,
    data: Partial<MockTemplate>,
  ): MockTemplate | undefined {
    const tmpl = this.templates.find((t) => t.id === id);
    if (!tmpl) return undefined;
    Object.assign(tmpl, data, { updated_at: new Date().toISOString() });
    return tmpl;
  }

  public publishOrgTemplate(id: string): MockTemplate | undefined {
    const tmpl = this.templates.find((t) => t.id === id);
    if (!tmpl) return undefined;
    tmpl.status = "published";
    tmpl.visibility = "public";
    tmpl.updated_at = new Date().toISOString();
    return tmpl;
  }

  public archiveOrgTemplate(id: string): MockTemplate | undefined {
    const tmpl = this.templates.find((t) => t.id === id);
    if (!tmpl) return undefined;
    tmpl.status = "archived";
    tmpl.updated_at = new Date().toISOString();
    return tmpl;
  }

  public getTemplateVersions(templateId: string): MockTemplateVersion[] {
    return this.templateVersions.filter((v) => v.template_id === templateId);
  }

  public createTemplateVersion(
    templateId: string,
    data: {
      version: string;
      changelog?: string;
      manifest?: Record<string, unknown>;
      readme?: string;
    },
  ): MockTemplateVersion {
    const id = `ver_${Math.random().toString(16).slice(2, 8)}`;
    const ver: MockTemplateVersion = {
      id,
      template_id: templateId,
      version: data.version,
      changelog: data.changelog || "",
      manifest: data.manifest || {},
      readme: data.readme || "",
      install_count: 0,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    this.templateVersions.unshift(ver);

    const tmpl = this.templates.find((t) => t.id === templateId);
    if (tmpl) {
      tmpl.latest_version = data.version;
      tmpl.versions_count = this.templateVersions.filter(
        (v) => v.template_id === templateId,
      ).length;
    }

    return ver;
  }
}

// Global singleton for the server mock lifecycle
const globalForMock = global as unknown as { mockDataStore?: MockDataStore };
export const mockStore = globalForMock.mockDataStore ?? new MockDataStore();
if (process.env.NODE_ENV !== "production")
  globalForMock.mockDataStore = mockStore;
