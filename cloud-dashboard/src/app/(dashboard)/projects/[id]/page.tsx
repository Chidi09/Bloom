"use client";

import * as React from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import {
  Plus,
  ArrowSquareOut,
  Clock,
  GitBranch,
  GitFork,
  Trash,
  Pulse,
  DeviceMobile,
  ArrowsClockwise,
  Gear,
  Hammer,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
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
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { PageHeader } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import { PlatformIcon } from "@/components/status/platform-icon";
import { api } from "@/lib/api/client";
import { ProjectResponse } from "@/lib/schemas/project";
import { AppResponse } from "@/lib/schemas/app";
import { useOrganizationEvents } from "@/lib/hooks/use-organization-events";
import { useOrganizationStore } from "@/stores/organization-store";

export default function ProjectDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const projectId = params.id;
  const { currentOrganizationId } = useOrganizationStore();

  useOrganizationEvents(currentOrganizationId);

  const [project, setProject] = React.useState<ProjectResponse | null>(null);
  const [apps, setApps] = React.useState<AppResponse[]>([]);
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // New App Dialog State
  const [createAppOpen, setCreateAppOpen] = React.useState(false);
  const [newAppName, setNewAppName] = React.useState("");
  const [newAppRepo, setNewAppRepo] = React.useState("");
  const [newAppBranch, setNewAppBranch] = React.useState("main");
  const [isCreatingApp, setIsCreatingApp] = React.useState(false);

  // Delete Project State
  const [deleteConfirmSlug, setDeleteConfirmSlug] = React.useState("");
  const [isDeleting, setIsDeleting] = React.useState(false);

  const fetchProjectData = React.useCallback(async () => {
    if (!projectId) return;
    setIsLoading(true);
    setError(null);
    try {
      const [prjRes, appsRes] = await Promise.all([
        api.get<ProjectResponse>(`/projects/${projectId}`),
        api.get<{ results: AppResponse[] }>("/apps", {
          params: { project_id: projectId },
        }),
      ]);
      setProject(prjRes);
      setApps(appsRes?.results ?? []);
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Failed to load project details",
      );
    } finally {
      setIsLoading(false);
    }
  }, [projectId]);

  React.useEffect(() => {
    const run = async () => {
      await fetchProjectData();
    };
    void run();
  }, [fetchProjectData]);

  const handleCreateApp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newAppName.trim() || !project) return;

    setIsCreatingApp(true);
    try {
      const created = await api.post<AppResponse>("/apps", {
        project_id: project.id,
        name: newAppName.trim(),
        repository_url: newAppRepo.trim() || undefined,
        default_branch: newAppBranch.trim() || "main",
      });
      toast.success("App created successfully");
      setCreateAppOpen(false);
      setNewAppName("");
      setNewAppRepo("");
      setNewAppBranch("main");
      await fetchProjectData();
      router.push(`/apps/${created.id}/builds`);
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Failed to create app");
    } finally {
      setIsCreatingApp(false);
    }
  };

  const handleDeleteProject = async () => {
    if (!project || deleteConfirmSlug !== project.slug) return;
    setIsDeleting(true);
    try {
      await api.delete(`/projects/${project.id}`);
      toast.success("Project deleted");
      router.push("/projects");
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to delete project",
      );
      setIsDeleting(false);
    }
  };

  if (isLoading) {
    return (
      <div className="mx-auto flex max-w-6xl items-center justify-center py-12">
        <BloomSpinner size={32} label="Loading project details..." />
      </div>
    );
  }

  if (error || !project) {
    return (
      <div className="mx-auto max-w-6xl space-y-4">
        <Alert variant="destructive">
          <AlertTitle>Failed to load project</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error || "Project not found"}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchProjectData()}
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      </div>
    );
  }

  // Simulated recent activity for this project
  const recentActivities = [
    {
      id: "act_1",
      icon: GitFork,
      text: `App repository linked to ${project.name}`,
      timestamp: "10m ago",
    },
    {
      id: "act_2",
      icon: Clock,
      text: "Automated cloud build finished with status success",
      timestamp: "1h ago",
    },
    {
      id: "act_3",
      icon: Pulse,
      text: `Project created with ${apps.length} configured targets`,
      timestamp: "2d ago",
    },
  ];

  return (
    <div className="mx-auto max-w-6xl space-y-5">
      <PageHeader
        breadcrumbs={[
          { label: "Projects", href: "/projects" },
          { label: project.name },
        ]}
        title={project.name}
        description={project.description || `Slug: ${project.slug}`}
        badge={
          <Badge variant="outline" className="font-mono text-xs">
            {apps.length} {apps.length === 1 ? "App" : "Apps"}
          </Badge>
        }
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchProjectData()}
              className="h-8 gap-1.5 transition-colors"
            >
              <ArrowsClockwise className="size-3.5" />
              <span>Refresh</span>
            </Button>
            <Button
              size="sm"
              onClick={() => setCreateAppOpen(true)}
              className="h-8 gap-1.5"
            >
              <Plus className="size-3.5" weight="bold" />
              <span>New App</span>
            </Button>
          </div>
        }
      />

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
        {/* Left 8 Cols: Apps Table */}
        <div className="space-y-3 lg:col-span-8">
          <div className="flex items-center justify-between">
            <h2 className="text-foreground text-sm font-semibold">
              Project Applications
            </h2>
          </div>

          {apps.length === 0 ? (
            <EmptyState
              icon={DeviceMobile}
              title="No apps in this project"
              description="Add your first Bloom mobile or web app to this project."
              actionLabel="Create App"
              onAction={() => setCreateAppOpen(true)}
            />
          ) : (
            <div className="border-border/80 bg-card overflow-hidden rounded-lg border shadow-xs">
              <div className="overflow-x-auto">
                <TooltipProvider>
                  <Table>
                    <TableHeader>
                      <TableRow className="hover:bg-transparent">
                        <TableHead className="w-[240px]">Application</TableHead>
                        <TableHead>Branch</TableHead>
                        <TableHead>Repository</TableHead>
                        <TableHead>Updated</TableHead>
                        <TableHead className="w-[100px] text-right">
                          Quick Actions
                        </TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {apps.map((app) => (
                        <TableRow
                          key={app.id}
                          onClick={() => router.push(`/apps/${app.id}/builds`)}
                          className="hover:bg-muted/40 group cursor-pointer transition-colors duration-150"
                        >
                          <TableCell>
                            <div className="flex items-center gap-3">
                              <div className="border-border/80 bg-muted/50 text-foreground group-hover:border-primary/40 flex size-8 shrink-0 items-center justify-center rounded-md border shadow-xs transition-colors">
                                <PlatformIcon platform="all" size="sm" />
                              </div>
                              <div className="space-y-0.5">
                                <span className="text-foreground group-hover:text-primary block text-xs font-semibold transition-colors">
                                  {app.name}
                                </span>
                                <span className="text-muted-foreground block font-mono text-[10px]">
                                  {app.slug}
                                </span>
                              </div>
                            </div>
                          </TableCell>

                          <TableCell>
                            <Badge
                              variant="secondary"
                              className="bg-muted/60 text-foreground border-border/40 gap-1 px-1.5 py-0 font-mono text-[10px]"
                            >
                              <GitBranch className="size-3" />
                              <span>{app.default_branch || "main"}</span>
                            </Badge>
                          </TableCell>

                          <TableCell>
                            {app.repository_url ? (
                              <Link
                                href={app.repository_url}
                                target="_blank"
                                onClick={(e) => e.stopPropagation()}
                                className="text-muted-foreground hover:text-foreground inline-flex items-center gap-1 font-mono text-xs transition-colors"
                              >
                                <span className="max-w-[140px] truncate">
                                  {app.repository_url.replace(
                                    "https://github.com/",
                                    "",
                                  )}
                                </span>
                                <ArrowSquareOut className="size-3 shrink-0" />
                              </Link>
                            ) : (
                              <span className="text-muted-foreground font-mono text-xs italic">
                                None
                              </span>
                            )}
                          </TableCell>

                          <TableCell className="text-muted-foreground font-mono text-xs">
                            {new Date(app.updated_at).toLocaleDateString()}
                          </TableCell>

                          <TableCell
                            className="text-right"
                            onClick={(e) => e.stopPropagation()}
                          >
                            <div className="flex items-center justify-end gap-1 opacity-0 transition-opacity duration-150 group-hover:opacity-100">
                              <Tooltip>
                                <TooltipTrigger
                                  className="text-muted-foreground hover:text-foreground inline-flex size-7 items-center justify-center rounded-md p-0"
                                  onClick={() =>
                                    router.push(`/apps/${app.id}/builds`)
                                  }
                                >
                                  <Hammer className="size-3.5" />
                                  <span className="sr-only">Builds</span>
                                </TooltipTrigger>
                                <TooltipContent>
                                  <p className="text-xs">Builds & Pipeline</p>
                                </TooltipContent>
                              </Tooltip>

                              <Tooltip>
                                <TooltipTrigger
                                  className="text-muted-foreground hover:text-foreground inline-flex size-7 items-center justify-center rounded-md p-0"
                                  onClick={() =>
                                    router.push(`/apps/${app.id}/settings`)
                                  }
                                >
                                  <Gear className="size-3.5" />
                                  <span className="sr-only">App Settings</span>
                                </TooltipTrigger>
                                <TooltipContent>
                                  <p className="text-xs">App Settings</p>
                                </TooltipContent>
                              </Tooltip>
                            </div>
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </TooltipProvider>
              </div>
            </div>
          )}
        </div>

        {/* Right 4 Cols: Project Info & Activity Feed */}
        <div className="space-y-4 lg:col-span-4">
          <Card className="border-border/80 bg-card shadow-xs">
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-semibold">
                Recent Activity
              </CardTitle>
              <CardDescription className="text-xs">
                Real-time project event timeline.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <ScrollArea className="h-44 pr-3">
                <div className="space-y-3">
                  {recentActivities.map((act) => {
                    const Icon = act.icon;
                    return (
                      <div
                        key={act.id}
                        className="flex items-start gap-2.5 text-xs"
                      >
                        <div className="border-border/80 bg-muted/50 text-muted-foreground mt-0.5 flex size-6 shrink-0 items-center justify-center rounded-full border">
                          <Icon className="size-3" />
                        </div>
                        <div className="flex-1 space-y-0.5">
                          <p className="text-foreground leading-snug">
                            {act.text}
                          </p>
                          <span className="text-muted-foreground block font-mono text-[10px]">
                            {act.timestamp}
                          </span>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </ScrollArea>
            </CardContent>
          </Card>

          {/* Delete Project Card */}
          <Card className="border-destructive/30 bg-destructive/5">
            <CardHeader className="pb-2">
              <CardTitle className="text-destructive text-xs font-semibold">
                Delete Project
              </CardTitle>
              <CardDescription className="text-[11px]">
                Remove &quot;{project.name}&quot; and dissociate all nested
                apps.
              </CardDescription>
            </CardHeader>
            <CardContent className="pt-0">
              <AlertDialog>
                <AlertDialogTrigger className="bg-destructive text-destructive-foreground hover:bg-destructive/90 inline-flex h-7 w-full cursor-pointer items-center justify-center gap-1.5 rounded-md px-3 py-1.5 text-xs font-medium">
                  <Trash className="size-3" />
                  <span>Delete Project</span>
                </AlertDialogTrigger>
                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle>Delete {project.name}?</AlertDialogTitle>
                    <AlertDialogDescription className="space-y-2">
                      <p>
                        This action cannot be undone. All apps in this project
                        will be deleted.
                      </p>
                      <p className="text-foreground">
                        Type{" "}
                        <strong className="text-primary font-mono">
                          {project.slug}
                        </strong>{" "}
                        to confirm:
                      </p>
                      <Input
                        placeholder={project.slug}
                        value={deleteConfirmSlug}
                        onChange={(e) => setDeleteConfirmSlug(e.target.value)}
                        className="font-mono text-xs"
                      />
                    </AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel onClick={() => setDeleteConfirmSlug("")}>
                      Cancel
                    </AlertDialogCancel>
                    <AlertDialogAction
                      disabled={
                        deleteConfirmSlug !== project.slug || isDeleting
                      }
                      onClick={handleDeleteProject}
                      className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                    >
                      {isDeleting ? (
                        <BloomSpinner size={14} speed="fast" className="mr-2" />
                      ) : null}
                      Delete Project
                    </AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
            </CardContent>
          </Card>
        </div>
      </div>

      {/* Create App in Project Dialog */}
      <Dialog open={createAppOpen} onOpenChange={setCreateAppOpen}>
        <DialogContent className="sm:max-w-md">
          <form onSubmit={handleCreateApp}>
            <DialogHeader>
              <DialogTitle>Add App to {project.name}</DialogTitle>
              <DialogDescription>
                Create a new Bloom application inside this project.
              </DialogDescription>
            </DialogHeader>

            <div className="space-y-4 py-4">
              <div className="space-y-2">
                <Label htmlFor="app-name">App Name</Label>
                <Input
                  id="app-name"
                  placeholder="e.g. mobile_client"
                  value={newAppName}
                  onChange={(e) => setNewAppName(e.target.value)}
                  autoFocus
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="app-repo">Git Repository URL (optional)</Label>
                <Input
                  id="app-repo"
                  type="url"
                  placeholder="https://github.com/my-org/my-app"
                  value={newAppRepo}
                  onChange={(e) => setNewAppRepo(e.target.value)}
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="app-branch">Default Branch</Label>
                <Input
                  id="app-branch"
                  value={newAppBranch}
                  onChange={(e) => setNewAppBranch(e.target.value)}
                />
              </div>
            </div>

            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => setCreateAppOpen(false)}
                disabled={isCreatingApp}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                disabled={isCreatingApp || !newAppName.trim()}
              >
                {isCreatingApp ? (
                  <BloomSpinner size={16} speed="fast" className="mr-2" />
                ) : null}
                Create Application
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
