import { BuildStageResponse } from "./schemas/build";
import { ReleaseArtifact } from "./schemas/release";

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
  framework: "bloom" | "flutter";
  platforms: string[];
  repository_url: string | null;
  default_branch: string;
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
    framework: "bloom" | "flutter" = "bloom",
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
          stage: "compile",
          status: "running",
          started_at: new Date().toISOString(),
          finished_at: null,
          log_snippet: `Building for platform: ${platform}...`,
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

  public getBuild(id: string): MockBuild | undefined {
    return this.builds.find((b) => b.id === id);
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
      last_used_at: new Date(Date.now() - 3600000 * 2).toISOString(),
      created_at: new Date(Date.now() - 86400000 * 14).toISOString(),
    },
    {
      id: "tok_002",
      name: "GitHub Actions Deploy Key",
      last_used_at: new Date(Date.now() - 86400000 * 1).toISOString(),
      created_at: new Date(Date.now() - 86400000 * 30).toISOString(),
    },
  ];

  public getApiTokens(): MockApiToken[] {
    return this.apiTokens;
  }

  public createApiToken(name: string): {
    tokenRecord: MockApiToken;
    rawToken: string;
  } {
    const id = `tok_${Math.random().toString(16).slice(2, 10)}`;
    const rawToken = `blm_${Math.random().toString(36).slice(2, 10)}${Math.random().toString(36).slice(2, 10)}${Math.random().toString(36).slice(2, 10)}`;
    const tokenRecord: MockApiToken = {
      id,
      name,
      token: rawToken,
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
}

// Global singleton for the server mock lifecycle
const globalForMock = global as unknown as { mockDataStore?: MockDataStore };
export const mockStore = globalForMock.mockDataStore ?? new MockDataStore();
if (process.env.NODE_ENV !== "production")
  globalForMock.mockDataStore = mockStore;
