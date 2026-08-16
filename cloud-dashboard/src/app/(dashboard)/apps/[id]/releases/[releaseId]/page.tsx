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
import { PageHeader } from "@/components/shared/page-header";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { PlatformIcon } from "@/components/status/platform-icon";
import { StatusBadge } from "@/components/status/status-badge";
import { api } from "@/lib/api/client";
import { ReleaseResponse } from "@/lib/schemas/release";
import { AppResponse } from "@/lib/schemas/app";
import { useOrganizationStore } from "@/stores/organization-store";
import { useOrganizationEvents } from "@/lib/hooks/use-organization-events";
import { OrganizationRoleName, hasRole } from "@/lib/auth/roles";

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
      toast.success("Changelog saved");
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
      toast.success(approved ? "Release approved" : "Release rejected");
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

  const canApprove = hasRole(userRole, "ReleaseManager");

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-16">
        <BloomSpinner size={28} label="Loading release details..." />
      </div>
    );
  }

  if (error || !release) {
    return (
      <Alert variant="destructive">
        <AlertTitle>Release Not Found</AlertTitle>
        <AlertDescription className="flex items-center justify-between">
          <span>{error || "Unable to locate release record."}</span>
          <Button
            variant="outline"
            size="sm"
            onClick={() => router.push(`/apps/${appId}/releases`)}
            className="h-7 text-xs"
          >
            Back to Releases
          </Button>
        </AlertDescription>
      </Alert>
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
                    <AlertDialogDescription>
                      This will transition the release state to
                      &quot;rolled_back&quot; and stop traffic from directing to
                      this version.
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

      {/* Pending Approval Banner (§22.4) */}
      {isPending && (
        <Alert className="border-[var(--status-warning)]/40 bg-[var(--status-warning-bg)] text-[var(--status-warning)]">
          <WarningOctagon className="size-4 shrink-0" />
          <div className="flex w-full items-center justify-between">
            <div>
              <AlertTitle className="font-semibold">
                Pending Release Approval
              </AlertTitle>
              <AlertDescription className="text-foreground/80 mt-0.5 text-xs">
                This release is staged for distribution and requires
                confirmation from a Release Manager.
              </AlertDescription>
            </div>
            {/* Actionable buttons hard-gated to ReleaseManager+ */}
            {canApprove && (
              <div className="flex items-center gap-2">
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => void handleApprove(false)}
                  disabled={isProcessing}
                  className="text-destructive border-destructive/30 h-7 text-xs"
                >
                  <ThumbsDown className="mr-1 size-3" />
                  Reject
                </Button>
                <Button
                  size="sm"
                  onClick={() => void handleApprove(true)}
                  disabled={isProcessing}
                  className="h-7 text-xs"
                >
                  <ThumbsUp className="mr-1 size-3" />
                  Approve Release
                </Button>
              </div>
            )}
          </div>
        </Alert>
      )}

      {/* Content Grid */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        {/* Left Column: Changelog Editor */}
        <div className="space-y-6 lg:col-span-2">
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <div>
                  <CardTitle className="text-base font-semibold">
                    Release Notes & Changelog
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
                    rows={12}
                    className="font-mono text-xs leading-relaxed"
                  />
                </TabsContent>

                <TabsContent value="preview" className="pt-3">
                  <div className="border-border/80 bg-muted/20 text-foreground/90 min-h-[240px] rounded-md border p-4 font-mono text-xs leading-relaxed whitespace-pre-wrap shadow-xs">
                    {changelog || "(No changelog content provided)"}
                  </div>
                </TabsContent>
              </Tabs>
            </CardContent>
          </Card>
        </div>

        {/* Right Column: Metadata & Artifacts */}
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
            </CardContent>
          </Card>

          {/* Rollout Card */}
          <Card className="border-border/80 bg-card shadow-xs">
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-semibold">
                Platform Rollout Progress
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-2 font-mono text-xs">
              {release.platforms?.map((p) => {
                const percent =
                  (release.rollout_status as Record<string, number>)?.[p] ??
                  100;
                return (
                  <div
                    key={p}
                    className="border-border/60 bg-muted/20 flex items-center justify-between rounded-md p-2"
                  >
                    <div className="flex items-center gap-1.5 capitalize">
                      <PlatformIcon platform={p} size="sm" />
                      <span>{p}</span>
                    </div>
                    <Badge
                      variant="secondary"
                      className="bg-muted/60 text-foreground border-border/40 font-mono text-[10px]"
                    >
                      {percent}% rolled out
                    </Badge>
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
