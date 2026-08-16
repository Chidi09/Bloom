"use client";

import * as React from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import {
  Globe,
  RocketLaunch,
  Plus,
  ArrowSquareOut,
  ArrowsClockwise,
  CheckCircle,
  Copy,
  ClockCounterClockwise,
  Trash,
  ShieldCheck,
  Code,
  Info,
  Check,
  X,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
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
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { EmptyState } from "@/components/shared/empty-state";
import { StatusBadge } from "@/components/status/status-badge";
import { ProviderIcon } from "@/components/status/provider-icon";
import { api } from "@/lib/api/client";
import {
  WebDeploymentResponse,
  CustomDomainResponse,
} from "@/lib/schemas/webhosting";
import { EnvironmentResponse } from "@/lib/schemas/environment";
import { AppResponse } from "@/lib/schemas/app";
import { useOrganizationStore } from "@/stores/organization-store";
import { OrganizationRoleName, hasRole } from "@/lib/auth/roles";

interface DnsProviderConfig {
  id: string;
  name: string;
  domain: string;
  dashboardUrl: string;
  guideText: string;
}

const DNS_PROVIDERS: DnsProviderConfig[] = [
  {
    id: "cloudflare",
    name: "Cloudflare",
    domain: "cloudflare.com",
    dashboardUrl: "https://dash.cloudflare.com",
    guideText:
      "Go to DNS > Records > Add record (Set Proxy status to 'DNS only' / grey cloud during verification).",
  },
  {
    id: "godaddy",
    name: "GoDaddy",
    domain: "godaddy.com",
    dashboardUrl: "https://dcc.godaddy.com/manage/dns",
    guideText: "Go to Domain Portfolio > DNS > Add New Record.",
  },
  {
    id: "namecheap",
    name: "Namecheap",
    domain: "namecheap.com",
    dashboardUrl: "https://ap.www.namecheap.com/domains/domaincontrolpanel",
    guideText: "Go to Domain List > Manage > Advanced DNS > Add New Record.",
  },
  {
    id: "aws",
    name: "AWS Route 53",
    domain: "aws.amazon.com",
    dashboardUrl:
      "https://us-east-1.console.aws.amazon.com/route53/v2/hostedzones",
    guideText: "Go to Route 53 > Hosted Zones > Choose domain > Create record.",
  },
  {
    id: "squarespace",
    name: "Squarespace Domains",
    domain: "squarespace.com",
    dashboardUrl: "https://account.squarespace.com/domains",
    guideText: "Go to Domains > Manage > DNS Settings > Add Record.",
  },
  {
    id: "porkbun",
    name: "Porkbun",
    domain: "porkbun.com",
    dashboardUrl: "https://porkbun.com/account/domains",
    guideText: "Go to Domain Management > Details > DNS Records > Edit.",
  },
  {
    id: "vercel",
    name: "Vercel DNS",
    domain: "vercel.com",
    dashboardUrl: "https://vercel.com/dashboard/domains",
    guideText: "Go to Domains dashboard > Select domain > DNS Records.",
  },
];

export function matchNameserver(rawNs: string): string | null {
  const ns = rawNs.trim().toLowerCase().replace(/\.$/, "");
  if (!ns) return null;

  if (ns.includes("cloudflare.com") || ns.endsWith(".ns.cloudflare.com")) {
    return "cloudflare";
  }
  if (ns.includes("domaincontrol.com") || ns.endsWith(".domaincontrol.com")) {
    return "godaddy";
  }
  if (
    ns.includes("registrar-servers.com") ||
    ns.endsWith(".registrar-servers.com")
  ) {
    return "namecheap";
  }
  if (ns.includes("porkbun.com") || ns.endsWith(".ns.porkbun.com")) {
    return "porkbun";
  }
  if (ns.includes("awsdns-")) {
    return "aws";
  }
  if (ns.includes("vercel-dns.com")) {
    return "vercel";
  }
  if (ns.includes("squarespacedns.com")) {
    return "squarespace";
  }
  return null;
}

export async function detectDnsProvider(
  rawDomain: string,
): Promise<string | null> {
  const domain = rawDomain
    .trim()
    .toLowerCase()
    .replace(/^https?:\/\//, "")
    .replace(/\/.*$/, "");

  if (!domain || !domain.includes(".")) {
    return null;
  }

  const queryDohNs = async (targetDomain: string): Promise<string[]> => {
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 4000);
      const res = await fetch(
        `https://dns.google/resolve?name=${encodeURIComponent(targetDomain)}&type=NS`,
        {
          headers: { Accept: "application/dns-json" },
          signal: controller.signal,
        },
      );
      clearTimeout(timer);

      if (!res.ok) return [];
      const json = (await res.json()) as {
        Answer?: Array<{ data?: string; type?: number }>;
        Authority?: Array<{ data?: string; type?: number }>;
      };

      const hostnames: string[] = [];
      if (Array.isArray(json.Answer)) {
        for (const item of json.Answer) {
          if (typeof item.data === "string") {
            hostnames.push(item.data);
          }
        }
      }
      if (Array.isArray(json.Authority)) {
        for (const item of json.Authority) {
          if (typeof item.data === "string") {
            hostnames.push(item.data);
          }
        }
      }
      return hostnames;
    } catch {
      return [];
    }
  };

  try {
    // 1. Query the domain directly
    let nameservers = await queryDohNs(domain);

    // 2. If no NS records found and domain is a subdomain, query apex domain
    if (nameservers.length === 0) {
      const parts = domain.split(".");
      if (parts.length > 2) {
        const apex = parts.slice(-2).join(".");
        nameservers = await queryDohNs(apex);
      }
    }

    for (const ns of nameservers) {
      const matched = matchNameserver(ns);
      if (matched) return matched;
    }

    return null;
  } catch {
    return null;
  }
}

export default function AppWebHostingPage() {
  const params = useParams<{ id: string }>();
  const appId = params.id;
  const { currentOrganizationId } = useOrganizationStore();

  const [activeTab, setActiveTab] = React.useState<"deployments" | "domains">(
    "deployments",
  );
  const [environments, setEnvironments] = React.useState<EnvironmentResponse[]>(
    [],
  );
  const [deployments, setDeployments] = React.useState<WebDeploymentResponse[]>(
    [],
  );
  const [domains, setDomains] = React.useState<CustomDomainResponse[]>([]);
  const [userRole, setUserRole] = React.useState<OrganizationRoleName>("Owner");

  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Deploy Dialog State
  const [deployDialogOpen, setDeployDialogOpen] = React.useState(false);
  const [selectedEnvId, setSelectedEnvId] = React.useState("");
  const [targetType, setTargetType] = React.useState<"preview" | "production">(
    "preview",
  );
  const [gitBranch, setGitBranch] = React.useState("main");
  const [isDeploying, setIsDeploying] = React.useState(false);

  // Add Domain Dialog State
  const [domainDialogOpen, setDomainDialogOpen] = React.useState(false);
  const [newDomainName, setNewDomainName] = React.useState("");
  const [isAddingDomain, setIsAddingDomain] = React.useState(false);
  const [newlyCreatedDomain, setNewlyCreatedDomain] =
    React.useState<CustomDomainResponse | null>(null);

  // Verification State
  const [verifyingDomainId, setVerifyingDomainId] = React.useState<
    string | null
  >(null);

  // View Records Dialog State
  const [recordsDialogDomain, setRecordsDialogDomain] =
    React.useState<CustomDomainResponse | null>(null);

  // Delete Domain State
  const [domainToDelete, setDomainToDelete] =
    React.useState<CustomDomainResponse | null>(null);
  const [isDeletingDomain, setIsDeletingDomain] = React.useState(false);

  // DNS Provider Shortcut State
  const [selectedDnsProviderId, setSelectedDnsProviderId] =
    React.useState<string>("cloudflare");

  // DNS Provider Auto-detection State
  const [isDetectingDns, setIsDetectingDns] = React.useState(false);
  const [detectedProviderId, setDetectedProviderId] = React.useState<
    string | null
  >(null);
  const [isDetectingExistingDns, setIsDetectingExistingDns] =
    React.useState(false);
  const [existingDetectedProviderId, setExistingDetectedProviderId] =
    React.useState<string | null>(null);

  const handleDomainDetection = React.useCallback(
    async (domainToDetect: string) => {
      const clean = domainToDetect
        .trim()
        .toLowerCase()
        .replace(/^https?:\/\//, "")
        .replace(/\/.*$/, "");
      if (!clean || !clean.includes(".") || clean.length < 3) {
        setDetectedProviderId(null);
        setIsDetectingDns(false);
        return;
      }

      setIsDetectingDns(true);
      const matched = await detectDnsProvider(clean);
      setIsDetectingDns(false);

      if (matched) {
        setSelectedDnsProviderId(matched);
        setDetectedProviderId(matched);
      }
    },
    [],
  );

  // Debounced auto-detection when user types domain in Add Domain dialog
  React.useEffect(() => {
    if (!domainDialogOpen || !newDomainName.trim() || newlyCreatedDomain) {
      return;
    }

    const timer = setTimeout(() => {
      void handleDomainDetection(newDomainName);
    }, 500);

    return () => clearTimeout(timer);
  }, [
    newDomainName,
    domainDialogOpen,
    newlyCreatedDomain,
    handleDomainDetection,
  ]);

  // Auto-detect DNS provider when opening records dialog for an existing domain
  React.useEffect(() => {
    let active = true;

    const run = async () => {
      if (!recordsDialogDomain) {
        setExistingDetectedProviderId(null);
        setIsDetectingExistingDns(false);
        return;
      }

      setIsDetectingExistingDns(true);
      setExistingDetectedProviderId(null);

      const matched = await detectDnsProvider(recordsDialogDomain.domain);
      if (!active) return;
      setIsDetectingExistingDns(false);
      if (matched) {
        setSelectedDnsProviderId(matched);
        setExistingDetectedProviderId(matched);
      }
    };

    void run();

    return () => {
      active = false;
    };
  }, [recordsDialogDomain]);

  // Rollback State
  const [rollbackDepId, setRollbackDepId] = React.useState<string | null>(null);
  const [isRollingBack, setIsRollingBack] = React.useState(false);

  // Copy helper
  const [copiedKey, setCopiedKey] = React.useState<string | null>(null);

  const canDeploy = hasRole(userRole, "Developer");
  const canRollback = hasRole(userRole, "ReleaseManager");
  const canManageDomains = hasRole(userRole, "Developer");

  const selectedDnsProvider =
    DNS_PROVIDERS.find((p) => p.id === selectedDnsProviderId) ||
    DNS_PROVIDERS[0];

  const fetchData = React.useCallback(async () => {
    if (!appId) return;
    setIsLoading(true);
    setError(null);
    try {
      const [appRes, envsRes, depsRes, domsRes, orgsRes] = await Promise.all([
        api.get<AppResponse>(`/apps/${appId}`),
        api
          .get<{ results: EnvironmentResponse[] }>("/environments", {
            params: { app_id: appId },
          })
          .catch(() => ({ results: [] })),
        api
          .get<{ results: WebDeploymentResponse[] }>(
            "/webhosting/deployments",
            { params: { app_id: appId } },
          )
          .catch(() => ({ results: [] })),
        api
          .get<{ results: CustomDomainResponse[] }>("/webhosting/domains", {
            params: { app_id: appId },
          })
          .catch(() => ({ results: [] })),
        api
          .get<{ results: Array<{ id: string; role: string }> }>(
            "/organizations",
          )
          .catch(() => ({ results: [] })),
      ]);

      const envs = envsRes.results ?? [];
      setEnvironments(envs);
      if (envs.length > 0 && !selectedEnvId) {
        setSelectedEnvId(envs[0].id);
      }
      setGitBranch(appRes.default_branch || "main");
      setDeployments(depsRes.results ?? []);
      setDomains(domsRes.results ?? []);

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
          : "Failed to load web hosting resources",
      );
    } finally {
      setIsLoading(false);
    }
  }, [appId, currentOrganizationId, selectedEnvId]);

  React.useEffect(() => {
    const run = async () => {
      await fetchData();
    };
    void run();
  }, [fetchData]);

  const handleCopy = (text: string, key: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(key);
    toast.success("Copied to clipboard");
    setTimeout(() => setCopiedKey(null), 1500);
  };

  const handleDeploy = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!appId || !selectedEnvId) return;

    setIsDeploying(true);
    try {
      const dep = await api.post<WebDeploymentResponse>(
        "/webhosting/deployments",
        {
          app_id: appId,
          environment_id: selectedEnvId,
          artifact_id: `art_web_${Date.now()}`,
          target: targetType,
          git_branch: gitBranch,
        },
      );

      toast.success(
        targetType === "production"
          ? "Production web deployment is live!"
          : "Preview deployment created successfully!",
      );
      setDeployDialogOpen(false);
      setDeployments((prev) => [dep, ...prev]);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to trigger web deployment",
      );
    } finally {
      setIsDeploying(false);
    }
  };

  const handleRollback = async (depId: string) => {
    setIsRollingBack(true);
    try {
      const rolled = await api.post<WebDeploymentResponse>(
        `/webhosting/deployments/${depId}/rollback`,
        {},
      );
      toast.success("Web deployment rolled back successfully");
      setDeployments((prev) => prev.map((d) => (d.id === depId ? rolled : d)));
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to rollback deployment",
      );
    } finally {
      setIsRollingBack(false);
      setRollbackDepId(null);
    }
  };

  const handleAddDomain = async (e: React.FormEvent) => {
    e.preventDefault();
    const cleanDomain = newDomainName.trim().toLowerCase();
    if (!cleanDomain || !appId) return;

    setIsAddingDomain(true);
    try {
      const created = await api.post<CustomDomainResponse>(
        "/webhosting/domains",
        {
          app_id: appId,
          domain: cleanDomain,
        },
      );

      toast.success(
        "Custom domain registered. Configure DNS records below to verify.",
      );
      setDomains((prev) => [created, ...prev]);
      setNewlyCreatedDomain(created);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to register custom domain",
      );
    } finally {
      setIsAddingDomain(false);
    }
  };

  const handleVerifyDomain = async (domainId: string) => {
    setVerifyingDomainId(domainId);
    try {
      const verified = await api.post<CustomDomainResponse>(
        `/webhosting/domains/${domainId}/verify`,
        {},
      );
      toast.success(
        `Domain ${verified.domain} successfully verified! TLS certificate issued.`,
      );
      setDomains((prev) => prev.map((d) => (d.id === domainId ? verified : d)));
      if (recordsDialogDomain?.id === domainId) {
        setRecordsDialogDomain(verified);
      }
    } catch (err: unknown) {
      toast.error(
        err instanceof Error
          ? err.message
          : "Verification check failed. Please ensure DNS propagation has finished.",
      );
    } finally {
      setVerifyingDomainId(null);
    }
  };

  const handleDeleteDomain = async () => {
    if (!domainToDelete) return;
    setIsDeletingDomain(true);
    try {
      await api.delete(`/webhosting/domains/${domainToDelete.id}`);
      toast.success(`Custom domain ${domainToDelete.domain} removed.`);
      setDomains((prev) => prev.filter((d) => d.id !== domainToDelete.id));
      setDomainToDelete(null);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to delete custom domain",
      );
    } finally {
      setIsDeletingDomain(false);
    }
  };

  const activeProduction = deployments.find(
    (d) => d.target === "production" && d.status === "live",
  );
  const activeDomainsCount = domains.filter(
    (d) => d.certificate_status === "active",
  ).length;

  return (
    <div className="space-y-6">
      {/* Overview Metric Banner */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <Card className="border-border/80 bg-zinc-950/60 p-4">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium text-zinc-400">
              Production Web Host
            </span>
            <Globe className="size-4 text-zinc-500" />
          </div>
          <div className="mt-2">
            {activeProduction ? (
              <div className="space-y-1">
                <Link
                  href={activeProduction.url}
                  target="_blank"
                  className="flex items-center gap-1.5 font-mono text-sm font-semibold text-emerald-400 hover:underline"
                >
                  <span className="truncate">
                    {activeProduction.url.replace("https://", "")}
                  </span>
                  <ArrowSquareOut className="size-3.5 shrink-0" />
                </Link>
                <p className="text-[10px] text-zinc-500">
                  Live on Global Edge CDN
                </p>
              </div>
            ) : (
              <p className="text-xs text-zinc-500">
                No production deployment live
              </p>
            )}
          </div>
        </Card>

        <Card className="border-border/80 bg-zinc-950/60 p-4">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium text-zinc-400">
              Custom Apex / Subdomains
            </span>
            <ShieldCheck className="size-4 text-zinc-500" />
          </div>
          <div className="mt-2">
            <div className="flex items-baseline gap-2">
              <span className="font-mono text-xl font-bold text-zinc-100">
                {domains.length}
              </span>
              <span className="text-xs text-zinc-500">
                ({activeDomainsCount} verified & SSL active)
              </span>
            </div>
            <p className="mt-1 text-[10px] text-zinc-500">
              Automatic Let&apos;s Encrypt TLS
            </p>
          </div>
        </Card>

        <Card className="border-border/80 bg-zinc-950/60 p-4">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium text-zinc-400">
              Web Engine & CDN
            </span>
            <Badge
              variant="outline"
              className="border-zinc-700 font-mono text-[10px] text-zinc-300"
            >
              WASM + CanvasKit
            </Badge>
          </div>
          <div className="mt-2">
            <div className="flex items-center gap-2">
              <span className="size-2 animate-pulse rounded-full bg-emerald-500" />
              <span className="text-xs font-medium text-zinc-200">
                HTTP/3 & Brotli Edge
              </span>
            </div>
            <p className="mt-1 text-[10px] text-zinc-500">
              bloom.yaml routing & headers enabled
            </p>
          </div>
        </Card>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertTitle>Error loading web hosting</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchData()}
              className="h-7 text-xs"
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      )}

      {/* Main Tabs Container */}
      <Tabs
        value={activeTab}
        onValueChange={(v) => setActiveTab(v as "deployments" | "domains")}
        className="space-y-4"
      >
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <TabsList className="border-border/60 bg-zinc-900/80 p-1">
            <TabsTrigger
              value="deployments"
              className="cursor-pointer gap-2 text-xs"
            >
              <RocketLaunch className="size-3.5" />
              <span>Deployments ({deployments.length})</span>
            </TabsTrigger>
            <TabsTrigger
              value="domains"
              className="cursor-pointer gap-2 text-xs"
            >
              <Globe className="size-3.5" />
              <span>Custom Domains ({domains.length})</span>
            </TabsTrigger>
          </TabsList>

          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchData()}
              className="h-8 gap-1.5 text-xs text-zinc-300 transition-colors hover:bg-zinc-800"
            >
              <ArrowsClockwise className="size-3.5" />
              <span>Refresh</span>
            </Button>

            {activeTab === "deployments" && canDeploy && (
              <Button
                size="sm"
                onClick={() => {
                  setTargetType("preview");
                  setDeployDialogOpen(true);
                }}
                className="h-8 gap-1.5 bg-zinc-100 text-xs font-medium text-zinc-950 hover:bg-zinc-200"
              >
                <RocketLaunch className="size-3.5" weight="bold" />
                <span>Deploy Now</span>
              </Button>
            )}

            {activeTab === "domains" && canManageDomains && (
              <Button
                size="sm"
                onClick={() => {
                  setNewDomainName("");
                  setNewlyCreatedDomain(null);
                  setDetectedProviderId(null);
                  setIsDetectingDns(false);
                  setDomainDialogOpen(true);
                }}
                className="h-8 gap-1.5 bg-zinc-100 text-xs font-medium text-zinc-950 hover:bg-zinc-200"
              >
                <Plus className="size-3.5" weight="bold" />
                <span>Add Domain</span>
              </Button>
            )}
          </div>
        </div>

        {/* Deployments Tab Content */}
        <TabsContent value="deployments" className="mt-0 space-y-4">
          {isLoading ? (
            <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-16">
              <BloomSpinner size={28} label="Loading web deployments..." />
            </div>
          ) : deployments.length === 0 ? (
            <EmptyState
              icon={RocketLaunch}
              title="No web deployments yet"
              description="Deploy your Flutter or Bloom web bundle to our high-performance global edge CDN."
              actionLabel={canDeploy ? "Deploy now" : undefined}
              onAction={canDeploy ? () => setDeployDialogOpen(true) : undefined}
            />
          ) : (
            <div className="border-border/80 bg-card overflow-hidden rounded-lg border shadow-xs">
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow className="hover:bg-transparent">
                      <TableHead className="w-[120px]">Target</TableHead>
                      <TableHead>Preview / Live URL</TableHead>
                      <TableHead className="w-[130px]">Status</TableHead>
                      <TableHead>Deployed By</TableHead>
                      <TableHead>Created</TableHead>
                      <TableHead className="text-right">Actions</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {deployments.map((dep) => {
                      const isLive = dep.status === "live";
                      const isRolledBack = dep.status === "rolled_back";
                      const isFailed = dep.status === "failed";
                      const isDeployingState = dep.status === "deploying";

                      return (
                        <TableRow
                          key={dep.id}
                          className="hover:bg-muted/40 group transition-colors"
                        >
                          <TableCell>
                            <Badge
                              variant={
                                dep.target === "production"
                                  ? "default"
                                  : "secondary"
                              }
                              className="font-mono text-[10px] uppercase"
                            >
                              {dep.target}
                            </Badge>
                          </TableCell>

                          <TableCell>
                            <div className="flex items-center gap-2">
                              <Link
                                href={dep.url}
                                target="_blank"
                                className="font-mono text-xs font-medium text-zinc-100 hover:text-emerald-400 hover:underline"
                              >
                                {dep.url}
                              </Link>
                              <ArrowSquareOut className="size-3 text-zinc-500" />
                            </div>
                          </TableCell>

                          <TableCell>
                            <div className="flex items-center gap-1.5">
                              {isDeployingState && <BloomSpinner size={12} />}
                              <StatusBadge
                                status={
                                  isLive
                                    ? "healthy"
                                    : isFailed
                                      ? "failed"
                                      : isRolledBack
                                        ? "rolled_back"
                                        : "running"
                                }
                                label={dep.status.replace("_", " ")}
                                size="sm"
                              />
                            </div>
                          </TableCell>

                          <TableCell className="font-mono text-xs text-zinc-400">
                            {dep.deployed_by_id.slice(0, 8)}...
                          </TableCell>

                          <TableCell className="font-mono text-xs text-zinc-400">
                            <TooltipProvider>
                              <Tooltip>
                                <TooltipTrigger className="cursor-help">
                                  {new Date(
                                    dep.created_at,
                                  ).toLocaleDateString()}
                                </TooltipTrigger>
                                <TooltipContent>
                                  <p className="text-xs">
                                    {new Date(dep.created_at).toLocaleString()}
                                  </p>
                                </TooltipContent>
                              </Tooltip>
                            </TooltipProvider>
                          </TableCell>

                          <TableCell className="text-right">
                            <div className="flex items-center justify-end gap-1.5">
                              {isLive && canRollback && (
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  onClick={() => setRollbackDepId(dep.id)}
                                  className="h-7 gap-1 px-2 text-xs text-zinc-400 hover:text-zinc-200"
                                >
                                  <ClockCounterClockwise className="size-3.5" />
                                  <span>Rollback</span>
                                </Button>
                              )}
                              <Link
                                href={dep.url}
                                target="_blank"
                                className="border-border bg-card hover:bg-muted inline-flex h-7 items-center justify-center rounded-md border px-2 text-xs font-medium text-zinc-200 transition-colors"
                              >
                                Visit ↗
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
          )}
        </TabsContent>

        {/* Custom Domains Tab Content */}
        <TabsContent value="domains" className="mt-0 space-y-4">
          {isLoading ? (
            <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-16">
              <BloomSpinner size={28} label="Loading custom domains..." />
            </div>
          ) : domains.length === 0 ? (
            <EmptyState
              icon={Globe}
              title="No custom domains configured"
              description="Point your custom domain (e.g. app.example.com) to your Bloom web hosting deployment."
              actionLabel={canManageDomains ? "Add Custom Domain" : undefined}
              onAction={
                canManageDomains
                  ? () => {
                      setNewDomainName("");
                      setNewlyCreatedDomain(null);
                      setDetectedProviderId(null);
                      setIsDetectingDns(false);
                      setDomainDialogOpen(true);
                    }
                  : undefined
              }
            />
          ) : (
            <div className="border-border/80 bg-card overflow-hidden rounded-lg border shadow-xs">
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow className="hover:bg-transparent">
                      <TableHead className="w-[280px]">Domain</TableHead>
                      <TableHead>TLS Certificate</TableHead>
                      <TableHead>DNS Status</TableHead>
                      <TableHead>Expires</TableHead>
                      <TableHead className="text-right">Actions</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {domains.map((dom) => {
                      const isActive = dom.certificate_status === "active";
                      const isPending =
                        dom.certificate_status === "pending" ||
                        dom.certificate_status === "issuing";
                      const isVerifying = verifyingDomainId === dom.id;

                      return (
                        <TableRow
                          key={dom.id}
                          className="hover:bg-muted/40 group transition-colors"
                        >
                          <TableCell>
                            <div className="flex items-center gap-2">
                              <Globe className="size-4 text-zinc-400" />
                              <span className="font-mono text-xs font-semibold text-zinc-100">
                                {dom.domain}
                              </span>
                            </div>
                          </TableCell>

                          <TableCell>
                            <StatusBadge
                              status={
                                isActive
                                  ? "healthy"
                                  : isPending
                                    ? "pending"
                                    : "error"
                              }
                              label={dom.certificate_status}
                              size="sm"
                            />
                          </TableCell>

                          <TableCell>
                            <button
                              type="button"
                              onClick={() => setRecordsDialogDomain(dom)}
                              className="inline-flex cursor-pointer items-center gap-1.5 font-mono text-xs text-zinc-400 hover:text-zinc-200 hover:underline"
                            >
                              <span>
                                {dom.required_records.length} records configured
                              </span>
                              <ArrowSquareOut className="size-3" />
                            </button>
                          </TableCell>

                          <TableCell className="font-mono text-xs text-zinc-400">
                            {dom.certificate_expires_at
                              ? new Date(
                                  dom.certificate_expires_at,
                                ).toLocaleDateString()
                              : "—"}
                          </TableCell>

                          <TableCell className="text-right">
                            <div className="flex items-center justify-end gap-1.5">
                              {canManageDomains && (
                                <Button
                                  variant="outline"
                                  size="sm"
                                  onClick={() =>
                                    void handleVerifyDomain(dom.id)
                                  }
                                  disabled={isVerifying}
                                  className="h-7 gap-1 text-xs"
                                >
                                  {isVerifying ? (
                                    <BloomSpinner size={12} className="mr-1" />
                                  ) : (
                                    <ArrowsClockwise className="size-3" />
                                  )}
                                  <span>Verify DNS</span>
                                </Button>
                              )}

                              {canManageDomains && (
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  onClick={() => setDomainToDelete(dom)}
                                  className="size-7 h-7 p-0 text-red-400 hover:bg-red-950/40 hover:text-red-300"
                                >
                                  <Trash className="size-3.5" />
                                </Button>
                              )}
                            </div>
                          </TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              </div>
            </div>
          )}
        </TabsContent>
      </Tabs>

      {/* Config-as-Code: Redirects & Headers Section (Read-Only per §22.4 Spec) */}
      <Card className="border-border/80 bg-zinc-950/40">
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <div className="space-y-1">
              <CardTitle className="flex items-center gap-2 text-sm font-semibold text-zinc-100">
                <Code className="size-4 text-zinc-400" />
                <span>Redirects, Rewrites & Security Headers</span>
              </CardTitle>
              <CardDescription className="text-xs text-zinc-400">
                Configured via{" "}
                <code className="rounded bg-zinc-800 px-1 py-0.5 font-mono text-[11px] text-zinc-300">
                  bloom.yaml
                </code>{" "}
                at your repository root.
              </CardDescription>
            </div>

            <TooltipProvider>
              <Tooltip>
                <TooltipTrigger className="flex cursor-help items-center gap-1 rounded-md border border-zinc-800 bg-zinc-900/60 px-2 py-1 text-[11px] text-zinc-400">
                  <Info className="size-3 text-zinc-500" />
                  <span>Config-as-code</span>
                </TooltipTrigger>
                <TooltipContent side="left" className="max-w-xs text-xs">
                  <p>
                    Redirects and headers are version-controlled in{" "}
                    <code className="font-mono text-zinc-300">bloom.yaml</code>.
                    Changes are applied automatically during your next build &
                    deployment.
                  </p>
                </TooltipContent>
              </Tooltip>
            </TooltipProvider>
          </div>
        </CardHeader>
        <CardContent>
          <div className="border-border/60 overflow-hidden rounded-md border bg-zinc-900/30">
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow className="hover:bg-transparent">
                    <TableHead className="w-[200px]">Source Route</TableHead>
                    <TableHead>Target Destination</TableHead>
                    <TableHead className="w-[100px]">Type</TableHead>
                    <TableHead>Security Headers Applied</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody className="font-mono text-xs">
                  <TableRow className="hover:bg-transparent">
                    <TableCell className="text-zinc-300">/docs/*</TableCell>
                    <TableCell className="text-zinc-400">
                      https://bloom.dev/docs/:splat
                    </TableCell>
                    <TableCell>
                      <Badge
                        variant="outline"
                        className="font-mono text-[10px]"
                      >
                        301 Perm
                      </Badge>
                    </TableCell>
                    <TableCell className="text-zinc-500">
                      X-Frame-Options: SAMEORIGIN
                    </TableCell>
                  </TableRow>
                  <TableRow className="hover:bg-transparent">
                    <TableCell className="text-zinc-300">/app/*</TableCell>
                    <TableCell className="text-zinc-400">
                      /index.html (SPA Fallback)
                    </TableCell>
                    <TableCell>
                      <Badge
                        variant="outline"
                        className="font-mono text-[10px]"
                      >
                        Rewrite
                      </Badge>
                    </TableCell>
                    <TableCell className="text-zinc-500">
                      Content-Security-Policy: default-src &apos;self&apos;
                    </TableCell>
                  </TableRow>
                  <TableRow className="hover:bg-transparent">
                    <TableCell className="text-zinc-300">{"/*"}</TableCell>
                    <TableCell className="text-zinc-400">—</TableCell>
                    <TableCell>
                      <Badge
                        variant="outline"
                        className="font-mono text-[10px]"
                      >
                        Edge Cache
                      </Badge>
                    </TableCell>
                    <TableCell className="text-zinc-500">
                      Strict-Transport-Security: max-age=31536000
                    </TableCell>
                  </TableRow>
                </TableBody>
              </Table>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Deploy Dialog */}
      <Dialog open={deployDialogOpen} onOpenChange={setDeployDialogOpen}>
        <DialogContent className="border-zinc-800 bg-zinc-900 text-zinc-100 sm:max-w-md">
          <form onSubmit={handleDeploy} className="space-y-4">
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2 text-base">
                <RocketLaunch className="size-4 text-zinc-400" />
                <span>Trigger Web Hosting Deployment</span>
              </DialogTitle>
              <DialogDescription className="text-xs text-zinc-400">
                Instantly deploy the web bundle to Bloom&apos;s edge CDN
                network.
              </DialogDescription>
            </DialogHeader>

            <div className="space-y-3 py-2">
              <div className="space-y-1.5">
                <Label
                  htmlFor="env-select"
                  className="text-xs font-medium text-zinc-300"
                >
                  Target Environment
                </Label>
                <Select
                  value={selectedEnvId}
                  onValueChange={(v) => v && setSelectedEnvId(v)}
                >
                  <SelectTrigger
                    id="env-select"
                    className="border-zinc-700 bg-zinc-950 font-mono text-xs"
                  >
                    <SelectValue placeholder="Select environment" />
                  </SelectTrigger>
                  <SelectContent className="border-zinc-800 bg-zinc-900 text-zinc-100">
                    {environments.map((e) => (
                      <SelectItem
                        key={e.id}
                        value={e.id}
                        className="font-mono text-xs"
                      >
                        {e.name} ({e.slug})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-1.5">
                <Label
                  htmlFor="target-select"
                  className="text-xs font-medium text-zinc-300"
                >
                  Deployment Channel
                </Label>
                <Select
                  value={targetType}
                  onValueChange={(v) =>
                    setTargetType(v as "preview" | "production")
                  }
                >
                  <SelectTrigger
                    id="target-select"
                    className="border-zinc-700 bg-zinc-950 font-mono text-xs"
                  >
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent className="border-zinc-800 bg-zinc-900 text-zinc-100">
                    <SelectItem value="preview" className="font-mono text-xs">
                      Preview (Isolated URL for PRs / staging)
                    </SelectItem>
                    <SelectItem
                      value="production"
                      className="font-mono text-xs"
                    >
                      Production (Live apex & custom domains)
                    </SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-1.5">
                <Label
                  htmlFor="branch-input"
                  className="text-xs font-medium text-zinc-300"
                >
                  Git Branch
                </Label>
                <Input
                  id="branch-input"
                  value={gitBranch}
                  onChange={(e) => setGitBranch(e.target.value)}
                  placeholder="main"
                  className="border-zinc-700 bg-zinc-950 font-mono text-xs"
                  required
                />
              </div>
            </div>

            <DialogFooter className="border-t border-zinc-800 pt-3">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => setDeployDialogOpen(false)}
                disabled={isDeploying}
                className="text-xs"
              >
                Cancel
              </Button>
              <Button
                type="submit"
                size="sm"
                disabled={isDeploying || !selectedEnvId}
                className="bg-zinc-100 text-xs font-semibold text-zinc-950 hover:bg-zinc-200"
              >
                {isDeploying ? (
                  <BloomSpinner size={14} className="mr-2" />
                ) : null}
                Deploy to Edge
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* Add Custom Domain Dialog */}
      <Dialog open={domainDialogOpen} onOpenChange={setDomainDialogOpen}>
        <DialogContent className="border-zinc-800 bg-zinc-900 text-zinc-100 sm:max-w-lg">
          {!newlyCreatedDomain ? (
            <form onSubmit={handleAddDomain} className="space-y-4">
              <DialogHeader>
                <DialogTitle className="flex items-center gap-2 text-base">
                  <Globe className="size-4 text-zinc-400" />
                  <span>Connect Custom Domain</span>
                </DialogTitle>
                <DialogDescription className="text-xs text-zinc-400">
                  Enter your custom domain or subdomain to route traffic to this
                  web app.
                </DialogDescription>
              </DialogHeader>

              <div className="space-y-2 py-2">
                <Label
                  htmlFor="domain-name"
                  className="text-xs font-medium text-zinc-300"
                >
                  Domain Name
                </Label>
                <Input
                  id="domain-name"
                  value={newDomainName}
                  onChange={(e) => setNewDomainName(e.target.value)}
                  onBlur={() => {
                    if (newDomainName.trim()) {
                      void handleDomainDetection(newDomainName);
                    }
                  }}
                  placeholder="e.g. app.mycompany.com"
                  className="border-zinc-700 bg-zinc-950 font-mono text-xs"
                  required
                />
                {isDetectingDns && (
                  <div className="flex items-center gap-1.5 text-xs text-zinc-400">
                    <BloomSpinner size={12} />
                    <span>Detecting DNS provider...</span>
                  </div>
                )}
                {!isDetectingDns && detectedProviderId && (
                  <div className="flex items-center gap-2">
                    <div className="inline-flex items-center gap-1.5 rounded-full border border-emerald-800/60 bg-emerald-950/40 px-2.5 py-0.5 text-xs text-emerald-300">
                      <CheckCircle
                        className="size-3.5 text-emerald-400"
                        weight="fill"
                      />
                      <span>
                        Detected:{" "}
                        {DNS_PROVIDERS.find((p) => p.id === detectedProviderId)
                          ?.name || detectedProviderId}
                      </span>
                      <button
                        type="button"
                        onClick={() => setDetectedProviderId(null)}
                        className="ml-1 rounded text-emerald-400 hover:text-emerald-200"
                        title="Dismiss detection"
                      >
                        <X className="size-3" />
                      </button>
                    </div>
                  </div>
                )}
                <p className="text-[11px] text-zinc-500">
                  Supports apex domains (example.com) and subdomains
                  (app.example.com).
                </p>
              </div>

              <DialogFooter className="border-t border-zinc-800 pt-3">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => setDomainDialogOpen(false)}
                  disabled={isAddingDomain}
                  className="text-xs"
                >
                  Cancel
                </Button>
                <Button
                  type="submit"
                  size="sm"
                  disabled={isAddingDomain || !newDomainName.trim()}
                  className="bg-zinc-100 text-xs font-semibold text-zinc-950 hover:bg-zinc-200"
                >
                  {isAddingDomain ? (
                    <BloomSpinner size={14} className="mr-2" />
                  ) : null}
                  Continue to DNS Setup
                </Button>
              </DialogFooter>
            </form>
          ) : (
            <div className="space-y-4">
              <DialogHeader>
                <DialogTitle className="flex items-center gap-2 text-base text-emerald-400">
                  <CheckCircle className="size-4" weight="fill" />
                  <span>Domain Registered: {newlyCreatedDomain.domain}</span>
                </DialogTitle>
                <DialogDescription className="text-xs text-zinc-400">
                  Add the following DNS records at your DNS provider
                  (Cloudflare, Route 53, Namecheap, etc.):
                </DialogDescription>
              </DialogHeader>

              {/* DNS Provider Picker Shortcut */}
              <div className="space-y-2.5 rounded-lg border border-zinc-800 bg-zinc-950/90 p-3">
                <div className="flex items-center justify-between gap-2">
                  <div className="flex flex-wrap items-center gap-2 text-xs font-medium text-zinc-200">
                    <ProviderIcon
                      provider={selectedDnsProvider.id}
                      domain={selectedDnsProvider.domain}
                      size="sm"
                    />
                    <span>DNS Provider Assistant</span>
                    {detectedProviderId &&
                      detectedProviderId === selectedDnsProviderId && (
                        <span className="inline-flex items-center gap-1 rounded-full border border-emerald-800/60 bg-emerald-950/50 px-2 py-0.5 text-[10px] text-emerald-300">
                          <CheckCircle
                            className="size-3 text-emerald-400"
                            weight="fill"
                          />
                          <span>Detected: {selectedDnsProvider.name}</span>
                          <button
                            type="button"
                            onClick={() => setDetectedProviderId(null)}
                            className="ml-0.5 text-emerald-400 hover:text-emerald-200"
                            title="Dismiss"
                          >
                            <X className="size-2.5" />
                          </button>
                        </span>
                      )}
                  </div>
                  <Select
                    value={selectedDnsProviderId}
                    onValueChange={(v) => v && setSelectedDnsProviderId(v)}
                  >
                    <SelectTrigger className="h-7 w-[170px] border-zinc-700 bg-zinc-900 text-xs">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent className="border-zinc-800 bg-zinc-900 text-zinc-100">
                      {DNS_PROVIDERS.map((p) => (
                        <SelectItem key={p.id} value={p.id} className="text-xs">
                          <div className="flex items-center gap-2">
                            <ProviderIcon
                              provider={p.id}
                              domain={p.domain}
                              size={14}
                            />
                            <span>{p.name}</span>
                          </div>
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                <div className="flex flex-col gap-2 border-t border-zinc-800/80 pt-2 sm:flex-row sm:items-center sm:justify-between">
                  <p className="text-[11px] leading-tight text-zinc-400">
                    {selectedDnsProvider.guideText}
                  </p>
                  <a
                    href={selectedDnsProvider.dashboardUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex shrink-0 items-center justify-center gap-1.5 rounded-md border border-zinc-700 bg-zinc-800 px-2.5 py-1 text-xs font-medium text-zinc-200 transition-colors hover:bg-zinc-700 hover:text-white"
                  >
                    <span>Open {selectedDnsProvider.name} DNS</span>
                    <ArrowSquareOut className="size-3" />
                  </a>
                </div>
              </div>

              <div className="space-y-3 py-1">
                {newlyCreatedDomain.required_records.map((rec, i) => (
                  <Card key={i} className="border-zinc-800 bg-zinc-950 p-3">
                    <div className="flex items-center justify-between text-xs">
                      <div className="flex items-center gap-2">
                        <Badge
                          variant="outline"
                          className="border-zinc-700 font-mono text-[10px] text-zinc-300"
                        >
                          {rec.record_type}
                        </Badge>
                        <span className="font-semibold text-zinc-200">
                          {rec.purpose}
                        </span>
                      </div>
                    </div>

                    <div className="mt-2 grid grid-cols-2 gap-2 font-mono text-xs">
                      <div className="rounded bg-zinc-900 p-2">
                        <span className="block text-[10px] text-zinc-500 uppercase">
                          Host / Name
                        </span>
                        <div className="mt-0.5 flex items-center justify-between">
                          <span className="truncate text-zinc-200">
                            {rec.host}
                          </span>
                          <button
                            type="button"
                            onClick={() => handleCopy(rec.host, `host_${i}`)}
                            className="text-zinc-400 hover:text-zinc-100"
                            title="Copy Host"
                          >
                            {copiedKey === `host_${i}` ? (
                              <Check className="size-3 text-emerald-400" />
                            ) : (
                              <Copy className="size-3" />
                            )}
                          </button>
                        </div>
                      </div>

                      <div className="rounded bg-zinc-900 p-2">
                        <span className="block text-[10px] text-zinc-500 uppercase">
                          Target / Value
                        </span>
                        <div className="mt-0.5 flex items-center justify-between">
                          <span className="truncate text-zinc-200">
                            {rec.value}
                          </span>
                          <button
                            type="button"
                            onClick={() => handleCopy(rec.value, `val_${i}`)}
                            className="text-zinc-400 hover:text-zinc-100"
                            title="Copy Value"
                          >
                            {copiedKey === `val_${i}` ? (
                              <Check className="size-3 text-emerald-400" />
                            ) : (
                              <Copy className="size-3" />
                            )}
                          </button>
                        </div>
                      </div>
                    </div>
                  </Card>
                ))}
              </div>

              <DialogFooter className="border-t border-zinc-800 pt-3">
                <Button
                  size="sm"
                  onClick={() => setDomainDialogOpen(false)}
                  className="w-full bg-zinc-100 text-xs font-semibold text-zinc-950 hover:bg-zinc-200"
                >
                  Done
                </Button>
              </DialogFooter>
            </div>
          )}
        </DialogContent>
      </Dialog>

      {/* View DNS Records Modal */}
      <Dialog
        open={!!recordsDialogDomain}
        onOpenChange={(open) => !open && setRecordsDialogDomain(null)}
      >
        <DialogContent className="border-zinc-800 bg-zinc-900 text-zinc-100 sm:max-w-lg">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2 text-base">
              <Globe className="size-4 text-zinc-400" />
              <span>DNS Configuration for {recordsDialogDomain?.domain}</span>
            </DialogTitle>
            <DialogDescription className="text-xs text-zinc-400">
              Ensure these records are configured at your DNS host for automated
              SSL generation.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-3 py-1">
            {/* DNS Provider Picker Shortcut */}
            <div className="space-y-2.5 rounded-lg border border-zinc-800 bg-zinc-950/90 p-3">
              <div className="flex items-center justify-between gap-2">
                <div className="flex flex-wrap items-center gap-2 text-xs font-medium text-zinc-200">
                  <ProviderIcon
                    provider={selectedDnsProvider.id}
                    domain={selectedDnsProvider.domain}
                    size="sm"
                  />
                  <span>DNS Provider Assistant</span>
                  {isDetectingExistingDns && (
                    <span className="flex items-center gap-1 text-[11px] text-zinc-400">
                      <BloomSpinner size={10} />
                      <span>Detecting DNS provider...</span>
                    </span>
                  )}
                  {!isDetectingExistingDns &&
                    existingDetectedProviderId &&
                    existingDetectedProviderId === selectedDnsProviderId && (
                      <span className="inline-flex items-center gap-1 rounded-full border border-emerald-800/60 bg-emerald-950/50 px-2 py-0.5 text-[10px] text-emerald-300">
                        <CheckCircle
                          className="size-3 text-emerald-400"
                          weight="fill"
                        />
                        <span>Detected: {selectedDnsProvider.name}</span>
                        <button
                          type="button"
                          onClick={() => setExistingDetectedProviderId(null)}
                          className="ml-0.5 text-emerald-400 hover:text-emerald-200"
                          title="Dismiss"
                        >
                          <X className="size-2.5" />
                        </button>
                      </span>
                    )}
                </div>
                <Select
                  value={selectedDnsProviderId}
                  onValueChange={(v) => v && setSelectedDnsProviderId(v)}
                >
                  <SelectTrigger className="h-7 w-[170px] border-zinc-700 bg-zinc-900 text-xs">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent className="border-zinc-800 bg-zinc-900 text-zinc-100">
                    {DNS_PROVIDERS.map((p) => (
                      <SelectItem key={p.id} value={p.id} className="text-xs">
                        <div className="flex items-center gap-2">
                          <ProviderIcon
                            provider={p.id}
                            domain={p.domain}
                            size={14}
                          />
                          <span>{p.name}</span>
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="flex flex-col gap-2 border-t border-zinc-800/80 pt-2 sm:flex-row sm:items-center sm:justify-between">
                <p className="text-[11px] leading-tight text-zinc-400">
                  {selectedDnsProvider.guideText}
                </p>
                <a
                  href={selectedDnsProvider.dashboardUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex shrink-0 items-center justify-center gap-1.5 rounded-md border border-zinc-700 bg-zinc-800 px-2.5 py-1 text-xs font-medium text-zinc-200 transition-colors hover:bg-zinc-700 hover:text-white"
                >
                  <span>Open {selectedDnsProvider.name} DNS</span>
                  <ArrowSquareOut className="size-3" />
                </a>
              </div>
            </div>

            {recordsDialogDomain?.required_records?.map((rec, i) => (
              <Card key={i} className="border-zinc-800 bg-zinc-950 p-3">
                <div className="flex items-center justify-between text-xs">
                  <div className="flex items-center gap-2">
                    <Badge
                      variant="outline"
                      className="border-zinc-700 font-mono text-[10px] text-zinc-300"
                    >
                      {rec.record_type}
                    </Badge>
                    <span className="font-semibold text-zinc-200">
                      {rec.purpose}
                    </span>
                  </div>
                </div>

                <div className="mt-2 grid grid-cols-2 gap-2 font-mono text-xs">
                  <div className="rounded bg-zinc-900 p-2">
                    <span className="block text-[10px] text-zinc-500 uppercase">
                      Host / Name
                    </span>
                    <div className="mt-0.5 flex items-center justify-between">
                      <span className="truncate text-zinc-200">{rec.host}</span>
                      <button
                        type="button"
                        onClick={() => handleCopy(rec.host, `view_host_${i}`)}
                        className="text-zinc-400 hover:text-zinc-100"
                        title="Copy Host"
                      >
                        {copiedKey === `view_host_${i}` ? (
                          <Check className="size-3 text-emerald-400" />
                        ) : (
                          <Copy className="size-3" />
                        )}
                      </button>
                    </div>
                  </div>

                  <div className="rounded bg-zinc-900 p-2">
                    <span className="block text-[10px] text-zinc-500 uppercase">
                      Target / Value
                    </span>
                    <div className="mt-0.5 flex items-center justify-between">
                      <span className="truncate text-zinc-200">
                        {rec.value}
                      </span>
                      <button
                        type="button"
                        onClick={() => handleCopy(rec.value, `view_val_${i}`)}
                        className="text-zinc-400 hover:text-zinc-100"
                        title="Copy Value"
                      >
                        {copiedKey === `view_val_${i}` ? (
                          <Check className="size-3 text-emerald-400" />
                        ) : (
                          <Copy className="size-3" />
                        )}
                      </button>
                    </div>
                  </div>
                </div>
              </Card>
            ))}
          </div>

          <DialogFooter className="border-t border-zinc-800 pt-3">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setRecordsDialogDomain(null)}
              className="text-xs"
            >
              Close
            </Button>
            {recordsDialogDomain && canManageDomains && (
              <Button
                size="sm"
                onClick={() => void handleVerifyDomain(recordsDialogDomain.id)}
                disabled={verifyingDomainId === recordsDialogDomain.id}
                className="bg-zinc-100 text-xs font-semibold text-zinc-950 hover:bg-zinc-200"
              >
                {verifyingDomainId === recordsDialogDomain.id ? (
                  <BloomSpinner size={14} className="mr-2" />
                ) : (
                  <ArrowsClockwise className="mr-1.5 size-3.5" />
                )}
                Verify Records Now
              </Button>
            )}
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Domain Alert Dialog */}
      <AlertDialog
        open={!!domainToDelete}
        onOpenChange={(open) => !open && setDomainToDelete(null)}
      >
        <AlertDialogContent className="border-zinc-800 bg-zinc-900 text-zinc-100">
          <AlertDialogHeader>
            <AlertDialogTitle className="text-base">
              Disconnect Custom Domain?
            </AlertDialogTitle>
            <AlertDialogDescription className="text-xs text-zinc-400">
              Are you sure you want to remove{" "}
              <strong className="font-mono text-zinc-200">
                {domainToDelete?.domain}
              </strong>
              ? Incoming traffic to this domain will stop resolving to your
              application.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={isDeletingDomain} className="text-xs">
              Cancel
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDeleteDomain}
              disabled={isDeletingDomain}
              className="bg-red-600 text-xs font-semibold text-white hover:bg-red-700"
            >
              {isDeletingDomain ? (
                <BloomSpinner size={14} className="mr-2" />
              ) : null}
              Disconnect Domain
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Rollback Alert Dialog */}
      <AlertDialog
        open={!!rollbackDepId}
        onOpenChange={(open) => !open && setRollbackDepId(null)}
      >
        <AlertDialogContent className="border-zinc-800 bg-zinc-900 text-zinc-100">
          <AlertDialogHeader>
            <AlertDialogTitle className="text-base">
              Rollback Deployment?
            </AlertDialogTitle>
            <AlertDialogDescription className="text-xs text-zinc-400">
              This will mark the current deployment as rolled back and
              immediately restore traffic to the previously active stable
              release.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={isRollingBack} className="text-xs">
              Cancel
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={() => rollbackDepId && handleRollback(rollbackDepId)}
              disabled={isRollingBack}
              className="bg-amber-600 text-xs font-semibold text-white hover:bg-amber-700"
            >
              {isRollingBack ? (
                <BloomSpinner size={14} className="mr-2" />
              ) : null}
              Confirm Rollback
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
