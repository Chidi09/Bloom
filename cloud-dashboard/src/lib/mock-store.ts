import { BuildStageResponse } from "./schemas/build";

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
  api_config: {
    env_vars: { key: string; value: string }[];
    feature_flags: { key: string; enabled: boolean }[];
  };
  created_at: string;
  updated_at?: string;
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
    plan_name: "free",
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
      api_config: {
        env_vars: [{ key: "API_URL", value: "https://api.bloom.dev" }],
        feature_flags: [{ key: "enable_biometrics", enabled: true }],
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
      api_config: {
        env_vars: [{ key: "API_URL", value: "https://staging-api.bloom.dev" }],
        feature_flags: [{ key: "enable_biometrics", enabled: false }],
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
      api_config: { env_vars: [], feature_flags: [] },
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
      git_commit: "7bc32f9184019280194810294819028491028491",
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
      git_commit: "5e1029ab48f720194810294819028491028491a",
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
    {
      id: "00000000-0000-0000-0000-000000000056",
      app_id: "00000000-0000-0000-0000-000000000032",
      environment_id: "00000000-0000-0000-0000-000000000043",
      organization_id: "00000000-0000-0000-0000-000000000010",
      git_commit: "8f30291abc7482910294810294810294810abcd",
      git_branch: "main",
      git_ref: "refs/heads/main",
      status: "success",
      platform: "web",
      build_profile: "release",
      flutter_version: "3.27.0",
      dart_version: "3.6.0",
      bloom_version: "0.8.2",
      flavor: null,
      started_at: new Date(Date.now() - 1000 * 60 * 60 * 6).toISOString(),
      finished_at: new Date(
        Date.now() - 1000 * 60 * 60 * 6 + 1000 * 75,
      ).toISOString(),
      logs_url: "logs/builds/bld_portal_12.log",
      stages: [
        {
          stage: "checkout",
          status: "completed",
          started_at: new Date(Date.now() - 1000 * 60 * 60 * 6).toISOString(),
          finished_at: new Date(
            Date.now() - 1000 * 60 * 60 * 6 + 1000 * 10,
          ).toISOString(),
          log_snippet: "Checked out main (8f30291)",
        },
        {
          stage: "compile",
          status: "completed",
          started_at: new Date(
            Date.now() - 1000 * 60 * 60 * 6 + 1000 * 10,
          ).toISOString(),
          finished_at: new Date(
            Date.now() - 1000 * 60 * 60 * 6 + 1000 * 65,
          ).toISOString(),
          log_snippet: "Building Flutter Web release bundle for portal...",
        },
        {
          stage: "artifact_upload",
          status: "completed",
          started_at: new Date(
            Date.now() - 1000 * 60 * 60 * 6 + 1000 * 65,
          ).toISOString(),
          finished_at: new Date(
            Date.now() - 1000 * 60 * 60 * 6 + 1000 * 75,
          ).toISOString(),
          log_snippet: "Deployed to portal.bloom.dev via Web Hosting.",
        },
      ],
      created_at: new Date(Date.now() - 1000 * 60 * 60 * 6).toISOString(),
      updated_at: new Date(
        Date.now() - 1000 * 60 * 60 * 6 + 1000 * 75,
      ).toISOString(),
      app_name: "bloom_web_portal",
      build_number: 12,
      commit_message: "feat(pricing): ship new pricing page behind flag",
      author: "dev",
      commit_hash: "8f30291",
      preview_url: "portal.bloom.dev",
      duration_seconds: 75,
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
    return true;
  }

  // Environments
  public createEnvironment(
    appId: string,
    orgId: string,
    name: string,
    slug: string,
    buildProfile: string = "release",
  ): MockEnvironment {
    const id = `00000000-0000-0000-0000-${Math.random().toString(16).slice(2, 14).padEnd(12, "0")}`;
    const env: MockEnvironment = {
      id,
      app_id: appId,
      organization_id: orgId,
      name,
      slug,
      build_profile: buildProfile,
      api_config: { env_vars: [], feature_flags: [] },
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    this.environments.unshift(env);
    return env;
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
}

// Global singleton for the server mock lifecycle
const globalForMock = global as unknown as { mockDataStore?: MockDataStore };
export const mockStore = globalForMock.mockDataStore ?? new MockDataStore();
if (process.env.NODE_ENV !== "production")
  globalForMock.mockDataStore = mockStore;
