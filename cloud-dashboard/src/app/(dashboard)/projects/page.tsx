"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import {
  Plus,
  FolderSimple,
  ArrowsClockwise,
  ArrowRight,
  DeviceMobile,
  Clock,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
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
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { PageHeader } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import { api } from "@/lib/api/client";
import { ProjectResponse } from "@/lib/schemas/project";
import { AppResponse } from "@/lib/schemas/app";
import { useOrganizationStore } from "@/stores/organization-store";

export default function ProjectsPage() {
  const router = useRouter();
  const { currentOrganizationId } = useOrganizationStore();

  const [projects, setProjects] = React.useState<ProjectResponse[]>([]);
  const [apps, setApps] = React.useState<AppResponse[]>([]);
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  const [createDialogOpen, setCreateDialogOpen] = React.useState(false);
  const [newProjectName, setNewProjectName] = React.useState("");
  const [newProjectDesc, setNewProjectDesc] = React.useState("");
  const [isCreating, setIsCreating] = React.useState(false);

  const fetchProjectsData = React.useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const [prjRes, appsRes] = await Promise.all([
        api.get<{ results: ProjectResponse[] }>("/projects"),
        api.get<{ results: AppResponse[] }>("/apps"),
      ]);
      setProjects(prjRes?.results ?? []);
      setApps(appsRes?.results ?? []);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to load projects");
    } finally {
      setIsLoading(false);
    }
  }, []);

  React.useEffect(() => {
    const run = async () => {
      await fetchProjectsData();
    };
    void run();
  }, [fetchProjectsData, currentOrganizationId]);

  const handleCreateProject = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newProjectName.trim()) return;

    setIsCreating(true);
    try {
      const created = await api.post<ProjectResponse>("/projects", {
        name: newProjectName.trim(),
        description: newProjectDesc.trim() || undefined,
      });
      toast.success("Project created successfully");
      setCreateDialogOpen(false);
      setNewProjectName("");
      setNewProjectDesc("");
      await fetchProjectsData();
      router.push(`/projects/${created.id}`);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to create project",
      );
    } finally {
      setIsCreating(false);
    }
  };

  const getAppsForProject = (projectId: string) => {
    return apps.filter((a) => a.project_id === projectId);
  };

  return (
    <div className="mx-auto max-w-6xl space-y-5">
      <PageHeader
        breadcrumbs={[{ label: "Projects" }]}
        title="Projects"
        description="Organize your Bloom mobile applications, web portals, and micro-frontends into logical projects."
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchProjectsData()}
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
              <span>New Project</span>
            </Button>
          </div>
        }
      />

      {error && (
        <Alert variant="destructive">
          <AlertTitle>Error loading projects</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchProjectsData()}
              className="h-7 text-xs"
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      )}

      {isLoading ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {[0, 1, 2].map((i) => (
            <div
              key={i}
              className="border-border/80 bg-card h-44 animate-pulse rounded-lg border p-5"
            />
          ))}
        </div>
      ) : projects.length === 0 ? (
        <EmptyState
          icon={FolderSimple}
          title="No projects yet"
          description="Create your first project to start grouping and managing related Bloom apps."
          actionLabel="Create Project"
          onAction={() => setCreateDialogOpen(true)}
        />
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {projects.map((project) => {
            const projectApps = getAppsForProject(project.id);
            return (
              <Card
                key={project.id}
                className="group border-border/80 bg-card hover:border-border hover:bg-muted/10 flex cursor-pointer flex-col justify-between shadow-xs transition-all duration-150"
                onClick={() => router.push(`/projects/${project.id}`)}
              >
                <CardHeader className="space-y-2 pb-2">
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex items-center gap-2.5">
                      <div className="border-border/80 bg-muted/50 text-foreground flex size-8 shrink-0 items-center justify-center rounded-md border shadow-xs">
                        <FolderSimple className="size-4" weight="bold" />
                      </div>
                      <div className="space-y-0.5">
                        <CardTitle className="text-foreground group-hover:text-primary text-sm font-semibold transition-colors">
                          {project.name}
                        </CardTitle>
                        <span className="text-muted-foreground block font-mono text-[11px]">
                          {project.slug}
                        </span>
                      </div>
                    </div>

                    <Badge
                      variant="outline"
                      className="bg-muted/30 gap-1 font-mono text-[10px]"
                    >
                      <DeviceMobile className="size-3" />
                      <span>
                        {projectApps.length}{" "}
                        {projectApps.length === 1 ? "app" : "apps"}
                      </span>
                    </Badge>
                  </div>

                  <CardDescription className="text-muted-foreground line-clamp-2 pt-0.5 text-xs leading-relaxed">
                    {project.description || "No description provided."}
                  </CardDescription>
                </CardHeader>

                <CardContent className="py-0">
                  {projectApps.length > 0 && (
                    <div className="flex flex-wrap gap-1.5 pt-1">
                      {projectApps.slice(0, 3).map((app) => (
                        <Badge
                          key={app.id}
                          variant="secondary"
                          className="bg-muted/60 text-foreground border-border/40 px-1.5 py-0 font-mono text-[10px]"
                        >
                          {app.name}
                        </Badge>
                      ))}
                      {projectApps.length > 3 && (
                        <span className="text-muted-foreground self-center font-mono text-[10px]">
                          +{projectApps.length - 3} more
                        </span>
                      )}
                    </div>
                  )}
                </CardContent>

                <CardFooter className="border-border/40 text-muted-foreground mt-4 flex items-center justify-between border-t pt-3 font-mono text-[11px]">
                  <div className="flex items-center gap-1.5">
                    <Clock className="size-3" />
                    <span>
                      Updated{" "}
                      {new Date(project.updated_at).toLocaleDateString()}
                    </span>
                  </div>

                  <span className="text-primary inline-flex items-center gap-1 font-medium transition-transform duration-150 group-hover:translate-x-0.5">
                    <span>Open</span>
                    <ArrowRight className="size-3" />
                  </span>
                </CardFooter>
              </Card>
            );
          })}
        </div>
      )}

      {/* Create Project Dialog */}
      <Dialog open={createDialogOpen} onOpenChange={setCreateDialogOpen}>
        <DialogContent className="sm:max-w-md">
          <form onSubmit={handleCreateProject}>
            <DialogHeader>
              <DialogTitle>Create Project</DialogTitle>
              <DialogDescription>
                Group your related Bloom mobile, web, and backend applications
                together.
              </DialogDescription>
            </DialogHeader>

            <div className="space-y-4 py-4">
              <div className="space-y-2">
                <Label htmlFor="prj-name">Project Name</Label>
                <Input
                  id="prj-name"
                  placeholder="e.g. Mobile Suite"
                  value={newProjectName}
                  onChange={(e) => setNewProjectName(e.target.value)}
                  autoFocus
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="prj-desc">Description (optional)</Label>
                <Textarea
                  id="prj-desc"
                  placeholder="Briefly describe what this project encompasses..."
                  value={newProjectDesc}
                  onChange={(e) => setNewProjectDesc(e.target.value)}
                  rows={3}
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
                disabled={isCreating || !newProjectName.trim()}
              >
                {isCreating ? (
                  <BloomSpinner size={16} speed="fast" className="mr-2" />
                ) : null}
                Create Project
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
