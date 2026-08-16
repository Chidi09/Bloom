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
  api_config: {
    env_vars: { key: string; value: string }[];
    feature_flags: { key: string; enabled: boolean }[];
  };
  created_at: string;
}

export interface MockBuild {
  id: string;
  app_id: string;
  app_name: string;
  build_number: number;
  platform: string;
  branch: string;
  commit_message: string;
  author: string;
  commit_hash: string;
  preview_url: string | null;
  status: "success" | "running" | "failed" | "queued";
  duration_seconds: number;
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
      created_at: new Date(Date.now() - 86400000 * 5).toISOString(),
    },
  ];

  public projects: MockProject[] = [
    {
      id: "00000000-0000-0000-0000-000000000020",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "Mobile Suite",
      slug: "mobile-suite",
      description: "Core Bloom Framework applications",
      created_at: new Date(Date.now() - 86400000 * 4).toISOString(),
      updated_at: new Date(Date.now() - 86400000 * 2).toISOString(),
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
      created_at: new Date(Date.now() - 86400000 * 4).toISOString(),
    },
    {
      id: "00000000-0000-0000-0000-000000000031",
      project_id: "00000000-0000-0000-0000-000000000020",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "flutter_dashboard",
      slug: "flutter-dashboard",
      framework: "flutter",
      platforms: ["web", "desktop"],
      repository_url: "https://github.com/bloom-labs/analytics",
      default_branch: "main",
      latest_release: "v2.0.0-rc.1",
      crash_free_rate: 99.9,
      created_at: new Date(Date.now() - 86400000 * 3).toISOString(),
    },
  ];

  public environments: MockEnvironment[] = [
    {
      id: "00000000-0000-0000-0000-000000000040",
      app_id: "00000000-0000-0000-0000-000000000030",
      organization_id: "00000000-0000-0000-0000-000000000010",
      name: "Production",
      slug: "production",
      api_config: { env_vars: [], feature_flags: [] },
      created_at: new Date(Date.now() - 86400000 * 4).toISOString(),
    },
  ];

  public builds: MockBuild[] = [
    {
      id: "bld_101",
      app_id: "00000000-0000-0000-0000-000000000030",
      app_name: "bloom_wallet",
      build_number: 142,
      platform: "iOS & Android",
      branch: "main",
      commit_message:
        "feat(mobile): add signals reactive state and offline sync queue",
      author: "Chidi09/wallet",
      commit_hash: "a4f89d1",
      preview_url: "wallet.bloom.dev",
      status: "success",
      duration_seconds: 145,
      created_at: new Date(Date.now() - 1000 * 60 * 18).toISOString(),
    },
    {
      id: "bld_102",
      app_id: "00000000-0000-0000-0000-000000000031",
      app_name: "flutter_dashboard",
      build_number: 88,
      platform: "Web",
      branch: "feat/charts",
      commit_message:
        "fix(web): improve chart rendering performance and memory allocation",
      author: "Chidi09/analytics",
      commit_hash: "7bc32f9",
      preview_url: "analytics.bloom.dev",
      status: "running",
      duration_seconds: 45,
      created_at: new Date(Date.now() - 1000 * 60 * 3).toISOString(),
    },
    {
      id: "bld_103",
      app_id: "00000000-0000-0000-0000-000000000030",
      app_name: "bloom_wallet",
      build_number: 140,
      platform: "iOS",
      branch: "fix/auth-flow",
      commit_message: "fix(auth): update session token refresh retry handler",
      author: "Chidi09/wallet",
      commit_hash: "96RNKXa",
      preview_url: "wallet-prev-96rnk.bloom.dev",
      status: "success",
      duration_seconds: 128,
      created_at: new Date(Date.now() - 1000 * 60 * 60 * 4).toISOString(),
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

  public createOrganization(name: string): MockOrganization {
    const slug = name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/(^-|-$)/g, "");
    const org: MockOrganization = {
      id: `org_${Date.now()}`,
      name,
      slug,
      plan: "free",
      role: "Owner",
      created_at: new Date().toISOString(),
    };
    this.organizations.unshift(org);
    return org;
  }

  public createProject(
    orgId: string,
    name: string,
    description?: string,
  ): MockProject {
    const slug = name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/(^-|-$)/g, "");
    const project: MockProject = {
      id: `prj_${Date.now()}`,
      organization_id: orgId,
      name,
      slug,
      description: description ?? null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    this.projects.unshift(project);
    return project;
  }

  public createApp(
    projectId: string,
    orgId: string,
    name: string,
    repositoryUrl?: string,
    framework: "bloom" | "flutter" = "bloom",
    platforms: string[] = ["ios", "android", "web"],
  ): MockApp {
    const slug = name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/(^-|-$)/g, "");
    const app: MockApp = {
      id: `app_${Date.now()}`,
      project_id: projectId,
      organization_id: orgId,
      name,
      slug,
      framework,
      platforms,
      repository_url: repositoryUrl ?? null,
      default_branch: "main",
      latest_release: "v0.1.0",
      crash_free_rate: 100.0,
      created_at: new Date().toISOString(),
    };
    this.apps.unshift(app);
    return app;
  }

  public createEnvironment(
    appId: string,
    orgId: string,
    name: string,
    slug: string,
  ): MockEnvironment {
    const env: MockEnvironment = {
      id: `env_${Date.now()}`,
      app_id: appId,
      organization_id: orgId,
      name,
      slug,
      api_config: { env_vars: [], feature_flags: [] },
      created_at: new Date().toISOString(),
    };
    this.environments.unshift(env);
    return env;
  }

  public createBuild(
    appId: string,
    _environmentId: string,
    platform: string,
  ): MockBuild {
    const app = this.apps.find((a) => a.id === appId);
    const build: MockBuild = {
      id: `bld_${Date.now()}`,
      app_id: appId,
      app_name: app?.name ?? "app",
      build_number: this.builds.filter((b) => b.app_id === appId).length + 1,
      platform,
      branch: app?.default_branch ?? "main",
      commit_message: "Manual cloud build triggered from dashboard",
      author: this.currentUser.username,
      commit_hash: Math.random().toString(36).slice(2, 9),
      preview_url: null,
      status: "queued",
      duration_seconds: 0,
      created_at: new Date().toISOString(),
    };
    this.builds.unshift(build);
    return build;
  }
}

// Global singleton for the server mock lifecycle
const globalForMock = global as unknown as { mockDataStore?: MockDataStore };
export const mockStore = globalForMock.mockDataStore ?? new MockDataStore();
if (process.env.NODE_ENV !== "production")
  globalForMock.mockDataStore = mockStore;
