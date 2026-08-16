"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { GitFork, Plus, Play, ArrowsClockwise } from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { StatusBadge } from "@/components/status/status-badge";
import { PageHeader } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import { api } from "@/lib/api/client";
import { WorkflowResponse, WorkflowRunResponse } from "@/lib/schemas/workflow";
import { AppResponse } from "@/lib/schemas/app";
import { useOrganizationStore } from "@/stores/organization-store";

const DEFAULT_WORKFLOW_YAML = `name: CI/CD Pipeline
on:
  push:
    branches: [main]
jobs:
  test:
    name: Run Unit Tests
    kind: test
    run: flutter test

  build:
    name: Build Multiplatform App
    needs: [test]
    kind: build
    platforms: [android, ios]

  approval:
    name: Production Release Gate
    needs: [build]
    kind: approval_gate
    requires_approval: true

  deploy:
    name: Deploy Release
    needs: [approval]
    kind: deploy_production`;

export default function WorkflowsListPage() {
  const router = useRouter();
  const { currentOrganizationId } = useOrganizationStore();

  const [workflows, setWorkflows] = React.useState<WorkflowResponse[]>([]);
  const [runsMap, setRunsMap] = React.useState<
    Record<string, WorkflowRunResponse>
  >({});
  const [apps, setApps] = React.useState<AppResponse[]>([]);
  const [selectedAppId, setSelectedAppId] = React.useState<string>("all");
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Create workflow dialog state
  const [createDialogOpen, setCreateDialogOpen] = React.useState(false);
  const [formAppId, setFormAppId] = React.useState<string>("");
  const [formName, setFormName] = React.useState("");
  const [formSlug, setFormSlug] = React.useState("");
  const [formDescription, setFormDescription] = React.useState("");
  const [formDefinition, setFormDefinition] = React.useState(
    DEFAULT_WORKFLOW_YAML,
  );
  const [formIsActive, setFormIsActive] = React.useState(true);
  const [isSubmitting, setIsSubmitting] = React.useState(false);

  // Trigger run modal state
  const [triggerRunWorkflowId, setTriggerRunWorkflowId] = React.useState<
    string | null
  >(null);
  const [triggerBranch, setTriggerBranch] = React.useState("main");
  const [triggerCommit, setTriggerCommit] = React.useState("");
  const [isTriggering, setIsTriggering] = React.useState(false);

  const fetchWorkflowsData = React.useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const [wfRes, appsRes] = await Promise.all([
        api.get<{ results: WorkflowResponse[] }>("/workflows", {
          params:
            selectedAppId !== "all" ? { app_id: selectedAppId } : undefined,
        }),
        api.get<{ results: AppResponse[] }>("/apps"),
      ]);

      const loadedWfs = wfRes?.results ?? [];
      setWorkflows(loadedWfs);
      setApps(appsRes?.results ?? []);
      if (appsRes?.results?.length && !formAppId) {
        setFormAppId(appsRes.results[0].id);
      }

      // Fetch latest run for each workflow in parallel
      const runsObj: Record<string, WorkflowRunResponse> = {};
      await Promise.all(
        loadedWfs.map(async (wf) => {
          try {
            const runsRes = await api.get<{ results: WorkflowRunResponse[] }>(
              `/workflows/${wf.id}/runs`,
            );
            if (runsRes?.results?.length) {
              runsObj[wf.id] = runsRes.results[0];
            }
          } catch {
            // ignore individual run fetch failure
          }
        }),
      );
      setRunsMap(runsObj);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to load workflows");
    } finally {
      setIsLoading(false);
    }
  }, [selectedAppId, formAppId]);

  React.useEffect(() => {
    const run = async () => {
      await fetchWorkflowsData();
    };
    void run();
  }, [fetchWorkflowsData, currentOrganizationId]);

  const handleNameChange = (val: string) => {
    setFormName(val);
    if (
      !formSlug ||
      formSlug === formName.toLowerCase().replace(/[^a-z0-9]+/g, "-")
    ) {
      setFormSlug(
        val
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, "-")
          .replace(/^-|-$/g, ""),
      );
    }
  };

  const handleCreateWorkflow = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formName.trim() || !formSlug.trim() || !formDefinition.trim()) {
      toast.error("Please fill in all required fields");
      return;
    }

    setIsSubmitting(true);
    try {
      const created = await api.post<WorkflowResponse>("/workflows", {
        app_id: formAppId || apps[0]?.id,
        name: formName.trim(),
        slug: formSlug.trim(),
        description: formDescription.trim() || undefined,
        definition: formDefinition,
        is_active: formIsActive,
      });
      toast.success(`Workflow "${created.name}" created successfully`);
      setCreateDialogOpen(false);
      setFormName("");
      setFormSlug("");
      setFormDescription("");
      setFormDefinition(DEFAULT_WORKFLOW_YAML);
      void fetchWorkflowsData();
      router.push(`/workflows/${created.id}`);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to create workflow",
      );
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleToggleActive = async (
    wf: WorkflowResponse,
    e: React.MouseEvent,
  ) => {
    e.stopPropagation();
    try {
      const updated = await api.patch<WorkflowResponse>(`/workflows/${wf.id}`, {
        is_active: !wf.is_active,
      });
      setWorkflows((prev) =>
        prev.map((item) =>
          item.id === wf.id ? { ...item, is_active: updated.is_active } : item,
        ),
      );
      toast.success(`Workflow ${updated.is_active ? "enabled" : "disabled"}`);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to toggle workflow status",
      );
    }
  };

  const handleTriggerRun = async () => {
    if (!triggerRunWorkflowId) return;
    setIsTriggering(true);
    try {
      const run = await api.post<WorkflowRunResponse>(
        `/workflows/${triggerRunWorkflowId}/runs`,
        {
          git_branch: triggerBranch || "main",
          git_commit: triggerCommit.trim() || undefined,
          trigger_event: "manual",
        },
      );
      toast.success(`Execution run triggered (${run.status})`);
      setTriggerRunWorkflowId(null);
      setTriggerCommit("");
      router.push(`/workflows/${triggerRunWorkflowId}`);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to trigger workflow run",
      );
    } finally {
      setIsTriggering(false);
    }
  };

  const getAppName = (appId: string) => {
    const a = apps.find((item) => item.id === appId);
    return a ? a.name : appId;
  };

  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <PageHeader
        breadcrumbs={[{ label: "Workflows" }]}
        title="Workflows"
        description="Automated CI/CD pipelines, multiplatform compilation gates, and deployment triggers."
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchWorkflowsData()}
              className="h-8 gap-1.5"
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
              <span>Create Workflow</span>
            </Button>
          </div>
        }
      />

      {error && (
        <Alert variant="destructive">
          <AlertTitle>Failed to load workflows</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchWorkflowsData()}
              className="h-7 text-xs"
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      )}

      {/* Filter Bar */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <span className="text-muted-foreground text-xs font-medium">
            Application:
          </span>
          <Select
            value={selectedAppId}
            onValueChange={(v) => v && setSelectedAppId(v)}
          >
            <SelectTrigger className="h-8 w-48 text-xs">
              <SelectValue placeholder="All Applications" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all" className="text-xs">
                All Applications
              </SelectItem>
              {apps.map((a) => (
                <SelectItem key={a.id} value={a.id} className="text-xs">
                  {a.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>

      {isLoading ? (
        <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-16">
          <BloomSpinner size={28} label="Loading workflow pipelines..." />
        </div>
      ) : workflows.length === 0 ? (
        <EmptyState
          icon={GitFork}
          title="No workflows defined"
          description="Create your first YAML-based build and deployment automation pipeline."
          actionNode={
            <Button
              size="sm"
              onClick={() => setCreateDialogOpen(true)}
              className="gap-1.5"
            >
              <Plus className="size-3.5" weight="bold" />
              <span>Create Workflow</span>
            </Button>
          }
        />
      ) : (
        <div className="border-border/80 bg-card overflow-hidden rounded-lg border">
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="w-[280px]">Workflow</TableHead>
                  <TableHead>Application</TableHead>
                  <TableHead>Last Run Status</TableHead>
                  <TableHead>Trigger / Branch</TableHead>
                  <TableHead>Active</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {workflows.map((wf) => {
                  const latestRun = runsMap[wf.id];
                  const appName = getAppName(wf.app_id);

                  return (
                    <TableRow
                      key={wf.id}
                      onClick={() => router.push(`/workflows/${wf.id}`)}
                      className="hover:bg-muted/40 cursor-pointer transition-colors"
                    >
                      <TableCell>
                        <div className="space-y-0.5">
                          <div className="flex items-center gap-2">
                            <span className="text-foreground text-xs font-semibold hover:underline">
                              {wf.name}
                            </span>
                          </div>
                          <div className="text-muted-foreground font-mono text-[11px]">
                            {wf.slug}
                          </div>
                        </div>
                      </TableCell>

                      <TableCell>
                        <Badge
                          variant="outline"
                          className="font-mono text-[11px]"
                        >
                          {appName}
                        </Badge>
                      </TableCell>

                      <TableCell>
                        {latestRun ? (
                          <div className="flex items-center gap-2">
                            <StatusBadge status={latestRun.status} size="sm" />
                            <span className="text-muted-foreground font-mono text-[11px]">
                              {
                                latestRun.steps.filter(
                                  (s) => s.status === "completed",
                                ).length
                              }
                              /{latestRun.steps.length} steps
                            </span>
                          </div>
                        ) : (
                          <span className="text-muted-foreground font-mono text-xs">
                            No runs yet
                          </span>
                        )}
                      </TableCell>

                      <TableCell>
                        {latestRun ? (
                          <div className="space-y-0.5 font-mono text-xs">
                            <div className="text-foreground flex items-center gap-1.5">
                              <span className="capitalize">
                                {latestRun.trigger_event}
                              </span>
                              <span className="text-muted-foreground">
                                ({latestRun.git_branch})
                              </span>
                            </div>
                            <div className="text-muted-foreground text-[10px]">
                              {latestRun.git_commit.slice(0, 7)}
                            </div>
                          </div>
                        ) : (
                          <span className="text-muted-foreground font-mono text-xs">
                            --
                          </span>
                        )}
                      </TableCell>

                      <TableCell onClick={(e) => e.stopPropagation()}>
                        <TooltipProvider>
                          <Tooltip>
                            <TooltipTrigger className="flex items-center gap-2">
                              <Switch
                                checked={wf.is_active}
                                disabled
                                onCheckedChange={() =>
                                  void handleToggleActive(
                                    wf,
                                    {} as React.MouseEvent,
                                  )
                                }
                                aria-label="Workflow active state"
                              />
                              <span className="text-muted-foreground font-mono text-[11px]">
                                {wf.is_active ? "Enabled" : "Disabled"}
                              </span>
                            </TooltipTrigger>
                            <TooltipContent>
                              <p className="text-xs">
                                Not yet available: the backend has no workflow
                                update endpoint.
                              </p>
                            </TooltipContent>
                          </Tooltip>
                        </TooltipProvider>
                      </TableCell>

                      <TableCell
                        className="text-right"
                        onClick={(e) => e.stopPropagation()}
                      >
                        <div className="flex items-center justify-end gap-1.5">
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => {
                              setTriggerRunWorkflowId(wf.id);
                              setTriggerBranch("main");
                            }}
                            className="h-7 gap-1 px-2 text-xs transition-colors hover:border-emerald-500/40 hover:bg-emerald-950/30"
                          >
                            <Play
                              className="size-3 text-emerald-400"
                              weight="fill"
                            />
                            <span>Run</span>
                          </Button>
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => router.push(`/workflows/${wf.id}`)}
                            className="h-7 px-2 text-xs"
                          >
                            Details
                          </Button>
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

      {/* Create Workflow Dialog */}
      <Dialog open={createDialogOpen} onOpenChange={setCreateDialogOpen}>
        <DialogContent className="sm:max-w-2xl">
          <form onSubmit={handleCreateWorkflow}>
            <DialogHeader>
              <DialogTitle>Create New Workflow</DialogTitle>
              <DialogDescription>
                Define an automated multi-step build, test, and release pipeline
                via YAML specification.
              </DialogDescription>
            </DialogHeader>

            <div className="space-y-4 py-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <Label htmlFor="wf-app">Target Application</Label>
                  <Select
                    value={formAppId}
                    onValueChange={(v) => v && setFormAppId(v)}
                  >
                    <SelectTrigger id="wf-app" className="text-xs">
                      <SelectValue placeholder="Select application" />
                    </SelectTrigger>
                    <SelectContent>
                      {apps.map((a) => (
                        <SelectItem key={a.id} value={a.id} className="text-xs">
                          {a.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                <div className="space-y-1.5">
                  <Label htmlFor="wf-name">Workflow Name</Label>
                  <Input
                    id="wf-name"
                    placeholder="e.g. Staging Rollout Pipeline"
                    value={formName}
                    onChange={(e) => handleNameChange(e.target.value)}
                    required
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <Label htmlFor="wf-slug">Slug Identifier</Label>
                  <Input
                    id="wf-slug"
                    placeholder="staging-rollout"
                    value={formSlug}
                    onChange={(e) => setFormSlug(e.target.value)}
                    className="font-mono text-xs"
                    required
                  />
                </div>

                <div className="space-y-1.5">
                  <Label htmlFor="wf-desc">Description (Optional)</Label>
                  <Input
                    id="wf-desc"
                    placeholder="Brief summary of pipeline purpose"
                    value={formDescription}
                    onChange={(e) => setFormDescription(e.target.value)}
                  />
                </div>
              </div>

              <div className="space-y-1.5">
                <div className="flex items-center justify-between">
                  <Label htmlFor="wf-yaml">Pipeline YAML Definition</Label>
                  <span className="text-muted-foreground font-mono text-[10px]">
                    YAML Syntax
                  </span>
                </div>
                <Textarea
                  id="wf-yaml"
                  value={formDefinition}
                  onChange={(e) => setFormDefinition(e.target.value)}
                  rows={11}
                  className="bg-black font-mono text-xs leading-relaxed text-zinc-200"
                  required
                />
              </div>

              <div className="flex items-center gap-2 pt-1">
                <Switch
                  id="wf-active"
                  checked={formIsActive}
                  onCheckedChange={setFormIsActive}
                />
                <Label
                  htmlFor="wf-active"
                  className="cursor-pointer text-xs font-normal"
                >
                  Enable automatic trigger on Git webhook events
                </Label>
              </div>
            </div>

            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => setCreateDialogOpen(false)}
                disabled={isSubmitting}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                disabled={isSubmitting || !formName || !formSlug}
              >
                {isSubmitting ? (
                  <BloomSpinner size={14} speed="fast" className="mr-2" />
                ) : null}
                Create Workflow
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* Trigger Run Dialog */}
      <Dialog
        open={triggerRunWorkflowId !== null}
        onOpenChange={(open) => !open && setTriggerRunWorkflowId(null)}
      >
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Trigger Workflow Run</DialogTitle>
            <DialogDescription>
              Execute an on-demand manual pipeline run on a target branch or
              commit SHA.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4 py-3">
            <div className="space-y-1.5">
              <Label htmlFor="trig-branch">Git Branch</Label>
              <Input
                id="trig-branch"
                value={triggerBranch}
                onChange={(e) => setTriggerBranch(e.target.value)}
                placeholder="main"
                className="font-mono text-xs"
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="trig-commit">Commit SHA (Optional)</Label>
              <Input
                id="trig-commit"
                value={triggerCommit}
                onChange={(e) => setTriggerCommit(e.target.value)}
                placeholder="Defaults to latest branch HEAD"
                className="font-mono text-xs"
              />
            </div>
          </div>

          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setTriggerRunWorkflowId(null)}
              disabled={isTriggering}
            >
              Cancel
            </Button>
            <Button
              onClick={() => void handleTriggerRun()}
              disabled={isTriggering}
            >
              {isTriggering ? (
                <BloomSpinner size={14} speed="fast" className="mr-2" />
              ) : (
                <Play className="mr-1.5 size-3.5" weight="fill" />
              )}
              Trigger Run
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
