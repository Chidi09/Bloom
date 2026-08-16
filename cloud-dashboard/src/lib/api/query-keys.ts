// Hierarchical, typed query keys — cloud-dashboard-frontend.md §5.2.
// One entry per resource in the route inventory (§21.1). Add new keys here, not inline in hooks.
export const queryKeys = {
  me: ["me"] as const,

  organizations: ["organizations"] as const,
  organization: (id: string) => ["organizations", id] as const,
  organizationMembers: (id: string) =>
    ["organizations", id, "members"] as const,

  projects: (orgId: string) => ["organizations", orgId, "projects"] as const,
  project: (id: string) => ["projects", id] as const,

  apps: (orgId: string) => ["organizations", orgId, "apps"] as const,
  app: (id: string) => ["apps", id] as const,

  environments: (appId: string) => ["apps", appId, "environments"] as const,
  environment: (id: string) => ["environments", id] as const,

  secrets: (environmentId: string) =>
    ["environments", environmentId, "secrets"] as const,
  secret: (id: string) => ["secrets", id] as const,

  credentials: (orgId: string) =>
    ["organizations", orgId, "credentials"] as const,
  credential: (id: string) => ["credentials", id] as const,

  signingIdentities: (appId: string) => ["apps", appId, "signing"] as const,

  gitConnections: (orgId: string) =>
    ["organizations", orgId, "git-connections"] as const,
  gitConnectionRepositories: (id: string) =>
    ["git-connections", id, "repositories"] as const,

  builds: (appId: string) => ["apps", appId, "builds"] as const,
  build: (id: string) => ["builds", id] as const,
  buildLogs: (id: string) => ["builds", id, "logs"] as const,

  artifacts: (appId: string) => ["apps", appId, "artifacts"] as const,

  releases: (appId: string) => ["apps", appId, "releases"] as const,
  release: (id: string) => ["releases", id] as const,

  deployments: (appId: string) => ["apps", appId, "deployments"] as const,
  deployment: (id: string) => ["deployments", id] as const,

  webDeployments: (appId: string) =>
    ["apps", appId, "webhosting", "deployments"] as const,
  webDeployment: (id: string) => ["webhosting", "deployments", id] as const,
  customDomains: (appId: string) =>
    ["apps", appId, "webhosting", "domains"] as const,

  workflows: (orgId: string) => ["organizations", orgId, "workflows"] as const,
  workflow: (id: string) => ["workflows", id] as const,
  workflowRuns: (workflowId: string) =>
    ["workflows", workflowId, "runs"] as const,

  observabilityAppStatus: (appId: string) =>
    ["observability", "apps", appId, "status"] as const,
  observabilityAppHealth: (appId: string) =>
    ["observability", "apps", appId, "health"] as const,
  observabilityReleaseHealth: (releaseId: string) =>
    ["observability", "releases", releaseId, "health"] as const,

  events: (orgId: string) => ["organizations", orgId, "events"] as const,

  billingPlans: ["billing", "plans"] as const,
  billingSubscription: (orgId: string) =>
    ["organizations", orgId, "billing", "subscription"] as const,
  billingInvoices: (orgId: string) =>
    ["organizations", orgId, "billing", "invoices"] as const,
  billingUsage: (orgId: string) =>
    ["organizations", orgId, "billing", "usage"] as const,

  marketplaceTemplates: ["marketplace", "templates"] as const,
  marketplaceTemplate: (id: string) =>
    ["marketplace", "templates", id] as const,
  orgTemplates: (orgId: string) =>
    ["organizations", orgId, "templates"] as const,
  marketplacePurchases: (orgId: string) =>
    ["organizations", orgId, "marketplace", "purchases"] as const,
  sellerAccount: (orgId: string) =>
    ["organizations", orgId, "marketplace", "seller"] as const,

  auditLog: (orgId: string) => ["organizations", orgId, "audit-log"] as const,

  apiTokens: ["account", "api-tokens"] as const,
  sessions: ["account", "sessions"] as const,
  notificationPreferences: ["account", "notification-preferences"] as const,
} as const;
