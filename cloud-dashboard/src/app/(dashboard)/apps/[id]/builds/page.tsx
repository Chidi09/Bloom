"use client";

import * as React from "react";
import { useParams } from "next/navigation";
import {
  Hammer,
  Plus,
  GitBranch,
  Clock,
  CaretDown,
  CaretRight,
  Prohibit,
  ArrowsClockwise,
  DotsThreeVertical,
  CheckCircle,
  TerminalWindow,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
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
import { Collapsible, CollapsibleContent } from "@/components/ui/collapsible";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { UserAvatar } from "@/components/ui/user-avatar";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { StatusBadge } from "@/components/status/status-badge";
import { PlatformIcon } from "@/components/status/platform-icon";
import { EmptyState } from "@/components/shared/empty-state";
import { api } from "@/lib/api/client";
import { BuildResponse } from "@/lib/schemas/build";
import { EnvironmentResponse } from "@/lib/schemas/environment";
import { useOrganizationStore } from "@/stores/organization-store";
import { useOrganizationEvents } from "@/lib/hooks/use-organization-events";
import { OrganizationRoleName, hasRole } from "@/lib/auth/roles";

export default function AppBuildsPage() {
  const params = useParams<{ id: string }>();
  const appId = params.id;
  const { currentOrganizationId } = useOrganizationStore();

  useOrganizationEvents(currentOrganizationId);

  const [builds, setBuilds] = React.useState<BuildResponse[]>([]);
  const [environments, setEnvironments] = React.useState<EnvironmentResponse[]>(
    [],
  );
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Expanded Accordion Rows
  const [expandedRows, setExpandedRows] = React.useState<
    Record<string, boolean>
  >({});

  // New Build Dialog
  const [newBuildOpen, setNewBuildOpen] = React.useState(false);
  const [selectedEnvId, setSelectedEnvId] = React.useState("");
  const [selectedPlatform, setSelectedPlatform] = React.useState("all");
  const [customBranch, setCustomBranch] = React.useState("");
  const [isTriggering, setIsTriggering] = React.useState(false);

  // Role info
  const [userRole, setUserRole] =
    React.useState<OrganizationRoleName>("Developer");

  const toggleRow = (buildId: string) => {
    setExpandedRows((prev) => ({
      ...prev,
      [buildId]: !prev[buildId],
    }));
  };

  const fetchBuildsAndEnvs = React.useCallback(async () => {
    if (!appId) return;
    setIsLoading(true);
    setError(null);
    try {
      const [buildsRes, envsRes, orgRes] = await Promise.all([
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

      setBuilds(buildsRes?.results ?? []);
      setEnvironments(envsRes?.results ?? []);
      if (envsRes?.results?.length && !selectedEnvId) {
        setSelectedEnvId(envsRes.results[0].id);
      }
      if (orgRes?.role) {
        setUserRole(orgRes.role as OrganizationRoleName);
      }
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to load builds");
    } finally {
      setIsLoading(false);
    }
  }, [appId, currentOrganizationId, selectedEnvId]);

  React.useEffect(() => {
    const run = async () => {
      await fetchBuildsAndEnvs();
    };
    void run();
  }, [fetchBuildsAndEnvs]);

  const handleTriggerBuild = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!appId) return;

    setIsTriggering(true);
    try {
      let targetEnvId = selectedEnvId;

      // Inline environment creation if none exists (per spec and overview pattern)
      if (!targetEnvId) {
        const createdEnv = await api.post<EnvironmentResponse>(
          "/environments",
          {
            app_id: appId,
            name: "Production",
            slug: "production",
            api_config: { env_vars: [], feature_flags: [] },
          },
        );
        targetEnvId = createdEnv.id;
        setSelectedEnvId(createdEnv.id);
      }

      await api.post<BuildResponse>("/builds", {
        app_id: appId,
        environment_id: targetEnvId,
        platform: selectedPlatform,
        git_branch: customBranch.trim() || undefined,
      });

      toast.success("Build queued successfully");
      setNewBuildOpen(false);
      setCustomBranch("");
      await fetchBuildsAndEnvs();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to trigger build",
      );
    } finally {
      setIsTriggering(false);
    }
  };

  const handleCancelBuild = async (buildId: string) => {
    try {
      await api.post(`/builds/${buildId}/cancel`);
      toast.success("Build cancelled");
      await fetchBuildsAndEnvs();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to cancel build",
      );
    }
  };

  const canCancelBuild = hasRole(userRole, "Developer");

  return (
    <div className="space-y-5">
      {/* Builds Header Toolbar */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="space-y-0.5">
          <h2 className="text-foreground text-sm font-semibold">
            Build History
          </h2>
          <p className="text-muted-foreground text-xs">
            View cloud compiler status, platform artifacts, and stage telemetry.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => void fetchBuildsAndEnvs()}
            className="h-8 gap-1.5"
          >
            <ArrowsClockwise className="size-3.5" />
            <span>Refresh</span>
          </Button>

          <Button
            size="sm"
            onClick={() => setNewBuildOpen(true)}
            className="h-8 gap-1.5"
          >
            <Plus className="size-3.5" weight="bold" />
            <span>New Build</span>
          </Button>
        </div>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertTitle>Failed to load builds</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchBuildsAndEnvs()}
              className="h-7 text-xs"
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      )}

      {isLoading ? (
        <div className="border-border/80 bg-card space-y-3 rounded-lg border p-6">
          <div className="flex items-center justify-center py-12">
            <BloomSpinner size={28} label="Loading build history..." />
          </div>
        </div>
      ) : builds.length === 0 ? (
        <EmptyState
          icon={Hammer}
          title="No builds triggered yet"
          description="Trigger your first cloud build to compile iOS, Android, and Web binaries with zero local toolchain setup."
          actionLabel="Trigger First Build"
          onAction={() => setNewBuildOpen(true)}
        />
      ) : (
        <div className="border-border/80 bg-card overflow-hidden rounded-lg border">
          <TooltipProvider>
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="w-[36px]"></TableHead>
                  <TableHead className="w-[120px]">Status</TableHead>
                  <TableHead>Build</TableHead>
                  <TableHead>Platform</TableHead>
                  <TableHead>Branch / Commit</TableHead>
                  <TableHead>Duration</TableHead>
                  <TableHead>Triggered By</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {builds.map((b, idx) => {
                  const isExpanded = !!expandedRows[b.id];
                  const buildNumber = b.build_number ?? builds.length - idx;
                  const commitSha = b.git_commit || "HEAD";
                  const isRunningOrQueued =
                    b.status === "running" ||
                    b.status === "queued" ||
                    b.status === "pending";

                  return (
                    <React.Fragment key={b.id}>
                      {/* Scannable Surface Layer Row (§22.6) */}
                      <TableRow
                        onClick={() => toggleRow(b.id)}
                        className="hover:bg-muted/40 cursor-pointer transition-colors"
                      >
                        <TableCell className="p-2 text-center">
                          {isExpanded ? (
                            <CaretDown className="text-muted-foreground size-3.5" />
                          ) : (
                            <CaretRight className="text-muted-foreground size-3.5" />
                          )}
                        </TableCell>

                        <TableCell>
                          <StatusBadge status={b.status} size="sm" />
                        </TableCell>

                        <TableCell className="text-foreground font-mono text-xs font-semibold">
                          #{buildNumber}
                        </TableCell>

                        <TableCell>
                          <div className="flex items-center gap-1.5">
                            <PlatformIcon platform={b.platform} size="sm" />
                            <span className="text-muted-foreground font-mono text-xs uppercase">
                              {b.platform}
                            </span>
                          </div>
                        </TableCell>

                        <TableCell>
                          <div className="flex items-center gap-2">
                            <Badge
                              variant="secondary"
                              className="gap-1 px-1.5 py-0 font-mono text-[10px]"
                            >
                              <GitBranch className="size-3" />
                              <span>{b.git_branch || "main"}</span>
                            </Badge>

                            <Tooltip>
                              <TooltipTrigger className="text-muted-foreground hover:text-foreground cursor-help font-mono text-xs">
                                {commitSha.slice(0, 7)}
                              </TooltipTrigger>
                              <TooltipContent>
                                <p className="font-mono text-xs">{commitSha}</p>
                              </TooltipContent>
                            </Tooltip>
                          </div>
                        </TableCell>

                        <TableCell className="text-muted-foreground font-mono text-xs">
                          <div className="flex items-center gap-1">
                            <Clock className="size-3" />
                            <span>
                              {b.duration_seconds
                                ? `${b.duration_seconds}s`
                                : "--"}
                            </span>
                          </div>
                        </TableCell>

                        <TableCell>
                          <div className="flex items-center gap-1.5">
                            <UserAvatar name={b.author || "dev"} size={18} />
                            <span className="text-foreground text-xs">
                              {b.author || "dev"}
                            </span>
                          </div>
                        </TableCell>

                        <TableCell
                          className="text-right"
                          onClick={(e) => e.stopPropagation()}
                        >
                          <DropdownMenu>
                            <DropdownMenuTrigger className="hover:bg-muted/80 text-muted-foreground hover:text-foreground inline-flex size-7 items-center justify-center rounded-md">
                              <DotsThreeVertical className="size-4" />
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end">
                              <DropdownMenuItem
                                onClick={() => toggleRow(b.id)}
                                className="cursor-pointer text-xs"
                              >
                                {isExpanded
                                  ? "Collapse stages"
                                  : "View stages & logs"}
                              </DropdownMenuItem>
                              {/* Hard-hide cancel per §21.5 if role cannot cancel or status is terminal */}
                              {canCancelBuild && isRunningOrQueued && (
                                <DropdownMenuItem
                                  onClick={() => void handleCancelBuild(b.id)}
                                  className="text-destructive cursor-pointer gap-1.5 text-xs"
                                >
                                  <Prohibit className="size-3.5" />
                                  <span>Cancel Build</span>
                                </DropdownMenuItem>
                              )}
                            </DropdownMenuContent>
                          </DropdownMenu>
                        </TableCell>
                      </TableRow>

                      {/* Inline Accordion Row (§22.4 / §22.6 Instant Triage) */}
                      {isExpanded && (
                        <TableRow className="bg-muted/15 hover:bg-muted/15">
                          <TableCell colSpan={8} className="p-4">
                            <Collapsible open={isExpanded}>
                              <CollapsibleContent className="space-y-4">
                                <div className="space-y-2">
                                  <div className="flex items-center justify-between">
                                    <h3 className="text-foreground text-xs font-semibold">
                                      Pipeline Stages
                                    </h3>
                                    <span className="text-muted-foreground font-mono text-[10px]">
                                      Flutter {b.flutter_version || "3.27.0"} ·
                                      Dart {b.dart_version || "3.6.0"}
                                    </span>
                                  </div>

                                  {/* Stage progress badges */}
                                  <div className="flex flex-wrap gap-2">
                                    {b.stages && b.stages.length > 0 ? (
                                      b.stages.map((stg) => (
                                        <div
                                          key={stg.stage}
                                          className="border-border bg-card flex items-center gap-1.5 rounded border px-2.5 py-1 text-xs"
                                        >
                                          <StatusBadge
                                            status={stg.status}
                                            size="sm"
                                            showIcon={false}
                                          />
                                          <span className="text-foreground font-mono font-medium">
                                            {stg.stage}
                                          </span>
                                        </div>
                                      ))
                                    ) : (
                                      <div className="text-muted-foreground flex items-center gap-1 text-xs">
                                        <CheckCircle className="size-3.5 text-[var(--status-success)]" />
                                        <span>Standard automated pipeline</span>
                                      </div>
                                    )}
                                  </div>
                                </div>

                                {/* Log snippet */}
                                <div className="space-y-1.5">
                                  <div className="text-muted-foreground flex items-center gap-1.5 font-mono text-xs">
                                    <TerminalWindow className="size-3.5" />
                                    <span>
                                      Live Log Preview (last 10 lines)
                                    </span>
                                  </div>
                                  <pre className="border-border overflow-x-auto rounded-md border bg-[#000000] p-3 font-mono text-[11px] leading-relaxed text-zinc-300">
                                    {b.stages
                                      ?.flatMap((s) => s.log_snippet)
                                      .filter(Boolean)
                                      .join("\n") ||
                                      `[00:00.01] Worker initialized for build #${buildNumber}\n[00:00.15] Target platform: ${b.platform}\n[00:01.02] Resolved branch: ${b.git_branch || "main"} (${commitSha.slice(0, 7)})\n[00:02.40] Compiling artifacts with bloom-engine...\n[00:04.10] Build status: ${b.status}`}
                                  </pre>
                                </div>
                              </CollapsibleContent>
                            </Collapsible>
                          </TableCell>
                        </TableRow>
                      )}
                    </React.Fragment>
                  );
                })}
              </TableBody>
            </Table>
          </TooltipProvider>
        </div>
      )}

      {/* New Build Dialog */}
      <Dialog open={newBuildOpen} onOpenChange={setNewBuildOpen}>
        <DialogContent className="sm:max-w-md">
          <form onSubmit={handleTriggerBuild}>
            <DialogHeader>
              <DialogTitle>Trigger Cloud Build</DialogTitle>
              <DialogDescription>
                Dispatch a cloud compilation pipeline for this application.
              </DialogDescription>
            </DialogHeader>

            <div className="space-y-4 py-4">
              {/* Target Environment */}
              <div className="space-y-2">
                <Label htmlFor="build-env">Target Environment</Label>
                {environments.length > 0 ? (
                  <Select
                    value={selectedEnvId}
                    onValueChange={(val) => {
                      if (val) setSelectedEnvId(val);
                    }}
                  >
                    <SelectTrigger id="build-env" className="font-mono text-xs">
                      <SelectValue placeholder="Select environment" />
                    </SelectTrigger>
                    <SelectContent>
                      {environments.map((env) => (
                        <SelectItem
                          key={env.id}
                          value={env.id}
                          className="font-mono text-xs"
                        >
                          {env.name} ({env.slug})
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                ) : (
                  <div className="border-border bg-muted/20 text-muted-foreground rounded border p-2.5 text-xs">
                    No environments configured yet. A default{" "}
                    <strong>Production</strong> environment will be created
                    automatically.
                  </div>
                )}
              </div>

              {/* Target Platform */}
              <div className="space-y-2">
                <Label htmlFor="build-platform">Platform Matrix</Label>
                <Select
                  value={selectedPlatform}
                  onValueChange={(val) => {
                    if (val) setSelectedPlatform(val);
                  }}
                >
                  <SelectTrigger
                    id="build-platform"
                    className="font-mono text-xs"
                  >
                    <SelectValue placeholder="Select platform" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all" className="font-mono text-xs">
                      All Targets (iOS, Android, Web)
                    </SelectItem>
                    <SelectItem value="ios" className="font-mono text-xs">
                      iOS (IPA bundle)
                    </SelectItem>
                    <SelectItem value="android" className="font-mono text-xs">
                      Android (AAB & APK)
                    </SelectItem>
                    <SelectItem value="web" className="font-mono text-xs">
                      Web (WASM + HTML5)
                    </SelectItem>
                  </SelectContent>
                </Select>
              </div>

              {/* Optional Custom Branch */}
              <div className="space-y-2">
                <Label htmlFor="build-branch">
                  Custom Git Branch / Ref (optional)
                </Label>
                <Input
                  id="build-branch"
                  placeholder="Defaults to app default branch (main)"
                  value={customBranch}
                  onChange={(e) => setCustomBranch(e.target.value)}
                  className="font-mono text-xs"
                />
              </div>
            </div>

            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => setNewBuildOpen(false)}
                disabled={isTriggering}
              >
                Cancel
              </Button>
              <Button type="submit" disabled={isTriggering}>
                {isTriggering ? (
                  <BloomSpinner size={16} speed="fast" className="mr-2" />
                ) : null}
                Trigger Build
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
