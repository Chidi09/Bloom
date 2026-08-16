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
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
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
  const [isLoading, setIsLoading] = React.useState(true);
  const [isRollingBack, setIsRollingBack] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  const fetchData = React.useCallback(async () => {
    if (!appId || !deploymentId) return;
    setIsLoading(true);
    setError(null);
    try {
      const [appRes, depRes] = await Promise.all([
        api.get<AppResponse>(`/apps/${appId}`),
        api.get<DeploymentResponse>(`/deployments/${deploymentId}`),
      ]);

      setApp(appRes);
      setDeployment(depRes);
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
              className="h-8 gap-1.5"
            >
              <ArrowsClockwise className="size-3.5" />
              <span>Refresh</span>
            </Button>

            {deployment.external_url && (
              <Link
                href={deployment.external_url}
                target="_blank"
                className="border-border hover:bg-muted text-foreground inline-flex h-8 items-center gap-1.5 rounded-md border px-3 text-xs font-medium"
              >
                <span>External Console</span>
                <ArrowSquareOut className="size-3.5" />
              </Link>
            )}

            {deployment.status !== "rolled_back" && (
              <AlertDialog>
                <AlertDialogTrigger className="bg-destructive/10 text-destructive hover:bg-destructive hover:text-destructive-foreground border-destructive/30 inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-md border px-3 text-xs font-medium transition-colors">
                  <ArrowCounterClockwise className="size-3.5" />
                  <span>Rollback</span>
                </AlertDialogTrigger>
                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle>Rollback Deployment?</AlertDialogTitle>
                    <AlertDialogDescription>
                      This will transition the deployment state to
                      &quot;rolled_back&quot; and notify worker pools to stop
                      distribution.
                    </AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>Cancel</AlertDialogCancel>
                    <AlertDialogAction
                      onClick={handleRollback}
                      disabled={isRollingBack}
                      className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                    >
                      {isRollingBack ? (
                        <BloomSpinner size={14} speed="fast" />
                      ) : (
                        "Confirm Rollback"
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
        <Alert variant="destructive">
          <WarningOctagon className="size-4" />
          <AlertTitle>Deployment Failure Diagnostics</AlertTitle>
          <AlertDescription className="mt-1 font-mono text-xs">
            {deployment.error_message}
          </AlertDescription>
        </Alert>
      )}

      {/* Info Cards Grid */}
      <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
        {/* Execution Status Card */}
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
                  : deployment.status === "running"
                    ? "In progress..."
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
              Provider & Track Details
            </CardTitle>
            <CardDescription>
              Platform provider endpoints and remote distribution channels.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3 font-mono text-xs">
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
                <span>Open in Store Console</span>
                <ArrowSquareOut className="size-3.5" />
              </Link>
            </CardFooter>
          )}
        </Card>
      </div>
    </div>
  );
}
