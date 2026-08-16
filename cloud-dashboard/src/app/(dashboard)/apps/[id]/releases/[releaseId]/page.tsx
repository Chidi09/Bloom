"use client";

import * as React from "react";
import { useParams, useRouter } from "next/navigation";
import {
  FloppyDisk,
  ThumbsUp,
  ThumbsDown,
  ArrowCounterClockwise,
  WarningOctagon,
  ArrowsClockwise,
  RocketLaunch,
  DownloadSimple,
  Copy,
  Check,
  Package,
  ShieldCheck,
  Lock,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Textarea } from "@/components/ui/textarea";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Progress } from "@/components/ui/progress";
import { PageHeader } from "@/components/shared/page-header";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { PlatformIcon } from "@/components/status/platform-icon";
import { StatusBadge } from "@/components/status/status-badge";
import { EmptyState } from "@/components/shared/empty-state";
import { api } from "@/lib/api/client";
import { ReleaseResponse, ReleaseArtifact } from "@/lib/schemas/release";
import { AppResponse } from "@/lib/schemas/app";
import { useOrganizationStore } from "@/stores/organization-store";
import { useOrganizationEvents } from "@/lib/hooks/use-organization-events";
import { OrganizationRoleName, hasRole } from "@/lib/auth/roles";

function formatFileSize(bytes?: number): string {
  if (!bytes || bytes <= 0) return "--";
  const units = ["B", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  return `${(bytes / Math.pow(1024, i)).toFixed(1)} ${units[i]}`;
}

export default function AppReleaseDetailPage() {
  const params = useParams<{ id: string; releaseId: string }>();
  const router = useRouter();
  const appId = params.id;
  const releaseId = params.releaseId;
  const { currentOrganizationId } = useOrganizationStore();

  useOrganizationEvents(currentOrganizationId);

  const [app, setApp] = React.useState<AppResponse | null>(null);
  const [release, setRelease] = React.useState<ReleaseResponse | null>(null);
  const [changelog, setChangelog] = React.useState("");
  const [activeChangelogTab, setActiveChangelogTab] = React.useState("write");
  const [isLoading, setIsLoading] = React.useState(true);
  const [isSaving, setIsSaving] = React.useState(false);
  const [isProcessing, setIsProcessing] = React.useState(false);
  const [copiedChecksumId, setCopiedChecksumId] = React.useState<string | null>(
    null,
  );
  const [error, setError] = React.useState<string | null>(null);

  // User role for hard-hide gating
  const [userRole, setUserRole] =
    React.useState<OrganizationRoleName>("Developer");

  const fetchData = React.useCallback(async () => {
    if (!appId || !releaseId) return;
    setIsLoading(true);
    setError(null);
    try {
      const [appRes, relRes, orgRes] = await Promise.all([
        api.get<AppResponse>(`/apps/${appId}`),
        api.get<ReleaseResponse>(`/releases/${releaseId}`),
        currentOrganizationId
          ? api
              .get<{ role: string }>(`/organizations/${currentOrganizationId}`)
              .catch(() => null)
          : Promise.resolve(null),
      ]);

      setApp(appRes);
      setRelease(relRes);
      setChangelog(relRes.changelog || "");
      if (orgRes?.role) {
        setUserRole(orgRes.role as OrganizationRoleName);
      }
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Failed to load release details",
      );
    } finally {
      setIsLoading(false);
    }
  }, [appId, releaseId, currentOrganizationId]);

  React.useEffect(() => {
    const run = async () => {
      await fetchData();
    };
    void run();
  }, [fetchData]);

  const handleSaveChangelog = async () => {
    if (!release) return;
    setIsSaving(true);
    try {
      const updated = await api.patch<ReleaseResponse>(
        `/releases/${release.id}`,
        { changelog: changelog.trim() },
      );
      setRelease(updated);
      toast.success("Changelog saved successfully");
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to save changelog",
      );
    } finally {
      setIsSaving(false);
    }
  };

  const handleApprove = async (approved: boolean) => {
    if (!release) return;
    setIsProcessing(true);
    try {
      const updated = await api.post<ReleaseResponse>(
        `/releases/${release.id}/approve`,
        { approved },
      );
      setRelease(updated);
      toast.success(
        approved
          ? "Release approved and scheduled for rollout"
          : "Release rejected",
      );
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to update approval status",
      );
    } finally {
      setIsProcessing(false);
    }
  };

  const handleRollback = async () => {
    if (!release) return;
    setIsProcessing(true);
    try {
      const updated = await api.post<ReleaseResponse>(
        `/releases/${release.id}/rollback`,
        { reason: "Manual rollback from release detail page" },
      );
      setRelease(updated);
      toast.success("Release marked as rolled back");
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to rollback release",
      );
    } finally {
      setIsProcessing(false);
    }
  };

  const handleCopyChecksum = (id: string, checksum: string) => {
    if (!checksum) return;
    navigator.clipboard.writeText(checksum);
    setCopiedChecksumId(id);
    toast.success("SHA-256 checksum copied to clipboard");
    setTimeout(() => {
      setCopiedChecksumId((prev) => (prev === id ? null : prev));
    }, 2000);
  };

  const handleDownloadArtifact = (artifact: ReleaseArtifact) => {
    if (artifact.download_url) {
      window.open(artifact.download_url, "_blank");
    } else {
      toast.success(`Starting download for ${artifact.file_name}`);
    }
  };

  const canApprove = hasRole(userRole, "ReleaseManager");

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-16">
        <BloomSpinner size={28} label="Loading release details..." />
      </div>
    );
  }

  if (error) {
    return (
      <Alert variant="destructive">
        <AlertTitle>Failed to load release</AlertTitle>
        <AlertDescription className="flex items-center justify-between">
          <span>{error}</span>
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchData()}
              className="h-7 text-xs"
            >
              Retry
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => router.push(`/apps/${appId}/releases`)}
              className="h-7 text-xs"
            >
              Back to Releases
            </Button>
          </div>
        </AlertDescription>
      </Alert>
    );
  }

  if (!release) {
    return (
      <EmptyState
        icon={RocketLaunch}
        title="Release Not Found"
        description="The requested release record could not be found or has been removed."
        actionLabel="Back to Releases"
        onAction={() => router.push(`/apps/${appId}/releases`)}
      />
    );
  }

  const isPending = release.status === "pending_approval";

  return (
    <div className="space-y-6">
      {/* Top Header */}
      <PageHeader
        breadcrumbs={[
          { label: "Applications", href: "/apps" },
          { label: app?.name || "App", href: `/apps/${appId}/builds` },
          { label: "Releases", href: `/apps/${appId}/releases` },
          { label: release.version },
        ]}
        title={`Release ${release.version}`}
        badge={
          <div className="flex items-center gap-2">
            <StatusBadge status={release.status} />
            <Badge variant="secondary" className="font-mono text-xs">
              Build #{release.build_number}
            </Badge>
          </div>
        }
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchData()}
              className="h-8 gap-1.5"
            >
              <ArrowsClockwise className="size-3.5" />
              <span>Refresh</span>
            </Button>

            {release.status !== "rolled_back" && (
              <AlertDialog>
                <AlertDialogTrigger className="bg-destructive/10 text-destructive hover:bg-destructive hover:text-destructive-foreground border-destructive/30 inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-md border px-3 text-xs font-medium transition-colors">
                  <ArrowCounterClockwise className="size-3.5" />
                  <span>Rollback</span>
                </AlertDialogTrigger>
                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle>
                      Rollback Release {release.version}?
                    </AlertDialogTitle>
                    <AlertDialogDescription className="space-y-2 text-left">
                      <p>
                        This is a destructive action. Rolling back will
                        transition release <strong>{release.version}</strong> to
                        the <strong>rolled_back</strong> state and immediately
                        stop active distribution channels from serving this
                        version.
                      </p>
                      <p className="text-muted-foreground text-xs">
                        Connected app stores and edge hosts will revert to the
                        previous verified stable release.
                      </p>
                    </AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>Cancel</AlertDialogCancel>
                    <AlertDialogAction
                      onClick={handleRollback}
                      className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                    >
                      Confirm Rollback
                    </AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
            )}
          </div>
        }
      />

      {/* High-Impact Approval Panel (Action Needed) */}
      {isPending && (
        <Card className="border-amber-500/50 bg-gradient-to-br from-amber-500/15 via-amber-500/5 to-transparent shadow-md ring-1 ring-amber-500/20">
          <CardHeader className="pb-3">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div className="flex items-start gap-3">
                <div className="mt-0.5 rounded-lg border border-amber-500/30 bg-amber-500/20 p-2 text-amber-400 shadow-xs">
                  <WarningOctagon className="size-5" weight="bold" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <CardTitle className="text-base font-semibold text-amber-200">
                      Action Required: Release Approval Pending
                    </CardTitle>
                    <Badge className="border-amber-500/40 bg-amber-500/20 text-[10px] font-semibold text-amber-300">
                      Awaiting Sign-off
                    </Badge>
                  </div>
                  <CardDescription className="text-foreground/80 mt-1 text-xs">
                    Release <strong>v{release.version}</strong> (Build #
                    {release.build_number}) is fully built and staged for
                    distribution. A Release Manager must approve or reject this
                    version before rollout begins.
                  </CardDescription>
                </div>
              </div>

              {/* Action Buttons for Release Managers */}
              {canApprove ? (
                <div className="flex items-center gap-2 pt-1 sm:pt-0">
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => void handleApprove(false)}
                    disabled={isProcessing}
                    className="border-destructive/40 bg-background/60 text-destructive hover:bg-destructive hover:text-destructive-foreground h-8 cursor-pointer gap-1.5 text-xs font-medium transition-colors"
                  >
                    <ThumbsDown className="size-3.5" />
                    <span>Reject</span>
                  </Button>
                  <Button
                    size="sm"
                    onClick={() => void handleApprove(true)}
                    disabled={isProcessing}
                    className="h-8 cursor-pointer gap-1.5 bg-emerald-600 text-xs font-medium text-white shadow-xs transition-colors hover:bg-emerald-500"
                  >
                    {isProcessing ? (
                      <BloomSpinner size={14} speed="fast" />
                    ) : (
                      <ThumbsUp className="size-3.5" />
                    )}
                    <span>Approve &amp; Rollout</span>
                  </Button>
                </div>
              ) : (
                <div className="border-border/60 bg-background/50 text-muted-foreground flex items-center gap-1.5 rounded-md border px-3 py-1.5 text-xs">
                  <Lock className="size-3.5 shrink-0" />
                  <span>
                    Role <strong>{userRole}</strong> cannot approve. Requires{" "}
                    <strong>ReleaseManager</strong>.
                  </span>
                </div>
              )}
            </div>
          </CardHeader>
        </Card>
      )}

      {/* Content Grid */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        {/* Left Column: Changelog Editor & Artifacts */}
        <div className="space-y-6 lg:col-span-2">
          {/* Changelog Editor */}
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <div>
                  <CardTitle className="text-base font-semibold">
                    Release Notes &amp; Changelog
                  </CardTitle>
                  <CardDescription>
                    Markdown formatted notes distributed to app stores and
                    release tags.
                  </CardDescription>
                </div>
                <Button
                  size="sm"
                  onClick={handleSaveChangelog}
                  disabled={isSaving}
                  className="h-8 gap-1.5"
                >
                  {isSaving ? (
                    <BloomSpinner size={14} speed="fast" />
                  ) : (
                    <FloppyDisk className="size-3.5" />
                  )}
                  <span>Save Notes</span>
                </Button>
              </div>
            </CardHeader>

            <CardContent>
              <Tabs
                value={activeChangelogTab}
                onValueChange={setActiveChangelogTab}
              >
                <TabsList className="grid w-[180px] grid-cols-2">
                  <TabsTrigger value="write" className="text-xs">
                    Write
                  </TabsTrigger>
                  <TabsTrigger value="preview" className="text-xs">
                    Preview
                  </TabsTrigger>
                </TabsList>

                <TabsContent value="write" className="pt-3">
                  <Textarea
                    placeholder="Describe new features, fixes, and improvements in markdown..."
                    value={changelog}
                    onChange={(e) => setChangelog(e.target.value)}
                    rows={10}
                    className="font-mono text-xs leading-relaxed"
                  />
                </TabsContent>

                <TabsContent value="preview" className="pt-3">
                  <div className="border-border/80 bg-muted/20 text-foreground/90 min-h-[200px] rounded-md border p-4 font-mono text-xs leading-relaxed whitespace-pre-wrap shadow-xs">
                    {changelog || "(No changelog content provided)"}
                  </div>
                </TabsContent>
              </Tabs>
            </CardContent>
          </Card>

          {/* Artifacts List Section */}
          <Card className="border-border/80 bg-card shadow-xs">
            <CardHeader className="pb-3">
              <div className="flex items-center justify-between">
                <div>
                  <CardTitle className="text-base font-semibold">
                    Release Artifacts &amp; Binaries
                  </CardTitle>
                  <CardDescription>
                    Compiled application packages and distribution bundles for
                    this release.
                  </CardDescription>
                </div>
                <Badge
                  variant="secondary"
                  className="font-mono text-[10px] tracking-wider uppercase"
                >
                  {release.artifacts?.length || 0} Binaries
                </Badge>
              </div>
            </CardHeader>

            <CardContent className="space-y-3">
              {release.artifacts && release.artifacts.length > 0 ? (
                <div className="divide-border/60 border-border/70 divide-y rounded-lg border">
                  {release.artifacts.map((artifact) => {
                    const isCopied = copiedChecksumId === artifact.id;
                    return (
                      <div
                        key={artifact.id}
                        className="hover:bg-muted/30 flex flex-col gap-3 p-3 transition-colors sm:flex-row sm:items-center sm:justify-between"
                      >
                        <div className="flex min-w-0 items-start gap-3">
                          <div className="border-border/60 bg-muted/40 text-foreground mt-0.5 shrink-0 rounded-md border p-2">
                            <PlatformIcon
                              platform={artifact.platform}
                              size="sm"
                            />
                          </div>
                          <div className="min-w-0 space-y-1">
                            <div className="flex flex-wrap items-center gap-2">
                              <span className="text-foreground truncate font-mono text-xs font-semibold">
                                {artifact.file_name}
                              </span>
                              <Badge
                                variant="outline"
                                className="bg-muted/40 font-mono text-[9px] uppercase"
                              >
                                {artifact.kind || "binary"}
                              </Badge>
                            </div>

                            {/* Secondary text treatment for size & checksum */}
                            <div className="text-muted-foreground flex items-center gap-3 font-mono text-[11px]">
                              <span>
                                Size:{" "}
                                <strong className="text-foreground/90 font-medium">
                                  {formatFileSize(artifact.file_size)}
                                </strong>
                              </span>
                              <span>•</span>
                              <div className="flex items-center gap-1">
                                <span>SHA-256:</span>
                                <span className="text-foreground/80 max-w-[120px] truncate sm:max-w-[180px]">
                                  {artifact.checksum
                                    ? artifact.checksum.replace(/^sha256:/i, "")
                                    : "verified"}
                                </span>
                                {artifact.checksum && (
                                  <button
                                    type="button"
                                    onClick={() =>
                                      handleCopyChecksum(
                                        artifact.id,
                                        artifact.checksum,
                                      )
                                    }
                                    className="text-muted-foreground hover:text-foreground inline-flex cursor-pointer p-0.5 transition-colors"
                                    title="Copy full SHA-256 checksum"
                                  >
                                    {isCopied ? (
                                      <Check className="size-3 text-emerald-400" />
                                    ) : (
                                      <Copy className="size-3" />
                                    )}
                                  </button>
                                )}
                              </div>
                            </div>
                          </div>
                        </div>

                        {/* Download Action with clear hover state */}
                        <div className="flex shrink-0 items-center justify-end pt-1 sm:pt-0">
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => handleDownloadArtifact(artifact)}
                            className="border-border/80 bg-background/50 hover:bg-primary hover:text-primary-foreground group h-8 cursor-pointer gap-1.5 text-xs font-medium shadow-xs transition-all duration-150"
                          >
                            <DownloadSimple className="size-3.5 transition-transform group-hover:-translate-y-0.5" />
                            <span>Download</span>
                          </Button>
                        </div>
                      </div>
                    );
                  })}
                </div>
              ) : (
                <div className="border-border/60 bg-muted/10 flex flex-col items-center justify-center rounded-lg border border-dashed py-8 text-center">
                  <Package className="text-muted-foreground mb-2 size-8 opacity-60" />
                  <p className="text-foreground text-xs font-medium">
                    No Binary Artifacts Attached
                  </p>
                  <p className="text-muted-foreground mt-0.5 text-[11px]">
                    Artifacts generated by automated CI/CD builds will appear
                    here.
                  </p>
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Right Column: Metadata & Rollout */}
        <div className="space-y-6">
          {/* Metadata Card */}
          <Card className="border-border/80 bg-card shadow-xs">
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-semibold">
                Release Metadata
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 font-mono text-xs">
              <div className="text-muted-foreground flex items-center justify-between">
                <span>Version</span>
                <span className="text-foreground font-semibold">
                  {release.version}
                </span>
              </div>
              <div className="text-muted-foreground flex items-center justify-between">
                <span>Source Build</span>
                <span className="text-foreground font-semibold">
                  #{release.build_number}
                </span>
              </div>
              <div className="text-muted-foreground flex items-center justify-between">
                <span>Commit SHA</span>
                <span className="text-foreground font-semibold">
                  {release.commit.slice(0, 7)}
                </span>
              </div>
              <div className="text-muted-foreground flex items-center justify-between">
                <span>Platforms</span>
                <div className="flex items-center gap-1.5">
                  {release.platforms?.map((p) => (
                    <PlatformIcon key={p} platform={p} size="sm" />
                  ))}
                </div>
              </div>
              <div className="text-muted-foreground flex items-center justify-between">
                <span>Created Date</span>
                <span className="text-foreground">
                  {new Date(release.created_at).toLocaleDateString()}
                </span>
              </div>
              <div className="text-muted-foreground flex items-center justify-between">
                <span>Created By</span>
                <span className="text-foreground">
                  {release.created_by_id || "CI/CD Pipeline"}
                </span>
              </div>
            </CardContent>
          </Card>

          {/* Rollout Progress Card with Progress Bars */}
          <Card className="border-border/80 bg-card shadow-xs">
            <CardHeader className="pb-3">
              <div className="flex items-center justify-between">
                <CardTitle className="text-sm font-semibold">
                  Platform Rollout Progress
                </CardTitle>
                <ShieldCheck className="text-muted-foreground size-4" />
              </div>
              <CardDescription className="text-xs">
                Active staged rollout distribution across platform tracks.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              {release.platforms?.map((p) => {
                const rawPercent = (
                  release.rollout_status as Record<string, unknown>
                )?.[p];
                const percent =
                  typeof rawPercent === "number"
                    ? rawPercent
                    : release.status === "released" ||
                        release.status === "approved"
                      ? 100
                      : release.status === "draft" ||
                          release.status === "pending_approval"
                        ? 0
                        : 50;

                const isComplete = percent >= 100;

                return (
                  <div
                    key={p}
                    className="border-border/60 bg-muted/20 space-y-2 rounded-lg border p-3"
                  >
                    <div className="flex items-center justify-between text-xs">
                      <div className="flex items-center gap-2 font-medium capitalize">
                        <PlatformIcon platform={p} size="sm" />
                        <span className="text-foreground">{p}</span>
                      </div>
                      <Badge
                        variant="secondary"
                        className={
                          isComplete
                            ? "border-emerald-500/30 bg-emerald-500/10 font-mono text-[10px] text-emerald-400"
                            : percent > 0
                              ? "border-blue-500/30 bg-blue-500/10 font-mono text-[10px] text-blue-400"
                              : "bg-muted/60 text-muted-foreground font-mono text-[10px]"
                        }
                      >
                        {percent}% {isComplete ? "completed" : "active"}
                      </Badge>
                    </div>

                    {/* Progress Bar Component */}
                    <Progress value={percent} className="bg-muted h-1.5 w-full">
                      <div className="bg-primary h-full transition-all duration-300" />
                    </Progress>
                  </div>
                );
              })}
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
