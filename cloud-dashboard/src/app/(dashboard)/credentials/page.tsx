"use client";

import * as React from "react";
import {
  Key,
  Plus,
  Trash,
  ArrowsClockwise,
  Clock,
  CheckCircle,
  XCircle,
  ShieldCheck,
} from "@phosphor-icons/react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { StatusBadge } from "@/components/status/status-badge";
import { ProviderIcon } from "@/components/status/provider-icon";
import { Textarea } from "@/components/ui/textarea";
import {
  Card,
  CardContent,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { EmptyState } from "@/components/shared/empty-state";
import { PageHeader } from "@/components/shared/page-header";
import { api } from "@/lib/api/client";
import {
  CredentialResponse,
  CredentialTestResponse,
} from "@/lib/schemas/credential";
import { useOrganizationStore } from "@/stores/organization-store";
import { OrganizationRoleName, hasRole } from "@/lib/auth/roles";

type ProviderType =
  "apple" | "google_play" | "shorebird" | "github" | "gitlab" | "bitbucket";

interface ProviderOption {
  id: ProviderType;
  name: string;
  category: "Store Distribution" | "CodePush" | "Source Control";
  description: string;
}

const PROVIDERS: ProviderOption[] = [
  {
    id: "apple",
    name: "Apple App Store Connect",
    category: "Store Distribution",
    description:
      "App Store Connect API Key for TestFlight & App Store releases",
  },
  {
    id: "google_play",
    name: "Google Play Console",
    category: "Store Distribution",
    description: "Google Cloud Service Account for Play Store tracks",
  },
  {
    id: "shorebird",
    name: "Shorebird CodePush",
    category: "CodePush",
    description: "Over-the-air instantaneous patch distribution for Flutter",
  },
  {
    id: "github",
    name: "GitHub App",
    category: "Source Control",
    description: "Automated PR previews, triggers, and deployment check suites",
  },
  {
    id: "gitlab",
    name: "GitLab",
    category: "Source Control",
    description: "GitLab CI/CD integration and pipeline triggers",
  },
  {
    id: "bitbucket",
    name: "Bitbucket Cloud",
    category: "Source Control",
    description: "Atlassian Bitbucket repository webhooks & deployment sync",
  },
];

function getProviderStyle(provider: ProviderType) {
  switch (provider) {
    case "apple":
      return {
        topBorder: "border-t-slate-400/80",
        glow: "hover:shadow-[0_4px_24px_rgba(255,255,255,0.06)] hover:border-slate-600",
        badgeColor: "border-slate-500/30 bg-slate-500/10 text-slate-300",
      };
    case "google_play":
      return {
        topBorder: "border-t-emerald-500/80",
        glow: "hover:shadow-[0_4px_24px_rgba(16,185,129,0.12)] hover:border-emerald-500/40",
        badgeColor: "border-emerald-500/30 bg-emerald-500/10 text-emerald-400",
      };
    case "shorebird":
      return {
        topBorder: "border-t-cyan-500/80",
        glow: "hover:shadow-[0_4px_24px_rgba(6,182,212,0.12)] hover:border-cyan-500/40",
        badgeColor: "border-cyan-500/30 bg-cyan-500/10 text-cyan-400",
      };
    case "github":
      return {
        topBorder: "border-t-violet-500/80",
        glow: "hover:shadow-[0_4px_24px_rgba(139,92,246,0.12)] hover:border-violet-500/40",
        badgeColor: "border-violet-500/30 bg-violet-500/10 text-violet-300",
      };
    case "gitlab":
      return {
        topBorder: "border-t-amber-500/80",
        glow: "hover:shadow-[0_4px_24px_rgba(245,158,11,0.12)] hover:border-amber-500/40",
        badgeColor: "border-amber-500/30 bg-amber-500/10 text-amber-400",
      };
    case "bitbucket":
      return {
        topBorder: "border-t-blue-500/80",
        glow: "hover:shadow-[0_4px_24px_rgba(59,130,246,0.12)] hover:border-blue-500/40",
        badgeColor: "border-blue-500/30 bg-blue-500/10 text-blue-400",
      };
    default:
      return {
        topBorder: "border-t-primary/80",
        glow: "hover:shadow-[0_4px_24px_rgba(255,255,255,0.05)]",
        badgeColor: "border-zinc-500/30 bg-zinc-500/10 text-zinc-300",
      };
  }
}

export default function CredentialsPage() {
  const { currentOrganizationId } = useOrganizationStore();

  const [credentials, setCredentials] = React.useState<CredentialResponse[]>(
    [],
  );
  const [userRole, setUserRole] = React.useState<OrganizationRoleName>("Owner");
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Add Credential Wizard State
  const [dialogOpen, setDialogOpen] = React.useState(false);
  const [selectedProvider, setSelectedProvider] =
    React.useState<ProviderType>("apple");
  const [credentialName, setCredentialName] = React.useState("");
  const [secretToken, setSecretToken] = React.useState("");
  const [isCreating, setIsCreating] = React.useState(false);

  // Apple Metadata Fields
  const [appleKeyId, setAppleKeyId] = React.useState("");
  const [appleIssuerId, setAppleIssuerId] = React.useState("");
  const [appleTeamId, setAppleTeamId] = React.useState("");

  // Google Play Fields
  const [googleClientEmail, setGoogleClientEmail] = React.useState("");

  // Shorebird Fields
  const [shorebirdAppId, setShorebirdAppId] = React.useState("");

  // GitHub Fields
  const [githubInstallationId, setGithubInstallationId] = React.useState("");

  // GitLab Fields
  const [gitlabApplicationId, setGitlabApplicationId] = React.useState("");

  // Bitbucket Fields
  const [bitbucketWorkspace, setBitbucketWorkspace] = React.useState("");

  // Testing State
  const [testingId, setTestingId] = React.useState<string | null>(null);
  const [testResults, setTestResults] = React.useState<
    Record<string, { success: boolean; message: string; timestamp: Date }>
  >({});

  // Delete State
  const [credentialToDelete, setCredentialToDelete] =
    React.useState<CredentialResponse | null>(null);
  const [isDeleting, setIsDeleting] = React.useState(false);

  const canTest = hasRole(userRole, "Developer");
  const canManage = hasRole(userRole, "Admin");

  const fetchCredentials = React.useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const [credsRes, orgsRes] = await Promise.all([
        api.get<{ results: CredentialResponse[] }>("/credentials"),
        api
          .get<{ results: Array<{ id: string; role: string }> }>(
            "/organizations",
          )
          .catch(() => ({ results: [] })),
      ]);

      setCredentials(credsRes.results ?? []);

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
          : "Failed to load platform credentials",
      );
    } finally {
      setIsLoading(false);
    }
  }, [currentOrganizationId]);

  React.useEffect(() => {
    const run = async () => {
      await fetchCredentials();
    };
    void run();
  }, [fetchCredentials]);

  const resetForm = () => {
    setCredentialName("");
    setSecretToken("");
    setAppleKeyId("");
    setAppleIssuerId("");
    setAppleTeamId("");
    setGoogleClientEmail("");
    setShorebirdAppId("");
    setGithubInstallationId("");
    setGitlabApplicationId("");
    setBitbucketWorkspace("");
  };

  const handleCreateCredential = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!credentialName.trim() || !secretToken.trim()) return;

    let metadata: Record<string, unknown> = { provider: selectedProvider };

    if (selectedProvider === "apple") {
      metadata = {
        provider: "apple",
        key_id: appleKeyId.trim(),
        issuer_id: appleIssuerId.trim(),
        team_id: appleTeamId.trim(),
      };
    } else if (selectedProvider === "google_play") {
      metadata = {
        provider: "google_play",
        client_email: googleClientEmail.trim(),
      };
    } else if (selectedProvider === "shorebird") {
      metadata = {
        provider: "shorebird",
        app_id: shorebirdAppId.trim(),
      };
    } else if (selectedProvider === "github") {
      metadata = {
        provider: "github",
        installation_id: githubInstallationId.trim(),
      };
    } else if (selectedProvider === "gitlab") {
      metadata = {
        provider: "gitlab",
        application_id: gitlabApplicationId.trim(),
      };
    } else if (selectedProvider === "bitbucket") {
      metadata = {
        provider: "bitbucket",
        workspace: bitbucketWorkspace.trim(),
      };
    }

    setIsCreating(true);
    try {
      const created = await api.post<CredentialResponse>("/credentials", {
        provider: selectedProvider,
        name: credentialName.trim(),
        token: secretToken.trim(),
        metadata,
      });

      toast.success(
        `Platform credential "${created.name}" stored securely in vault.`,
      );
      setCredentials((prev) => [created, ...prev]);
      setDialogOpen(false);
      resetForm();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to store credential",
      );
    } finally {
      setIsCreating(false);
    }
  };

  const handleTestConnection = async (cred: CredentialResponse) => {
    setTestingId(cred.id);
    try {
      const res = await api.post<CredentialTestResponse>(
        `/credentials/${cred.id}/test`,
        {},
      );
      if (res.success) {
        toast.success(res.message || `Successfully connected to ${cred.name}!`);
        setTestResults((prev) => ({
          ...prev,
          [cred.id]: {
            success: true,
            message: res.message || "Connection validated",
            timestamp: new Date(),
          },
        }));
      } else {
        toast.error(res.message || `Connection failed for ${cred.name}.`);
        setTestResults((prev) => ({
          ...prev,
          [cred.id]: {
            success: false,
            message: res.message || "Validation failed",
            timestamp: new Date(),
          },
        }));
      }
      await fetchCredentials();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Connection test error";
      toast.error(msg);
      setTestResults((prev) => ({
        ...prev,
        [cred.id]: {
          success: false,
          message: msg,
          timestamp: new Date(),
        },
      }));
    } finally {
      setTestingId(null);
    }
  };

  const handleDeleteCredential = async () => {
    if (!credentialToDelete) return;
    setIsDeleting(true);
    try {
      await api.delete(`/credentials/${credentialToDelete.id}`);
      toast.success(
        `Credential "${credentialToDelete.name}" removed from vault.`,
      );
      setCredentials((prev) =>
        prev.filter((c) => c.id !== credentialToDelete.id),
      );
      setCredentialToDelete(null);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to delete credential",
      );
    } finally {
      setIsDeleting(false);
    }
  };

  const renderMetadata = (cred: CredentialResponse) => {
    const meta = cred.metadata as Record<string, string>;
    switch (cred.provider) {
      case "apple":
        return (
          <div className="text-foreground space-y-1 font-mono text-xs">
            <div className="flex items-center justify-between text-[11px]">
              <span className="text-muted-foreground">Key ID:</span>
              <span className="font-semibold">{meta.key_id || "••••••••"}</span>
            </div>
            <div className="flex items-center justify-between text-[11px]">
              <span className="text-muted-foreground">Issuer ID:</span>
              <span className="max-w-[150px] truncate">
                {meta.issuer_id || "••••••••"}
              </span>
            </div>
            <div className="flex items-center justify-between text-[11px]">
              <span className="text-muted-foreground">Team ID:</span>
              <span className="font-semibold">
                {meta.team_id || "••••••••"}
              </span>
            </div>
          </div>
        );
      case "google_play":
        return (
          <div className="text-foreground space-y-1 font-mono text-xs">
            <div className="text-[11px]">
              <span className="text-muted-foreground mb-0.5 block">
                Client Email:
              </span>
              <span className="text-foreground block truncate font-semibold">
                {meta.client_email || "••••@iam.gserviceaccount.com"}
              </span>
            </div>
          </div>
        );
      case "shorebird":
        return (
          <div className="text-foreground space-y-1 font-mono text-xs">
            <div className="flex items-center justify-between text-[11px]">
              <span className="text-muted-foreground">App ID:</span>
              <span className="max-w-[170px] truncate font-semibold">
                {meta.app_id || "••••••••"}
              </span>
            </div>
          </div>
        );
      case "github":
        return (
          <div className="text-foreground space-y-1 font-mono text-xs">
            <div className="flex items-center justify-between text-[11px]">
              <span className="text-muted-foreground">Installation ID:</span>
              <span className="font-semibold">
                {meta.installation_id || "••••••••"}
              </span>
            </div>
          </div>
        );
      case "gitlab":
        return (
          <div className="text-foreground space-y-1 font-mono text-xs">
            <div className="flex items-center justify-between text-[11px]">
              <span className="text-muted-foreground">Application ID:</span>
              <span className="font-semibold">
                {meta.application_id || "••••••••"}
              </span>
            </div>
          </div>
        );
      case "bitbucket":
        return (
          <div className="text-foreground space-y-1 font-mono text-xs">
            <div className="flex items-center justify-between text-[11px]">
              <span className="text-muted-foreground">Workspace:</span>
              <span className="font-semibold">
                {meta.workspace || "••••••••"}
              </span>
            </div>
          </div>
        );
      default:
        return null;
    }
  };

  return (
    <div className="mx-auto max-w-6xl space-y-5">
      <PageHeader
        breadcrumbs={[
          { label: "Organization", href: "/organizations" },
          { label: "Credentials Vault" },
        ]}
        title="Platform Credentials Vault"
        description="Encrypted API keys and service accounts for automated App Store, Google Play, Shorebird, and Git deployments."
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchCredentials()}
              className="h-8 gap-1.5 transition-colors"
            >
              <ArrowsClockwise className="size-3.5" />
              <span>Refresh</span>
            </Button>
            {canManage && (
              <Button
                size="sm"
                onClick={() => {
                  resetForm();
                  setDialogOpen(true);
                }}
                className="h-8 gap-1.5"
              >
                <Plus className="size-3.5" weight="bold" />
                <span>Add Credential</span>
              </Button>
            )}
          </div>
        }
      />

      {error && (
        <Alert variant="destructive">
          <AlertTitle>Error loading credentials</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchCredentials()}
              className="h-7 text-xs"
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      )}

      {isLoading ? (
        <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-16">
          <BloomSpinner size={28} label="Loading platform credentials..." />
        </div>
      ) : credentials.length === 0 ? (
        <EmptyState
          icon={Key}
          title="No platform credentials configured"
          description="Add Apple App Store Connect, Google Play, Shorebird, or Git credentials to enable zero-config publishing."
          actionLabel={canManage ? "Add Credential" : undefined}
          onAction={canManage ? () => setDialogOpen(true) : undefined}
        />
      ) : (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
          {credentials.map((cred) => {
            const providerInfo =
              PROVIDERS.find((p) => p.id === cred.provider) || PROVIDERS[0];
            const isTesting = testingId === cred.id;
            const style = getProviderStyle(cred.provider);
            const lastTest = testResults[cred.id];

            return (
              <Card
                key={cred.id}
                className={cn(
                  "group border-border/80 bg-card flex flex-col justify-between border-t-2 shadow-xs transition-all duration-200 hover:-translate-y-0.5",
                  style.topBorder,
                  style.glow,
                )}
              >
                <CardHeader className="pb-3">
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex items-center gap-2.5">
                      <div className="border-border/80 bg-muted/50 text-foreground flex size-9 shrink-0 items-center justify-center rounded-md border shadow-xs transition-colors group-hover:border-zinc-600">
                        <ProviderIcon provider={cred.provider} size="sm" />
                      </div>
                      <div className="space-y-0.5">
                        <CardTitle className="text-foreground text-sm font-semibold">
                          {cred.name}
                        </CardTitle>
                        <p className="text-muted-foreground font-mono text-[11px]">
                          {providerInfo.name}
                        </p>
                      </div>
                    </div>
                    <Badge
                      variant="outline"
                      className={cn(
                        "text-[9px] tracking-wide uppercase",
                        style.badgeColor,
                      )}
                    >
                      {providerInfo.category}
                    </Badge>
                  </div>
                </CardHeader>

                <CardContent className="space-y-3 pt-0">
                  <div className="border-border/60 bg-muted/20 rounded-md border p-2.5">
                    {renderMetadata(cred)}
                  </div>

                  <div className="text-muted-foreground flex items-center justify-between font-mono text-[10px]">
                    <div className="flex items-center gap-1">
                      <Clock className="size-3" />
                      <span>
                        Last used:{" "}
                        {cred.last_used_at
                          ? new Date(cred.last_used_at).toLocaleDateString()
                          : "Never"}
                      </span>
                    </div>

                    {lastTest ? (
                      <div className="flex items-center gap-1">
                        {lastTest.success ? (
                          <span className="flex items-center gap-0.5 text-emerald-400">
                            <CheckCircle className="size-3" weight="fill" />
                            <span>Verified</span>
                          </span>
                        ) : (
                          <span className="flex items-center gap-0.5 text-rose-400">
                            <XCircle className="size-3" weight="fill" />
                            <span>Failed</span>
                          </span>
                        )}
                      </div>
                    ) : (
                      <StatusBadge status="healthy" label="Ready" size="sm" />
                    )}
                  </div>
                </CardContent>

                <CardFooter className="border-border/60 flex items-center justify-between border-t pt-3">
                  {canTest ? (
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => void handleTestConnection(cred)}
                      disabled={isTesting}
                      className="h-7 gap-1.5 text-xs transition-colors"
                    >
                      {isTesting ? (
                        <>
                          <BloomSpinner size={12} speed="fast" />
                          <span>Testing...</span>
                        </>
                      ) : (
                        <>
                          <ArrowsClockwise className="size-3" />
                          <span>Test Connection</span>
                        </>
                      )}
                    </Button>
                  ) : (
                    <div />
                  )}

                  {canManage && (
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => setCredentialToDelete(cred)}
                      className="text-muted-foreground hover:text-destructive hover:bg-destructive/10 size-7 h-7 p-0 transition-colors"
                    >
                      <Trash className="size-3.5" />
                    </Button>
                  )}
                </CardFooter>
              </Card>
            );
          })}
        </div>
      )}

      {/* Add Credential Dialog Wizard */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="sm:max-w-lg">
          <form onSubmit={handleCreateCredential} className="space-y-4">
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2 text-base">
                <ShieldCheck className="text-primary size-4" />
                <span>Store Platform Credential</span>
              </DialogTitle>
              <DialogDescription>
                Credentials are encrypted with AES-256-GCM and only decrypted in
                isolated build workers.
              </DialogDescription>
            </DialogHeader>

            <div className="space-y-3 py-1">
              <div className="space-y-1.5">
                <Label htmlFor="provider-select">
                  Target Platform / Provider
                </Label>
                <Select
                  value={selectedProvider}
                  onValueChange={(v) => setSelectedProvider(v as ProviderType)}
                >
                  <SelectTrigger id="provider-select" className="text-xs">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {PROVIDERS.map((p) => (
                      <SelectItem key={p.id} value={p.id} className="text-xs">
                        <div className="flex items-center gap-2">
                          <ProviderIcon provider={p.id} size="sm" />
                          <span className="font-medium">{p.name}</span>
                          <span className="text-muted-foreground text-[10px]">
                            ({p.category})
                          </span>
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="cred-name">Credential Name / Label</Label>
                <Input
                  id="cred-name"
                  value={credentialName}
                  onChange={(e) => setCredentialName(e.target.value)}
                  placeholder="e.g. Production App Store API Key"
                  className="text-xs"
                  required
                />
              </div>

              {/* Dynamic Metadata Fields based on Provider */}
              {selectedProvider === "apple" && (
                <div className="border-border/60 bg-muted/20 space-y-2.5 rounded-md border p-3">
                  <div className="space-y-1.5">
                    <Label htmlFor="apple-key" className="text-[11px]">
                      Key ID
                    </Label>
                    <Input
                      id="apple-key"
                      value={appleKeyId}
                      onChange={(e) => setAppleKeyId(e.target.value)}
                      placeholder="e.g. 2X9R4HXF34"
                      className="font-mono text-xs"
                      required
                    />
                  </div>
                  <div className="grid grid-cols-2 gap-2">
                    <div className="space-y-1.5">
                      <Label htmlFor="apple-issuer" className="text-[11px]">
                        Issuer ID (UUID)
                      </Label>
                      <Input
                        id="apple-issuer"
                        value={appleIssuerId}
                        onChange={(e) => setAppleIssuerId(e.target.value)}
                        placeholder="57246542-96fe-1a63-..."
                        className="font-mono text-xs"
                        required
                      />
                    </div>
                    <div className="space-y-1.5">
                      <Label htmlFor="apple-team" className="text-[11px]">
                        Team ID
                      </Label>
                      <Input
                        id="apple-team"
                        value={appleTeamId}
                        onChange={(e) => setAppleTeamId(e.target.value)}
                        placeholder="e.g. A3B8C9D0E1"
                        className="font-mono text-xs"
                        required
                      />
                    </div>
                  </div>
                </div>
              )}

              {selectedProvider === "google_play" && (
                <div className="border-border/60 bg-muted/20 space-y-2 rounded-md border p-3">
                  <div className="space-y-1.5">
                    <Label htmlFor="google-email" className="text-[11px]">
                      Service Account Client Email
                    </Label>
                    <Input
                      id="google-email"
                      type="email"
                      value={googleClientEmail}
                      onChange={(e) => setGoogleClientEmail(e.target.value)}
                      placeholder="deployer@project.iam.gserviceaccount.com"
                      className="font-mono text-xs"
                      required
                    />
                  </div>
                </div>
              )}

              {selectedProvider === "shorebird" && (
                <div className="border-border/60 bg-muted/20 space-y-2 rounded-md border p-3">
                  <div className="space-y-1.5">
                    <Label htmlFor="shorebird-app" className="text-[11px]">
                      Shorebird App ID (UUID)
                    </Label>
                    <Input
                      id="shorebird-app"
                      value={shorebirdAppId}
                      onChange={(e) => setShorebirdAppId(e.target.value)}
                      placeholder="8c7f6b5a-4d3e-2a1b-0c9d-8e7f6a5b4c3d"
                      className="font-mono text-xs"
                      required
                    />
                  </div>
                </div>
              )}

              {selectedProvider === "github" && (
                <div className="border-border/60 bg-muted/20 space-y-2 rounded-md border p-3">
                  <div className="space-y-1.5">
                    <Label htmlFor="gh-install" className="text-[11px]">
                      GitHub App Installation ID
                    </Label>
                    <Input
                      id="gh-install"
                      value={githubInstallationId}
                      onChange={(e) => setGithubInstallationId(e.target.value)}
                      placeholder="e.g. 54829104"
                      className="font-mono text-xs"
                      required
                    />
                  </div>
                </div>
              )}

              {selectedProvider === "gitlab" && (
                <div className="border-border/60 bg-muted/20 space-y-2 rounded-md border p-3">
                  <div className="space-y-1.5">
                    <Label htmlFor="gl-app" className="text-[11px]">
                      GitLab Application ID
                    </Label>
                    <Input
                      id="gl-app"
                      value={gitlabApplicationId}
                      onChange={(e) => setGitlabApplicationId(e.target.value)}
                      placeholder="e.g. gl_app_992144"
                      className="font-mono text-xs"
                      required
                    />
                  </div>
                </div>
              )}

              {selectedProvider === "bitbucket" && (
                <div className="border-border/60 bg-muted/20 space-y-2 rounded-md border p-3">
                  <div className="space-y-1.5">
                    <Label htmlFor="bb-workspace" className="text-[11px]">
                      Bitbucket Workspace Slug
                    </Label>
                    <Input
                      id="bb-workspace"
                      value={bitbucketWorkspace}
                      onChange={(e) => setBitbucketWorkspace(e.target.value)}
                      placeholder="e.g. bloom-workspace"
                      className="font-mono text-xs"
                      required
                    />
                  </div>
                </div>
              )}

              {/* Secret Token Textarea */}
              <div className="space-y-1.5">
                <Label htmlFor="secret-token">
                  Secret Material (Private Key .p8 / Service Account JSON /
                  Token)
                </Label>
                <Textarea
                  id="secret-token"
                  value={secretToken}
                  onChange={(e) => setSecretToken(e.target.value)}
                  placeholder="Paste private key text, JSON credential, or secret token here..."
                  rows={4}
                  className="font-mono text-xs leading-relaxed"
                  required
                />
                <p className="text-muted-foreground text-[11px]">
                  Encrypted immediately upon receipt. Plaintext secret is never
                  returned by the API.
                </p>
              </div>
            </div>

            <DialogFooter className="border-border/60 border-t pt-3">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => setDialogOpen(false)}
                disabled={isCreating}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                size="sm"
                disabled={isCreating || !credentialName || !secretToken}
              >
                {isCreating ? (
                  <BloomSpinner size={14} speed="fast" className="mr-2" />
                ) : null}
                Encrypt & Save Credential
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* Delete Credential Confirmation */}
      <AlertDialog
        open={!!credentialToDelete}
        onOpenChange={(open) => !open && setCredentialToDelete(null)}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Remove Platform Credential?</AlertDialogTitle>
            <AlertDialogDescription>
              Are you sure you want to delete credential{" "}
              <strong className="text-foreground font-mono">
                {credentialToDelete?.name}
              </strong>
              ? Builds and automated store release pipelines relying on this key
              will fail.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={isDeleting}>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDeleteCredential}
              disabled={isDeleting}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              {isDeleting ? (
                <BloomSpinner size={14} speed="fast" className="mr-2" />
              ) : null}
              Delete Credential
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
