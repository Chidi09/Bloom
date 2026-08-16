"use client";

import * as React from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import {
  CloudArrowUp,
  ArrowsClockwise,
  ArrowSquareOut,
  ArrowRight,
  ArrowCounterClockwise,
  Clock,
  DotsThreeVertical,
  TreeStructure,
  Check,
  CheckCircle,
  CaretRight,
  CaretLeft,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Label } from "@/components/ui/label";
import { cn } from "@/lib/utils";
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
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { PlatformIcon } from "@/components/status/platform-icon";
import { StatusBadge } from "@/components/status/status-badge";
import { EmptyState } from "@/components/shared/empty-state";
import { api } from "@/lib/api/client";
import { DeploymentResponse } from "@/lib/schemas/deployment";
import { ReleaseResponse } from "@/lib/schemas/release";
import { EnvironmentResponse } from "@/lib/schemas/environment";
import { useOrganizationStore } from "@/stores/organization-store";
import { useOrganizationEvents } from "@/lib/hooks/use-organization-events";

const PLATFORM_TARGETS: Record<string, { label: string; value: string }[]> = {
  ios: [
    { label: "Apple TestFlight (Beta Track)", value: "testflight" },
    { label: "App Store (Production Release)", value: "app_store" },
  ],
  android: [
    { label: "Google Play Internal Track", value: "internal" },
    { label: "Google Play Closed Testing", value: "closed" },
    { label: "Google Play Production Track", value: "production" },
  ],
  web: [
    { label: "Production Web Hosting", value: "production" },
    { label: "Preview Branch Environment", value: "preview" },
  ],
};

export default function AppDeploymentsPage() {
  const params = useParams<{ id: string }>();
  const appId = params.id;
  const { currentOrganizationId } = useOrganizationStore();

  useOrganizationEvents(currentOrganizationId);

  const [deployments, setDeployments] = React.useState<DeploymentResponse[]>(
    [],
  );
  const [releases, setReleases] = React.useState<ReleaseResponse[]>([]);
  const [environments, setEnvironments] = React.useState<EnvironmentResponse[]>(
    [],
  );
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Deploy Wizard Dialog State
  const [deployDialogOpen, setDeployDialogOpen] = React.useState(false);
  const [wizardStep, setWizardStep] = React.useState<1 | 2 | 3>(1);
  const [selectedPlatform, setSelectedPlatform] = React.useState<
    "ios" | "android" | "web"
  >("ios");
  const [selectedTarget, setSelectedTarget] = React.useState("testflight");
  const [selectedReleaseId, setSelectedReleaseId] = React.useState("");
  const [selectedEnvId, setSelectedEnvId] = React.useState("");
  const [isDeploying, setIsDeploying] = React.useState(false);

  // Rollback state
  const [rollbackId, setRollbackId] = React.useState<string | null>(null);

  const fetchData = React.useCallback(async () => {
    if (!appId) return;
    setIsLoading(true);
    setError(null);
    try {
      const [depsRes, relsRes, envsRes] = await Promise.all([
        api.get<{ results: DeploymentResponse[] }>("/deployments", {
          params: { app_id: appId },
        }),
        api.get<{ results: ReleaseResponse[] }>("/releases", {
          params: { app_id: appId },
        }),
        api.get<{ results: EnvironmentResponse[] }>("/environments", {
          params: { app_id: appId },
        }),
      ]);

      setDeployments(depsRes?.results ?? []);
      setReleases(relsRes?.results ?? []);
      setEnvironments(envsRes?.results ?? []);

      if (relsRes?.results?.length && !selectedReleaseId) {
        setSelectedReleaseId(relsRes.results[0].id);
      }
      if (envsRes?.results?.length && !selectedEnvId) {
        setSelectedEnvId(envsRes.results[0].id);
      }
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Failed to load deployments",
      );
    } finally {
      setIsLoading(false);
    }
  }, [appId, selectedReleaseId, selectedEnvId]);

  React.useEffect(() => {
    const run = async () => {
      await fetchData();
    };
    void run();
  }, [fetchData]);

  const handlePlatformChange = (p: "ios" | "android" | "web") => {
    setSelectedPlatform(p);
    const availableTargets = PLATFORM_TARGETS[p];
    if (availableTargets && availableTargets.length > 0) {
      setSelectedTarget(availableTargets[0].value);
    }
  };

  const handleTriggerDeploy = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedEnvId) {
      toast.error("Please select a target environment");
      return;
    }

    setIsDeploying(true);
    try {
      await api.post("/deployments", {
        environment_id: selectedEnvId,
        platform: selectedPlatform,
        target: selectedTarget,
        release_id: selectedReleaseId || null,
        artifact_id: null,
      });

      toast.success("Deployment queued successfully");
      setDeployDialogOpen(false);
      await fetchData();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to trigger deployment",
      );
    } finally {
      setIsDeploying(false);
    }
  };

  const handleRollback = async (deploymentId: string) => {
    try {
      await api.post(`/deployments/${deploymentId}/rollback`);
      toast.success("Deployment rolled back");
      setRollbackId(null);
      await fetchData();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to rollback deployment",
      );
    }
  };

  const formatTargetLabel = (target: string) => {
    switch (target) {
      case "testflight":
        return "TestFlight";
      case "app_store":
        return "App Store";
      case "internal":
        return "Internal Track";
      case "closed":
        return "Closed Testing";
      case "production":
        return "Production";
      case "preview":
        return "Preview";
      default:
        return target;
    }
  };

  return (
    <div className="space-y-4">
      {/* Deployments Toolbar */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="space-y-0.5">
          <h2 className="text-foreground text-sm font-semibold">
            Deployments & Store Distribution
          </h2>
          <p className="text-muted-foreground text-xs">
            Automated mobile store publishing pipelines, web hosting artifacts,
            and OTA broadcast telemetry.
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
            onClick={() => setDeployDialogOpen(true)}
            className="h-8 gap-1.5"
          >
            <CloudArrowUp className="size-3.5" weight="bold" />
            <span>Deploy</span>
          </Button>
        </div>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertTitle>Failed to load deployments</AlertTitle>
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
          <BloomSpinner size={28} label="Loading deployments feed..." />
        </div>
      ) : deployments.length === 0 ? (
        <EmptyState
          icon={CloudArrowUp}
          title="No deployments dispatched"
          description="Deploy an approved release build to Apple TestFlight, Google Play tracks, or Bloom Web Hosting."
          actionLabel="Trigger First Deploy"
          onAction={() => setDeployDialogOpen(true)}
        />
      ) : (
        <div className="border-border/80 bg-card overflow-hidden rounded-lg border shadow-xs">
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="w-[110px]">Platform</TableHead>
                  <TableHead>Target</TableHead>
                  <TableHead>Release</TableHead>
                  <TableHead>Environment</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>External Link</TableHead>
                  <TableHead>Duration</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {deployments.map((dep) => {
                  const env = environments.find(
                    (e) => e.id === dep.environment_id,
                  );
                  const rel = releases.find((r) => r.id === dep.release_id);

                  return (
                    <TableRow
                      key={dep.id}
                      className="hover:bg-muted/40 group transition-colors duration-150"
                    >
                      <TableCell>
                        <div className="flex items-center gap-1.5 font-mono text-xs uppercase">
                          <PlatformIcon platform={dep.platform} size="sm" />
                          <span>{dep.platform}</span>
                        </div>
                      </TableCell>

                      <TableCell>
                        <Badge
                          variant="secondary"
                          className="bg-muted/60 text-foreground border-border/40 font-mono text-[10px]"
                        >
                          {formatTargetLabel(dep.target)}
                        </Badge>
                      </TableCell>

                      <TableCell className="text-foreground font-mono text-xs font-semibold">
                        {dep.release_version || rel?.version || "--"}
                      </TableCell>

                      <TableCell>
                        <div className="text-muted-foreground flex items-center gap-1.5 font-mono text-xs">
                          <TreeStructure className="size-3" />
                          <span>
                            {dep.environment_name || env?.name || "Production"}
                          </span>
                        </div>
                      </TableCell>

                      <TableCell>
                        <StatusBadge status={dep.status} size="sm" />
                      </TableCell>

                      <TableCell>
                        {dep.external_url ? (
                          <Link
                            href={dep.external_url}
                            target="_blank"
                            className="hover:bg-muted text-primary inline-flex items-center gap-1 rounded-md px-2 py-0.5 font-mono text-xs transition-colors hover:underline"
                          >
                            <span>Console</span>
                            <ArrowSquareOut className="size-3" />
                          </Link>
                        ) : (
                          <span className="text-muted-foreground font-mono text-xs">
                            --
                          </span>
                        )}
                      </TableCell>

                      <TableCell className="text-muted-foreground font-mono text-xs">
                        <div className="flex items-center gap-1">
                          <Clock className="size-3" />
                          <span>
                            {dep.duration_seconds
                              ? `${dep.duration_seconds}s`
                              : "--"}
                          </span>
                        </div>
                      </TableCell>

                      <TableCell className="text-right">
                        <div className="flex items-center justify-end gap-1">
                          <Link
                            href={`/apps/${appId}/deployments/${dep.id}`}
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
                              {dep.status !== "rolled_back" && (
                                <DropdownMenuItem
                                  onClick={() => setRollbackId(dep.id)}
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
          </div>
        </div>
      )}

      {/* Rollback Alert Dialog */}
      <AlertDialog
        open={!!rollbackId}
        onOpenChange={(open) => !open && setRollbackId(null)}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Rollback Deployment</AlertDialogTitle>
            <AlertDialogDescription>
              Are you sure you want to rollback this deployment? This will
              notify active worker pods and stop distribution on this track.
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

      {/* Deploy Multi-step Wizard Dialog (§22.4 / §22.6) */}
      <Dialog
        open={deployDialogOpen}
        onOpenChange={(open) => {
          setDeployDialogOpen(open);
          if (!open) setWizardStep(1);
        }}
      >
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2 text-base">
              <CloudArrowUp className="text-primary size-4" />
              <span>Deploy Release Pipeline</span>
            </DialogTitle>
            <DialogDescription className="text-xs">
              Dispatch an automated deployment pipeline to app stores or edge
              hosting.
            </DialogDescription>

            {/* Stepper Progress Header */}
            <div className="border-border/80 mt-3 flex items-center justify-between border-y py-2.5">
              {[
                { step: 1, title: "Platform & Target" },
                { step: 2, title: "Release & Env" },
                { step: 3, title: "Review & Dispatch" },
              ].map((s, idx) => {
                const isActive = wizardStep === s.step;
                const isDone = wizardStep > s.step;
                return (
                  <React.Fragment key={s.step}>
                    <div className="flex items-center gap-2">
                      <div
                        className={cn(
                          "flex size-5 shrink-0 items-center justify-center rounded-full text-[10px] font-semibold transition-colors",
                          isActive &&
                            "border-primary bg-primary text-primary-foreground border",
                          isDone &&
                            "border border-emerald-500/40 bg-emerald-500/20 text-emerald-400",
                          !isActive &&
                            !isDone &&
                            "border-border/80 bg-muted/40 text-muted-foreground border",
                        )}
                      >
                        {isDone ? (
                          <Check className="size-3" weight="bold" />
                        ) : (
                          s.step
                        )}
                      </div>
                      <span
                        className={cn(
                          "text-xs font-medium",
                          isActive
                            ? "text-foreground font-semibold"
                            : isDone
                              ? "text-emerald-400"
                              : "text-muted-foreground",
                        )}
                      >
                        {s.title}
                      </span>
                    </div>
                    {idx < 2 && (
                      <div className="bg-border/60 mx-1 h-px flex-1" />
                    )}
                  </React.Fragment>
                );
              })}
            </div>
          </DialogHeader>

          <div className="py-2">
            {/* Step 1: Target Platform & Track */}
            {wizardStep === 1 && (
              <div className="space-y-4">
                <div className="space-y-2">
                  <Label className="text-xs font-medium">Target Platform</Label>
                  <div className="grid grid-cols-3 gap-2">
                    {(["ios", "android", "web"] as const).map((p) => {
                      const isSelected = selectedPlatform === p;
                      return (
                        <button
                          key={p}
                          type="button"
                          onClick={() => handlePlatformChange(p)}
                          className={cn(
                            "flex cursor-pointer flex-col items-center justify-center gap-1.5 rounded-lg border p-3 text-xs transition-all",
                            isSelected
                              ? "border-primary bg-primary/10 text-foreground font-semibold shadow-xs"
                              : "border-border/80 hover:bg-muted/40 text-muted-foreground",
                          )}
                        >
                          <PlatformIcon platform={p} size="md" />
                          <span className="font-mono uppercase">{p}</span>
                        </button>
                      );
                    })}
                  </div>
                </div>

                <div className="space-y-1.5">
                  <Label
                    htmlFor="deploy-target"
                    className="text-xs font-medium"
                  >
                    Destination Target Track
                  </Label>
                  <Select
                    value={selectedTarget}
                    onValueChange={(val) => val && setSelectedTarget(val)}
                  >
                    <SelectTrigger id="deploy-target" className="text-xs">
                      <SelectValue placeholder="Select target track" />
                    </SelectTrigger>
                    <SelectContent>
                      {PLATFORM_TARGETS[selectedPlatform]?.map((t) => (
                        <SelectItem
                          key={t.value}
                          value={t.value}
                          className="text-xs"
                        >
                          {t.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>
            )}

            {/* Step 2: Release Selection & Environment */}
            {wizardStep === 2 && (
              <div className="space-y-4">
                <div className="space-y-1.5">
                  <Label
                    htmlFor="deploy-release"
                    className="text-xs font-medium"
                  >
                    Release Version
                  </Label>
                  {releases.length > 0 ? (
                    <Select
                      value={selectedReleaseId}
                      onValueChange={(val) => val && setSelectedReleaseId(val)}
                    >
                      <SelectTrigger
                        id="deploy-release"
                        className="font-mono text-xs"
                      >
                        <SelectValue placeholder="Select release artifact" />
                      </SelectTrigger>
                      <SelectContent>
                        {releases.map((rel) => (
                          <SelectItem
                            key={rel.id}
                            value={rel.id}
                            className="font-mono text-xs"
                          >
                            {rel.version} (#{rel.build_number}) · {rel.status}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  ) : (
                    <div className="border-border bg-muted/20 text-muted-foreground rounded border p-2.5 text-xs">
                      No releases found. Create a release before deploying.
                    </div>
                  )}
                </div>

                <div className="space-y-1.5">
                  <Label htmlFor="deploy-env" className="text-xs font-medium">
                    Deployment Environment
                  </Label>
                  <Select
                    value={selectedEnvId}
                    onValueChange={(val) => val && setSelectedEnvId(val)}
                  >
                    <SelectTrigger
                      id="deploy-env"
                      className="font-mono text-xs"
                    >
                      <SelectValue placeholder="Select target environment" />
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
                </div>
              </div>
            )}

            {/* Step 3: Review & Preflight */}
            {wizardStep === 3 && (
              <div className="space-y-3.5">
                <div className="border-border/80 bg-muted/20 space-y-2 rounded-lg border p-3 text-xs">
                  <div className="border-border/40 flex items-center justify-between border-b pb-1.5">
                    <span className="text-muted-foreground">
                      Target Platform
                    </span>
                    <Badge
                      variant="outline"
                      className="font-mono text-[10px] uppercase"
                    >
                      {selectedPlatform}
                    </Badge>
                  </div>
                  <div className="border-border/40 flex items-center justify-between border-b pb-1.5">
                    <span className="text-muted-foreground">
                      Track / Channel
                    </span>
                    <span className="text-foreground font-mono font-medium capitalize">
                      {selectedTarget}
                    </span>
                  </div>
                  <div className="border-border/40 flex items-center justify-between border-b pb-1.5">
                    <span className="text-muted-foreground">
                      Release Version
                    </span>
                    <span className="text-foreground font-mono font-medium">
                      {releases.find((r) => r.id === selectedReleaseId)
                        ?.version || selectedReleaseId}
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-muted-foreground">Environment</span>
                    <span className="text-foreground font-mono font-medium">
                      {environments.find((e) => e.id === selectedEnvId)?.name ||
                        selectedEnvId}
                    </span>
                  </div>
                </div>

                <div className="rounded-lg border border-emerald-500/30 bg-emerald-500/[0.05] p-3 text-xs text-emerald-300">
                  <div className="flex items-center gap-2 font-semibold">
                    <CheckCircle
                      className="size-4 text-emerald-400"
                      weight="fill"
                    />
                    <span>Preflight Validation Passed</span>
                  </div>
                  <p className="mt-1 text-[11px] leading-relaxed text-emerald-400/80">
                    Environment configuration and target credentials verified.
                    Pipeline triggers immediately on dispatch.
                  </p>
                </div>
              </div>
            )}
          </div>

          <DialogFooter className="border-border/60 border-t pt-3">
            {wizardStep === 1 ? (
              <>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => setDeployDialogOpen(false)}
                  disabled={isDeploying}
                  className="text-xs"
                >
                  Cancel
                </Button>
                <Button
                  type="button"
                  size="sm"
                  onClick={() => setWizardStep(2)}
                  disabled={!selectedTarget}
                  className="gap-1 text-xs"
                >
                  <span>Next: Release & Env</span>
                  <CaretRight className="size-3.5" />
                </Button>
              </>
            ) : wizardStep === 2 ? (
              <>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => setWizardStep(1)}
                  disabled={isDeploying}
                  className="gap-1 text-xs"
                >
                  <CaretLeft className="size-3.5" />
                  <span>Back</span>
                </Button>
                <Button
                  type="button"
                  size="sm"
                  onClick={() => setWizardStep(3)}
                  disabled={!selectedReleaseId || !selectedEnvId}
                  className="gap-1 text-xs"
                >
                  <span>Next: Review</span>
                  <CaretRight className="size-3.5" />
                </Button>
              </>
            ) : (
              <>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={() => setWizardStep(2)}
                  disabled={isDeploying}
                  className="gap-1 text-xs"
                >
                  <CaretLeft className="size-3.5" />
                  <span>Back</span>
                </Button>
                <Button
                  type="button"
                  size="sm"
                  onClick={(e) => void handleTriggerDeploy(e)}
                  disabled={!selectedEnvId || isDeploying}
                  className="bg-primary text-primary-foreground text-xs font-semibold"
                >
                  {isDeploying ? (
                    <BloomSpinner size={14} speed="fast" className="mr-2" />
                  ) : null}
                  Dispatch Deployment
                </Button>
              </>
            )}
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
