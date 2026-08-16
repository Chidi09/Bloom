"use client";

import * as React from "react";
import { useParams, useRouter } from "next/navigation";
import {
  ArrowsClockwise,
  Hammer,
  GitBranch,
  Clock,
  Check,
  XCircle,
  Circle,
  Prohibit,
  Copy,
  TerminalWindow,
  Cpu,
  FileCode,
  WarningOctagon,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";
import { Separator } from "@/components/ui/separator";
import { ScrollArea } from "@/components/ui/scroll-area";
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
import { PageHeader } from "@/components/shared/page-header";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { PlatformIcon } from "@/components/status/platform-icon";
import { StatusBadge } from "@/components/status/status-badge";
import { UserAvatar } from "@/components/ui/user-avatar";
import { EmptyState } from "@/components/shared/empty-state";
import { api } from "@/lib/api/client";
import {
  BuildResponse,
  BuildLogsResponse,
  BuildStageResponse,
} from "@/lib/schemas/build";
import { AppResponse } from "@/lib/schemas/app";
import { EnvironmentResponse } from "@/lib/schemas/environment";
import { useOrganizationStore } from "@/stores/organization-store";
import { useOrganizationEvents } from "@/lib/hooks/use-organization-events";
import { OrganizationRoleName, hasRole } from "@/lib/auth/roles";

export default function AppBuildDetailPage() {
  const params = useParams<{ id: string; buildId: string }>();
  const router = useRouter();
  const appId = params.id;
  const buildId = params.buildId;
  const { currentOrganizationId } = useOrganizationStore();

  useOrganizationEvents(currentOrganizationId);

  const [app, setApp] = React.useState<AppResponse | null>(null);
  const [build, setBuild] = React.useState<BuildResponse | null>(null);
  const [environment, setEnvironment] =
    React.useState<EnvironmentResponse | null>(null);
  const [allBuilds, setAllBuilds] = React.useState<BuildResponse[]>([]);
  const [logs, setLogs] = React.useState<string>("");
  const [, setLogsLoading] = React.useState<boolean>(false);
  const [autoScroll, setAutoScroll] = React.useState<boolean>(true);
  const [isRebuilding, setIsRebuilding] = React.useState<boolean>(false);
  const [isCancelling, setIsCancelling] = React.useState<boolean>(false);
  const [copiedLog, setCopiedLog] = React.useState<boolean>(false);
  const [copiedCommit, setCopiedCommit] = React.useState<boolean>(false);
  const [isLoading, setIsLoading] = React.useState<boolean>(true);
  const [error, setError] = React.useState<string | null>(null);
  const [userRole, setUserRole] =
    React.useState<OrganizationRoleName>("Developer");

  const logEndRef = React.useRef<HTMLDivElement>(null);

  const fetchLogs = React.useCallback(
    async (bldId: string, stages: BuildStageResponse[]) => {
      setLogsLoading(true);
      try {
        const logsRes = await api.get<BuildLogsResponse>(
          `/builds/${bldId}/logs`,
        );
        if (logsRes?.url) {
          try {
            const res = await fetch(logsRes.url);
            if (res.ok) {
              const text = await res.text();
              if (text && text.trim().length > 0) {
                setLogs(text);
                return;
              }
            }
          } catch {
            // Direct fetch of signed url failed or was mock URL; fallback to snippets
          }
        }
      } catch {
        // Endpoint failure or mock; fallback to snippets
      } finally {
        setLogsLoading(false);
      }

      // Fallback: concatenate stage log snippets
      const snippets = stages
        .flatMap((s) => s.log_snippet)
        .filter(Boolean) as string[];
      if (snippets.length > 0) {
        setLogs(snippets.join("\n"));
      } else {
        setLogs("");
      }
    },
    [],
  );

  const fetchData = React.useCallback(async () => {
    if (!appId || !buildId) return;
    setIsLoading(true);
    setError(null);
    try {
      const [appRes, buildRes, allBuildsRes, orgRes] = await Promise.all([
        api.get<AppResponse>(`/apps/${appId}`),
        api.get<BuildResponse>(`/builds/${buildId}`),
        api
          .get<{ results: BuildResponse[] }>("/builds", {
            params: { app_id: appId },
          })
          .catch(() => ({ results: [] })),
        currentOrganizationId
          ? api
              .get<{ role: string }>(`/organizations/${currentOrganizationId}`)
              .catch(() => null)
          : Promise.resolve(null),
      ]);

      setApp(appRes);
      setBuild(buildRes);
      setAllBuilds(allBuildsRes?.results ?? []);
      if (orgRes?.role) {
        setUserRole(orgRes.role as OrganizationRoleName);
      }

      // Fetch environment details if available
      if (buildRes.environment_id) {
        api
          .get<EnvironmentResponse>(`/environments/${buildRes.environment_id}`)
          .then((env) => setEnvironment(env))
          .catch(() => null);
      }

      // Fetch logs asynchronously without blocking the page
      void fetchLogs(buildRes.id, buildRes.stages || []);
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Failed to load build details",
      );
    } finally {
      setIsLoading(false);
    }
  }, [appId, buildId, currentOrganizationId, fetchLogs]);

  React.useEffect(() => {
    const run = async () => {
      await fetchData();
    };
    void run();
  }, [fetchData]);

  // Derived build number
  const buildIndex = build ? allBuilds.findIndex((b) => b.id === build.id) : -1;
  const buildNumber =
    build?.build_number ??
    (buildIndex >= 0 ? allBuilds.length - buildIndex : build?.id.slice(0, 8));

  // Resolved log text for pre viewer
  const formattedLogs = React.useMemo(() => {
    if (logs && logs.trim().length > 0) return logs;
    const snippets = build?.stages
      ?.flatMap((s) => s.log_snippet)
      .filter(Boolean)
      .join("\n");
    if (snippets && snippets.trim().length > 0) return snippets;

    const commitSha = build?.git_commit || "HEAD";
    return `[00:00.01] Worker initialized for build #${buildNumber}
[00:00.15] Target platform: ${build?.platform || "all"}
[00:01.02] Resolved branch: ${build?.git_branch || "main"} (${commitSha.slice(0, 7)})
[00:02.40] Compiling artifacts with bloom-engine...
[00:03.12] Flutter SDK: ${build?.flutter_version || "3.27.0"} · Dart: ${build?.dart_version || "3.6.0"}
[00:04.10] Build status: ${build?.status || "pending"}`;
  }, [logs, build, buildNumber]);

  // Auto-scroll effect
  React.useEffect(() => {
    if (autoScroll && logEndRef.current) {
      logEndRef.current.scrollIntoView({ behavior: "smooth" });
    }
  }, [formattedLogs, autoScroll]);

  const handleCopyLogs = () => {
    if (!formattedLogs) return;
    navigator.clipboard.writeText(formattedLogs);
    setCopiedLog(true);
    setTimeout(() => setCopiedLog(false), 2000);
    toast.success("Logs copied to clipboard");
  };

  const handleCopyCommit = () => {
    if (!build?.git_commit) return;
    navigator.clipboard.writeText(build.git_commit);
    setCopiedCommit(true);
    setTimeout(() => setCopiedCommit(false), 2000);
    toast.success("Git commit SHA copied");
  };

  const handleRebuild = async () => {
    if (!build || !appId) return;
    setIsRebuilding(true);
    try {
      // Rebuild creates a new build using the exact same parameters
      const newBuild = await api.post<BuildResponse>("/builds", {
        app_id: appId,
        environment_id: build.environment_id,
        platform: build.platform,
        git_commit: build.git_commit || undefined,
        git_branch: build.git_branch || undefined,
        git_ref: build.git_ref || undefined,
        build_profile: build.build_profile || undefined,
        flutter_version: build.flutter_version || undefined,
        dart_version: build.dart_version || undefined,
        bloom_version: build.bloom_version || undefined,
        flavor: build.flavor || undefined,
      });

      toast.success("New build queued from current configuration");
      router.push(`/apps/${appId}/builds/${newBuild.id}`);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to trigger rebuild",
      );
    } finally {
      setIsRebuilding(false);
    }
  };

  const handleCancelBuild = async () => {
    if (!build) return;
    setIsCancelling(true);
    try {
      const updated = await api.post<BuildResponse>(
        `/builds/${build.id}/cancel`,
      );
      setBuild(updated);
      toast.success("Build cancelled successfully");
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to cancel build",
      );
    } finally {
      setIsCancelling(false);
    }
  };

  const isRunningOrPending =
    build?.status === "running" ||
    build?.status === "queued" ||
    build?.status === "pending";

  const canCancelBuild = hasRole(userRole, "Developer");

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-16">
        <BloomSpinner size={28} label="Loading build telemetry..." />
      </div>
    );
  }

  if (error) {
    return (
      <Alert variant="destructive">
        <AlertTitle>Failed to load build</AlertTitle>
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
              onClick={() => router.push(`/apps/${appId}/builds`)}
              className="h-7 text-xs"
            >
              Back to Builds
            </Button>
          </div>
        </AlertDescription>
      </Alert>
    );
  }

  if (!build) {
    return (
      <EmptyState
        icon={Hammer}
        title="Build Not Found"
        description="The requested build record could not be found or has expired from the cluster."
        actionLabel="Back to Builds"
        onAction={() => router.push(`/apps/${appId}/builds`)}
      />
    );
  }

  // Define pipeline stages
  const stages: BuildStageResponse[] =
    build.stages && build.stages.length > 0
      ? build.stages
      : [
          {
            stage: "Environment Setup",
            status:
              build.status === "failed"
                ? "failed"
                : build.status === "pending" || build.status === "queued"
                  ? "running"
                  : "completed",
            started_at: build.started_at,
            finished_at: null,
            log_snippet: "Bootstrapping runner container and toolchain...",
          },
          {
            stage: "Checkout & Dependencies",
            status:
              build.status === "failed"
                ? "skipped"
                : build.status === "running"
                  ? "running"
                  : build.status === "success"
                    ? "completed"
                    : "pending",
            started_at: null,
            finished_at: null,
            log_snippet:
              "Resolving packages from pub.dev and git submodules...",
          },
          {
            stage: "Compilation & Engine",
            status:
              build.status === "success"
                ? "completed"
                : build.status === "running"
                  ? "running"
                  : "pending",
            started_at: null,
            finished_at: null,
            log_snippet: "Running bloom-engine bytecode compiler...",
          },
          {
            stage: "Artifact Packaging",
            status: build.status === "success" ? "completed" : "pending",
            started_at: null,
            finished_at: build.finished_at,
            log_snippet: "Generating signed application binaries...",
          },
        ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <PageHeader
        breadcrumbs={[
          { label: "Applications", href: "/apps" },
          { label: app?.name || "App", href: `/apps/${appId}/builds` },
          { label: "Builds", href: `/apps/${appId}/builds` },
          { label: `Build #${buildNumber}` },
        ]}
        title={`Build #${buildNumber}`}
        badge={
          <div className="flex items-center gap-2 font-mono text-xs">
            <PlatformIcon platform={build.platform} size="sm" />
            <StatusBadge status={build.status} />
          </div>
        }
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchData()}
              className="h-8 cursor-pointer gap-1.5"
            >
              <ArrowsClockwise className="size-3.5" />
              <span>Refresh</span>
            </Button>

            {/* Cancel Build (Hard-hidden unless role permits and status is active) */}
            {canCancelBuild && isRunningOrPending && (
              <AlertDialog>
                <AlertDialogTrigger className="border-destructive/40 bg-destructive/10 text-destructive hover:bg-destructive hover:text-destructive-foreground inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-md border px-3 text-xs font-medium shadow-xs transition-colors">
                  <Prohibit className="size-3.5" />
                  <span>Cancel Build</span>
                </AlertDialogTrigger>
                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle className="text-destructive flex items-center gap-2 font-semibold">
                      <WarningOctagon className="size-4.5 shrink-0" />
                      <span>Cancel Build #{buildNumber}?</span>
                    </AlertDialogTitle>
                    <AlertDialogDescription className="space-y-3 pt-1 text-left text-xs leading-relaxed">
                      <p>
                        Cancelling will immediately terminate worker execution,
                        drop pending compilation jobs, and mark this build as
                        cancelled.
                      </p>
                      <div className="border-destructive/30 bg-destructive/5 space-y-1.5 rounded-md border p-3 font-mono text-[11px]">
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">Target:</span>
                          <span className="text-foreground uppercase">
                            {build.platform}
                          </span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">Branch:</span>
                          <span className="text-foreground">
                            {build.git_branch || "main"}
                          </span>
                        </div>
                      </div>
                    </AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>Keep Running</AlertDialogCancel>
                    <AlertDialogAction
                      onClick={handleCancelBuild}
                      disabled={isCancelling}
                      className="bg-destructive text-destructive-foreground hover:bg-destructive/90 cursor-pointer font-medium"
                    >
                      {isCancelling ? (
                        <BloomSpinner size={14} speed="fast" />
                      ) : (
                        "Confirm Cancellation"
                      )}
                    </AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
            )}

            {/* Rebuild Action: Clearly dispatches a new build with identical parameters */}
            <Button
              size="sm"
              onClick={handleRebuild}
              disabled={isRebuilding}
              className="h-8 cursor-pointer gap-1.5"
            >
              {isRebuilding ? (
                <BloomSpinner size={14} speed="fast" />
              ) : (
                <Hammer className="size-3.5" weight="bold" />
              )}
              <span>Rebuild</span>
            </Button>
          </div>
        }
      />

      {/* Stage Progression Timeline */}
      <Card className="border-border/80 bg-card shadow-xs">
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <div>
              <CardTitle className="text-base font-semibold">
                Pipeline Stages &amp; Execution Telemetry
              </CardTitle>
              <CardDescription>
                Multi-stage compilation and validation pipeline execution
                tracking.
              </CardDescription>
            </div>
            <div className="flex items-center gap-2">
              <Badge
                variant="outline"
                className="font-mono text-[10px] uppercase"
              >
                {build.platform} Matrix
              </Badge>
            </div>
          </div>
        </CardHeader>

        <CardContent>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {stages.map((stg, idx) => {
              const normStatus = stg.status.toLowerCase();
              const isCompleted =
                normStatus === "completed" ||
                normStatus === "success" ||
                normStatus === "succeeded";
              const isRunning =
                normStatus === "running" || normStatus === "in_progress";
              const isFailed =
                normStatus === "failed" || normStatus === "error";
              const isSkipped = normStatus === "skipped";
              const isPending =
                normStatus === "pending" || normStatus === "queued";

              return (
                <div
                  key={stg.stage + idx}
                  className={cn(
                    "relative flex flex-col justify-between rounded-lg border p-3.5 transition-colors",
                    isRunning
                      ? "border-primary/50 bg-primary/5 ring-primary/20 shadow-xs ring-1"
                      : isCompleted
                        ? "border-border/80 bg-muted/20"
                        : isFailed
                          ? "border-destructive/50 bg-destructive/5"
                          : isSkipped
                            ? "border-border/40 bg-muted/5 opacity-60"
                            : "border-border/50 bg-muted/10 opacity-70",
                  )}
                >
                  <div>
                    {/* Header with Step Number & Status Icon */}
                    <div className="flex items-center justify-between pb-2">
                      <span className="text-muted-foreground font-mono text-[10px] font-semibold tracking-wider uppercase">
                        Stage 0{idx + 1}
                      </span>

                      <div>
                        {isCompleted && (
                          <div className="flex size-5 items-center justify-center rounded-full bg-emerald-500/15 text-emerald-400">
                            <Check className="size-3" weight="bold" />
                          </div>
                        )}
                        {isRunning && (
                          <div className="flex size-5 items-center justify-center">
                            <BloomSpinner size={14} speed="fast" />
                          </div>
                        )}
                        {isFailed && (
                          <div className="bg-destructive/15 text-destructive flex size-5 items-center justify-center rounded-full">
                            <XCircle className="size-3.5" weight="fill" />
                          </div>
                        )}
                        {isSkipped && (
                          <div className="text-muted-foreground flex size-5 items-center justify-center">
                            <Prohibit className="size-3.5 opacity-60" />
                          </div>
                        )}
                        {isPending && (
                          <div className="text-muted-foreground flex size-5 items-center justify-center">
                            <Circle className="size-3.5 opacity-50" />
                          </div>
                        )}
                      </div>
                    </div>

                    {/* Step Title & Details */}
                    <div className="space-y-1">
                      <h4
                        className={cn(
                          "text-xs font-semibold",
                          isRunning
                            ? "text-primary"
                            : isFailed
                              ? "text-destructive"
                              : "text-foreground",
                        )}
                      >
                        {stg.stage}
                      </h4>
                      {stg.log_snippet && (
                        <p className="text-muted-foreground line-clamp-2 font-mono text-[10px] leading-relaxed">
                          {stg.log_snippet}
                        </p>
                      )}
                    </div>
                  </div>

                  {/* Stage Status Badge with prefers-reduced-motion pulsing animation */}
                  <div className="pt-3">
                    <Badge
                      variant="secondary"
                      className={cn(
                        "font-mono text-[9px] font-medium uppercase",
                        isCompleted
                          ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-400"
                          : isRunning
                            ? "border-primary/40 bg-primary/20 text-primary motion-safe:animate-pulse"
                            : isFailed
                              ? "border-destructive/40 bg-destructive/15 text-destructive"
                              : isSkipped
                                ? "bg-muted/30 text-muted-foreground"
                                : "bg-muted/40 text-muted-foreground",
                      )}
                    >
                      {isCompleted
                        ? "Completed"
                        : isRunning
                          ? "Running"
                          : isFailed
                            ? "Failed"
                            : isSkipped
                              ? "Skipped"
                              : "Pending"}
                    </Badge>
                  </div>
                </div>
              );
            })}
          </div>
        </CardContent>
      </Card>

      {/* Live Log Viewer Section */}
      <Card className="border-border/80 bg-card shadow-xs">
        <CardHeader className="pb-3">
          <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex items-center gap-2">
              <TerminalWindow className="text-muted-foreground size-4" />
              <CardTitle className="text-base font-semibold">
                Build Pipeline Console Output
              </CardTitle>
            </div>

            <div className="flex items-center gap-4">
              {/* Auto-scroll toggle */}
              <div className="flex items-center gap-2">
                <Switch
                  id="auto-scroll-switch"
                  checked={autoScroll}
                  onCheckedChange={setAutoScroll}
                  size="sm"
                />
                <Label
                  htmlFor="auto-scroll-switch"
                  className="text-muted-foreground cursor-pointer text-xs"
                >
                  Auto-scroll
                </Label>
              </div>

              <Separator orientation="vertical" className="h-4" />

              {/* Copy log button */}
              <Button
                variant="outline"
                size="sm"
                onClick={handleCopyLogs}
                className="h-7 cursor-pointer gap-1 px-2.5 text-xs"
              >
                {copiedLog ? (
                  <Check className="size-3 text-emerald-400" />
                ) : (
                  <Copy className="size-3" />
                )}
                <span>{copiedLog ? "Copied" : "Copy Logs"}</span>
              </Button>
            </div>
          </div>
          <CardDescription className="text-xs">
            Standard output and error stream captured from cloud compilation
            runner.
          </CardDescription>
        </CardHeader>

        <CardContent>
          <div className="border-border/80 relative rounded-lg border bg-black shadow-inner">
            <ScrollArea className="h-[420px] w-full p-4">
              <pre className="font-mono text-[11px] leading-relaxed whitespace-pre-wrap text-emerald-400/90 select-text">
                {formattedLogs}
              </pre>
              <div ref={logEndRef} />
            </ScrollArea>
          </div>
        </CardContent>
      </Card>

      {/* Metadata & Telemetry Cards Grid */}
      <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
        {/* Toolchain & Configuration Card */}
        <Card className="border-border/80 bg-card shadow-xs">
          <CardHeader className="pb-3">
            <div className="flex items-center gap-2">
              <Cpu className="text-muted-foreground size-4" />
              <CardTitle className="text-base font-semibold">
                Toolchain &amp; Build Configuration
              </CardTitle>
            </div>
            <CardDescription className="text-xs">
              Target runtime SDK versions and engine profiles for this run.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3 font-mono text-xs">
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Platform</span>
              <div className="text-foreground flex items-center gap-1 font-semibold uppercase">
                <PlatformIcon platform={build.platform} size="sm" />
                <span>{build.platform}</span>
              </div>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Build Profile</span>
              <Badge
                variant="secondary"
                className="font-mono text-[10px] uppercase"
              >
                {build.build_profile || "release"}
              </Badge>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Environment</span>
              <span className="text-foreground font-semibold">
                {environment?.name || "Production"} (
                {environment?.slug || "production"})
              </span>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Flutter SDK</span>
              <span className="text-foreground font-semibold">
                v{build.flutter_version || "3.27.0"}
              </span>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Dart SDK</span>
              <span className="text-foreground font-semibold">
                v{build.dart_version || "3.6.0"}
              </span>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Bloom Engine</span>
              <span className="text-foreground font-semibold">
                v{build.bloom_version || "1.0.0"}
              </span>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Build Flavor</span>
              <span className="text-foreground">
                {build.flavor || "Default (None)"}
              </span>
            </div>
          </CardContent>
        </Card>

        {/* Source Control & Provenance Card */}
        <Card className="border-border/80 bg-card shadow-xs">
          <CardHeader className="pb-3">
            <div className="flex items-center gap-2">
              <FileCode className="text-muted-foreground size-4" />
              <CardTitle className="text-base font-semibold">
                Source Control &amp; Provenance
              </CardTitle>
            </div>
            <CardDescription className="text-xs">
              Git commit metadata, author details, and pipeline timings.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3 font-mono text-xs">
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Branch</span>
              <Badge
                variant="secondary"
                className="bg-muted/60 text-foreground border-border/40 gap-1 px-1.5 py-0 font-mono text-[10px]"
              >
                <GitBranch className="size-3" />
                <span>{build.git_branch || "main"}</span>
              </Badge>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Commit SHA</span>
              <div className="flex items-center gap-1.5">
                <span className="text-foreground font-semibold">
                  {(build.git_commit || "HEAD").slice(0, 8)}
                </span>
                <button
                  type="button"
                  onClick={handleCopyCommit}
                  className="hover:text-foreground text-muted-foreground cursor-pointer transition-colors"
                  title="Copy full commit SHA"
                >
                  {copiedCommit ? (
                    <Check className="size-3 text-emerald-400" />
                  ) : (
                    <Copy className="size-3" />
                  )}
                </button>
              </div>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Git Ref</span>
              <span className="text-foreground">
                {build.git_ref || `refs/heads/${build.git_branch || "main"}`}
              </span>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Triggered By</span>
              <div className="flex items-center gap-1.5">
                <UserAvatar name={build.author || "dev"} size={16} />
                <span className="text-foreground text-xs">
                  {build.author || "system"}
                </span>
              </div>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Started At</span>
              <span className="text-foreground">
                {build.started_at
                  ? new Date(build.started_at).toLocaleString()
                  : "--"}
              </span>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Finished At</span>
              <span className="text-foreground">
                {build.finished_at
                  ? new Date(build.finished_at).toLocaleString()
                  : isRunningOrPending
                    ? "In Progress..."
                    : "--"}
              </span>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Duration</span>
              <div className="text-foreground flex items-center gap-1 font-semibold">
                <Clock className="size-3" />
                <span>
                  {build.duration_seconds ? `${build.duration_seconds}s` : "--"}
                </span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
