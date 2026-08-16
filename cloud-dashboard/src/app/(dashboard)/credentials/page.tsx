"use client";

import * as React from "react";
import {
  Key,
  Plus,
  Trash,
  ArrowsClockwise,
  AppleLogo,
  AndroidLogo,
  GithubLogo,
  GitlabLogo,
  ShieldCheck,
  Lightning,
  Clock,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
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
  icon: React.ComponentType<{
    className?: string;
    weight?: "regular" | "bold" | "fill";
  }>;
}

const PROVIDERS: ProviderOption[] = [
  {
    id: "apple",
    name: "Apple App Store Connect",
    category: "Store Distribution",
    description:
      "App Store Connect API Key for TestFlight & App Store releases",
    icon: AppleLogo,
  },
  {
    id: "google_play",
    name: "Google Play Console",
    category: "Store Distribution",
    description: "Google Cloud Service Account for Play Store tracks",
    icon: AndroidLogo,
  },
  {
    id: "shorebird",
    name: "Shorebird CodePush",
    category: "CodePush",
    description: "Over-the-air instantaneous patch distribution for Flutter",
    icon: Lightning,
  },
  {
    id: "github",
    name: "GitHub App",
    category: "Source Control",
    description: "Automated PR previews, triggers, and deployment check suites",
    icon: GithubLogo,
  },
  {
    id: "gitlab",
    name: "GitLab",
    category: "Source Control",
    description: "GitLab CI/CD integration and pipeline triggers",
    icon: GitlabLogo,
  },
  {
    id: "bitbucket",
    name: "Bitbucket Cloud",
    category: "Source Control",
    description: "Atlassian Bitbucket repository webhooks & deployment sync",
    icon: ShieldCheck,
  },
];

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
        toast.success(res.message || "Connection validated successfully!");
      } else {
        toast.error(res.message || "Connection test failed.");
      }
      await fetchCredentials();
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Connection test error");
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
          <div className="space-y-1 font-mono text-xs text-zinc-300">
            <div className="flex items-center justify-between text-[11px]">
              <span className="text-zinc-500">Key ID:</span>
              <span>{meta.key_id || "••••••••"}</span>
            </div>
            <div className="flex items-center justify-between text-[11px]">
              <span className="text-zinc-500">Issuer ID:</span>
              <span className="max-w-[150px] truncate">
                {meta.issuer_id || "••••••••"}
              </span>
            </div>
            <div className="flex items-center justify-between text-[11px]">
              <span className="text-zinc-500">Team ID:</span>
              <span>{meta.team_id || "••••••••"}</span>
            </div>
          </div>
        );
      case "google_play":
        return (
          <div className="space-y-1 font-mono text-xs text-zinc-300">
            <div className="text-[11px]">
              <span className="block text-zinc-500">Client Email:</span>
              <span className="truncate text-zinc-200">
                {meta.client_email || "••••@iam.gserviceaccount.com"}
              </span>
            </div>
          </div>
        );
      case "shorebird":
        return (
          <div className="space-y-1 font-mono text-xs text-zinc-300">
            <div className="flex items-center justify-between text-[11px]">
              <span className="text-zinc-500">App ID:</span>
              <span className="max-w-[170px] truncate">
                {meta.app_id || "••••••••"}
              </span>
            </div>
          </div>
        );
      case "github":
        return (
          <div className="space-y-1 font-mono text-xs text-zinc-300">
            <div className="flex items-center justify-between text-[11px]">
              <span className="text-zinc-500">Installation ID:</span>
              <span>{meta.installation_id || "••••••••"}</span>
            </div>
          </div>
        );
      case "gitlab":
        return (
          <div className="space-y-1 font-mono text-xs text-zinc-300">
            <div className="flex items-center justify-between text-[11px]">
              <span className="text-zinc-500">Application ID:</span>
              <span>{meta.application_id || "••••••••"}</span>
            </div>
          </div>
        );
      case "bitbucket":
        return (
          <div className="space-y-1 font-mono text-xs text-zinc-300">
            <div className="flex items-center justify-between text-[11px]">
              <span className="text-zinc-500">Workspace:</span>
              <span>{meta.workspace || "••••••••"}</span>
            </div>
          </div>
        );
      default:
        return null;
    }
  };

  return (
    <div className="mx-auto max-w-6xl space-y-6">
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
              className="h-8 gap-1.5 text-xs text-zinc-300 transition-colors hover:bg-zinc-800"
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
                className="h-8 gap-1.5 bg-zinc-100 text-xs font-semibold text-zinc-950 hover:bg-zinc-200"
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
        <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-20">
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

            return (
              <Card
                key={cred.id}
                className="border-border/80 bg-zinc-950/60 transition-colors hover:border-zinc-700"
              >
                <CardHeader className="pb-3">
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex items-center gap-2.5">
                      <div className="border-border/80 flex size-8 items-center justify-center rounded-md border bg-zinc-900 text-zinc-200">
                        <ProviderIcon provider={cred.provider} size="sm" />
                      </div>
                      <div>
                        <CardTitle className="text-xs font-semibold text-zinc-100">
                          {cred.name}
                        </CardTitle>
                        <p className="text-[10px] text-zinc-400">
                          {providerInfo.name}
                        </p>
                      </div>
                    </div>
                    <StatusBadge status="healthy" label="Connected" size="sm" />
                  </div>
                </CardHeader>

                <CardContent className="space-y-3 pt-0">
                  <div className="rounded-md border border-zinc-800/80 bg-zinc-900/40 p-2.5">
                    {renderMetadata(cred)}
                  </div>

                  <div className="flex items-center justify-between font-mono text-[10px] text-zinc-500">
                    <div className="flex items-center gap-1">
                      <Clock className="size-3" />
                      <span>
                        Last used:{" "}
                        {cred.last_used_at
                          ? new Date(cred.last_used_at).toLocaleDateString()
                          : "Never"}
                      </span>
                    </div>
                  </div>
                </CardContent>

                <CardFooter className="flex items-center justify-between border-t border-zinc-800/80 pt-3">
                  {canTest && (
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => void handleTestConnection(cred)}
                      disabled={isTesting}
                      className="h-7 gap-1 text-xs"
                    >
                      {isTesting ? (
                        <BloomSpinner size={12} className="mr-1" />
                      ) : (
                        <ArrowsClockwise className="size-3" />
                      )}
                      <span>Test Connection</span>
                    </Button>
                  )}

                  {canManage && (
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => setCredentialToDelete(cred)}
                      className="size-7 h-7 p-0 text-red-400 hover:bg-red-950/40 hover:text-red-300"
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
        <DialogContent className="border-zinc-800 bg-zinc-900 text-zinc-100 sm:max-w-lg">
          <form onSubmit={handleCreateCredential} className="space-y-4">
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2 text-base">
                <Key className="size-4 text-zinc-400" />
                <span>Store Platform Credential</span>
              </DialogTitle>
              <DialogDescription className="text-xs text-zinc-400">
                Credentials are encrypted with AES-256-GCM and only decrypted in
                isolated build workers.
              </DialogDescription>
            </DialogHeader>

            <div className="space-y-3 py-1">
              <div className="space-y-1.5">
                <Label
                  htmlFor="provider-select"
                  className="text-xs font-medium text-zinc-300"
                >
                  Target Platform / Provider
                </Label>
                <Select
                  value={selectedProvider}
                  onValueChange={(v) => setSelectedProvider(v as ProviderType)}
                >
                  <SelectTrigger
                    id="provider-select"
                    className="border-zinc-700 bg-zinc-950 text-xs"
                  >
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent className="border-zinc-800 bg-zinc-900 text-zinc-100">
                    {PROVIDERS.map((p) => (
                      <SelectItem key={p.id} value={p.id} className="text-xs">
                        <div className="flex items-center gap-2">
                          <ProviderIcon provider={p.id} size={14} />
                          <span>{p.name}</span>
                          <span className="text-[10px] text-zinc-500">
                            ({p.category})
                          </span>
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-1.5">
                <Label
                  htmlFor="cred-name"
                  className="text-xs font-medium text-zinc-300"
                >
                  Credential Name / Label
                </Label>
                <Input
                  id="cred-name"
                  value={credentialName}
                  onChange={(e) => setCredentialName(e.target.value)}
                  placeholder="e.g. Production App Store API Key"
                  className="border-zinc-700 bg-zinc-950 text-xs"
                  required
                />
              </div>

              {/* Dynamic Metadata Fields based on Provider */}
              {selectedProvider === "apple" && (
                <div className="space-y-2 rounded-md border border-zinc-800 bg-zinc-950/60 p-3">
                  <div className="space-y-1.5">
                    <Label
                      htmlFor="apple-key"
                      className="text-[11px] font-medium text-zinc-300"
                    >
                      Key ID
                    </Label>
                    <Input
                      id="apple-key"
                      value={appleKeyId}
                      onChange={(e) => setAppleKeyId(e.target.value)}
                      placeholder="e.g. 2X9R4HXF34"
                      className="border-zinc-800 bg-zinc-900 font-mono text-xs"
                      required
                    />
                  </div>
                  <div className="grid grid-cols-2 gap-2">
                    <div className="space-y-1.5">
                      <Label
                        htmlFor="apple-issuer"
                        className="text-[11px] font-medium text-zinc-300"
                      >
                        Issuer ID (UUID)
                      </Label>
                      <Input
                        id="apple-issuer"
                        value={appleIssuerId}
                        onChange={(e) => setAppleIssuerId(e.target.value)}
                        placeholder="57246542-96fe-1a63-..."
                        className="border-zinc-800 bg-zinc-900 font-mono text-xs"
                        required
                      />
                    </div>
                    <div className="space-y-1.5">
                      <Label
                        htmlFor="apple-team"
                        className="text-[11px] font-medium text-zinc-300"
                      >
                        Team ID
                      </Label>
                      <Input
                        id="apple-team"
                        value={appleTeamId}
                        onChange={(e) => setAppleTeamId(e.target.value)}
                        placeholder="e.g. A3B8C9D0E1"
                        className="border-zinc-800 bg-zinc-900 font-mono text-xs"
                        required
                      />
                    </div>
                  </div>
                </div>
              )}

              {selectedProvider === "google_play" && (
                <div className="space-y-2 rounded-md border border-zinc-800 bg-zinc-950/60 p-3">
                  <div className="space-y-1.5">
                    <Label
                      htmlFor="google-email"
                      className="text-[11px] font-medium text-zinc-300"
                    >
                      Service Account Client Email
                    </Label>
                    <Input
                      id="google-email"
                      type="email"
                      value={googleClientEmail}
                      onChange={(e) => setGoogleClientEmail(e.target.value)}
                      placeholder="deployer@project.iam.gserviceaccount.com"
                      className="border-zinc-800 bg-zinc-900 font-mono text-xs"
                      required
                    />
                  </div>
                </div>
              )}

              {selectedProvider === "shorebird" && (
                <div className="space-y-2 rounded-md border border-zinc-800 bg-zinc-950/60 p-3">
                  <div className="space-y-1.5">
                    <Label
                      htmlFor="shorebird-app"
                      className="text-[11px] font-medium text-zinc-300"
                    >
                      Shorebird App ID (UUID)
                    </Label>
                    <Input
                      id="shorebird-app"
                      value={shorebirdAppId}
                      onChange={(e) => setShorebirdAppId(e.target.value)}
                      placeholder="8c7f6b5a-4d3e-2a1b-0c9d-8e7f6a5b4c3d"
                      className="border-zinc-800 bg-zinc-900 font-mono text-xs"
                      required
                    />
                  </div>
                </div>
              )}

              {selectedProvider === "github" && (
                <div className="space-y-2 rounded-md border border-zinc-800 bg-zinc-950/60 p-3">
                  <div className="space-y-1.5">
                    <Label
                      htmlFor="gh-install"
                      className="text-[11px] font-medium text-zinc-300"
                    >
                      GitHub App Installation ID
                    </Label>
                    <Input
                      id="gh-install"
                      value={githubInstallationId}
                      onChange={(e) => setGithubInstallationId(e.target.value)}
                      placeholder="e.g. 54829104"
                      className="border-zinc-800 bg-zinc-900 font-mono text-xs"
                      required
                    />
                  </div>
                </div>
              )}

              {selectedProvider === "gitlab" && (
                <div className="space-y-2 rounded-md border border-zinc-800 bg-zinc-950/60 p-3">
                  <div className="space-y-1.5">
                    <Label
                      htmlFor="gl-app"
                      className="text-[11px] font-medium text-zinc-300"
                    >
                      GitLab Application ID
                    </Label>
                    <Input
                      id="gl-app"
                      value={gitlabApplicationId}
                      onChange={(e) => setGitlabApplicationId(e.target.value)}
                      placeholder="e.g. gl_app_992144"
                      className="border-zinc-800 bg-zinc-900 font-mono text-xs"
                      required
                    />
                  </div>
                </div>
              )}

              {selectedProvider === "bitbucket" && (
                <div className="space-y-2 rounded-md border border-zinc-800 bg-zinc-950/60 p-3">
                  <div className="space-y-1.5">
                    <Label
                      htmlFor="bb-workspace"
                      className="text-[11px] font-medium text-zinc-300"
                    >
                      Bitbucket Workspace Slug
                    </Label>
                    <Input
                      id="bb-workspace"
                      value={bitbucketWorkspace}
                      onChange={(e) => setBitbucketWorkspace(e.target.value)}
                      placeholder="e.g. bloom-workspace"
                      className="border-zinc-800 bg-zinc-900 font-mono text-xs"
                      required
                    />
                  </div>
                </div>
              )}

              {/* Secret Token Textarea */}
              <div className="space-y-1.5">
                <Label
                  htmlFor="secret-token"
                  className="text-xs font-medium text-zinc-300"
                >
                  Secret Material (Private Key .p8 / Service Account JSON /
                  Token)
                </Label>
                <Textarea
                  id="secret-token"
                  value={secretToken}
                  onChange={(e) => setSecretToken(e.target.value)}
                  placeholder="Paste private key text, JSON credential, or secret token here..."
                  rows={4}
                  className="border-zinc-700 bg-zinc-950 font-mono text-xs leading-relaxed"
                  required
                />
                <p className="text-[11px] text-zinc-500">
                  Encrypted immediately upon receipt. Plaintext secret is never
                  returned by the API.
                </p>
              </div>
            </div>

            <DialogFooter className="border-t border-zinc-800 pt-3">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => setDialogOpen(false)}
                disabled={isCreating}
                className="text-xs"
              >
                Cancel
              </Button>
              <Button
                type="submit"
                size="sm"
                disabled={isCreating || !credentialName || !secretToken}
                className="bg-zinc-100 text-xs font-semibold text-zinc-950 hover:bg-zinc-200"
              >
                {isCreating ? (
                  <BloomSpinner size={14} className="mr-2" />
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
        <AlertDialogContent className="border-zinc-800 bg-zinc-900 text-zinc-100">
          <AlertDialogHeader>
            <AlertDialogTitle className="text-base">
              Remove Platform Credential?
            </AlertDialogTitle>
            <AlertDialogDescription className="text-xs text-zinc-400">
              Are you sure you want to delete credential{" "}
              <strong className="font-mono text-zinc-200">
                {credentialToDelete?.name}
              </strong>
              ? Builds and automated store release pipelines relying on this key
              will fail.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={isDeleting} className="text-xs">
              Cancel
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDeleteCredential}
              disabled={isDeleting}
              className="bg-red-600 text-xs font-semibold text-white hover:bg-red-700"
            >
              {isDeleting ? <BloomSpinner size={14} className="mr-2" /> : null}
              Delete Credential
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
