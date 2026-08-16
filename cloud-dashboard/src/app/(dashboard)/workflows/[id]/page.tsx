"use client";

import * as React from "react";
import { useParams } from "next/navigation";
import {
  Play,
  PencilSimple,
  FloppyDisk,
  CheckCircle,
  XCircle,
  WarningCircle,
  Clock,
  GitBranch,
  TerminalWindow,
  CaretRight,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
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
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { StatusBadge } from "@/components/status/status-badge";
import { PageHeader } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import { api } from "@/lib/api/client";
import { WorkflowResponse, WorkflowRunResponse } from "@/lib/schemas/workflow";

export default function WorkflowDetailPage() {
  const params = useParams<{ id: string }>();
  const workflowId = params.id;

  const [workflow, setWorkflow] = React.useState<WorkflowResponse | null>(null);
  const [runs, setRuns] = React.useState<WorkflowRunResponse[]>([]);
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // YAML editing state
  const [isEditingYaml, setIsEditingYaml] = React.useState(false);
  const [yamlContent, setYamlContent] = React.useState("");
  const [isSavingYaml, setIsSavingYaml] = React.useState(false);

  // Trigger run modal state
  const [triggerModalOpen, setTriggerModalOpen] = React.useState(false);
  const [triggerBranch, setTriggerBranch] = React.useState("main");
  const [triggerCommit, setTriggerCommit] = React.useState("");
  const [isTriggering, setIsTriggering] = React.useState(false);

  // Slide-over Sheet state for run detail timeline
  const [selectedRun, setSelectedRun] =
    React.useState<WorkflowRunResponse | null>(null);
  const [sheetOpen, setSheetOpen] = React.useState(false);

  // Approval decision state
  const [approvalReason, setApprovalReason] = React.useState("");
  const [isSubmittingApproval, setIsSubmittingApproval] = React.useState(false);

  const fetchWorkflowDetails = React.useCallback(async () => {
    if (!workflowId) return;
    setIsLoading(true);
    setError(null);
    try {
      const [wfRes, runsRes] = await Promise.all([
        api.get<WorkflowResponse>(`/workflows/${workflowId}`),
        api.get<{ results: WorkflowRunResponse[] }>(
          `/workflows/${workflowId}/runs`,
        ),
      ]);
      setWorkflow(wfRes);
      setYamlContent(wfRes.definition);
      setRuns(runsRes?.results ?? []);

      // If a run was already open in the slide-over, refresh it
      if (selectedRun) {
        const freshRun = runsRes?.results?.find((r) => r.id === selectedRun.id);
        if (freshRun) setSelectedRun(freshRun);
      }
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Failed to load workflow details",
      );
    } finally {
      setIsLoading(false);
    }
  }, [workflowId, selectedRun]);

  React.useEffect(() => {
    const run = async () => {
      await fetchWorkflowDetails();
    };
    void run();
  }, [fetchWorkflowDetails]);

  const handleSaveYaml = async () => {
    if (!workflow) return;
    setIsSavingYaml(true);
    try {
      const updated = await api.patch<WorkflowResponse>(
        `/workflows/${workflow.id}`,
        {
          definition: yamlContent,
        },
      );
      setWorkflow(updated);
      setIsEditingYaml(false);
      toast.success("Workflow YAML definition updated");
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Failed to update YAML");
    } finally {
      setIsSavingYaml(false);
    }
  };

  const handleToggleActive = async () => {
    if (!workflow) return;
    try {
      const updated = await api.patch<WorkflowResponse>(
        `/workflows/${workflow.id}`,
        {
          is_active: !workflow.is_active,
        },
      );
      setWorkflow(updated);
      toast.success(`Workflow ${updated.is_active ? "enabled" : "disabled"}`);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to update workflow status",
      );
    }
  };

  const handleTriggerRun = async () => {
    if (!workflow) return;
    setIsTriggering(true);
    try {
      const run = await api.post<WorkflowRunResponse>(
        `/workflows/${workflow.id}/runs`,
        {
          git_branch: triggerBranch || "main",
          git_commit: triggerCommit.trim() || undefined,
          trigger_event: "manual",
        },
      );
      toast.success("Workflow run triggered successfully");
      setTriggerModalOpen(false);
      setTriggerCommit("");
      void fetchWorkflowDetails();
      setSelectedRun(run);
      setSheetOpen(true);
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Failed to trigger run");
    } finally {
      setIsTriggering(false);
    }
  };

  const handleApproveOrReject = async (runId: string, approved: boolean) => {
    setIsSubmittingApproval(true);
    try {
      const updatedRun = await api.post<WorkflowRunResponse>(
        `/workflows/runs/${runId}/approve`,
        {
          approved,
          reason: approvalReason.trim() || undefined,
        },
      );
      toast.success(
        approved
          ? "Workflow run approved. Execution resumed."
          : "Workflow run rejected and terminated.",
      );
      setSelectedRun(updatedRun);
      setApprovalReason("");
      void fetchWorkflowDetails();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error
          ? err.message
          : "Failed to process approval decision",
      );
    } finally {
      setIsSubmittingApproval(false);
    }
  };

  const openRunSheet = (run: WorkflowRunResponse) => {
    setSelectedRun(run);
    setSheetOpen(true);
  };

  if (isLoading && !workflow) {
    return (
      <div className="mx-auto flex max-w-6xl items-center justify-center py-20">
        <BloomSpinner size={32} label="Loading workflow..." />
      </div>
    );
  }

  if (error || !workflow) {
    return (
      <div className="mx-auto max-w-6xl space-y-4">
        <Alert variant="destructive">
          <AlertTitle>Error loading workflow</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error || "Workflow not found"}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchWorkflowDetails()}
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <PageHeader
        breadcrumbs={[
          { label: "Workflows", href: "/workflows" },
          { label: workflow.name },
        ]}
        title={workflow.name}
        description={
          workflow.description || `Pipeline identifier: ${workflow.slug}`
        }
        badge={
          <Badge
            variant={workflow.is_active ? "default" : "secondary"}
            className="font-mono text-[11px]"
          >
            {workflow.is_active ? "Active" : "Inactive"}
          </Badge>
        }
        actions={
          <div className="flex items-center gap-2">
            <TooltipProvider>
              <Tooltip>
                <TooltipTrigger className="flex items-center gap-2 border-r border-zinc-800 pr-3">
                  <Switch
                    id="active-toggle"
                    checked={workflow.is_active}
                    disabled
                    onCheckedChange={() => void handleToggleActive()}
                  />
                  <Label
                    htmlFor="active-toggle"
                    className="text-xs font-medium text-zinc-400"
                  >
                    {workflow.is_active ? "Enabled" : "Disabled"}
                  </Label>
                </TooltipTrigger>
                <TooltipContent>
                  <p className="text-xs">
                    Not yet available: the backend has no workflow update
                    endpoint.
                  </p>
                </TooltipContent>
              </Tooltip>
            </TooltipProvider>

            <Button
              size="sm"
              onClick={() => setTriggerModalOpen(true)}
              className="h-8 gap-1.5"
            >
              <Play className="size-3.5" weight="fill" />
              <span>Trigger Run</span>
            </Button>
          </div>
        }
      />

      <Tabs defaultValue="runs" className="w-full space-y-5">
        <TabsList className="border border-zinc-800 bg-zinc-900/60 p-1">
          <TabsTrigger value="runs" className="text-xs transition-colors">
            Execution Runs ({runs.length})
          </TabsTrigger>
          <TabsTrigger value="definition" className="text-xs transition-colors">
            YAML Definition
          </TabsTrigger>
        </TabsList>

        {/* RUNS TAB */}
        <TabsContent value="runs" className="space-y-4">
          {runs.length === 0 ? (
            <EmptyState
              icon={Clock}
              title="No execution runs recorded"
              description="Trigger a manual run or push commits to trigger this workflow."
              actionNode={
                <Button
                  size="sm"
                  onClick={() => setTriggerModalOpen(true)}
                  className="gap-1.5"
                >
                  <Play className="size-3.5" weight="fill" />
                  <span>Trigger First Run</span>
                </Button>
              }
            />
          ) : (
            <div className="border-border/80 bg-card overflow-hidden rounded-lg border">
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow className="hover:bg-transparent">
                      <TableHead className="w-[120px]">Status</TableHead>
                      <TableHead>Commit SHA</TableHead>
                      <TableHead>Branch</TableHead>
                      <TableHead>Trigger</TableHead>
                      <TableHead>Steps Progress</TableHead>
                      <TableHead>Started</TableHead>
                      <TableHead className="text-right">Action</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {runs.map((run) => {
                      const completedSteps = run.steps.filter(
                        (s) => s.status === "completed",
                      ).length;
                      const hasBlocked = run.steps.some(
                        (s) =>
                          s.step_kind === "approval_gate" &&
                          s.status === "blocked",
                      );

                      return (
                        <TableRow
                          key={run.id}
                          onClick={() => openRunSheet(run)}
                          className="hover:bg-muted/40 cursor-pointer transition-colors"
                        >
                          <TableCell>
                            <StatusBadge status={run.status} size="sm" />
                          </TableCell>

                          <TableCell className="font-mono text-xs font-medium text-zinc-200">
                            {run.git_commit.slice(0, 7)}
                          </TableCell>

                          <TableCell>
                            <div className="flex items-center gap-1.5 font-mono text-xs text-zinc-300">
                              <GitBranch className="size-3 text-zinc-500" />
                              <span>{run.git_branch}</span>
                            </div>
                          </TableCell>

                          <TableCell className="font-mono text-xs text-zinc-400 capitalize">
                            {run.trigger_event}
                          </TableCell>

                          <TableCell>
                            <div className="flex items-center gap-2">
                              <span className="font-mono text-xs text-zinc-300">
                                {completedSteps} / {run.steps.length}
                              </span>
                              {hasBlocked && (
                                <Badge
                                  variant="outline"
                                  className="border-amber-500/40 bg-amber-500/10 font-mono text-[10px] text-amber-400"
                                >
                                  Approval Needed
                                </Badge>
                              )}
                            </div>
                          </TableCell>

                          <TableCell className="font-mono text-xs text-zinc-400">
                            {run.started_at
                              ? new Date(run.started_at).toLocaleTimeString(
                                  [],
                                  {
                                    hour: "2-digit",
                                    minute: "2-digit",
                                    second: "2-digit",
                                  },
                                )
                              : "--"}
                          </TableCell>

                          <TableCell className="text-right">
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={(e) => {
                                e.stopPropagation();
                                openRunSheet(run);
                              }}
                              className="h-7 text-xs"
                            >
                              <span>Inspect</span>
                              <CaretRight className="ml-1 size-3" />
                            </Button>
                          </TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              </div>
            </div>
          )}
        </TabsContent>

        {/* DEFINITION TAB */}
        <TabsContent value="definition" className="space-y-4">
          <Card className="border-zinc-800 bg-[#09090b]">
            <CardHeader className="flex flex-row items-center justify-between border-b border-zinc-800 pb-4">
              <div>
                <CardTitle className="text-sm font-semibold text-zinc-100">
                  Pipeline Configuration (YAML)
                </CardTitle>
                <CardDescription className="text-xs text-zinc-400">
                  Version controlled pipeline declaration.
                </CardDescription>
              </div>
              <div className="flex items-center gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    navigator.clipboard.writeText(workflow.definition);
                    toast.success("YAML copied to clipboard");
                  }}
                  className="h-7 text-xs text-zinc-300"
                >
                  Copy YAML
                </Button>
                {isEditingYaml ? (
                  <div className="flex items-center gap-2">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => {
                        setYamlContent(workflow.definition);
                        setIsEditingYaml(false);
                      }}
                      disabled={isSavingYaml}
                      className="h-7 text-xs"
                    >
                      Cancel
                    </Button>
                    <Button
                      size="sm"
                      onClick={() => void handleSaveYaml()}
                      disabled={isSavingYaml}
                      className="h-7 gap-1 text-xs"
                    >
                      {isSavingYaml ? (
                        <BloomSpinner size={12} speed="fast" />
                      ) : (
                        <FloppyDisk className="size-3.5" />
                      )}
                      <span>Save Changes</span>
                    </Button>
                  </div>
                ) : (
                  <TooltipProvider>
                    <Tooltip>
                      <TooltipTrigger
                        className="inline-flex h-7 cursor-not-allowed items-center gap-1 rounded-md border border-zinc-800 px-3 text-xs opacity-50"
                        disabled
                      >
                        <PencilSimple className="size-3.5" />
                        <span>Edit YAML</span>
                      </TooltipTrigger>
                      <TooltipContent>
                        <p className="text-xs">
                          Not yet available: the backend has no workflow update
                          endpoint.
                        </p>
                      </TooltipContent>
                    </Tooltip>
                  </TooltipProvider>
                )}
              </div>
            </CardHeader>
            <CardContent className="p-0">
              {isEditingYaml ? (
                <Textarea
                  value={yamlContent}
                  onChange={(e) => setYamlContent(e.target.value)}
                  rows={20}
                  className="rounded-none border-0 bg-black font-mono text-xs leading-relaxed text-zinc-200 focus-visible:ring-0"
                />
              ) : (
                <pre className="overflow-x-auto bg-black p-4 font-mono text-xs leading-relaxed text-zinc-300">
                  <code>{workflow.definition}</code>
                </pre>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      {/* Slide-over Sheet for Workflow Run Details & Connected Steps Timeline */}
      <Sheet open={sheetOpen} onOpenChange={setSheetOpen}>
        <SheetContent
          side="right"
          className="w-full overflow-y-auto border-zinc-800 bg-[#09090b] text-zinc-100 sm:max-w-xl"
        >
          {selectedRun && (
            <div className="space-y-6 py-2">
              <SheetHeader>
                <div className="flex items-center justify-between gap-2">
                  <SheetTitle className="text-base font-semibold text-zinc-100">
                    Execution Run
                  </SheetTitle>
                  <StatusBadge status={selectedRun.status} size="sm" />
                </div>
                <SheetDescription className="font-mono text-xs text-zinc-400">
                  Commit{" "}
                  <strong className="text-zinc-200">
                    {selectedRun.git_commit}
                  </strong>{" "}
                  on branch{" "}
                  <strong className="text-zinc-200">
                    {selectedRun.git_branch}
                  </strong>
                </SheetDescription>
              </SheetHeader>

              {/* Execution Summary Metadata Card */}
              <div className="grid grid-cols-2 gap-3 rounded-lg border border-zinc-800 bg-zinc-950 p-3 font-mono text-xs">
                <div>
                  <span className="text-[11px] text-zinc-500">
                    Trigger Event
                  </span>
                  <p className="font-semibold text-zinc-200 capitalize">
                    {selectedRun.trigger_event}
                  </p>
                </div>
                <div>
                  <span className="text-[11px] text-zinc-500">Started At</span>
                  <p className="text-zinc-200">
                    {selectedRun.started_at
                      ? new Date(selectedRun.started_at).toLocaleString()
                      : "--"}
                  </p>
                </div>
                <div>
                  <span className="text-[11px] text-zinc-500">Finished At</span>
                  <p className="text-zinc-200">
                    {selectedRun.finished_at
                      ? new Date(selectedRun.finished_at).toLocaleString()
                      : "In progress / Pending"}
                  </p>
                </div>
                <div>
                  <span className="text-[11px] text-zinc-500">Approved By</span>
                  <p className="text-zinc-200">
                    {selectedRun.approved_by || "None"}
                  </p>
                </div>
              </div>

              {/* Connected Step Timeline */}
              <div className="space-y-4">
                <h3 className="text-xs font-semibold tracking-wider text-zinc-400 uppercase">
                  Execution Steps Timeline
                </h3>

                <div className="relative space-y-6 before:absolute before:top-3 before:bottom-3 before:left-[17px] before:w-0.5 before:bg-zinc-800">
                  {selectedRun.steps.map((step) => {
                    const isGateBlocked =
                      step.step_kind === "approval_gate" &&
                      step.status === "blocked";
                    const isCompleted = step.status === "completed";
                    const isRunning = step.status === "running";
                    const isFailed = step.status === "failed";

                    return (
                      <div
                        key={step.id}
                        className="relative flex items-start gap-4"
                      >
                        {/* Step Marker Node */}
                        <div
                          className={`relative z-10 flex size-9 shrink-0 items-center justify-center rounded-full border font-mono text-xs font-bold transition-all ${
                            isCompleted
                              ? "border-emerald-500/50 bg-emerald-950/40 text-emerald-400"
                              : isRunning
                                ? "border-blue-500/50 bg-blue-950/40 text-blue-400 shadow-[0_0_12px_rgba(59,130,246,0.35)]"
                                : isGateBlocked
                                  ? "animate-pulse border-amber-500 bg-amber-950 text-amber-400 shadow-[0_0_12px_rgba(245,158,11,0.35)]"
                                  : isFailed
                                    ? "border-red-500/50 bg-red-950/40 text-red-400"
                                    : "border-zinc-800 bg-zinc-950 text-zinc-500"
                          }`}
                        >
                          {isCompleted ? (
                            <CheckCircle className="size-4.5" weight="bold" />
                          ) : isRunning ? (
                            <BloomSpinner size={16} speed="fast" />
                          ) : isGateBlocked ? (
                            <WarningCircle className="size-4.5" weight="fill" />
                          ) : isFailed ? (
                            <XCircle className="size-4.5" weight="bold" />
                          ) : (
                            <span>{step.step_order}</span>
                          )}
                        </div>

                        {/* Step Content Card */}
                        <div
                          className={`flex-1 rounded-lg border p-3.5 transition-colors ${
                            isGateBlocked
                              ? "border-amber-500/50 bg-amber-950/20 ring-1 ring-amber-500/20"
                              : "border-zinc-800/80 bg-zinc-900/40"
                          }`}
                        >
                          <div className="flex items-start justify-between gap-3">
                            <div className="space-y-1">
                              <div className="flex flex-wrap items-center gap-2">
                                <span className="text-xs font-semibold text-zinc-100">
                                  {step.name}
                                </span>
                                <Badge
                                  variant="outline"
                                  className="font-mono text-[9px] tracking-wider text-zinc-400 uppercase"
                                >
                                  {step.step_kind.replace("_", " ")}
                                </Badge>
                              </div>
                            </div>

                            <StatusBadge status={step.status} size="sm" />
                          </div>

                          {/* Log Preview */}
                          {step.log_snippet && (
                            <div className="mt-3 overflow-hidden rounded border border-zinc-800 bg-black">
                              <div className="flex items-center gap-1.5 border-b border-zinc-800/80 bg-zinc-950 px-2.5 py-1 text-[10px] text-zinc-500">
                                <TerminalWindow className="size-3" />
                                <span>Step Output</span>
                              </div>
                              <pre className="max-h-44 overflow-y-auto p-2.5 font-mono text-[11px] leading-relaxed whitespace-pre-wrap text-zinc-300">
                                {step.log_snippet}
                              </pre>
                            </div>
                          )}

                          {/* Approval Gate Decision Controls */}
                          {isGateBlocked && (
                            <div className="mt-4 space-y-3 border-t border-amber-500/20 pt-3">
                              <div className="flex items-center gap-2 text-xs font-medium text-amber-400">
                                <WarningCircle
                                  className="size-4"
                                  weight="fill"
                                />
                                <span>
                                  Manual approval required to continue release
                                  rollout.
                                </span>
                              </div>

                              <div className="space-y-1.5">
                                <Label
                                  htmlFor="appr-reason"
                                  className="text-[11px] text-zinc-400"
                                >
                                  Decision Note / Reason (Optional)
                                </Label>
                                <Input
                                  id="appr-reason"
                                  placeholder="e.g. QA signoff verified on staging"
                                  value={approvalReason}
                                  onChange={(e) =>
                                    setApprovalReason(e.target.value)
                                  }
                                  className="h-8 border-zinc-800 bg-zinc-950 text-xs"
                                />
                              </div>

                              <div className="flex items-center justify-end gap-2 pt-1">
                                {/* Reject Confirmation */}
                                <AlertDialog>
                                  <AlertDialogTrigger className="inline-flex h-7 items-center justify-center rounded-md border border-red-500/40 bg-red-950/40 px-3 text-xs font-medium text-red-300 transition-colors hover:bg-red-900/50">
                                    <XCircle className="mr-1 size-3.5" />
                                    Reject & Stop
                                  </AlertDialogTrigger>
                                  <AlertDialogContent className="border-zinc-800 bg-zinc-950 text-zinc-100">
                                    <AlertDialogHeader>
                                      <AlertDialogTitle>
                                        Reject this workflow run?
                                      </AlertDialogTitle>
                                      <AlertDialogDescription className="text-zinc-400">
                                        This will immediately terminate
                                        execution and abort any downstream
                                        deployments.
                                      </AlertDialogDescription>
                                    </AlertDialogHeader>
                                    <AlertDialogFooter>
                                      <AlertDialogCancel className="border-zinc-700 bg-zinc-800 text-zinc-200">
                                        Cancel
                                      </AlertDialogCancel>
                                      <AlertDialogAction
                                        disabled={isSubmittingApproval}
                                        onClick={() =>
                                          void handleApproveOrReject(
                                            selectedRun.id,
                                            false,
                                          )
                                        }
                                        className="bg-red-600 text-white hover:bg-red-700"
                                      >
                                        Confirm Rejection
                                      </AlertDialogAction>
                                    </AlertDialogFooter>
                                  </AlertDialogContent>
                                </AlertDialog>

                                {/* Approve Confirmation */}
                                <AlertDialog>
                                  <AlertDialogTrigger className="inline-flex h-7 items-center justify-center rounded-md bg-emerald-600 px-3 text-xs font-medium text-white transition-colors hover:bg-emerald-700">
                                    <CheckCircle
                                      className="mr-1 size-3.5"
                                      weight="bold"
                                    />
                                    Approve & Resume
                                  </AlertDialogTrigger>
                                  <AlertDialogContent className="border-zinc-800 bg-zinc-950 text-zinc-100">
                                    <AlertDialogHeader>
                                      <AlertDialogTitle>
                                        Approve release gate?
                                      </AlertDialogTitle>
                                      <AlertDialogDescription className="text-zinc-400">
                                        Approving will trigger the downstream
                                        production deployment to store tracks.
                                      </AlertDialogDescription>
                                    </AlertDialogHeader>
                                    <AlertDialogFooter>
                                      <AlertDialogCancel className="border-zinc-700 bg-zinc-800 text-zinc-200">
                                        Cancel
                                      </AlertDialogCancel>
                                      <AlertDialogAction
                                        disabled={isSubmittingApproval}
                                        onClick={() =>
                                          void handleApproveOrReject(
                                            selectedRun.id,
                                            true,
                                          )
                                        }
                                        className="bg-emerald-600 text-white hover:bg-emerald-700"
                                      >
                                        Authorize Deployment
                                      </AlertDialogAction>
                                    </AlertDialogFooter>
                                  </AlertDialogContent>
                                </AlertDialog>
                              </div>
                            </div>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          )}
        </SheetContent>
      </Sheet>

      {/* Trigger Run Dialog */}
      <Dialog open={triggerModalOpen} onOpenChange={setTriggerModalOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Trigger Workflow Execution</DialogTitle>
            <DialogDescription>
              Start an on-demand run of &quot;{workflow.name}&quot;.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4 py-3">
            <div className="space-y-1.5">
              <Label htmlFor="det-trig-branch">Git Branch</Label>
              <Input
                id="det-trig-branch"
                value={triggerBranch}
                onChange={(e) => setTriggerBranch(e.target.value)}
                placeholder="main"
                className="font-mono text-xs"
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="det-trig-commit">Commit SHA (Optional)</Label>
              <Input
                id="det-trig-commit"
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
              onClick={() => setTriggerModalOpen(false)}
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
