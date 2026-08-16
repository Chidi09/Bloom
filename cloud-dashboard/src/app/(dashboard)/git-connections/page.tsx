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
  Info,
  Plug,
  Copy,
  Check,
  MagnifyingGlass,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
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

  // Connect Provider Dialog State
  const [connectDialogOpen, setConnectDialogOpen] = React.useState(false);
  const [isConnecting, setIsConnecting] = React.useState(false);

  // Disconnect Confirmation State
  const [connectionToDisconnect, setConnectionToDisconnect] =
    React.useState<GitConnectionResponse | null>(null);
  const [isDisconnecting, setIsDisconnecting] = React.useState(false);

  // Copy state
  const [copiedInstId, setCopiedInstId] = React.useState<string | null>(null);

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
        installation_id: `${provider}_inst_${Math.floor(10000000 + Math.random() * 90000000)}`,
        access_token: `mock_${provider}_oauth_token_${Date.now()}`,
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
    toast.success("Installation ID copied");
    setTimeout(() => setCopiedInstId(null), 1500);
  };

  const getProviderIcon = (provider: string) => {
    return <ProviderIcon provider={provider} size="sm" />;
  };

  return (
    <div className="mx-auto max-w-6xl space-y-5">
      <PageHeader
        breadcrumbs={[
          { label: "Organization", href: "/organizations" },
          { label: "Git Connections" },
        ]}
        title="Git Integrations & Repositories"
        description="Connect your GitHub, GitLab, or Bitbucket accounts to automate continuous integration and branch preview deployments."
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
        <div className="space-y-5">
          <div className="border-border/80 bg-card overflow-hidden rounded-lg border shadow-xs">
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow className="hover:bg-transparent">
                    <TableHead className="w-[200px]">Git Host</TableHead>
                    <TableHead>Account / Organization</TableHead>
                    <TableHead>Installation ID</TableHead>
                    <TableHead>Connection Status</TableHead>
                    <TableHead>Connected Date</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {connections.map((conn) => {
                    const meta = conn.metadata as {
                      account_name?: string;
                      account_type?: string;
                      repositories_count?: number;
                    };

                    const isGitlab = conn.provider.toLowerCase() === "gitlab";
                    const isBitbucket =
                      conn.provider.toLowerCase() === "bitbucket";
                    const isGithub = conn.provider.toLowerCase() === "github";

                    return (
                      <TableRow
                        key={conn.id}
                        className={cn(
                          "hover:bg-muted/40 transition-colors",
                          isGitlab && "border-l-2 border-l-[#fc6d26]",
                          isBitbucket && "border-l-2 border-l-[#0052cc]",
                          isGithub &&
                            "border-l-2 border-l-zinc-300 dark:border-l-zinc-100",
                        )}
                      >
                        <TableCell>
                          <div className="flex items-center gap-2.5">
                            <div
                              className={cn(
                                "flex size-7 items-center justify-center rounded-md border text-xs shadow-xs",
                                isGitlab &&
                                  "border-[#fc6d26]/40 bg-[#fc6d26]/10 text-[#fc6d26]",
                                isBitbucket &&
                                  "border-[#0052cc]/40 bg-[#0052cc]/10 text-[#0052cc]",
                                isGithub &&
                                  "border-border/80 bg-muted/50 text-foreground",
                              )}
                            >
                              {getProviderIcon(conn.provider)}
                            </div>
                            <span className="text-foreground text-xs font-semibold uppercase">
                              {conn.provider}
                            </span>
                          </div>
                        </TableCell>

                        <TableCell>
                          <div className="space-y-0.5 font-mono text-xs">
                            <span className="text-foreground font-semibold">
                              {meta?.account_name || "bloom-labs"}
                            </span>
                            {meta?.account_type && (
                              <span className="text-muted-foreground block text-[10px]">
                                {meta.account_type}
                              </span>
                            )}
                          </div>
                        </TableCell>

                        <TableCell className="text-muted-foreground font-mono text-xs">
                          <div className="flex items-center gap-1.5">
                            <TooltipProvider>
                              <Tooltip>
                                <TooltipTrigger className="max-w-[140px] cursor-help truncate">
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
                              className="text-muted-foreground hover:text-foreground transition-colors"
                              title="Copy Installation ID"
                            >
                              {copiedInstId === conn.id ? (
                                <Check className="size-3 text-emerald-400" />
                              ) : (
                                <Copy className="size-3" />
                              )}
                            </button>
                          </div>
                        </TableCell>

                        <TableCell>
                          <StatusBadge
                            status="healthy"
                            label="Connected"
                            size="sm"
                          />
                        </TableCell>

                        <TableCell className="text-muted-foreground font-mono text-xs">
                          {new Date(conn.created_at).toLocaleDateString()}
                        </TableCell>

                        <TableCell className="text-right">
                          <div className="flex items-center justify-end gap-1.5">
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => void handleOpenRepositories(conn)}
                              className="h-7 gap-1.5 text-xs transition-colors"
                            >
                              <FolderSimple className="size-3.5" />
                              <span>Repositories</span>
                            </Button>

                            {canManage && (
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => setConnectionToDisconnect(conn)}
                                className="text-muted-foreground hover:text-destructive hover:bg-destructive/10 size-7 h-7 p-0 transition-colors"
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

          {/* Webhook & Branch Deploy Policies Notice Card */}
          <Card className="border-border/80 bg-card">
            <CardHeader className="pb-3">
              <div className="flex items-center justify-between">
                <CardTitle className="text-foreground flex items-center gap-2 text-sm font-semibold">
                  <GitBranch className="text-muted-foreground size-4" />
                  <span>Branch Deploy & Webhook Delivery Policies</span>
                </CardTitle>
                <Badge
                  variant="outline"
                  className="text-muted-foreground font-mono text-[10px]"
                >
                  Auto-Sync
                </Badge>
              </div>
              <CardDescription className="text-muted-foreground text-xs">
                Inbound push and pull request webhooks are cryptographically
                validated using HMAC-SHA256 signatures.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="border-border/60 bg-muted/20 text-muted-foreground rounded-md border p-3 text-xs">
                <div className="flex items-start gap-2.5">
                  <Info className="text-muted-foreground mt-0.5 size-4 shrink-0" />
                  <div className="space-y-1 text-xs">
                    <p className="text-foreground font-medium">
                      Automatic Pull Request Preview Environments
                    </p>
                    <p className="text-muted-foreground text-[11px] leading-relaxed">
                      Push events to{" "}
                      <code className="text-foreground font-mono">main</code> or
                      feature branches automatically create isolated WASM web
                      preview deployments with preview URLs commented directly
                      onto the pull request.
                    </p>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Repositories Sheet */}
      <Sheet open={sheetOpen} onOpenChange={setSheetOpen}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader className="border-border border-b pb-4">
            <SheetTitle className="flex items-center gap-2 text-base">
              <FolderSimple className="text-muted-foreground size-4" />
              <span>
                Available Repositories (
                {(selectedConnection?.metadata?.account_name as
                  string | undefined) || selectedConnection?.provider}
                )
              </span>
            </SheetTitle>
            <SheetDescription className="text-muted-foreground text-xs">
              Repositories accessible via this installation for application
              linking.
            </SheetDescription>
          </SheetHeader>

          <div className="space-y-3 py-4">
            {repositories.length > 0 && (
              <div className="relative">
                <MagnifyingGlass className="text-muted-foreground absolute top-2.5 left-2.5 size-3.5" />
                <Input
                  type="text"
                  value={repoSearchQuery}
                  onChange={(e) => setRepoSearchQuery(e.target.value)}
                  placeholder="Filter repositories by name or branch..."
                  className="h-8 pl-8 font-mono text-xs"
                />
              </div>
            )}

            {isLoadingRepos ? (
              <div className="flex items-center justify-center py-12">
                <BloomSpinner size={24} label="Querying repositories..." />
              </div>
            ) : repositories.length === 0 ? (
              <EmptyState
                icon={FolderSimple}
                title="No repositories found"
                description="Make sure repository permissions are granted to the Bloom Cloud App."
              />
            ) : (
              (() => {
                const filteredRepos = repositories.filter(
                  (r) =>
                    r.full_name
                      .toLowerCase()
                      .includes(repoSearchQuery.toLowerCase()) ||
                    (r.default_branch &&
                      r.default_branch
                        .toLowerCase()
                        .includes(repoSearchQuery.toLowerCase())),
                );

                if (filteredRepos.length === 0) {
                  return (
                    <div className="border-border bg-muted/20 text-muted-foreground rounded-md border p-6 text-center text-xs">
                      No repositories match &quot;{repoSearchQuery}&quot;
                    </div>
                  );
                }

                return (
                  <div className="border-border/80 bg-card overflow-hidden rounded-lg border shadow-xs">
                    <div className="overflow-x-auto">
                      <Table>
                        <TableHeader>
                          <TableRow className="hover:bg-transparent">
                            <TableHead>Repository</TableHead>
                            <TableHead className="w-[100px]">Branch</TableHead>
                            <TableHead className="text-right">Link</TableHead>
                          </TableRow>
                        </TableHeader>
                        <TableBody>
                          {filteredRepos.map((repo) => (
                            <TableRow
                              key={repo.id}
                              className="hover:bg-muted/40 transition-colors"
                            >
                              <TableCell>
                                <div className="text-foreground max-w-[200px] truncate font-mono text-xs font-semibold">
                                  {repo.full_name}
                                </div>
                              </TableCell>

                              <TableCell>
                                <Badge
                                  variant="outline"
                                  className="text-muted-foreground font-mono text-[10px]"
                                >
                                  {repo.default_branch || "main"}
                                </Badge>
                              </TableCell>

                              <TableCell className="text-right">
                                <Link
                                  href={repo.url}
                                  target="_blank"
                                  className="text-muted-foreground hover:text-foreground inline-flex items-center gap-1 font-mono text-xs transition-colors"
                                >
                                  <span>Open</span>
                                  <ArrowSquareOut className="size-3" />
                                </Link>
                              </TableCell>
                            </TableRow>
                          ))}
                        </TableBody>
                      </Table>
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
              webhook events.
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
    </div>
  );
}
