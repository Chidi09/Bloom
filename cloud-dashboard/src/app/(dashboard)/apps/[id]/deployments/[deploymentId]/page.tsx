"use client";

import * as React from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import {
  ArrowSquareOut,
  ArrowCounterClockwise,
  WarningOctagon,
  ArrowsClockwise,
  RocketLaunch,
  XCircle,
  Circle,
  Check,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { cn } from "@/lib/utils";
import { Button, buttonVariants } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
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
import { EmptyState } from "@/components/shared/empty-state";
import { api } from "@/lib/api/client";
import { DeploymentResponse } from "@/lib/schemas/deployment";
import { AppResponse } from "@/lib/schemas/app";
import { useOrganizationStore } from "@/stores/organization-store";
import { useOrganizationEvents } from "@/lib/hooks/use-organization-events";

interface ProgressionStep {
  id: string;
  title: string;
  subtitle: string;
  description: string;
  state: "completed" | "current" | "pending" | "failed" | "rolled_back";
}

export default function AppDeploymentDetailPage() {
  const params = useParams<{ id: string; deploymentId: string }>();
  const router = useRouter();
  const appId = params.id;
  const deploymentId = params.deploymentId;
  const { currentOrganizationId } = useOrganizationStore();

  useOrganizationEvents(currentOrganizationId);

  const [app, setApp] = React.useState<AppResponse | null>(null);
  const [deployment, setDeployment] = React.useState<DeploymentResponse | null>(
    null,
  );
  const [allDeployments, setAllDeployments] = React.useState<
    DeploymentResponse[]
  >([]);
  const [isLoading, setIsLoading] = React.useState(true);
  const [isRollingBack, setIsRollingBack] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  const fetchData = React.useCallback(async () => {
    if (!appId || !deploymentId) return;
    setIsLoading(true);
    setError(null);
    try {
      const [appRes, depRes, allDepsRes] = await Promise.all([
        api.get<AppResponse>(`/apps/${appId}`),
        api.get<DeploymentResponse>(`/deployments/${deploymentId}`),
        api
          .get<{ results: DeploymentResponse[] }>("/deployments", {
            params: { app_id: appId },
          })
          .catch(() => ({ results: [] })),
      ]);

      setApp(appRes);
      setDeployment(depRes);
      setAllDeployments(allDepsRes?.results ?? []);
    } catch (err: unknown) {
      setError(
        err instanceof Error
          ? err.message
          : "Failed to load deployment details",
      );
    } finally {
      setIsLoading(false);
    }
  }, [appId, deploymentId]);

  React.useEffect(() => {
    const run = async () => {
      await fetchData();
    };
    void run();
  }, [fetchData]);

  const handleRollback = async () => {
    if (!deployment) return;
    setIsRollingBack(true);
    try {
      const updated = await api.post<DeploymentResponse>(
        `/deployments/${deployment.id}/rollback`,
      );
      setDeployment(updated);
      toast.success("Deployment rolled back successfully");
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to rollback deployment",
      );
    } finally {
      setIsRollingBack(false);
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-16">
        <BloomSpinner size={28} label="Loading deployment details..." />
      </div>
    );
  }

  if (error) {
    return (
      <Alert variant="destructive">
        <AlertTitle>Failed to load deployment</AlertTitle>
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
              onClick={() => router.push(`/apps/${appId}/deployments`)}
              className="h-7 text-xs"
            >
              Back to Deployments
            </Button>
          </div>
        </AlertDescription>
      </Alert>
    );
  }

  if (!deployment) {
    return (
      <EmptyState
        icon={RocketLaunch}
        title="Deployment Not Found"
        description="The requested deployment record could not be found or has been removed."
        actionLabel="Back to Deployments"
        onAction={() => router.push(`/apps/${appId}/deployments`)}
      />
    );
  }

  const formatTargetTitle = (target: string) => {
    switch (target) {
      case "testflight":
        return "Apple TestFlight";
      case "app_store":
        return "App Store Release";
      case "internal":
        return "Google Play Internal Track";
      case "closed":
        return "Google Play Closed Track";
      case "production":
        return "Production Distribution";
      case "preview":
        return "Preview Branch Hosting";
      default:
        return target;
    }
  };

  const getExternalLinkInfo = (target: string, platform: string) => {
    if (target === "testflight") {
      return {
        label: "Open TestFlight Console",
        provider: "App Store Connect",
      };
    }
    if (target === "app_store") {
      return {
        label: "Open App Store Listing",
        provider: "App Store Connect",
      };
    }
    if (platform === "android") {
      return {
        label: "Open Google Play Console",
        provider: "Google Play Console",
      };
    }
    if (platform === "web") {
      return {
        label: "Visit Live Site",
        provider: "Bloom Edge CDN",
      };
    }
    return {
      label: "Open External Console",
      provider: "External Distribution",
    };
  };

  // Find previous stable/live deployment on the same target channel
  const previousDeployment = allDeployments.find(
    (d) =>
      d.id !== deployment.id &&
      d.platform === deployment.platform &&
      d.target === deployment.target &&
      (d.status === "live" || d.status === "ready"),
  );

  // Compute platform-specific progression timeline steps
  const getTimelineSteps = (): ProgressionStep[] => {
    const status = deployment.status;
    const platform = deployment.platform;
    const target = deployment.target;

    // Platform-specific step descriptions
    let step1 = {
      id: "stage",
      title: "Artifact Staging",
      subtitle: "Verified build binary",
      description: "Release binary validated and staged for remote pipeline.",
    };
    let step2 = {
      id: "upload",
      title: "Provider Ingestion",
      subtitle: "Remote transmittal",
      description: "Package uploaded to platform distribution servers.",
    };
    let step3 = {
      id: "platform_processing",
      title: "Platform Processing",
      subtitle: "Store compliance & indexing",
      description: "Remote verification and platform policy checks.",
    };
    let step4 = {
      id: "live_distribution",
      title: "Live Distribution",
      subtitle: "Serving to users",
      description: "Active and available on the target release track.",
    };

    if (platform === "ios") {
      if (target === "testflight") {
        step2 = {
          id: "upload",
          title: "App Store Connect Upload",
          subtitle: "Transporter upload",
          description: "IPA archive uploaded to Apple Transporter service.",
        };
        step3 = {
          id: "platform_processing",
          title: "TestFlight Processing",
          subtitle: "Apple Store Connect validation",
          description:
            "Apple automated binary indexing, dSYM symbolication & export compliance verification.",
        };
        step4 = {
          id: "live_distribution",
          title: "Available on TestFlight",
          subtitle: "Beta tester distribution",
          description:
            "Build ready and distributed to internal and external TestFlight groups.",
        };
      } else {
        step2 = {
          id: "upload",
          title: "App Store Connect Ingestion",
          subtitle: "Production binary intake",
          description:
            "Release archive received and indexed by App Store Connect.",
        };
        step3 = {
          id: "platform_processing",
          title: "App Store Review Queue",
          subtitle: "Apple App Review",
          description:
            "Staged in Apple review queue for human review and store compliance checks.",
        };
        step4 = {
          id: "live_distribution",
          title: "Live on App Store",
          subtitle: "Worldwide release",
          description:
            "Approved and propagating across global App Store regions.",
        };
      }
    } else if (platform === "android") {
      step1 = {
        id: "stage",
        title: "AAB Bundle Staging",
        subtitle: "Android App Bundle",
        description: "Signed .aab release bundle verified with Bloom Keystore.",
      };
      step2 = {
        id: "upload",
        title: "Play Console API Ingestion",
        subtitle: "Google Play Publishing API",
        description:
          "Bundle transmitted to Google Play Developer API and signature validated.",
      };
      if (target === "internal") {
        step3 = {
          id: "platform_processing",
          title: "Internal Track Ingestion",
          subtitle: "Instant Play indexing",
          description:
            "Google Play generates split APKs and indexes internal tester channel.",
        };
        step4 = {
          id: "live_distribution",
          title: "Live on Internal Track",
          subtitle: "Instant distribution",
          description:
            "Available immediately to registered internal testers and QA devices.",
        };
      } else {
        step3 = {
          id: "platform_processing",
          title: "Google Play Track Review",
          subtitle: "Google Play policy check",
          description:
            "Staged for Google Play automated compliance checks and roll-out assignment.",
        };
        step4 = {
          id: "live_distribution",
          title: "Live on Google Play",
          subtitle: "Active track rollout",
          description:
            "Serving live updates to Google Play users across specified countries.",
        };
      }
    } else if (platform === "web") {
      step1 = {
        id: "stage",
        title: "Web Bundle Staging",
        subtitle: "Flutter Web compilation",
        description:
          "Optimized Flutter WASM & JS bundles prepared with gzip & Brotli compression.",
      };
      step2 = {
        id: "upload",
        title: "Edge Storage Sync",
        subtitle: "Global object storage",
        description: "Static web assets uploaded to regional edge buckets.",
      };
      step3 = {
        id: "platform_processing",
        title: "CDN Edge Invalidation",
        subtitle: "Edge cache purge & TLS",
        description:
          "Global cache invalidation triggered and custom SSL certificates verified.",
      };
      step4 = {
        id: "live_distribution",
        title: "Live at Custom Domain",
        subtitle: "Serving global web traffic",
        description:
          "Edge routing configured and serving traffic with sub-10ms TTFB.",
      };
    }

    // Determine state for each step
    const steps = [step1, step2, step3, step4];

    if (status === "rolled_back") {
      return steps.map((s, idx) => ({
        ...s,
        state: idx === 3 ? "rolled_back" : "completed",
      }));
    }

    if (status === "failed") {
      return steps.map((s, idx) => ({
        ...s,
        state: idx === 2 ? "failed" : idx < 2 ? "completed" : "pending",
      }));
    }

    let activeIndex = 0;
    if (status === "pending" || status === "queued") activeIndex = 0;
    else if (status === "running") activeIndex = 1;
    else if (status === "processing") activeIndex = 2;
    else if (status === "ready" || status === "live") activeIndex = 4; // all done

    return steps.map((s, idx) => {
      let state: ProgressionStep["state"] = "pending";
      if (idx < activeIndex) {
        state = "completed";
      } else if (idx === activeIndex) {
        state = "current";
      }
      return { ...s, state };
    });
  };

  const timelineSteps = getTimelineSteps();
  const externalLinkInfo = getExternalLinkInfo(
    deployment.target,
    deployment.platform,
  );

  return (
    <div className="space-y-6">
      {/* Header */}
      <PageHeader
        breadcrumbs={[
          { label: "Applications", href: "/apps" },
          { label: app?.name || "App", href: `/apps/${appId}/builds` },
          { label: "Deployments", href: `/apps/${appId}/deployments` },
          { label: formatTargetTitle(deployment.target) },
        ]}
        title={`${formatTargetTitle(deployment.target)} Deployment`}
        badge={
          <div className="flex items-center gap-2 font-mono text-xs">
            <PlatformIcon platform={deployment.platform} size="sm" />
            <StatusBadge status={deployment.status} />
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

            {/* External Link Button: Clearly distinguishable secondary action */}
            {deployment.external_url && (
              <Link
                href={deployment.external_url}
                target="_blank"
                className={cn(
                  buttonVariants({ variant: "outline", size: "sm" }),
                  "border-border/80 bg-background/50 hover:bg-muted text-foreground h-8 gap-1.5 px-3 text-xs font-medium shadow-xs",
                )}
              >
                <span>{externalLinkInfo.label}</span>
                <ArrowSquareOut className="text-muted-foreground size-3.5" />
              </Link>
            )}

            {/* Rollback Action: Clear Destructive Impact Dialog */}
            {deployment.status !== "rolled_back" && (
              <AlertDialog>
                <AlertDialogTrigger className="border-destructive/40 bg-destructive/10 text-destructive hover:bg-destructive hover:text-destructive-foreground inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-md border px-3 text-xs font-medium shadow-xs transition-colors">
                  <ArrowCounterClockwise className="size-3.5" />
                  <span>Rollback</span>
                </AlertDialogTrigger>
                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle className="text-destructive flex items-center gap-2 font-semibold">
                      <WarningOctagon className="size-4.5 shrink-0" />
                      <span>
                        Rollback {formatTargetTitle(deployment.target)}?
                      </span>
                    </AlertDialogTitle>
                    <AlertDialogDescription className="space-y-3 pt-1 text-left text-xs leading-relaxed">
                      <p>
                        Rolling back is a high-consequence action that
                        immediately halts the distribution of release{" "}
                        <strong className="text-foreground">
                          v{deployment.release_version || "current"}
                        </strong>{" "}
                        on the{" "}
                        <strong className="text-foreground">
                          {formatTargetTitle(deployment.target)}
                        </strong>{" "}
                        channel.
                      </p>

                      {/* Explicit State Change Callout */}
                      <div className="border-destructive/30 bg-destructive/5 space-y-2 rounded-md border p-3 font-mono text-[11px]">
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">
                            Deactivating:
                          </span>
                          <span className="text-foreground font-semibold">
                            v{deployment.release_version || "current"} (Build #
                            {deployment.id.slice(0, 8)})
                          </span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">
                            Reverting To:
                          </span>
                          <span className="font-semibold text-emerald-400">
                            {previousDeployment?.release_version
                              ? `v${previousDeployment.release_version} (Previous verified stable)`
                              : "Previous verified stable release"}
                          </span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">
                            Target Channel:
                          </span>
                          <span className="text-foreground">
                            {formatTargetTitle(deployment.target)}
                          </span>
                        </div>
                      </div>

                      <p className="text-muted-foreground text-[11px]">
                        Active app installs and downloads on this track will
                        revert to serving the previous verified release. Store
                        review submissions will be withdrawn.
                      </p>
                    </AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>Cancel</AlertDialogCancel>
                    <AlertDialogAction
                      onClick={handleRollback}
                      disabled={isRollingBack}
                      className="bg-destructive text-destructive-foreground hover:bg-destructive/90 cursor-pointer font-medium"
                    >
                      {isRollingBack ? (
                        <BloomSpinner size={14} speed="fast" />
                      ) : (
                        "Confirm & Execute Rollback"
                      )}
                    </AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
            )}
          </div>
        }
      />

      {/* Diagnostics / Error Alert if failed */}
      {deployment.error_message && (
        <Alert variant="destructive" className="animate-in fade-in-50">
          <WarningOctagon className="size-4" />
          <AlertTitle className="text-xs font-semibold">
            Deployment Failure Diagnostics
          </AlertTitle>
          <AlertDescription className="mt-1 font-mono text-xs">
            {deployment.error_message}
          </AlertDescription>
        </Alert>
      )}

      {/* Platform-Specific Progression Status Timeline */}
      <Card className="border-border/80 bg-card shadow-xs">
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <div>
              <CardTitle className="text-base font-semibold">
                Deployment Pipeline &amp; Platform Progression
              </CardTitle>
              <CardDescription>
                Visual telemetry of the multi-stage distribution pipeline for{" "}
                {formatTargetTitle(deployment.target)}.
              </CardDescription>
            </div>
            <div className="flex items-center gap-2">
              <Badge
                variant="outline"
                className="font-mono text-[10px] uppercase"
              >
                {deployment.platform} Pipeline
              </Badge>
            </div>
          </div>
        </CardHeader>

        <CardContent>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {timelineSteps.map((step, idx) => {
              const isCompleted = step.state === "completed";
              const isCurrent = step.state === "current";
              const isFailed = step.state === "failed";
              const isRolledBack = step.state === "rolled_back";
              const isPending = step.state === "pending";

              return (
                <div
                  key={step.id}
                  className={`relative flex flex-col justify-between rounded-lg border p-3.5 transition-colors ${
                    isCurrent
                      ? "border-primary/50 bg-primary/5 ring-primary/20 shadow-xs ring-1"
                      : isCompleted
                        ? "border-border/80 bg-muted/20"
                        : isFailed
                          ? "border-destructive/50 bg-destructive/5"
                          : isRolledBack
                            ? "border-amber-500/50 bg-amber-500/5"
                            : "border-border/50 bg-muted/10 opacity-70"
                  }`}
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
                        {isCurrent && (
                          <div className="flex size-5 items-center justify-center">
                            <BloomSpinner size={14} speed="fast" />
                          </div>
                        )}
                        {isFailed && (
                          <div className="bg-destructive/15 text-destructive flex size-5 items-center justify-center rounded-full">
                            <XCircle className="size-3.5" weight="fill" />
                          </div>
                        )}
                        {isRolledBack && (
                          <div className="flex size-5 items-center justify-center rounded-full bg-amber-500/15 text-amber-400">
                            <ArrowCounterClockwise
                              className="size-3"
                              weight="bold"
                            />
                          </div>
                        )}
                        {isPending && (
                          <div className="text-muted-foreground flex size-5 items-center justify-center">
                            <Circle className="size-3.5 opacity-50" />
                          </div>
                        )}
                      </div>
                    </div>

                    {/* Step Title & Subtitle */}
                    <div className="space-y-0.5">
                      <h4
                        className={`text-xs font-semibold ${
                          isCurrent
                            ? "text-primary"
                            : isFailed
                              ? "text-destructive"
                              : "text-foreground"
                        }`}
                      >
                        {step.title}
                      </h4>
                      <p className="text-muted-foreground text-[11px] font-medium">
                        {step.subtitle}
                      </p>
                    </div>

                    {/* Platform Specific Description */}
                    <p className="text-muted-foreground mt-2 text-[11px] leading-relaxed">
                      {step.description}
                    </p>
                  </div>

                  {/* Stage Status Badge */}
                  <div className="pt-3">
                    <Badge
                      variant="secondary"
                      className={`font-mono text-[9px] font-medium uppercase ${
                        isCompleted
                          ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-400"
                          : isCurrent
                            ? "border-primary/40 bg-primary/20 text-primary animate-pulse"
                            : isFailed
                              ? "border-destructive/40 bg-destructive/15 text-destructive"
                              : isRolledBack
                                ? "border-amber-500/40 bg-amber-500/15 text-amber-400"
                                : "bg-muted/40 text-muted-foreground"
                      }`}
                    >
                      {isCompleted
                        ? "Completed"
                        : isCurrent
                          ? "In Progress"
                          : isFailed
                            ? "Failed"
                            : isRolledBack
                              ? "Rolled Back"
                              : "Pending"}
                    </Badge>
                  </div>
                </div>
              );
            })}
          </div>
        </CardContent>
      </Card>

      {/* Info Cards Grid */}
      <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
        {/* Execution Telemetry Card */}
        <Card className="border-border/80 bg-card shadow-xs">
          <CardHeader className="pb-3">
            <CardTitle className="text-base font-semibold">
              Execution Telemetry
            </CardTitle>
            <CardDescription>
              Timing and worker job tracking for this deployment run.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3 font-mono text-xs">
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Status</span>
              <StatusBadge status={deployment.status} size="sm" />
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Platform</span>
              <div className="text-foreground flex items-center gap-1 font-semibold uppercase">
                <PlatformIcon platform={deployment.platform} size="sm" />
                <span>{deployment.platform}</span>
              </div>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Target Track</span>
              <span className="text-foreground font-semibold">
                {formatTargetTitle(deployment.target)}
              </span>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Started At</span>
              <span className="text-foreground">
                {deployment.started_at
                  ? new Date(deployment.started_at).toLocaleTimeString()
                  : "--"}
              </span>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Finished At</span>
              <span className="text-foreground">
                {deployment.finished_at
                  ? new Date(deployment.finished_at).toLocaleTimeString()
                  : deployment.status === "running" ||
                      deployment.status === "processing"
                    ? "Processing..."
                    : "--"}
              </span>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Total Duration</span>
              <span className="text-foreground">
                {deployment.duration_seconds
                  ? `${deployment.duration_seconds}s`
                  : "--"}
              </span>
            </div>
          </CardContent>
        </Card>

        {/* Platform Destination Details */}
        <Card className="border-border/80 bg-card shadow-xs">
          <CardHeader className="pb-3">
            <CardTitle className="text-base font-semibold">
              Provider &amp; Track Details
            </CardTitle>
            <CardDescription>
              Platform provider endpoints and remote distribution channels.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3 font-mono text-xs">
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Provider</span>
              <span className="text-foreground font-semibold">
                {externalLinkInfo.provider}
              </span>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>External Identifier</span>
              <span className="text-foreground font-semibold">
                {deployment.external_id || "Auto-assigned by worker"}
              </span>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Release Version</span>
              <span className="text-foreground font-semibold">
                {deployment.release_version || "Latest Tag"}
              </span>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Target Environment</span>
              <span className="text-foreground font-semibold">
                {deployment.environment_name || "Production"}
              </span>
            </div>
            <div className="text-muted-foreground flex items-center justify-between">
              <span>Deployment UUID</span>
              <span className="text-muted-foreground max-w-[180px] truncate text-[11px]">
                {deployment.id}
              </span>
            </div>
          </CardContent>
          {deployment.external_url && (
            <CardFooter className="border-border/60 border-t pt-3">
              <Link
                href={deployment.external_url}
                target="_blank"
                className="text-primary flex items-center gap-1 font-mono text-xs transition-colors hover:underline"
              >
                <span>{externalLinkInfo.label}</span>
                <ArrowSquareOut className="size-3.5" />
              </Link>
            </CardFooter>
          )}
        </Card>
      </div>
    </div>
  );
}
