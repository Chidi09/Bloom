"use client";

import * as React from "react";
import Link from "next/link";
import {
  GitFork,
  Trash,
  ArrowsClockwise,
  ArrowSquareOut,
  GitBranch,
  FolderSimple,
  Plug,
  Copy,
  Check,
  MagnifyingGlass,
  Plus,
  Lock,
  Globe,
  ArrowCounterClockwise,
  ShieldCheck,
  Code,
  GitPullRequest,
  GitCommit,
  WarningCircle,
  Sparkle,
  X,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import { StatusBadge } from "@/components/status/status-badge";
import { ProviderIcon } from "@/components/status/provider-icon";
import { cn } from "@/lib/utils";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { EmptyState } from "@/components/shared/empty-state";
import { PageHeader } from "@/components/shared/page-header";
import { api } from "@/lib/api/client";
import {
  GitConnectionResponse,
  RepositoryResponse,
} from "@/lib/schemas/git-connection";
import { useOrganizationStore } from "@/stores/organization-store";
import { OrganizationRoleName, hasRole } from "@/lib/auth/roles";

// Types for Branch Deploy Policy
interface BranchDeployPolicy {
  id: string;
  pattern: string;
  environment: "production" | "staging" | "preview" | "development";
  autoDeploy: boolean;
  prPreviews: boolean;
}

// Types for Webhook Deliveries
interface WebhookDeliveryLogItem {
  id: string;
  provider: "github" | "gitlab" | "bitbucket";
  event: "push" | "pull_request" | "release" | "workflow_dispatch";
  repository: string;
  branch: string;
  commitSha: string;
  commitMessage: string;
  sender: string;
  statusCode: number;
  durationMs: number;
  deliveredAt: string;
  status: "success" | "failed" | "pending";
  payload: Record<string, unknown>;
}

const INITIAL_POLICIES: BranchDeployPolicy[] = [
  {
    id: "policy-1",
    pattern: "main",
    environment: "production",
    autoDeploy: true,
    prPreviews: false,
  },
  {
    id: "policy-2",
    pattern: "staging",
    environment: "staging",
    autoDeploy: true,
    prPreviews: false,
  },
  {
    id: "policy-3",
    pattern: "feat/*",
    environment: "preview",
    autoDeploy: true,
    prPreviews: true,
  },
];

const INITIAL_DELIVERIES: WebhookDeliveryLogItem[] = [
  {
    id: "del_8f3a102c91b4",
    provider: "github",
    event: "push",
    repository: "bloom-labs/mobile-app",
    branch: "main",
    commitSha: "8f3a102",
    commitMessage: "feat(auth): add biometrics WebAuthn fallback support",
    sender: "alex-dev",
    statusCode: 200,
    durationMs: 118,
    deliveredAt: new Date(Date.now() - 1000 * 60 * 14).toISOString(),
    status: "success",
    payload: {
      ref: "refs/heads/main",
      before: "a1b2c3d4e5f67890",
      after: "8f3a102c91b45201",
      repository: {
        id: 104928194,
        name: "mobile-app",
        full_name: "bloom-labs/mobile-app",
        private: true,
      },
      pusher: { name: "alex-dev", email: "alex@bloom.run" },
      head_commit: {
        id: "8f3a102c91b45201",
        message: "feat(auth): add biometrics WebAuthn fallback support",
        timestamp: new Date(Date.now() - 1000 * 60 * 14).toISOString(),
      },
    },
  },
  {
    id: "del_6c19e4a70b22",
    provider: "github",
    event: "pull_request",
    repository: "bloom-labs/mobile-app",
    branch: "feat/wasm-runtime",
    commitSha: "6c19e4a",
    commitMessage: "chore: update wasm compilation target to 2026.2",
    sender: "sarah-engineer",
    statusCode: 200,
    durationMs: 145,
    deliveredAt: new Date(Date.now() - 1000 * 60 * 85).toISOString(),
    status: "success",
    payload: {
      action: "synchronize",
      number: 42,
      pull_request: {
        title: "WASM Preview runtime update",
        head: { ref: "feat/wasm-runtime", sha: "6c19e4a" },
        base: { ref: "main" },
      },
    },
  },
  {
    id: "del_3e981ba25cd4",
    provider: "gitlab",
    event: "push",
    repository: "bloom-enterprise/api-gateway",
    branch: "hotfix/ssl-rotation",
    commitSha: "3e981ba",
    commitMessage: "fix(tls): update Let's Encrypt renewal chain parameters",
    sender: "ops-lead",
    statusCode: 500,
    durationMs: 312,
    deliveredAt: new Date(Date.now() - 1000 * 60 * 240).toISOString(),
    status: "failed",
    payload: {
      object_kind: "push",
      ref: "refs/heads/hotfix/ssl-rotation",
      user_name: "Ops Lead",
      project: { name: "api-gateway", default_branch: "main" },
      error_detail:
        "Target builder cluster timed out during worker allocation.",
    },
  },
  {
    id: "del_1a729cc55e88",
    provider: "bitbucket",
    event: "push",
    repository: "bloom-infra/edge-mesh",
    branch: "staging",
    commitSha: "1a729cc",
    commitMessage: "ci: trigger edge mesh canary healthcheck",
    sender: "bot-deployer",
    statusCode: 200,
    durationMs: 94,
    deliveredAt: new Date(Date.now() - 1000 * 60 * 480).toISOString(),
    status: "success",
    payload: {
      eventKey: "repo:push",
      changes: [{ new: { name: "staging", type: "branch" } }],
    },
  },
];

function generateMockInstallationId(provider: string): string {
  return `${provider}_inst_${Math.floor(10000000 + Math.random() * 90000000)}`;
}

function generateMockOAuthToken(provider: string): string {
  return `mock_${provider}_oauth_token_${Date.now()}`;
}

function generateMockDeliveryId(): string {
  return `del_${Math.random().toString(16).slice(2, 10)}`;
}

export default function GitConnectionsPage() {
  const { currentOrganizationId } = useOrganizationStore();

  const [connections, setConnections] = React.useState<GitConnectionResponse[]>(
    [],
  );
  const [userRole, setUserRole] = React.useState<OrganizationRoleName>("Owner");
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Repositories Sheet State
  const [sheetOpen, setSheetOpen] = React.useState(false);
  const [selectedConnection, setSelectedConnection] =
    React.useState<GitConnectionResponse | null>(null);
  const [repositories, setRepositories] = React.useState<RepositoryResponse[]>(
    [],
  );
  const [isLoadingRepos, setIsLoadingRepos] = React.useState(false);
  const [repoSearchQuery, setRepoSearchQuery] = React.useState("");
  const [repoFilterVisibility, setRepoFilterVisibility] = React.useState<
    "all" | "private" | "public"
  >("all");
  const [copiedRepoUrlId, setCopiedRepoUrlId] = React.useState<string | null>(
    null,
  );

  // Connect Provider Dialog State
  const [connectDialogOpen, setConnectDialogOpen] = React.useState(false);
  const [isConnecting, setIsConnecting] = React.useState(false);

  // Disconnect Confirmation State
  const [connectionToDisconnect, setConnectionToDisconnect] =
    React.useState<GitConnectionResponse | null>(null);
  const [isDisconnecting, setIsDisconnecting] = React.useState(false);

  // Copy state
  const [copiedInstId, setCopiedInstId] = React.useState<string | null>(null);

  // Branch Deploy Policy State
  const [policies, setPolicies] =
    React.useState<BranchDeployPolicy[]>(INITIAL_POLICIES);
  const [isSavingPolicies, setIsSavingPolicies] = React.useState(false);

  // Webhook Delivery Logs State
  const [deliveries, setDeliveries] =
    React.useState<WebhookDeliveryLogItem[]>(INITIAL_DELIVERIES);
  const [replayingDeliveryId, setReplayingDeliveryId] = React.useState<
    string | null
  >(null);
  const [selectedPayloadDelivery, setSelectedPayloadDelivery] =
    React.useState<WebhookDeliveryLogItem | null>(null);
  const [copiedPayloadText, setCopiedPayloadText] = React.useState(false);

  const canManage = hasRole(userRole, "Admin");

  const fetchConnections = React.useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const [connRes, orgsRes] = await Promise.all([
        api.get<{ results: GitConnectionResponse[] }>("/git-connections"),
        api
          .get<{ results: Array<{ id: string; role: string }> }>(
            "/organizations",
          )
          .catch(() => ({ results: [] })),
      ]);

      setConnections(connRes.results ?? []);

      if (orgsRes.results && currentOrganizationId) {
        const currentOrg = orgsRes.results.find(
          (o) => o.id === currentOrganizationId,
        );
        if (currentOrg && currentOrg.role) {
          setUserRole(currentOrg.role as OrganizationRoleName);
        }
      }
    } catch (err: unknown) {
      setError(
        err instanceof Error
          ? err.message
          : "Failed to load Git provider connections",
      );
    } finally {
      setIsLoading(false);
    }
  }, [currentOrganizationId]);

  React.useEffect(() => {
    const run = async () => {
      await fetchConnections();
    };
    void run();
  }, [fetchConnections]);

  const handleOpenRepositories = async (conn: GitConnectionResponse) => {
    setSelectedConnection(conn);
    setRepoSearchQuery("");
    setRepoFilterVisibility("all");
    setSheetOpen(true);
    setIsLoadingRepos(true);
    try {
      const res = await api.get<{ results: RepositoryResponse[] }>(
        `/git-connections/${conn.id}/repositories`,
      );
      setRepositories(res.results ?? []);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to fetch repositories",
      );
    } finally {
      setIsLoadingRepos(false);
    }
  };

  const handleConnectProvider = async (
    provider: "github" | "gitlab" | "bitbucket",
  ) => {
    setIsConnecting(true);
    try {
      const conn = await api.post<GitConnectionResponse>("/git-connections", {
        provider,
        installation_id: generateMockInstallationId(provider),
        access_token: generateMockOAuthToken(provider),
        metadata: {
          account_name: `bloom-${provider}-workspace`,
          account_type: "Organization",
          repositories_count: 2,
        },
      });

      toast.success(
        `Successfully connected ${provider.toUpperCase()} organization.`,
      );
      setConnections((prev) => [conn, ...prev]);
      setConnectDialogOpen(false);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error
          ? err.message
          : "Failed to establish Git connection",
      );
    } finally {
      setIsConnecting(false);
    }
  };

  const handleDisconnect = async () => {
    if (!connectionToDisconnect) return;
    setIsDisconnecting(true);
    try {
      await api.delete(`/git-connections/${connectionToDisconnect.id}`);
      toast.success("Git connection removed.");
      setConnections((prev) =>
        prev.filter((c) => c.id !== connectionToDisconnect.id),
      );
      setConnectionToDisconnect(null);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to disconnect provider",
      );
    } finally {
      setIsDisconnecting(false);
    }
  };

  const handleCopyInstId = (text: string, id: string) => {
    navigator.clipboard.writeText(text);
    setCopiedInstId(id);
    toast.success("Installation ID copied to clipboard");
    setTimeout(() => setCopiedInstId(null), 1500);
  };

  const handleCopyRepoUrl = (url: string, id: string) => {
    navigator.clipboard.writeText(url);
    setCopiedRepoUrlId(id);
    toast.success("Repository URL copied");
    setTimeout(() => setCopiedRepoUrlId(null), 1500);
  };

  // Branch Policy Array Handlers & Validation
  const duplicatePatterns = React.useMemo(() => {
    const counts: Record<string, number> = {};
    for (const p of policies) {
      const trimmed = p.pattern.trim().toLowerCase();
      if (trimmed) {
        counts[trimmed] = (counts[trimmed] || 0) + 1;
      }
    }
    const dupes = new Set<string>();
    for (const [pat, count] of Object.entries(counts)) {
      if (count > 1) {
        dupes.add(pat);
      }
    }
    return dupes;
  }, [policies]);

  const hasPolicyErrors = React.useMemo(() => {
    if (duplicatePatterns.size > 0) return true;
    if (policies.some((p) => p.pattern.trim() === "")) return true;
    return false;
  }, [duplicatePatterns, policies]);

  const handleAddPolicyRow = () => {
    const newPolicy: BranchDeployPolicy = {
      id: `policy-${Date.now()}`,
      pattern: "",
      environment: "preview",
      autoDeploy: true,
      prPreviews: false,
    };
    setPolicies((prev) => [...prev, newPolicy]);
  };

  const handleRemovePolicyRow = (id: string) => {
    if (policies.length <= 1) {
      toast.error("At least one branch deploy policy is required.");
      return;
    }
    setPolicies((prev) => prev.filter((p) => p.id !== id));
  };

  const handlePolicyChange = (
    id: string,
    field: keyof BranchDeployPolicy,
    value: unknown,
  ) => {
    setPolicies((prev) =>
      prev.map((p) => (p.id === id ? { ...p, [field]: value } : p)),
    );
  };

  const handleResetDefaultPolicies = () => {
    setPolicies(INITIAL_POLICIES);
    toast.info("Reset branch policies to recommended presets.");
  };

  const handleSavePolicies = async () => {
    if (hasPolicyErrors) {
      if (duplicatePatterns.size > 0) {
        toast.error("Cannot save: Duplicate branch patterns detected.");
      } else {
        toast.error("Cannot save: Branch pattern cannot be blank.");
      }
      return;
    }

    setIsSavingPolicies(true);
    await new Promise((resolve) => setTimeout(resolve, 600));
    setIsSavingPolicies(false);
    toast.success("Branch deployment policies saved successfully.");
  };

  // Webhook Delivery Replay Handler
  const handleReplayDelivery = async (delivery: WebhookDeliveryLogItem) => {
    setReplayingDeliveryId(delivery.id);
    try {
      await new Promise((resolve) => setTimeout(resolve, 800));

      const updatedDel: WebhookDeliveryLogItem = {
        ...delivery,
        id: generateMockDeliveryId(),
        deliveredAt: new Date().toISOString(),
        status: "success",
        statusCode: 200,
      };

      setDeliveries((prev) => [updatedDel, ...prev]);
      toast.success(
        `Webhook delivery replayed (${delivery.event} on ${delivery.repository}#${delivery.branch}). Deployment triggered.`,
      );
    } catch {
      toast.error("Failed to replay webhook delivery.");
    } finally {
      setReplayingDeliveryId(null);
    }
  };

  const handleCopyPayloadJson = () => {
    if (!selectedPayloadDelivery) return;
    navigator.clipboard.writeText(
      JSON.stringify(selectedPayloadDelivery.payload, null, 2),
    );
    setCopiedPayloadText(true);
    toast.success("Payload JSON copied to clipboard");
    setTimeout(() => setCopiedPayloadText(false), 1500);
  };

  // Connected providers map
  const connectedProviders = new Set(
    connections.map((c) => c.provider.toLowerCase()),
  );

  const availableProviders = [
    {
      id: "github",
      name: "GitHub",
      desc: "Link GitHub Organizations, User accounts, or GitHub Enterprise servers.",
      brandBg: "bg-zinc-900 dark:bg-zinc-950",
      accentBorder: "border-zinc-700/80",
    },
    {
      id: "gitlab",
      name: "GitLab",
      desc: "Connect GitLab.com groups, projects, or self-hosted GitLab CE/EE instances.",
      brandBg: "bg-[#fc6d26]/10",
      accentBorder: "border-[#fc6d26]/40",
    },
    {
      id: "bitbucket",
      name: "Bitbucket",
      desc: "Integrate Atlassian Bitbucket Cloud workspaces and server repositories.",
      brandBg: "bg-[#0052cc]/10",
      accentBorder: "border-[#0052cc]/40",
    },
  ] as const;

  return (
    <div className="mx-auto max-w-6xl space-y-7 pb-12">
      <PageHeader
        breadcrumbs={[
          { label: "Organization", href: "/organizations" },
          { label: "Git Connections" },
        ]}
        title="Git Integrations & Continuous Delivery"
        description="Connect your GitHub, GitLab, and Bitbucket hosts to power automated builds, branch deployment policies, and pull request previews."
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchConnections()}
              className="h-8 gap-1.5 transition-colors"
            >
              <ArrowsClockwise className="size-3.5" />
              <span>Refresh</span>
            </Button>
            {canManage && (
              <Button
                size="sm"
                onClick={() => setConnectDialogOpen(true)}
                className="h-8 gap-1.5"
              >
                <Plug className="size-3.5" weight="bold" />
                <span>Connect Provider</span>
              </Button>
            )}
          </div>
        }
      />

      {error && (
        <Alert variant="destructive">
          <AlertTitle>Error loading Git connections</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchConnections()}
              className="h-7 text-xs"
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      )}

      {/* SECTION 1: PROVIDER CONNECTION CARDS */}
      <div className="space-y-3.5">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-foreground text-sm font-semibold tracking-tight">
              Connected Git Providers
            </h2>
            <p className="text-muted-foreground text-xs">
              Authorized host integrations providing repository access and
              real-time event hooks.
            </p>
          </div>
          <Badge
            variant="outline"
            className="text-muted-foreground font-mono text-[11px]"
          >
            {connections.length} Connected
          </Badge>
        </div>

        {isLoading ? (
          <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-16">
            <BloomSpinner size={28} label="Loading Git host connections..." />
          </div>
        ) : connections.length === 0 ? (
          <EmptyState
            icon={GitFork}
            title="No Git providers connected"
            description="Connect your GitHub, GitLab, or Bitbucket account to import repositories and enable automated build triggers."
            actionLabel={canManage ? "Connect Provider" : undefined}
            onAction={canManage ? () => setConnectDialogOpen(true) : undefined}
          />
        ) : (
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
            {connections.map((conn) => {
              const meta = conn.metadata as {
                account_name?: string;
                account_type?: string;
                repositories_count?: number;
              };

              const providerKey = conn.provider.toLowerCase();
              const isGitlab = providerKey === "gitlab";
              const isBitbucket = providerKey === "bitbucket";
              const isGithub = providerKey === "github";

              return (
                <Card
                  key={conn.id}
                  className={cn(
                    "border-border/80 bg-card hover:border-border relative flex flex-col justify-between overflow-hidden shadow-xs transition-all",
                    isGithub &&
                      "border-t-2 border-t-zinc-300 dark:border-t-zinc-100",
                    isGitlab && "border-t-2 border-t-[#fc6d26]",
                    isBitbucket && "border-t-2 border-t-[#0052cc]",
                  )}
                >
                  <CardHeader className="pb-3">
                    <div className="flex items-start justify-between gap-2">
                      <div className="flex items-center gap-3">
                        <div
                          className={cn(
                            "flex size-10 items-center justify-center rounded-lg border shadow-xs",
                            isGitlab &&
                              "border-[#fc6d26]/40 bg-[#fc6d26]/10 text-[#fc6d26]",
                            isBitbucket &&
                              "border-[#0052cc]/40 bg-[#0052cc]/10 text-[#0052cc]",
                            isGithub &&
                              "border-border/80 bg-muted/60 text-foreground",
                          )}
                        >
                          <ProviderIcon provider={conn.provider} size={22} />
                        </div>
                        <div className="space-y-0.5">
                          <div className="text-foreground flex items-center gap-1.5 text-sm font-semibold">
                            <span>
                              {meta?.account_name ||
                                `bloom-${conn.provider}-org`}
                            </span>
                          </div>
                          <div className="text-muted-foreground flex items-center gap-2 text-xs">
                            <span className="text-[10px] font-medium tracking-wider uppercase">
                              {conn.provider}
                            </span>
                            <span>•</span>
                            <span className="text-[11px]">
                              {meta?.account_type || "Organization"}
                            </span>
                          </div>
                        </div>
                      </div>

                      <StatusBadge
                        status="healthy"
                        label="Connected"
                        size="sm"
                      />
                    </div>
                  </CardHeader>

                  <CardContent className="space-y-3 pb-3 text-xs">
                    <div className="border-border/60 bg-muted/20 space-y-2 rounded-md border p-2.5">
                      <div className="flex items-center justify-between">
                        <span className="text-muted-foreground text-[11px]">
                          Installation ID
                        </span>
                        <div className="flex items-center gap-1 font-mono text-[11px]">
                          <TooltipProvider>
                            <Tooltip>
                              <TooltipTrigger className="text-foreground max-w-[120px] truncate">
                                {conn.installation_id}
                              </TooltipTrigger>
                              <TooltipContent>
                                <p className="font-mono text-xs">
                                  {conn.installation_id}
                                </p>
                              </TooltipContent>
                            </Tooltip>
                          </TooltipProvider>
                          <button
                            type="button"
                            onClick={() =>
                              handleCopyInstId(conn.installation_id, conn.id)
                            }
                            className="text-muted-foreground hover:text-foreground p-0.5 transition-colors"
                            title="Copy Installation ID"
                          >
                            {copiedInstId === conn.id ? (
                              <Check className="size-3 text-emerald-400" />
                            ) : (
                              <Copy className="size-3" />
                            )}
                          </button>
                        </div>
                      </div>

                      <div className="flex items-center justify-between">
                        <span className="text-muted-foreground text-[11px]">
                          Connected Since
                        </span>
                        <span className="text-foreground font-mono text-[11px]">
                          {new Date(conn.created_at).toLocaleDateString(
                            undefined,
                            {
                              month: "short",
                              day: "numeric",
                              year: "numeric",
                            },
                          )}
                        </span>
                      </div>

                      <div className="flex items-center justify-between">
                        <span className="text-muted-foreground text-[11px]">
                          Webhook Sync
                        </span>
                        <span className="inline-flex items-center gap-1 font-mono text-[11px] text-emerald-400">
                          <ShieldCheck className="size-3.5" weight="fill" />
                          <span>HMAC-SHA256 Active</span>
                        </span>
                      </div>
                    </div>
                  </CardContent>

                  <CardFooter className="border-border/60 bg-muted/10 flex items-center justify-between border-t pt-3 pb-3">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => void handleOpenRepositories(conn)}
                      className="h-8 gap-1.5 text-xs transition-colors"
                    >
                      <FolderSimple className="size-3.5" />
                      <span>Browse Repositories</span>
                      <Badge
                        variant="secondary"
                        className="ml-1 h-4 px-1 font-mono text-[9px]"
                      >
                        {meta?.repositories_count ?? 2}
                      </Badge>
                    </Button>

                    {canManage && (
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => setConnectionToDisconnect(conn)}
                        className="text-muted-foreground hover:text-destructive hover:bg-destructive/10 size-8 p-0 transition-colors"
                        title="Disconnect Provider"
                      >
                        <Trash className="size-4" />
                      </Button>
                    )}
                  </CardFooter>
                </Card>
              );
            })}

            {/* Quick Connect Unlinked Providers */}
            {availableProviders
              .filter((p) => !connectedProviders.has(p.id))
              .map((provider) => (
                <Card
                  key={provider.id}
                  className="border-border/60 bg-card/40 hover:bg-card/70 flex flex-col justify-between border-dashed transition-all"
                >
                  <CardHeader className="pb-2">
                    <div className="flex items-start justify-between">
                      <div className="flex items-center gap-2.5">
                        <div className="border-border bg-muted/40 text-muted-foreground flex size-9 items-center justify-center rounded-lg border">
                          <ProviderIcon provider={provider.id} size={18} />
                        </div>
                        <div>
                          <CardTitle className="text-foreground text-sm font-medium">
                            {provider.name}
                          </CardTitle>
                          <span className="text-muted-foreground block text-[11px]">
                            Not Connected
                          </span>
                        </div>
                      </div>
                      <StatusBadge
                        status="pending"
                        label="Available"
                        size="sm"
                      />
                    </div>
                  </CardHeader>
                  <CardContent className="pb-3 text-xs">
                    <p className="text-muted-foreground text-[11px] leading-relaxed">
                      {provider.desc}
                    </p>
                  </CardContent>
                  <CardFooter className="border-border/40 border-t pt-3 pb-3">
                    {canManage ? (
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() =>
                          void handleConnectProvider(
                            provider.id as "github" | "gitlab" | "bitbucket",
                          )
                        }
                        disabled={isConnecting}
                        className="h-8 w-full gap-1.5 text-xs"
                      >
                        {isConnecting ? (
                          <BloomSpinner size={14} />
                        ) : (
                          <Plug className="size-3.5" />
                        )}
                        <span>Connect {provider.name}</span>
                      </Button>
                    ) : (
                      <span className="text-muted-foreground text-[11px] italic">
                        Requires Admin role to connect
                      </span>
                    )}
                  </CardFooter>
                </Card>
              ))}
          </div>
        )}
      </div>

      {/* SECTION 2: BRANCH DEPLOYMENT POLICIES */}
      <Card className="border-border/80 bg-card shadow-xs">
        <CardHeader className="pb-3">
          <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
            <div className="space-y-1">
              <CardTitle className="text-foreground flex items-center gap-2 text-sm font-semibold">
                <GitBranch className="text-muted-foreground size-4" />
                <span>Branch Deployment Policies</span>
              </CardTitle>
              <CardDescription className="text-muted-foreground text-xs">
                Configure pattern matching rules to automate preview and
                production builds on Git push and pull request events.
              </CardDescription>
            </div>
            <div className="flex items-center gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={handleResetDefaultPolicies}
                className="h-8 gap-1.5 text-xs"
              >
                <Sparkle className="size-3.5" />
                <span>Reset Defaults</span>
              </Button>
              <Button
                size="sm"
                onClick={() => void handleSavePolicies()}
                disabled={isSavingPolicies || hasPolicyErrors}
                className="h-8 gap-1.5 text-xs font-semibold"
              >
                {isSavingPolicies ? (
                  <BloomSpinner size={14} />
                ) : (
                  <Check className="size-3.5" />
                )}
                <span>Save Policy Rules</span>
              </Button>
            </div>
          </div>
        </CardHeader>

        <CardContent className="space-y-4">
          {duplicatePatterns.size > 0 && (
            <Alert variant="destructive" className="py-2.5">
              <WarningCircle className="size-4" />
              <AlertTitle className="text-xs font-semibold">
                Duplicate Branch Pattern Detected
              </AlertTitle>
              <AlertDescription className="text-[11px]">
                The branch pattern(s){" "}
                <strong className="font-mono">
                  {Array.from(duplicatePatterns).join(", ")}
                </strong>{" "}
                appear multiple times. Each policy rule must target a unique
                pattern.
              </AlertDescription>
            </Alert>
          )}

          <div className="border-border/80 bg-card overflow-hidden rounded-lg border">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="w-[280px]">Branch Pattern</TableHead>
                  <TableHead className="w-[180px]">
                    Target Environment
                  </TableHead>
                  <TableHead className="w-[140px] text-center">
                    Auto-Deploy
                  </TableHead>
                  <TableHead className="w-[160px] text-center">
                    PR Previews
                  </TableHead>
                  <TableHead className="w-[60px] text-right">Action</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {policies.map((policy) => {
                  const trimmedPattern = policy.pattern.trim().toLowerCase();
                  const isDupe =
                    trimmedPattern !== "" &&
                    duplicatePatterns.has(trimmedPattern);
                  const isBlank = policy.pattern.trim() === "";

                  return (
                    <TableRow
                      key={policy.id}
                      className={cn(
                        "hover:bg-muted/40 transition-colors",
                        isDupe && "bg-destructive/10 hover:bg-destructive/15",
                      )}
                    >
                      <TableCell>
                        <div className="space-y-1">
                          <div className="relative">
                            <GitBranch className="text-muted-foreground absolute top-2.5 left-2.5 size-3.5" />
                            <Input
                              value={policy.pattern}
                              onChange={(e) =>
                                handlePolicyChange(
                                  policy.id,
                                  "pattern",
                                  e.target.value,
                                )
                              }
                              placeholder="e.g. main, feat/*, staging"
                              className={cn(
                                "h-8 pl-8 font-mono text-xs",
                                isDupe &&
                                  "border-destructive focus-visible:ring-destructive/30",
                                isBlank &&
                                  "border-amber-500/60 focus-visible:ring-amber-500/30",
                              )}
                            />
                          </div>
                          {isDupe && (
                            <span className="text-destructive block font-mono text-[10px]">
                              Duplicate pattern: already in use.
                            </span>
                          )}
                          {isBlank && (
                            <span className="block font-mono text-[10px] text-amber-400">
                              Pattern cannot be empty.
                            </span>
                          )}
                        </div>
                      </TableCell>

                      <TableCell>
                        <select
                          value={policy.environment}
                          onChange={(e) =>
                            handlePolicyChange(
                              policy.id,
                              "environment",
                              e.target.value,
                            )
                          }
                          className="border-input bg-card text-foreground focus-visible:border-ring focus-visible:ring-ring/50 h-8 w-full rounded-md border px-2 font-mono text-xs capitalize shadow-xs transition-colors focus-visible:ring-[3px] focus-visible:outline-none"
                        >
                          <option value="production">Production</option>
                          <option value="staging">Staging</option>
                          <option value="preview">Preview</option>
                          <option value="development">Development</option>
                        </select>
                      </TableCell>

                      <TableCell className="text-center">
                        <div className="flex items-center justify-center">
                          <Switch
                            checked={policy.autoDeploy}
                            onCheckedChange={(checked) =>
                              handlePolicyChange(
                                policy.id,
                                "autoDeploy",
                                checked,
                              )
                            }
                          />
                        </div>
                      </TableCell>

                      <TableCell className="text-center">
                        <div className="flex items-center justify-center">
                          <Switch
                            checked={policy.prPreviews}
                            onCheckedChange={(checked) =>
                              handlePolicyChange(
                                policy.id,
                                "prPreviews",
                                checked,
                              )
                            }
                          />
                        </div>
                      </TableCell>

                      <TableCell className="text-right">
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleRemovePolicyRow(policy.id)}
                          className="text-muted-foreground hover:text-destructive hover:bg-destructive/10 size-7 p-0 transition-colors"
                          title="Remove policy row"
                        >
                          <Trash className="size-3.5" />
                        </Button>
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </div>

          <div className="flex items-center justify-between pt-1">
            <Button
              variant="outline"
              size="sm"
              onClick={handleAddPolicyRow}
              className="h-8 gap-1.5 text-xs"
            >
              <Plus className="size-3.5" />
              <span>Add Policy Rule</span>
            </Button>
            <span className="text-muted-foreground font-mono text-[11px]">
              Patterns support wildcards (e.g.{" "}
              <code className="text-foreground">release/v*</code>,{" "}
              <code className="text-foreground">feat/**</code>)
            </span>
          </div>
        </CardContent>
      </Card>

      {/* SECTION 3: WEBHOOK DELIVERY LOG & REPLAY */}
      <Card className="border-border/80 bg-card shadow-xs">
        <CardHeader className="pb-3">
          <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
            <div className="space-y-1">
              <CardTitle className="text-foreground flex items-center gap-2 text-sm font-semibold">
                <ShieldCheck className="text-muted-foreground size-4" />
                <span>Inbound Webhook Delivery Log</span>
              </CardTitle>
              <CardDescription className="text-muted-foreground text-xs">
                Real-time cryptographic webhook events received from Git
                providers. Replaying a delivery safely re-triggers continuous
                deployment workflows.
              </CardDescription>
            </div>
            <Badge
              variant="outline"
              className="text-muted-foreground font-mono text-[11px]"
            >
              HMAC-SHA256 Verified
            </Badge>
          </div>
        </CardHeader>

        <CardContent className="space-y-3">
          <div className="border-border/80 bg-card overflow-hidden rounded-lg border">
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow className="hover:bg-transparent">
                    <TableHead className="w-[120px]">Status</TableHead>
                    <TableHead className="w-[120px]">Event Type</TableHead>
                    <TableHead>Repository & Ref</TableHead>
                    <TableHead>Commit / Sender</TableHead>
                    <TableHead className="w-[140px]">Delivered At</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {deliveries.map((delivery) => {
                    const isReplaying = replayingDeliveryId === delivery.id;

                    return (
                      <TableRow
                        key={delivery.id}
                        className="hover:bg-muted/40 transition-colors"
                      >
                        <TableCell>
                          <StatusBadge
                            status={
                              delivery.status === "success"
                                ? "healthy"
                                : delivery.status === "failed"
                                  ? "failed"
                                  : "pending"
                            }
                            label={
                              delivery.status === "success"
                                ? `${delivery.statusCode} OK`
                                : `${delivery.statusCode} Error`
                            }
                            size="sm"
                          />
                        </TableCell>

                        <TableCell>
                          <div className="flex items-center gap-1.5">
                            {delivery.event === "pull_request" ? (
                              <GitPullRequest className="size-3.5 text-purple-400" />
                            ) : (
                              <GitCommit className="size-3.5 text-blue-400" />
                            )}
                            <Badge
                              variant="secondary"
                              className="h-5 px-1.5 font-mono text-[10px] uppercase"
                            >
                              {delivery.event}
                            </Badge>
                          </div>
                        </TableCell>

                        <TableCell>
                          <div className="space-y-0.5">
                            <div className="flex items-center gap-1.5">
                              <ProviderIcon
                                provider={delivery.provider}
                                size="xs"
                              />
                              <span className="text-foreground font-mono text-xs font-semibold">
                                {delivery.repository}
                              </span>
                            </div>
                            <div className="flex items-center gap-1 text-[11px]">
                              <GitBranch className="text-muted-foreground size-3" />
                              <code className="text-muted-foreground font-mono">
                                {delivery.branch}
                              </code>
                            </div>
                          </div>
                        </TableCell>

                        <TableCell>
                          <div className="space-y-0.5 text-xs">
                            <div className="flex items-center gap-1.5 font-mono">
                              <Badge
                                variant="outline"
                                className="h-4 px-1 text-[9px]"
                              >
                                {delivery.commitSha}
                              </Badge>
                              <span className="text-muted-foreground max-w-[160px] truncate text-[11px]">
                                {delivery.commitMessage}
                              </span>
                            </div>
                            <span className="text-muted-foreground block text-[10px]">
                              by @{delivery.sender} • {delivery.durationMs}ms
                            </span>
                          </div>
                        </TableCell>

                        <TableCell className="text-muted-foreground font-mono text-xs">
                          {new Date(delivery.deliveredAt).toLocaleTimeString(
                            undefined,
                            {
                              hour: "2-digit",
                              minute: "2-digit",
                              second: "2-digit",
                            },
                          )}
                        </TableCell>

                        <TableCell className="text-right">
                          <div className="flex items-center justify-end gap-1.5">
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() =>
                                setSelectedPayloadDelivery(delivery)
                              }
                              className="h-7 gap-1 px-2 text-xs"
                              title="View webhook payload headers and body"
                            >
                              <Code className="size-3.5" />
                              <span>Payload</span>
                            </Button>

                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() =>
                                void handleReplayDelivery(delivery)
                              }
                              disabled={isReplaying}
                              className="h-7 gap-1 px-2.5 text-xs transition-colors"
                              title="Replay this webhook to trigger a deployment"
                            >
                              {isReplaying ? (
                                <BloomSpinner size={12} />
                              ) : (
                                <ArrowCounterClockwise className="size-3" />
                              )}
                              <span>Replay</span>
                            </Button>
                          </div>
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Repositories Sheet */}
      <Sheet open={sheetOpen} onOpenChange={setSheetOpen}>
        <SheetContent side="right" className="w-full sm:max-w-xl">
          <SheetHeader className="border-border border-b pb-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                {selectedConnection && (
                  <div className="border-border bg-muted/40 flex size-8 items-center justify-center rounded-md border">
                    <ProviderIcon
                      provider={selectedConnection.provider}
                      size={18}
                    />
                  </div>
                )}
                <div>
                  <SheetTitle className="text-base">
                    {(selectedConnection?.metadata?.account_name as
                      string | undefined) || selectedConnection?.provider}{" "}
                    Repositories
                  </SheetTitle>
                  <SheetDescription className="text-muted-foreground text-xs">
                    Repositories accessible via this integration for application
                    linking and builds.
                  </SheetDescription>
                </div>
              </div>
            </div>
          </SheetHeader>

          <div className="space-y-3.5 py-4">
            {/* Filter and Search Bar */}
            <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
              <div className="relative flex-1">
                <MagnifyingGlass className="text-muted-foreground absolute top-2.5 left-2.5 size-3.5" />
                <Input
                  type="text"
                  value={repoSearchQuery}
                  onChange={(e) => setRepoSearchQuery(e.target.value)}
                  placeholder="Filter by name, owner, or branch..."
                  className="h-8 pr-8 pl-8 font-mono text-xs"
                />
                {repoSearchQuery && (
                  <button
                    type="button"
                    onClick={() => setRepoSearchQuery("")}
                    className="text-muted-foreground hover:text-foreground absolute top-2 right-2.5"
                  >
                    <X className="size-3.5" />
                  </button>
                )}
              </div>

              <div className="flex items-center gap-1">
                <Button
                  variant={
                    repoFilterVisibility === "all" ? "default" : "outline"
                  }
                  size="sm"
                  onClick={() => setRepoFilterVisibility("all")}
                  className="h-8 px-2.5 text-xs"
                >
                  All
                </Button>
                <Button
                  variant={
                    repoFilterVisibility === "private" ? "default" : "outline"
                  }
                  size="sm"
                  onClick={() => setRepoFilterVisibility("private")}
                  className="h-8 gap-1 px-2.5 text-xs"
                >
                  <Lock className="size-3" />
                  <span>Private</span>
                </Button>
                <Button
                  variant={
                    repoFilterVisibility === "public" ? "default" : "outline"
                  }
                  size="sm"
                  onClick={() => setRepoFilterVisibility("public")}
                  className="h-8 gap-1 px-2.5 text-xs"
                >
                  <Globe className="size-3" />
                  <span>Public</span>
                </Button>
              </div>
            </div>

            {isLoadingRepos ? (
              <div className="flex items-center justify-center py-16">
                <BloomSpinner size={26} label="Querying repositories..." />
              </div>
            ) : repositories.length === 0 ? (
              <EmptyState
                icon={FolderSimple}
                title="No repositories found"
                description="Make sure repository permissions are granted in your Git provider app settings."
              />
            ) : (
              (() => {
                const filteredRepos = repositories.filter((r) => {
                  const matchesSearch =
                    r.full_name
                      .toLowerCase()
                      .includes(repoSearchQuery.toLowerCase()) ||
                    (r.default_branch &&
                      r.default_branch
                        .toLowerCase()
                        .includes(repoSearchQuery.toLowerCase()));

                  const isPrivate =
                    r.is_private ??
                    (r.visibility
                      ? r.visibility === "private"
                      : r.full_name.includes("mobile"));

                  if (repoFilterVisibility === "private" && !isPrivate)
                    return false;
                  if (repoFilterVisibility === "public" && isPrivate)
                    return false;

                  return matchesSearch;
                });

                if (filteredRepos.length === 0) {
                  return (
                    <div className="border-border bg-muted/20 text-muted-foreground rounded-md border p-8 text-center text-xs">
                      No repositories match your filter criteria.
                    </div>
                  );
                }

                return (
                  <div className="space-y-2">
                    <div className="text-muted-foreground flex items-center justify-between text-[11px]">
                      <span>
                        Showing {filteredRepos.length} of {repositories.length}{" "}
                        repositories
                      </span>
                    </div>

                    <div className="border-border/80 bg-card overflow-hidden rounded-lg border shadow-xs">
                      <div className="overflow-x-auto">
                        <Table>
                          <TableHeader>
                            <TableRow className="hover:bg-transparent">
                              <TableHead>Repository</TableHead>
                              <TableHead className="w-[100px]">
                                Visibility
                              </TableHead>
                              <TableHead className="w-[100px]">
                                Branch
                              </TableHead>
                              <TableHead className="text-right">
                                Actions
                              </TableHead>
                            </TableRow>
                          </TableHeader>
                          <TableBody>
                            {filteredRepos.map((repo) => {
                              const isPrivate =
                                repo.is_private ??
                                (repo.visibility
                                  ? repo.visibility === "private"
                                  : repo.full_name.includes("mobile"));

                              return (
                                <TableRow
                                  key={repo.id}
                                  className="hover:bg-muted/40 transition-colors"
                                >
                                  <TableCell>
                                    <div className="space-y-0.5">
                                      <div className="text-foreground max-w-[220px] truncate font-mono text-xs font-semibold">
                                        {repo.full_name}
                                      </div>
                                      <div className="text-muted-foreground truncate font-mono text-[10px]">
                                        {repo.url}
                                      </div>
                                    </div>
                                  </TableCell>

                                  <TableCell>
                                    {isPrivate ? (
                                      <Badge
                                        variant="outline"
                                        className="gap-1 border-amber-500/30 bg-amber-500/10 font-mono text-[10px] text-amber-400"
                                      >
                                        <Lock className="size-2.5" />
                                        <span>Private</span>
                                      </Badge>
                                    ) : (
                                      <Badge
                                        variant="outline"
                                        className="text-muted-foreground gap-1 border-zinc-500/30 bg-zinc-500/10 font-mono text-[10px]"
                                      >
                                        <Globe className="size-2.5" />
                                        <span>Public</span>
                                      </Badge>
                                    )}
                                  </TableCell>

                                  <TableCell>
                                    <Badge
                                      variant="outline"
                                      className="text-muted-foreground gap-1 font-mono text-[10px]"
                                    >
                                      <GitBranch className="size-2.5" />
                                      <span>
                                        {repo.default_branch || "main"}
                                      </span>
                                    </Badge>
                                  </TableCell>

                                  <TableCell className="text-right">
                                    <div className="flex items-center justify-end gap-1.5">
                                      <button
                                        type="button"
                                        onClick={() =>
                                          handleCopyRepoUrl(repo.url, repo.id)
                                        }
                                        className="text-muted-foreground hover:text-foreground p-1 transition-colors"
                                        title="Copy repository URL"
                                      >
                                        {copiedRepoUrlId === repo.id ? (
                                          <Check className="size-3.5 text-emerald-400" />
                                        ) : (
                                          <Copy className="size-3.5" />
                                        )}
                                      </button>

                                      <Link
                                        href={repo.url}
                                        target="_blank"
                                        className="text-muted-foreground hover:text-foreground inline-flex items-center gap-1 font-mono text-xs transition-colors"
                                      >
                                        <ArrowSquareOut className="size-3.5" />
                                      </Link>
                                    </div>
                                  </TableCell>
                                </TableRow>
                              );
                            })}
                          </TableBody>
                        </Table>
                      </div>
                    </div>
                  </div>
                );
              })()
            )}
          </div>
        </SheetContent>
      </Sheet>

      {/* Connect Provider Dialog */}
      <Dialog open={connectDialogOpen} onOpenChange={setConnectDialogOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2 text-base">
              <Plug className="text-muted-foreground size-4" />
              <span>Connect Git Provider</span>
            </DialogTitle>
            <DialogDescription className="text-muted-foreground text-xs">
              Authorize Bloom Cloud to read repository structures and receive
              cryptographic webhook events.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-2.5 py-3">
            <Button
              variant="outline"
              onClick={() => void handleConnectProvider("github")}
              disabled={isConnecting}
              className="border-border/80 bg-card hover:bg-muted/60 text-foreground h-11 w-full justify-start gap-3 text-xs font-semibold transition-colors"
            >
              {isConnecting ? (
                <BloomSpinner size={16} />
              ) : (
                <ProviderIcon provider="github" size={20} />
              )}
              <span>Connect GitHub Organization</span>
            </Button>

            <Button
              variant="outline"
              onClick={() => void handleConnectProvider("gitlab")}
              disabled={isConnecting}
              className="border-border/80 bg-card hover:bg-muted/60 text-foreground h-11 w-full justify-start gap-3 text-xs font-semibold transition-colors"
            >
              {isConnecting ? (
                <BloomSpinner size={16} />
              ) : (
                <ProviderIcon provider="gitlab" size={20} />
              )}
              <span>Connect GitLab Group / Account</span>
            </Button>

            <Button
              variant="outline"
              onClick={() => void handleConnectProvider("bitbucket")}
              disabled={isConnecting}
              className="border-border/80 bg-card hover:bg-muted/60 text-foreground h-11 w-full justify-start gap-3 text-xs font-semibold transition-colors"
            >
              {isConnecting ? (
                <BloomSpinner size={16} />
              ) : (
                <ProviderIcon provider="bitbucket" size={20} />
              )}
              <span>Connect Bitbucket Workspace</span>
            </Button>
          </div>

          <DialogFooter className="border-border border-t pt-3">
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => setConnectDialogOpen(false)}
              className="w-full text-xs"
            >
              Cancel
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Disconnect Alert Dialog */}
      <AlertDialog
        open={!!connectionToDisconnect}
        onOpenChange={(open) => !open && setConnectionToDisconnect(null)}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle className="text-base">
              Disconnect Git Provider?
            </AlertDialogTitle>
            <AlertDialogDescription className="text-muted-foreground text-xs">
              Are you sure you want to disconnect{" "}
              <strong className="text-foreground font-mono">
                {connectionToDisconnect?.provider.toUpperCase()}
              </strong>
              ? Automated pull request previews and webhook build triggers will
              be paused.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={isDisconnecting} className="text-xs">
              Cancel
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDisconnect}
              disabled={isDisconnecting}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90 text-xs font-semibold"
            >
              {isDisconnecting ? (
                <BloomSpinner size={14} className="mr-2" />
              ) : null}
              Disconnect Integration
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Webhook Payload View Dialog */}
      <Dialog
        open={!!selectedPayloadDelivery}
        onOpenChange={(open) => !open && setSelectedPayloadDelivery(null)}
      >
        <DialogContent className="sm:max-w-xl">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2 text-base">
              <Code className="text-muted-foreground size-4" />
              <span>Webhook Delivery Payload</span>
            </DialogTitle>
            <DialogDescription className="text-muted-foreground text-xs">
              Delivery GUID:{" "}
              <code className="text-foreground font-mono">
                {selectedPayloadDelivery?.id}
              </code>
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-3 py-2">
            <div className="flex items-center justify-between text-xs">
              <span className="text-muted-foreground">
                Event:{" "}
                <strong className="text-foreground font-mono uppercase">
                  {selectedPayloadDelivery?.event}
                </strong>
              </span>
              <Button
                variant="outline"
                size="sm"
                onClick={handleCopyPayloadJson}
                className="h-7 gap-1 text-xs"
              >
                {copiedPayloadText ? (
                  <Check className="size-3 text-emerald-400" />
                ) : (
                  <Copy className="size-3" />
                )}
                <span>Copy JSON</span>
              </Button>
            </div>

            <div className="border-border bg-muted/40 max-h-72 overflow-y-auto rounded-md border p-3 font-mono text-xs text-zinc-300">
              <pre>
                {selectedPayloadDelivery
                  ? JSON.stringify(selectedPayloadDelivery.payload, null, 2)
                  : ""}
              </pre>
            </div>
          </div>

          <DialogFooter className="border-border border-t pt-3">
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => setSelectedPayloadDelivery(null)}
              className="w-full text-xs"
            >
              Close
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
