"use client";

import * as React from "react";
import { useParams, useRouter } from "next/navigation";
import {
  FloppyDisk,
  Trash,
  WarningOctagon,
  ArrowsClockwise,
  GitBranch,
  GitFork,
  IdentificationCard,
  LockSimple,
  Copy,
  Check,
  Warning,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Separator } from "@/components/ui/separator";
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
  const [copiedSlug, setCopiedSlug] = React.useState(false);

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

  const handleCopySlug = () => {
    if (!app?.slug) return;
    void navigator.clipboard.writeText(app.slug);
    setCopiedSlug(true);
    toast.success("Slug copied to clipboard");
    setTimeout(() => setCopiedSlug(false), 2000);
  };

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
      toast.success("Application settings updated successfully");
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
      toast.success("Application deleted permanently");
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
      <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-16">
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
    <div className="max-w-4xl space-y-6">
      {/* General Settings Card */}
      <Card className="border-border/80 bg-card shadow-xs">
        <form onSubmit={handleSaveSettings}>
          <CardHeader className="pb-4">
            <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <CardTitle className="text-base font-semibold">
                  General Application Settings
                </CardTitle>
                <CardDescription>
                  Configure core metadata, project identifiers, and repository
                  links for this application.
                </CardDescription>
              </div>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => void fetchApp()}
                className="h-8 gap-1.5 self-start transition-colors sm:self-auto"
              >
                <ArrowsClockwise className="size-3.5" />
                <span>Refresh</span>
              </Button>
            </div>
          </CardHeader>

          <CardContent className="space-y-6">
            {/* Section 1: Identification */}
            <div className="space-y-4">
              <div className="text-muted-foreground flex items-center gap-2 text-xs font-semibold tracking-wider uppercase">
                <IdentificationCard className="text-primary size-4" />
                <span>Identity & Metadata</span>
              </div>

              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div className="space-y-1.5">
                  <Label htmlFor="app-name">Application Name</Label>
                  <Input
                    id="app-name"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="My Bloom App"
                    required
                  />
                  <p className="text-muted-foreground text-[11px]">
                    Display name shown throughout dashboard and notifications.
                  </p>
                </div>

                <div className="space-y-1.5">
                  <div className="flex items-center justify-between">
                    <Label htmlFor="app-slug">App Slug</Label>
                    <button
                      type="button"
                      onClick={handleCopySlug}
                      className="text-muted-foreground hover:text-foreground inline-flex items-center gap-1 text-[11px] transition-colors"
                    >
                      {copiedSlug ? (
                        <Check className="size-3 text-emerald-400" />
                      ) : (
                        <Copy className="size-3" />
                      )}
                      <span>{copiedSlug ? "Copied" : "Copy"}</span>
                    </button>
                  </div>
                  <div className="relative">
                    <Input
                      id="app-slug"
                      value={app.slug}
                      disabled
                      className="bg-muted/30 pr-8 font-mono text-xs"
                    />
                    <LockSimple className="text-muted-foreground/60 absolute top-2.5 right-2.5 size-3.5" />
                  </div>
                  <p className="text-muted-foreground text-[11px]">
                    Immutable system identifier used in CLI, webhooks, and REST
                    endpoints.
                  </p>
                </div>
              </div>
            </div>

            <Separator className="bg-border/60" />

            {/* Section 2: Git Repository Integration */}
            <div className="space-y-4">
              <div className="text-muted-foreground flex items-center gap-2 text-xs font-semibold tracking-wider uppercase">
                <GitFork className="text-primary size-4" />
                <span>Source Control Integration</span>
              </div>

              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div className="space-y-1.5">
                  <Label htmlFor="app-repo">Git Repository URL</Label>
                  <Input
                    id="app-repo"
                    type="url"
                    placeholder="https://github.com/org/repo"
                    value={repoUrl}
                    onChange={(e) => setRepoUrl(e.target.value)}
                    className="font-mono text-xs"
                  />
                  <p className="text-muted-foreground text-[11px]">
                    HTTPS clone URL for automated build triggers and check runs.
                  </p>
                </div>

                <div className="space-y-1.5">
                  <Label htmlFor="app-branch">Default Git Branch</Label>
                  <div className="relative">
                    <Input
                      id="app-branch"
                      value={defaultBranch}
                      onChange={(e) => setDefaultBranch(e.target.value)}
                      placeholder="main"
                      className="pl-8 font-mono text-xs"
                      required
                    />
                    <GitBranch className="text-muted-foreground absolute top-2.5 left-2.5 size-3.5" />
                  </div>
                  <p className="text-muted-foreground text-[11px]">
                    Base branch targeted for continuous integration builds.
                  </p>
                </div>
              </div>
            </div>
          </CardContent>

          <CardFooter className="border-border/60 flex items-center justify-between border-t pt-4">
            <span className="text-muted-foreground font-mono text-xs">
              App ID:{" "}
              <span className="text-foreground">{app.id.slice(0, 8)}...</span> •
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

      {/* Danger Zone Card - Deeply distinct visual styling */}
      <Card className="border-rose-500/30 bg-gradient-to-b from-rose-950/20 to-rose-950/10 shadow-[0_0_24px_rgba(244,63,94,0.06)]">
        <CardHeader className="pb-3">
          <div className="flex items-center gap-2.5">
            <div className="flex size-8 shrink-0 items-center justify-center rounded-md bg-rose-500/15 text-rose-400">
              <WarningOctagon className="size-5" />
            </div>
            <div>
              <CardTitle className="text-base font-semibold text-rose-300">
                Danger Zone
              </CardTitle>
              <CardDescription className="text-xs text-rose-200/70">
                Irreversible destructive actions affecting &ldquo;{app.name}
                &rdquo;.
              </CardDescription>
            </div>
          </div>
        </CardHeader>

        <CardContent className="space-y-3 pb-3 text-xs">
          <div className="space-y-2 rounded-md border border-rose-500/20 bg-rose-950/30 p-3 text-rose-200/90">
            <p className="font-medium text-rose-300">
              Deleting this application will permanently remove:
            </p>
            <ul className="list-inside list-disc space-y-1 text-[11px] text-rose-200/80">
              <li>
                All historical compilation artifacts, release binaries, and
                build logs.
              </li>
              <li>
                Encrypted signing keystores, Apple provisioning profiles, and
                API credentials.
              </li>
              <li>
                Configured runtime environments, feature flags, and non-secret
                variables.
              </li>
              <li>Active web hosting deployments and linked preview URLs.</li>
            </ul>
          </div>
        </CardContent>

        <CardFooter className="flex items-center justify-between border-t border-rose-500/20 pt-4">
          <span className="font-mono text-xs text-rose-300/80">
            Requires explicit confirmation slug
          </span>
          <AlertDialog>
            <AlertDialogTrigger className="inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-md bg-rose-600 px-3 text-xs font-medium text-white shadow-xs hover:bg-rose-700">
              <Trash className="size-3.5" />
              <span>Delete Application</span>
            </AlertDialogTrigger>
            <AlertDialogContent className="border-rose-500/40">
              <AlertDialogHeader>
                <AlertDialogTitle className="flex items-center gap-2 text-rose-400">
                  <Warning className="size-5" />
                  <span>Are you absolutely sure?</span>
                </AlertDialogTitle>
                <AlertDialogDescription className="space-y-3 text-left">
                  <p>
                    This action{" "}
                    <strong className="text-rose-400">cannot be undone</strong>.
                    This will permanently delete the application{" "}
                    <strong className="text-foreground">{app.name}</strong> and
                    all its associated artifacts.
                  </p>
                  <div className="border-border/60 bg-muted/30 space-y-2 rounded-md border p-3">
                    <p className="text-foreground text-xs">
                      Please type the application slug{" "}
                      <strong className="font-mono text-rose-400 select-all">
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
                  </div>
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
                  Permanently Delete Application
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        </CardFooter>
      </Card>
    </div>
  );
}
