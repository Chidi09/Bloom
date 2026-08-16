"use client";

import * as React from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  MagnifyingGlass,
  Plus,
  ArrowSquareOut,
  GitBranch,
  DeviceMobile,
  LinkSimple,
  ArrowsClockwise,
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
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { PageHeader } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import { PlatformIcon } from "@/components/status/platform-icon";
import { StatusBadge } from "@/components/status/status-badge";
import { api } from "@/lib/api/client";
import { AppResponse } from "@/lib/schemas/app";
import { ProjectResponse } from "@/lib/schemas/project";
import { useOrganizationStore } from "@/stores/organization-store";

export default function AppsPage() {
  const router = useRouter();
  const { currentOrganizationId } = useOrganizationStore();

  const [apps, setApps] = React.useState<AppResponse[]>([]);
  const [projects, setProjects] = React.useState<ProjectResponse[]>([]);
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Filters & Search
  const [searchQuery, setSearchQuery] = React.useState("");
  const [platformFilter, setPlatformFilter] = React.useState<string>("all");
  const [projectFilter, setProjectFilter] = React.useState<string>("all");

  // Create Modal State
  const [createDialogOpen, setCreateDialogOpen] = React.useState(false);
  const [createTab, setCreateTab] = React.useState<"blank" | "link">("blank");
  const [selectedProjectId, setSelectedProjectId] = React.useState("");
  const [appName, setAppName] = React.useState("");
  const [appRepo, setAppRepo] = React.useState("");
  const [appBranch, setAppBranch] = React.useState("main");

  // Link Repo State
  const [linkProjectSlug, setLinkProjectSlug] = React.useState("");
  const [linkAppSlug, setLinkAppSlug] = React.useState("");
  const [isSubmitting, setIsSubmitting] = React.useState(false);

  const fetchAppsData = React.useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const [appsRes, prjRes] = await Promise.all([
        api.get<{ results: AppResponse[] }>("/apps"),
        api.get<{ results: ProjectResponse[] }>("/projects"),
      ]);
      setApps(appsRes?.results ?? []);
      setProjects(prjRes?.results ?? []);
      if (prjRes?.results?.length && !selectedProjectId) {
        setSelectedProjectId(prjRes.results[0].id);
        setLinkProjectSlug(prjRes.results[0].slug);
      }
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to load apps");
    } finally {
      setIsLoading(false);
    }
  }, [selectedProjectId]);

  React.useEffect(() => {
    const run = async () => {
      await fetchAppsData();
    };
    void run();
  }, [fetchAppsData, currentOrganizationId]);

  const handleCreateBlankApp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!appName.trim() || !selectedProjectId) return;

    setIsSubmitting(true);
    try {
      const created = await api.post<AppResponse>("/apps", {
        project_id: selectedProjectId,
        name: appName.trim(),
        repository_url: appRepo.trim() || undefined,
        default_branch: appBranch.trim() || "main",
      });
      toast.success("App created successfully");
      setCreateDialogOpen(false);
      setAppName("");
      setAppRepo("");
      setAppBranch("main");
      await fetchAppsData();
      router.push(`/apps/${created.id}/builds`);
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Failed to create app");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleLinkRepo = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!linkAppSlug.trim() || !linkProjectSlug.trim()) return;

    setIsSubmitting(true);
    try {
      const linked = await api.post<AppResponse>("/apps/link", {
        project_slug: linkProjectSlug.trim(),
        app_slug: linkAppSlug.trim(),
      });
      toast.success("Repository linked successfully");
      setCreateDialogOpen(false);
      setLinkAppSlug("");
      await fetchAppsData();
      router.push(`/apps/${linked.id}/builds`);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to link repository",
      );
    } finally {
      setIsSubmitting(false);
    }
  };

  const filteredApps = apps.filter((app) => {
    const matchesSearch =
      app.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      app.slug.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (app.repository_url &&
        app.repository_url.toLowerCase().includes(searchQuery.toLowerCase()));

    const matchesProject =
      projectFilter === "all" ? true : app.project_id === projectFilter;

    return matchesSearch && matchesProject;
  });

  const getProjectName = (projectId: string) => {
    const prj = projects.find((p) => p.id === projectId);
    return prj ? prj.name : "Unknown Project";
  };

  return (
    <div className="mx-auto max-w-6xl space-y-5">
      <PageHeader
        breadcrumbs={[{ label: "Applications" }]}
        title="Applications"
        description="Build, test, sign, and deploy Bloom and Flutter applications across Mobile, Web, and Desktop."
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchAppsData()}
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
              <span>New App</span>
            </Button>
          </div>
        }
      />

      {/* Toolbar: Search & Filters */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="relative max-w-sm flex-1">
          <MagnifyingGlass className="text-muted-foreground absolute top-2.5 left-3 size-3.5" />
          <Input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search applications..."
            className="h-8 pl-8 text-xs"
          />
        </div>

        <div className="flex flex-wrap items-center gap-2">
          {/* Project Filter */}
          <Select
            value={projectFilter}
            onValueChange={(val) => {
              if (val) setProjectFilter(val);
            }}
          >
            <SelectTrigger className="h-8 w-40 font-mono text-xs">
              <SelectValue placeholder="All Projects" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all" className="font-mono text-xs">
                All Projects
              </SelectItem>
              {projects.map((p) => (
                <SelectItem
                  key={p.id}
                  value={p.id}
                  className="font-mono text-xs"
                >
                  {p.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>

          {/* Platform Filter */}
          <Select
            value={platformFilter}
            onValueChange={(val) => {
              if (val) setPlatformFilter(val);
            }}
          >
            <SelectTrigger className="h-8 w-36 font-mono text-xs">
              <SelectValue placeholder="All Platforms" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all" className="font-mono text-xs">
                All Platforms
              </SelectItem>
              <SelectItem value="ios" className="font-mono text-xs">
                iOS
              </SelectItem>
              <SelectItem value="android" className="font-mono text-xs">
                Android
              </SelectItem>
              <SelectItem value="web" className="font-mono text-xs">
                Web
              </SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertTitle>Error loading applications</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchAppsData()}
              className="h-7 text-xs"
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      )}

      {isLoading ? (
        <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-16">
          <BloomSpinner size={28} label="Loading applications..." />
        </div>
      ) : filteredApps.length === 0 ? (
        <EmptyState
          icon={DeviceMobile}
          title="No applications found"
          description={
            apps.length === 0
              ? "Create or link your first application to trigger cloud builds and automate releases."
              : "No applications match your filter criteria."
          }
          actionLabel={apps.length === 0 ? "Create App" : undefined}
          onAction={() => setCreateDialogOpen(true)}
        />
      ) : (
        <div className="border-border/80 bg-card overflow-hidden rounded-lg border shadow-xs">
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="w-[300px]">Application</TableHead>
                  <TableHead>Project</TableHead>
                  <TableHead>Branch</TableHead>
                  <TableHead>Repository</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Updated</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredApps.map((app) => (
                  <TableRow
                    key={app.id}
                    onClick={() => router.push(`/apps/${app.id}/builds`)}
                    className="hover:bg-muted/40 group cursor-pointer transition-colors duration-150"
                  >
                    <TableCell>
                      <div className="flex items-center gap-3">
                        <div className="border-border/80 bg-muted/50 text-foreground flex size-8 shrink-0 items-center justify-center rounded-md border shadow-xs">
                          <PlatformIcon platform="all" size="md" />
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

                    <TableCell className="text-muted-foreground text-xs">
                      <span className="text-foreground font-medium">
                        {getProjectName(app.project_id)}
                      </span>
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
                          <span className="max-w-[150px] truncate">
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

                    <TableCell>
                      <StatusBadge status="healthy" size="sm" />
                    </TableCell>

                    <TableCell className="text-muted-foreground font-mono text-xs">
                      {new Date(app.updated_at).toLocaleDateString()}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        </div>
      )}

      {/* Create Application Dialog with Tabs: Blank vs Link */}
      <Dialog open={createDialogOpen} onOpenChange={setCreateDialogOpen}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>Add Application</DialogTitle>
            <DialogDescription>
              Create a new application or connect an existing Git repository.
            </DialogDescription>
          </DialogHeader>

          <Tabs
            value={createTab}
            onValueChange={(val) => setCreateTab(val as "blank" | "link")}
            className="w-full pt-2"
          >
            <TabsList className="grid w-full grid-cols-2">
              <TabsTrigger value="blank">Blank App</TabsTrigger>
              <TabsTrigger value="link">Link Existing Repo</TabsTrigger>
            </TabsList>

            {/* TAB 1: Blank App (POST /apps) */}
            <TabsContent value="blank" className="space-y-4 pt-4">
              <form onSubmit={handleCreateBlankApp} className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="create-project">Target Project</Label>
                  <Select
                    value={selectedProjectId}
                    onValueChange={(val) => {
                      if (val) setSelectedProjectId(val);
                    }}
                  >
                    <SelectTrigger
                      id="create-project"
                      className="font-mono text-xs"
                    >
                      <SelectValue placeholder="Select project" />
                    </SelectTrigger>
                    <SelectContent>
                      {projects.map((p) => (
                        <SelectItem
                          key={p.id}
                          value={p.id}
                          className="font-mono text-xs"
                        >
                          {p.name} ({p.slug})
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                <div className="space-y-2">
                  <Label htmlFor="create-app-name">App Name</Label>
                  <Input
                    id="create-app-name"
                    placeholder="e.g. mobile_checkout"
                    value={appName}
                    onChange={(e) => setAppName(e.target.value)}
                    required
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="create-app-repo">
                    Git Repository URL (optional)
                  </Label>
                  <Input
                    id="create-app-repo"
                    type="url"
                    placeholder="https://github.com/my-org/checkout"
                    value={appRepo}
                    onChange={(e) => setAppRepo(e.target.value)}
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="create-app-branch">Default Branch</Label>
                  <Input
                    id="create-app-branch"
                    value={appBranch}
                    onChange={(e) => setAppBranch(e.target.value)}
                  />
                </div>

                <DialogFooter className="pt-2">
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
                    disabled={
                      isSubmitting || !appName.trim() || !selectedProjectId
                    }
                  >
                    {isSubmitting ? (
                      <BloomSpinner size={16} speed="fast" className="mr-2" />
                    ) : null}
                    Create App
                  </Button>
                </DialogFooter>
              </form>
            </TabsContent>

            {/* TAB 2: Link Existing Repo (POST /apps/link) */}
            <TabsContent value="link" className="space-y-4 pt-4">
              <form onSubmit={handleLinkRepo} className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="link-project-slug">Project Slug</Label>
                  <Input
                    id="link-project-slug"
                    placeholder="e.g. mobile-suite"
                    value={linkProjectSlug}
                    onChange={(e) => setLinkProjectSlug(e.target.value)}
                    required
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="link-app-slug">Target App Slug</Label>
                  <Input
                    id="link-app-slug"
                    placeholder="e.g. bloom-wallet"
                    value={linkAppSlug}
                    onChange={(e) => setLinkAppSlug(e.target.value)}
                    required
                  />
                </div>

                <div className="border-border/80 bg-muted/20 text-muted-foreground flex items-center gap-2 rounded-lg border p-3 text-xs">
                  <LinkSimple className="text-primary size-4 shrink-0" />
                  <span>
                    Directly connects your CLI/Git workspace to the specified
                    project.
                  </span>
                </div>

                <DialogFooter className="pt-2">
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
                    disabled={
                      isSubmitting ||
                      !linkAppSlug.trim() ||
                      !linkProjectSlug.trim()
                    }
                  >
                    {isSubmitting ? (
                      <BloomSpinner size={16} speed="fast" className="mr-2" />
                    ) : null}
                    Link Repository
                  </Button>
                </DialogFooter>
              </form>
            </TabsContent>
          </Tabs>
        </DialogContent>
      </Dialog>
    </div>
  );
}
