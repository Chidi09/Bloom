"use client";

import * as React from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import {
  RocketLaunch,
  Plus,
  ArrowsClockwise,
  ArrowCounterClockwise,
  ArrowRight,
  DotsThreeVertical,
  ThumbsUp,
  ThumbsDown,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
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
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { PlatformIcon } from "@/components/status/platform-icon";
import { StatusBadge } from "@/components/status/status-badge";
import { EmptyState } from "@/components/shared/empty-state";
import { api } from "@/lib/api/client";
import { ReleaseResponse } from "@/lib/schemas/release";
import { BuildResponse } from "@/lib/schemas/build";
import { EnvironmentResponse } from "@/lib/schemas/environment";
import { useOrganizationStore } from "@/stores/organization-store";
import { useOrganizationEvents } from "@/lib/hooks/use-organization-events";
import { OrganizationRoleName, hasRole } from "@/lib/auth/roles";

export default function AppReleasesPage() {
  const params = useParams<{ id: string }>();
  const appId = params.id;
  const { currentOrganizationId } = useOrganizationStore();

  useOrganizationEvents(currentOrganizationId);

  const [releases, setReleases] = React.useState<ReleaseResponse[]>([]);
  const [builds, setBuilds] = React.useState<BuildResponse[]>([]);
  const [environments, setEnvironments] = React.useState<EnvironmentResponse[]>(
    [],
  );
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // User role for hard-hide gating
  const [userRole, setUserRole] =
    React.useState<OrganizationRoleName>("Developer");

  // Create Release Dialog State
  const [createDialogOpen, setCreateDialogOpen] = React.useState(false);
  const [selectedBuildId, setSelectedBuildId] = React.useState("");
  const [version, setVersion] = React.useState("");
  const [selectedEnvId, setSelectedEnvId] = React.useState("");
  const [selectedPlatforms, setSelectedPlatforms] = React.useState<string[]>([
    "ios",
    "android",
    "web",
  ]);
  const [changelog, setChangelog] = React.useState("");
  const [isCreating, setIsCreating] = React.useState(false);

  // Rollback Action State
  const [rollbackId, setRollbackId] = React.useState<string | null>(null);

  const fetchData = React.useCallback(async () => {
    if (!appId) return;
    setIsLoading(true);
    setError(null);
    try {
      const [releasesRes, buildsRes, envsRes, orgRes] = await Promise.all([
        api.get<{ results: ReleaseResponse[] }>("/releases", {
          params: { app_id: appId },
        }),
        api.get<{ results: BuildResponse[] }>("/builds", {
          params: { app_id: appId },
        }),
        api.get<{ results: EnvironmentResponse[] }>("/environments", {
          params: { app_id: appId },
        }),
        currentOrganizationId
          ? api
              .get<{ role: string }>(`/organizations/${currentOrganizationId}`)
              .catch(() => null)
          : Promise.resolve(null),
      ]);

      setReleases(releasesRes?.results ?? []);
      setBuilds(buildsRes?.results ?? []);
      setEnvironments(envsRes?.results ?? []);

      if (envsRes?.results?.length) {
        setSelectedEnvId(envsRes.results[0].id);
      }
      if (orgRes?.role) {
        setUserRole(orgRes.role as OrganizationRoleName);
      }
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to load releases");
    } finally {
      setIsLoading(false);
    }
  }, [appId, currentOrganizationId]);

  React.useEffect(() => {
    const run = async () => {
      await fetchData();
    };
    void run();
  }, [fetchData]);

  const handleBuildSelect = (buildId: string) => {
    setSelectedBuildId(buildId);
    const found = builds.find((b) => b.id === buildId);
    if (found) {
      if (!version) {
        setVersion(`v1.${found.build_number ?? 1}.0`);
      }
      if (found.environment_id) {
        setSelectedEnvId(found.environment_id);
      }
    }
  };

  const handleCreateRelease = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!appId || !selectedBuildId) {
      toast.error("Please select a source build");
      return;
    }

    const bld = builds.find((b) => b.id === selectedBuildId);
    if (!bld) return;

    setIsCreating(true);
    try {
      await api.post("/releases", {
        app_id: appId,
        version: version.trim().startsWith("v")
          ? version.trim()
          : `v${version.trim()}`,
        build_number: bld.build_number ?? 1,
        commit: bld.git_commit || "HEAD",
        changelog: changelog.trim(),
        environment_id: selectedEnvId || null,
        platforms: selectedPlatforms,
        artifact_ids: [],
      });

      toast.success(`Release ${version} created`);
      setCreateDialogOpen(false);
      setVersion("");
      setChangelog("");
      setSelectedBuildId("");
      await fetchData();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to create release",
      );
    } finally {
      setIsCreating(false);
    }
  };

  const handleApprove = async (releaseId: string, approved: boolean) => {
    try {
      await api.post(`/releases/${releaseId}/approve`, { approved });
      toast.success(approved ? "Release approved" : "Release rejected");
      await fetchData();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to process approval",
      );
    }
  };

  const handleRollback = async (releaseId: string) => {
    try {
      await api.post(`/releases/${releaseId}/rollback`, {
        reason: "Manual rollback from dashboard",
      });
      toast.success("Release marked as rolled back");
      setRollbackId(null);
      await fetchData();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to rollback release",
      );
    }
  };

  // Hard-gated role checks per §21.5 / §22.2
  const canApprove = hasRole(userRole, "ReleaseManager");

  const getRolloutSummary = (rollout: Record<string, unknown>) => {
    const values = Object.values(rollout).filter(
      (v): v is number => typeof v === "number",
    );
    if (values.length === 0) return "--";
    const avg = Math.round(values.reduce((a, b) => a + b, 0) / values.length);
    return `${avg}%`;
  };

  return (
    <div className="space-y-4">
      {/* Releases Toolbar */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="space-y-0.5">
          <h2 className="text-foreground text-sm font-semibold">
            Releases & Versioning
          </h2>
          <p className="text-muted-foreground text-xs">
            Manage semantic versions, approval governance, changelogs, and store
            rollout phases.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => void fetchData()}
            className="h-8 gap-1.5 transition-colors"
          >
            <ArrowsClockwise className="size-3.5" />
            <span>Refresh</span>
          </Button>

          <Button
            size="sm"
            onClick={() => setCreateDialogOpen(true)}
            className="h-8 gap-1.5"
          >
            <Plus className="size-3.5" weight="bold" />
            <span>Create Release</span>
          </Button>
        </div>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertTitle>Failed to load releases</AlertTitle>
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

      {isLoading ? (
        <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-16">
          <BloomSpinner size={28} label="Loading release track..." />
        </div>
      ) : releases.length === 0 ? (
        <EmptyState
          icon={RocketLaunch}
          title="No releases created yet"
          description="Promote a successful cloud build into a formal versioned release with changelogs and approval gates."
          actionLabel="Create First Release"
          onAction={() => setCreateDialogOpen(true)}
        />
      ) : (
        <div className="border-border/80 bg-card overflow-hidden rounded-lg border shadow-xs">
          <TooltipProvider>
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="w-[110px]">Version</TableHead>
                  <TableHead className="w-[80px]">Build</TableHead>
                  <TableHead>Commit</TableHead>
                  <TableHead>Platforms</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="w-[100px]">Rollout</TableHead>
                  <TableHead>Created</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {releases.map((rel) => {
                  const commitSha = rel.commit || "HEAD";
                  const isPending = rel.status === "pending_approval";

                  return (
                    <TableRow
                      key={rel.id}
                      className="hover:bg-muted/40 group transition-colors duration-150"
                    >
                      <TableCell>
                        <Link
                          href={`/apps/${appId}/releases/${rel.id}`}
                          className="text-foreground group-hover:text-primary font-mono text-xs font-semibold transition-colors hover:underline"
                        >
                          {rel.version}
                        </Link>
                      </TableCell>

                      <TableCell className="text-muted-foreground font-mono text-xs">
                        #{rel.build_number}
                      </TableCell>

                      <TableCell>
                        <Tooltip>
                          <TooltipTrigger className="text-muted-foreground hover:text-foreground cursor-help font-mono text-xs transition-colors">
                            {commitSha.slice(0, 7)}
                          </TooltipTrigger>
                          <TooltipContent>
                            <p className="font-mono text-xs">{commitSha}</p>
                          </TooltipContent>
                        </Tooltip>
                      </TableCell>

                      <TableCell>
                        <div className="flex items-center gap-1.5">
                          {rel.platforms?.map((p) => (
                            <PlatformIcon key={p} platform={p} size="sm" />
                          ))}
                        </div>
                      </TableCell>

                      <TableCell>
                        <StatusBadge status={rel.status} size="sm" />
                      </TableCell>

                      <TableCell className="text-muted-foreground font-mono text-xs">
                        {getRolloutSummary(rel.rollout_status || {})}
                      </TableCell>

                      <TableCell className="text-muted-foreground font-mono text-xs">
                        {new Date(rel.created_at).toLocaleDateString()}
                      </TableCell>

                      <TableCell className="text-right">
                        <div className="flex items-center justify-end gap-1">
                          <Link
                            href={`/apps/${appId}/releases/${rel.id}`}
                            className="border-border/80 hover:bg-muted text-foreground inline-flex h-7 items-center gap-1 rounded-md border px-2 text-xs font-medium transition-colors"
                          >
                            <span>Detail</span>
                            <ArrowRight className="size-3" />
                          </Link>

                          <DropdownMenu>
                            <DropdownMenuTrigger className="hover:bg-muted/80 text-muted-foreground hover:text-foreground inline-flex size-7 cursor-pointer items-center justify-center rounded-md transition-colors">
                              <DotsThreeVertical className="size-4" />
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end">
                              {/* Hard-gated Approve/Reject per §21.5 */}
                              {canApprove && isPending && (
                                <>
                                  <DropdownMenuItem
                                    onClick={() =>
                                      void handleApprove(rel.id, true)
                                    }
                                    className="cursor-pointer gap-1.5 text-xs text-[var(--status-success)]"
                                  >
                                    <ThumbsUp className="size-3.5" />
                                    <span>Approve Release</span>
                                  </DropdownMenuItem>
                                  <DropdownMenuItem
                                    onClick={() =>
                                      void handleApprove(rel.id, false)
                                    }
                                    className="text-destructive cursor-pointer gap-1.5 text-xs"
                                  >
                                    <ThumbsDown className="size-3.5" />
                                    <span>Reject Release</span>
                                  </DropdownMenuItem>
                                </>
                              )}

                              {rel.status !== "rolled_back" && (
                                <DropdownMenuItem
                                  onClick={() => setRollbackId(rel.id)}
                                  className="text-destructive cursor-pointer gap-1.5 text-xs"
                                >
                                  <ArrowCounterClockwise className="size-3.5" />
                                  <span>Rollback</span>
                                </DropdownMenuItem>
                              )}
                            </DropdownMenuContent>
                          </DropdownMenu>
                        </div>
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </TooltipProvider>
        </div>
      )}

      {/* Rollback Alert Dialog */}
      <AlertDialog
        open={!!rollbackId}
        onOpenChange={(open) => !open && setRollbackId(null)}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Rollback Release</AlertDialogTitle>
            <AlertDialogDescription>
              Are you sure you want to rollback this release? This will update
              its status and prevent new client updates from pulling this
              version.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={() => rollbackId && void handleRollback(rollbackId)}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              Confirm Rollback
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Create Release Dialog */}
      <Dialog open={createDialogOpen} onOpenChange={setCreateDialogOpen}>
        <DialogContent className="sm:max-w-lg">
          <form onSubmit={handleCreateRelease}>
            <DialogHeader>
              <DialogTitle>Create Release</DialogTitle>
              <DialogDescription>
                Select a source build and tag a new SemVer release for
                distribution.
              </DialogDescription>
            </DialogHeader>

            <div className="space-y-4 py-3">
              {/* Build Selection */}
              <div className="space-y-1.5">
                <Label htmlFor="source-build">Source Build</Label>
                {builds.length > 0 ? (
                  <Select
                    value={selectedBuildId}
                    onValueChange={(value) => value && handleBuildSelect(value)}
                  >
                    <SelectTrigger
                      id="source-build"
                      className="font-mono text-xs"
                    >
                      <SelectValue placeholder="Select build from history" />
                    </SelectTrigger>
                    <SelectContent>
                      {builds.map((b) => (
                        <SelectItem
                          key={b.id}
                          value={b.id}
                          className="font-mono text-xs"
                        >
                          #{b.build_number || "?"} · {b.platform} ·{" "}
                          {b.git_branch} ({b.git_commit?.slice(0, 7) || "HEAD"})
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                ) : (
                  <div className="border-border bg-muted/20 text-muted-foreground rounded border p-2.5 text-xs">
                    No builds found for this application. Trigger a build first.
                  </div>
                )}
              </div>

              {/* Version String */}
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1.5">
                  <Label htmlFor="release-ver">Release Version (SemVer)</Label>
                  <Input
                    id="release-ver"
                    placeholder="v1.0.0"
                    value={version}
                    onChange={(e) => setVersion(e.target.value)}
                    className="font-mono text-xs"
                    required
                  />
                </div>

                <div className="space-y-1.5">
                  <Label htmlFor="release-env">Target Environment</Label>
                  <Select
                    value={selectedEnvId}
                    onValueChange={(val) => val && setSelectedEnvId(val)}
                  >
                    <SelectTrigger
                      id="release-env"
                      className="font-mono text-xs"
                    >
                      <SelectValue placeholder="Environment">
                        {environments.find((e) => e.id === selectedEnvId)
                          ?.name || "Environment"}
                      </SelectValue>
                    </SelectTrigger>
                    <SelectContent>
                      {environments.map((env) => (
                        <SelectItem
                          key={env.id}
                          value={env.id}
                          className="font-mono text-xs"
                        >
                          {env.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>

              {/* Platform matrix */}
              <div className="space-y-2">
                <Label className="text-xs">Included Platforms</Label>
                <div className="flex items-center gap-4">
                  {(["ios", "android", "web"] as const).map((p) => {
                    const checked = selectedPlatforms.includes(p);
                    return (
                      <label
                        key={p}
                        className="flex cursor-pointer items-center gap-1.5 font-mono text-xs capitalize"
                      >
                        <Checkbox
                          checked={checked}
                          onCheckedChange={(c) => {
                            if (c) {
                              setSelectedPlatforms((prev) => [...prev, p]);
                            } else {
                              setSelectedPlatforms((prev) =>
                                prev.filter((item) => item !== p),
                              );
                            }
                          }}
                        />
                        <PlatformIcon platform={p} size="sm" />
                        <span>{p}</span>
                      </label>
                    );
                  })}
                </div>
              </div>

              {/* Changelog */}
              <div className="space-y-1.5">
                <Label htmlFor="release-changelog">Changelog (Markdown)</Label>
                <Textarea
                  id="release-changelog"
                  placeholder="### New Features&#10;- Added dark mode support&#10;&#10;### Fixes&#10;- Resolved payment checkout issue"
                  value={changelog}
                  onChange={(e) => setChangelog(e.target.value)}
                  rows={4}
                  className="font-mono text-xs leading-relaxed"
                />
              </div>
            </div>

            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => setCreateDialogOpen(false)}
                disabled={isCreating}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                disabled={!selectedBuildId || !version || isCreating}
              >
                {isCreating ? (
                  <BloomSpinner size={14} speed="fast" className="mr-2" />
                ) : null}
                Create Release
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
