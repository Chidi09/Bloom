"use client";

import * as React from "react";
import { useParams, useRouter } from "next/navigation";
import {
  FloppyDisk,
  Trash,
  WarningOctagon,
  ArrowsClockwise,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
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
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { api } from "@/lib/api/client";
import { AppResponse } from "@/lib/schemas/app";

export default function AppSettingsPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const appId = params.id;

  const [app, setApp] = React.useState<AppResponse | null>(null);
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Form State
  const [name, setName] = React.useState("");
  const [repoUrl, setRepoUrl] = React.useState("");
  const [defaultBranch, setDefaultBranch] = React.useState("main");
  const [isSaving, setIsSaving] = React.useState(false);

  // Delete State
  const [deleteConfirmSlug, setDeleteConfirmSlug] = React.useState("");
  const [isDeleting, setIsDeleting] = React.useState(false);

  const fetchApp = React.useCallback(async () => {
    if (!appId) return;
    setIsLoading(true);
    setError(null);
    try {
      const appRes = await api.get<AppResponse>(`/apps/${appId}`);
      setApp(appRes);
      setName(appRes.name);
      setRepoUrl(appRes.repository_url || "");
      setDefaultBranch(appRes.default_branch || "main");
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Failed to load app settings",
      );
    } finally {
      setIsLoading(false);
    }
  }, [appId]);

  React.useEffect(() => {
    const run = async () => {
      await fetchApp();
    };
    void run();
  }, [fetchApp]);

  const handleSaveSettings = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!app) return;

    setIsSaving(true);
    try {
      const updated = await api.patch<AppResponse>(`/apps/${app.id}`, {
        name: name.trim(),
        repository_url: repoUrl.trim() || null,
        default_branch: defaultBranch.trim() || "main",
      });
      setApp(updated);
      toast.success("Application settings updated");
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to update settings",
      );
    } finally {
      setIsSaving(false);
    }
  };

  const handleDeleteApp = async () => {
    if (!app || deleteConfirmSlug !== app.slug) return;

    setIsDeleting(true);
    try {
      await api.delete(`/apps/${app.id}`);
      toast.success("Application deleted");
      router.push("/apps");
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to delete application",
      );
      setIsDeleting(false);
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <BloomSpinner size={28} label="Loading settings..." />
      </div>
    );
  }

  if (error || !app) {
    return (
      <Alert variant="destructive">
        <AlertTitle>Error loading settings</AlertTitle>
        <AlertDescription className="flex items-center justify-between">
          <span>{error || "App not found"}</span>
          <Button
            variant="outline"
            size="sm"
            onClick={() => void fetchApp()}
            className="h-7 text-xs"
          >
            Retry
          </Button>
        </AlertDescription>
      </Alert>
    );
  }

  return (
    <div className="max-w-4xl space-y-5">
      <Card className="border-border/80 bg-card shadow-xs">
        <form onSubmit={handleSaveSettings}>
          <CardHeader>
            <div className="flex items-center justify-between">
              <div>
                <CardTitle className="text-base font-semibold">
                  General Settings
                </CardTitle>
                <CardDescription>
                  Configure core metadata and repository connections for this
                  application.
                </CardDescription>
              </div>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => void fetchApp()}
                className="h-8 gap-1.5 transition-colors"
              >
                <ArrowsClockwise className="size-3.5" />
                <span>Refresh</span>
              </Button>
            </div>
          </CardHeader>

          <CardContent className="max-w-md space-y-4">
            <div className="space-y-1.5">
              <Label htmlFor="app-name">Application Name</Label>
              <Input
                id="app-name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                required
              />
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="app-slug">Slug</Label>
              <Input
                id="app-slug"
                value={app.slug}
                disabled
                className="bg-muted/30 font-mono text-xs"
              />
              <p className="text-muted-foreground text-[11px]">
                Unique identifier used for builds, CLI, and API calls.
              </p>
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="app-repo">Git Repository URL</Label>
              <Input
                id="app-repo"
                type="url"
                placeholder="https://github.com/org/repo"
                value={repoUrl}
                onChange={(e) => setRepoUrl(e.target.value)}
              />
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="app-branch">Default Git Branch</Label>
              <Input
                id="app-branch"
                value={defaultBranch}
                onChange={(e) => setDefaultBranch(e.target.value)}
                required
              />
            </div>
          </CardContent>

          <CardFooter className="border-border/60 flex justify-between border-t pt-4">
            <span className="text-muted-foreground font-mono text-xs">
              Created {new Date(app.created_at).toLocaleDateString()}
            </span>
            <Button
              type="submit"
              disabled={isSaving}
              size="sm"
              className="gap-1.5"
            >
              {isSaving ? (
                <BloomSpinner size={14} speed="fast" />
              ) : (
                <FloppyDisk className="size-3.5" />
              )}
              <span>Save Changes</span>
            </Button>
          </CardFooter>
        </form>
      </Card>

      {/* Danger Zone */}
      <Card className="border-destructive/30 bg-destructive/5 shadow-xs">
        <CardHeader>
          <div className="text-destructive flex items-center gap-2">
            <WarningOctagon className="size-5" />
            <CardTitle className="text-base font-semibold">
              Danger Zone
            </CardTitle>
          </div>
          <CardDescription>
            Permanently delete &quot;{app.name}&quot; and all build history,
            signing keys, and deployments.
          </CardDescription>
        </CardHeader>
        <CardFooter className="border-destructive/20 flex items-center justify-between border-t pt-4">
          <span className="text-muted-foreground text-xs">
            This action is irreversible.
          </span>
          <AlertDialog>
            <AlertDialogTrigger className="bg-destructive text-destructive-foreground hover:bg-destructive/90 inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-md px-3 py-1.5 text-xs font-medium transition-colors">
              <Trash className="size-3.5" />
              <span>Delete Application</span>
            </AlertDialogTrigger>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>Are you absolutely sure?</AlertDialogTitle>
                <AlertDialogDescription className="space-y-3">
                  <p>
                    This will permanently delete the application{" "}
                    <strong className="text-foreground">{app.name}</strong> and
                    all its cloud artifacts.
                  </p>
                  <p className="text-foreground">
                    Please type{" "}
                    <strong className="text-primary font-mono">
                      {app.slug}
                    </strong>{" "}
                    to confirm:
                  </p>
                  <Input
                    placeholder={app.slug}
                    value={deleteConfirmSlug}
                    onChange={(e) => setDeleteConfirmSlug(e.target.value)}
                    className="font-mono text-xs"
                    autoFocus
                  />
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel onClick={() => setDeleteConfirmSlug("")}>
                  Cancel
                </AlertDialogCancel>
                <AlertDialogAction
                  disabled={deleteConfirmSlug !== app.slug || isDeleting}
                  onClick={handleDeleteApp}
                  className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                >
                  {isDeleting ? (
                    <BloomSpinner size={14} speed="fast" className="mr-2" />
                  ) : null}
                  Delete Application
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        </CardFooter>
      </Card>
    </div>
  );
}
