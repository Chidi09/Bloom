"use client";

import * as React from "react";
import { useParams } from "next/navigation";
import {
  TreeStructure,
  Plus,
  Trash,
  ArrowsClockwise,
  Sliders,
  Code,
  ToggleLeft,
  LockSimple,
} from "@phosphor-icons/react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
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
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
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
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { EmptyState } from "@/components/shared/empty-state";
import { api } from "@/lib/api/client";
import { EnvironmentResponse } from "@/lib/schemas/environment";
import { BuildResponse } from "@/lib/schemas/build";
import { useOrganizationStore } from "@/stores/organization-store";
import { useOrganizationEvents } from "@/lib/hooks/use-organization-events";

interface EnvVarRow {
  key: string;
  value: string;
}

interface FeatureFlagRow {
  key: string;
  enabled: boolean;
}

function getEnvTheme(slug: string, name: string, profile: string) {
  const s = `${slug} ${name}`.toLowerCase();
  if (s.includes("prod") || profile === "release") {
    return {
      topBorder: "border-t-rose-500/90",
      badgeVariant: "default" as const,
      badgeClass: "border-rose-500/30 bg-rose-500/10 text-rose-400 font-mono",
      iconTint: "text-rose-400",
      glow: "hover:shadow-[0_4px_24px_rgba(244,63,94,0.12)] hover:border-rose-500/40",
      label: "Production Tier",
    };
  }
  if (s.includes("stag") || s.includes("uat")) {
    return {
      topBorder: "border-t-amber-500/90",
      badgeVariant: "secondary" as const,
      badgeClass:
        "border-amber-500/30 bg-amber-500/10 text-amber-400 font-mono",
      iconTint: "text-amber-400",
      glow: "hover:shadow-[0_4px_24px_rgba(245,158,11,0.12)] hover:border-amber-500/40",
      label: "Staging Tier",
    };
  }
  if (s.includes("prev") || s.includes("qa") || s.includes("test")) {
    return {
      topBorder: "border-t-sky-500/90",
      badgeVariant: "secondary" as const,
      badgeClass: "border-sky-500/30 bg-sky-500/10 text-sky-400 font-mono",
      iconTint: "text-sky-400",
      glow: "hover:shadow-[0_4px_24px_rgba(14,165,233,0.12)] hover:border-sky-500/40",
      label: "Preview Tier",
    };
  }
  return {
    topBorder: "border-t-emerald-500/90",
    badgeVariant: "secondary" as const,
    badgeClass:
      "border-emerald-500/30 bg-emerald-500/10 text-emerald-400 font-mono",
    iconTint: "text-emerald-400",
    glow: "hover:shadow-[0_4px_24px_rgba(16,185,129,0.12)] hover:border-emerald-500/40",
    label: "Development Tier",
  };
}

export default function AppEnvironmentsPage() {
  const params = useParams<{ id: string }>();
  const appId = params.id;
  const { currentOrganizationId } = useOrganizationStore();

  useOrganizationEvents(currentOrganizationId);

  const [environments, setEnvironments] = React.useState<EnvironmentResponse[]>(
    [],
  );
  const [builds, setBuilds] = React.useState<BuildResponse[]>([]);
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Sheet Editor State (Configure)
  const [editingEnv, setEditingEnv] =
    React.useState<EnvironmentResponse | null>(null);
  const [sheetOpen, setSheetOpen] = React.useState(false);
  const [editName, setEditName] = React.useState("");
  const [editBuildProfile, setEditBuildProfile] = React.useState("release");
  const [editFlutterVer, setEditFlutterVer] = React.useState("");
  const [editDartVer, setEditDartVer] = React.useState("");
  const [editBloomVer, setEditBloomVer] = React.useState("");
  const [editFlavor, setEditFlavor] = React.useState("");
  const [editEnvVars, setEditEnvVars] = React.useState<EnvVarRow[]>([]);
  const [editFeatureFlags, setEditFeatureFlags] = React.useState<
    FeatureFlagRow[]
  >([]);
  const [isSaving, setIsSaving] = React.useState(false);

  // Create Dialog State
  const [createDialogOpen, setCreateDialogOpen] = React.useState(false);
  const [newName, setNewName] = React.useState("");
  const [newSlug, setNewSlug] = React.useState("");
  const [newBuildProfile, setNewBuildProfile] = React.useState("release");
  const [newFlutterVer, setNewFlutterVer] = React.useState("3.27.0");
  const [newDartVer, setNewDartVer] = React.useState("3.6.0");
  const [newBloomVer, setNewBloomVer] = React.useState("0.8.2");
  const [newFlavor, setNewFlavor] = React.useState("");
  const [newEnvVars, setNewEnvVars] = React.useState<EnvVarRow[]>([]);
  const [newFeatureFlags, setNewFeatureFlags] = React.useState<
    FeatureFlagRow[]
  >([]);
  const [isCreating, setIsCreating] = React.useState(false);

  // Deletion State
  const [isDeleting, setIsDeleting] = React.useState(false);

  const fetchData = React.useCallback(async () => {
    if (!appId) return;
    setIsLoading(true);
    setError(null);
    try {
      const [envsRes, buildsRes] = await Promise.all([
        api.get<{ results: EnvironmentResponse[] }>("/environments", {
          params: { app_id: appId },
        }),
        api.get<{ results: BuildResponse[] }>("/builds", {
          params: { app_id: appId },
        }),
      ]);
      setEnvironments(envsRes?.results ?? []);
      setBuilds(buildsRes?.results ?? []);
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Failed to load environments",
      );
    } finally {
      setIsLoading(false);
    }
  }, [appId]);

  React.useEffect(() => {
    const run = async () => {
      await fetchData();
    };
    void run();
  }, [fetchData]);

  const openEditSheet = (env: EnvironmentResponse) => {
    setEditingEnv(env);
    setEditName(env.name);
    setEditBuildProfile(env.build_profile || "release");
    setEditFlutterVer(env.flutter_version || "");
    setEditDartVer(env.dart_version || "");
    setEditBloomVer(env.bloom_version || "");
    setEditFlavor(env.flavor || "");
    setEditEnvVars(env.api_config?.env_vars?.map((ev) => ({ ...ev })) ?? []);
    setEditFeatureFlags(
      env.api_config?.feature_flags?.map((ff) => ({ ...ff })) ?? [],
    );
    setSheetOpen(true);
  };

  const handleSaveSheet = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingEnv) return;

    setIsSaving(true);
    try {
      const payload = {
        name: editName.trim(),
        build_profile: editBuildProfile,
        flutter_version: editFlutterVer.trim() || null,
        dart_version: editDartVer.trim() || null,
        bloom_version: editBloomVer.trim() || null,
        flavor: editFlavor.trim() || null,
        api_config: {
          env_vars: editEnvVars.filter((r) => r.key.trim().length > 0),
          feature_flags: editFeatureFlags.filter(
            (r) => r.key.trim().length > 0,
          ),
        },
      };

      const updated = await api.patch<EnvironmentResponse>(
        `/environments/${editingEnv.id}`,
        payload,
      );

      toast.success(`Environment "${updated.name}" updated`);
      setSheetOpen(false);
      setEditingEnv(null);
      await fetchData();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to update environment",
      );
    } finally {
      setIsSaving(false);
    }
  };

  const handleCreateEnvironment = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!appId) return;

    setIsCreating(true);
    try {
      const slugVal =
        newSlug.trim() ||
        newName
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, "-")
          .replace(/(^-|-$)/g, "");

      const payload = {
        app_id: appId,
        name: newName.trim(),
        slug: slugVal,
        build_profile: newBuildProfile,
        flutter_version: newFlutterVer.trim() || null,
        dart_version: newDartVer.trim() || null,
        bloom_version: newBloomVer.trim() || null,
        flavor: newFlavor.trim() || null,
        api_config: {
          env_vars: newEnvVars.filter((r) => r.key.trim().length > 0),
          feature_flags: newFeatureFlags.filter((r) => r.key.trim().length > 0),
        },
      };

      const created = await api.post<EnvironmentResponse>(
        "/environments",
        payload,
      );

      toast.success(`Environment "${created.name}" created`);
      setCreateDialogOpen(false);
      setNewName("");
      setNewSlug("");
      setNewEnvVars([]);
      setNewFeatureFlags([]);
      await fetchData();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to create environment",
      );
    } finally {
      setIsCreating(false);
    }
  };

  const handleDeleteEnvironment = async (envId: string, envName: string) => {
    setIsDeleting(true);
    try {
      await api.delete(`/environments/${envId}`);
      toast.success(`Environment "${envName}" deleted`);
      await fetchData();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to delete environment",
      );
    } finally {
      setIsDeleting(false);
    }
  };

  return (
    <TooltipProvider>
      <div className="space-y-4">
        {/* Environments Toolbar */}
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="space-y-0.5">
            <h2 className="text-foreground text-sm font-semibold">
              Environments & Configuration
            </h2>
            <p className="text-muted-foreground text-xs">
              Manage target environments, pinned engine toolchains, non-secret
              variables, and feature flags.
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
              <span>New Environment</span>
            </Button>
          </div>
        </div>

        {error && (
          <Alert variant="destructive">
            <AlertTitle>Failed to load environments</AlertTitle>
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
            <BloomSpinner size={28} label="Loading environments..." />
          </div>
        ) : environments.length === 0 ? (
          <EmptyState
            icon={TreeStructure}
            title="No environments configured"
            description="Create environments like Production, Staging, or Preview to customize toolchain flags and runtime variables."
            actionLabel="Create Environment"
            onAction={() => setCreateDialogOpen(true)}
          />
        ) : (
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
            {environments.map((env) => {
              const hasBuilds = builds.some((b) => b.environment_id === env.id);
              const envVarCount = env.api_config?.env_vars?.length ?? 0;
              const flagCount = env.api_config?.feature_flags?.length ?? 0;
              const theme = getEnvTheme(
                env.slug,
                env.name,
                env.build_profile || "release",
              );

              return (
                <Card
                  key={env.id}
                  className={cn(
                    "group border-border/80 bg-card flex flex-col justify-between border-t-2 shadow-xs transition-all duration-200 hover:-translate-y-0.5",
                    theme.topBorder,
                    theme.glow,
                  )}
                >
                  <CardHeader className="pb-3">
                    <div className="flex items-start justify-between gap-2">
                      <div className="space-y-1">
                        <div className="flex items-center gap-1.5">
                          <TreeStructure
                            className={cn("size-4", theme.iconTint)}
                          />
                          <CardTitle className="text-foreground text-sm font-semibold">
                            {env.name}
                          </CardTitle>
                        </div>
                        <CardDescription className="text-muted-foreground font-mono text-[11px]">
                          {env.slug}
                        </CardDescription>
                      </div>
                      <Badge
                        variant={theme.badgeVariant}
                        className={cn(
                          "text-[10px] tracking-wide uppercase",
                          theme.badgeClass,
                        )}
                      >
                        {env.build_profile || "release"}
                      </Badge>
                    </div>
                  </CardHeader>

                  <CardContent className="space-y-3 pb-3 text-xs">
                    {/* Toolchain Badges */}
                    <div className="border-border/60 bg-muted/20 space-y-1.5 rounded-md border p-2.5">
                      <div className="text-muted-foreground flex items-center justify-between font-mono text-[11px]">
                        <span>Flutter SDK</span>
                        <span className="text-foreground font-semibold">
                          {env.flutter_version || "Default (3.27.0)"}
                        </span>
                      </div>
                      <div className="text-muted-foreground flex items-center justify-between font-mono text-[11px]">
                        <span>Dart SDK</span>
                        <span className="text-foreground font-semibold">
                          {env.dart_version || "Default (3.6.0)"}
                        </span>
                      </div>
                      {env.flavor ? (
                        <div className="text-muted-foreground flex items-center justify-between font-mono text-[11px]">
                          <span>Build Flavor</span>
                          <span className="text-foreground font-semibold">
                            {env.flavor}
                          </span>
                        </div>
                      ) : null}
                    </div>

                    {/* Summary counts */}
                    <div className="text-muted-foreground flex items-center justify-between font-mono text-xs">
                      <div className="flex items-center gap-3">
                        <div className="flex items-center gap-1">
                          <Code className="size-3.5" />
                          <span>{envVarCount} env vars</span>
                        </div>
                        <div className="flex items-center gap-1">
                          <ToggleLeft className="size-3.5" />
                          <span>{flagCount} flags</span>
                        </div>
                      </div>
                      <span className="text-muted-foreground/80 font-sans text-[10px]">
                        {theme.label}
                      </span>
                    </div>
                  </CardContent>

                  <CardFooter className="border-border/60 flex items-center justify-between border-t pt-3">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => openEditSheet(env)}
                      className="h-7 gap-1.5 text-xs transition-colors"
                    >
                      <Sliders className="size-3.5" />
                      <span>Configure</span>
                    </Button>

                    {/* Hard constraint: Delete action hidden with Tooltip explanation when environment has builds */}
                    {hasBuilds ? (
                      <Tooltip>
                        <TooltipTrigger className="text-muted-foreground/60 bg-muted/30 border-border/40 flex h-7 cursor-help items-center gap-1 rounded-md border px-2 text-[11px]">
                          <LockSimple className="size-3" />
                          <span>
                            Locked (
                            {
                              builds.filter((b) => b.environment_id === env.id)
                                .length
                            }{" "}
                            builds)
                          </span>
                        </TooltipTrigger>
                        <TooltipContent side="top" className="max-w-xs text-xs">
                          Environment deletion is locked because builds have
                          been executed in this environment. Preserving build
                          lineage.
                        </TooltipContent>
                      </Tooltip>
                    ) : (
                      <AlertDialog>
                        <AlertDialogTrigger className="text-muted-foreground hover:text-destructive hover:bg-destructive/10 inline-flex size-7 cursor-pointer items-center justify-center rounded-md transition-colors">
                          <Trash className="size-3.5" />
                        </AlertDialogTrigger>
                        <AlertDialogContent>
                          <AlertDialogHeader>
                            <AlertDialogTitle>
                              Delete Environment?
                            </AlertDialogTitle>
                            <AlertDialogDescription>
                              Are you sure you want to delete environment{" "}
                              <strong className="text-foreground">
                                {env.name}
                              </strong>
                              ? This action cannot be undone.
                            </AlertDialogDescription>
                          </AlertDialogHeader>
                          <AlertDialogFooter>
                            <AlertDialogCancel>Cancel</AlertDialogCancel>
                            <AlertDialogAction
                              onClick={() =>
                                void handleDeleteEnvironment(env.id, env.name)
                              }
                              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                              disabled={isDeleting}
                            >
                              Delete
                            </AlertDialogAction>
                          </AlertDialogFooter>
                        </AlertDialogContent>
                      </AlertDialog>
                    )}
                  </CardFooter>
                </Card>
              );
            })}
          </div>
        )}

        {/* Sheet Configuration Editor */}
        <Sheet open={sheetOpen} onOpenChange={setSheetOpen}>
          <SheetContent
            side="right"
            className="w-full overflow-y-auto sm:max-w-xl"
          >
            {editingEnv && (
              <form onSubmit={handleSaveSheet} className="space-y-6">
                <SheetHeader>
                  <SheetTitle className="flex items-center gap-2 text-base">
                    <TreeStructure className="text-primary size-4" />
                    <span>Configure {editingEnv.name}</span>
                  </SheetTitle>
                  <SheetDescription>
                    Modify build profiles, pinned toolchain versions, runtime
                    variables, and feature flags.
                  </SheetDescription>
                </SheetHeader>

                {/* General Settings */}
                <div className="space-y-4">
                  <h4 className="text-foreground text-xs font-semibold tracking-wider uppercase">
                    General & Engine Toolchain
                  </h4>

                  <div className="grid grid-cols-2 gap-3">
                    <div className="space-y-1.5">
                      <Label htmlFor="sheet-env-name">Environment Name</Label>
                      <Input
                        id="sheet-env-name"
                        value={editName}
                        onChange={(e) => setEditName(e.target.value)}
                        required
                      />
                    </div>
                    <div className="space-y-1.5">
                      <Label htmlFor="sheet-env-slug">Slug</Label>
                      <Input
                        id="sheet-env-slug"
                        value={editingEnv.slug}
                        disabled
                        className="bg-muted/30 font-mono text-xs"
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div className="space-y-1.5">
                      <Label htmlFor="sheet-profile">Build Profile</Label>
                      <Select
                        value={editBuildProfile}
                        onValueChange={(val) => val && setEditBuildProfile(val)}
                      >
                        <SelectTrigger id="sheet-profile" className="text-xs">
                          <SelectValue placeholder="Build Profile" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="release">Release</SelectItem>
                          <SelectItem value="debug">Debug</SelectItem>
                          <SelectItem value="profile">Profile</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                    <div className="space-y-1.5">
                      <Label htmlFor="sheet-flavor">Build Flavor</Label>
                      <Input
                        id="sheet-flavor"
                        placeholder="e.g. dev, staging, prod"
                        value={editFlavor}
                        onChange={(e) => setEditFlavor(e.target.value)}
                        className="font-mono text-xs"
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-3 gap-3">
                    <div className="space-y-1.5">
                      <Label htmlFor="sheet-flutter">Flutter Version</Label>
                      <Input
                        id="sheet-flutter"
                        placeholder="3.27.0"
                        value={editFlutterVer}
                        onChange={(e) => setEditFlutterVer(e.target.value)}
                        className="font-mono text-xs"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <Label htmlFor="sheet-dart">Dart Version</Label>
                      <Input
                        id="sheet-dart"
                        placeholder="3.6.0"
                        value={editDartVer}
                        onChange={(e) => setEditDartVer(e.target.value)}
                        className="font-mono text-xs"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <Label htmlFor="sheet-bloom">Bloom CLI</Label>
                      <Input
                        id="sheet-bloom"
                        placeholder="0.8.2"
                        value={editBloomVer}
                        onChange={(e) => setEditBloomVer(e.target.value)}
                        className="font-mono text-xs"
                      />
                    </div>
                  </div>
                </div>

                {/* Non-secret Environment Variables */}
                <div className="space-y-3 pt-2">
                  <div className="flex items-center justify-between">
                    <div>
                      <h4 className="text-foreground text-xs font-semibold tracking-wider uppercase">
                        Environment Variables
                      </h4>
                      <p className="text-muted-foreground text-[11px]">
                        Non-secret configuration variables injected into
                        runtime.
                      </p>
                    </div>
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={() =>
                        setEditEnvVars((prev) => [
                          ...prev,
                          { key: "", value: "" },
                        ])
                      }
                      className="h-7 gap-1 text-xs"
                    >
                      <Plus className="size-3" />
                      <span>Add Row</span>
                    </Button>
                  </div>

                  {editEnvVars.length === 0 ? (
                    <div className="border-border/60 bg-muted/10 text-muted-foreground rounded border p-4 text-center text-xs">
                      No environment variables defined. Click &ldquo;Add
                      Row&rdquo; to inject runtime configuration.
                    </div>
                  ) : (
                    <div className="border-border/80 overflow-hidden rounded-md border">
                      <div className="overflow-x-auto">
                        <Table>
                          <TableHeader>
                            <TableRow>
                              <TableHead className="text-xs">
                                Variable Key
                              </TableHead>
                              <TableHead className="text-xs">Value</TableHead>
                              <TableHead className="w-[44px]"></TableHead>
                            </TableRow>
                          </TableHeader>
                          <TableBody>
                            {editEnvVars.map((row, idx) => (
                              <TableRow
                                key={idx}
                                className="animate-in fade-in-0 slide-in-from-top-1 transition-all duration-150"
                              >
                                <TableCell className="p-2">
                                  <Input
                                    placeholder="API_ENDPOINT"
                                    value={row.key}
                                    onChange={(e) => {
                                      const keyVal = e.target.value;
                                      setEditEnvVars((prev) =>
                                        prev.map((r, i) =>
                                          i === idx ? { ...r, key: keyVal } : r,
                                        ),
                                      );
                                    }}
                                    className="h-8 font-mono text-xs"
                                  />
                                </TableCell>
                                <TableCell className="p-2">
                                  <Input
                                    placeholder="https://api.example.com"
                                    value={row.value}
                                    onChange={(e) => {
                                      const val = e.target.value;
                                      setEditEnvVars((prev) =>
                                        prev.map((r, i) =>
                                          i === idx ? { ...r, value: val } : r,
                                        ),
                                      );
                                    }}
                                    className="h-8 font-mono text-xs"
                                  />
                                </TableCell>
                                <TableCell className="p-2 text-center">
                                  <Button
                                    type="button"
                                    variant="ghost"
                                    size="sm"
                                    onClick={() =>
                                      setEditEnvVars((prev) =>
                                        prev.filter((_, i) => i !== idx),
                                      )
                                    }
                                    className="text-muted-foreground hover:text-destructive hover:bg-destructive/10 size-7 p-0 transition-colors"
                                  >
                                    <Trash className="size-3.5" />
                                  </Button>
                                </TableCell>
                              </TableRow>
                            ))}
                          </TableBody>
                        </Table>
                      </div>
                    </div>
                  )}
                </div>

                {/* Feature Flags - Polished modular card rows */}
                <div className="space-y-3 pt-2">
                  <div className="flex items-center justify-between">
                    <div>
                      <h4 className="text-foreground text-xs font-semibold tracking-wider uppercase">
                        Feature Flags
                      </h4>
                      <p className="text-muted-foreground text-[11px]">
                        Dynamic feature gates and rollout switches mapped to
                        environment builds.
                      </p>
                    </div>
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      onClick={() =>
                        setEditFeatureFlags((prev) => [
                          ...prev,
                          { key: "", enabled: true },
                        ])
                      }
                      className="h-7 gap-1 text-xs"
                    >
                      <Plus className="size-3" />
                      <span>Add Flag</span>
                    </Button>
                  </div>

                  {editFeatureFlags.length === 0 ? (
                    <div className="border-border/60 bg-muted/10 text-muted-foreground rounded border p-4 text-center text-xs">
                      No feature flags configured. Click &ldquo;Add Flag&rdquo;
                      to add a toggle.
                    </div>
                  ) : (
                    <div className="space-y-2">
                      {editFeatureFlags.map((flag, idx) => {
                        const isPrefixed = flag.key.includes("_");
                        const categoryTag = isPrefixed
                          ? flag.key.split("_")[0].toUpperCase()
                          : null;

                        return (
                          <div
                            key={idx}
                            className="border-border/80 bg-muted/10 hover:bg-muted/20 animate-in fade-in-0 slide-in-from-top-1 flex items-center justify-between gap-3 rounded-lg border p-3 transition-all duration-200"
                          >
                            <div className="flex-1 space-y-1.5">
                              <div className="flex items-center gap-2">
                                <Input
                                  placeholder="enable_new_dashboard"
                                  value={flag.key}
                                  onChange={(e) => {
                                    const keyVal = e.target.value;
                                    setEditFeatureFlags((prev) =>
                                      prev.map((r, i) =>
                                        i === idx ? { ...r, key: keyVal } : r,
                                      ),
                                    );
                                  }}
                                  className="h-8 font-mono text-xs"
                                />
                                {categoryTag && (
                                  <Badge
                                    variant="outline"
                                    className="text-muted-foreground shrink-0 font-mono text-[9px]"
                                  >
                                    {categoryTag}
                                  </Badge>
                                )}
                              </div>
                            </div>

                            <div className="flex shrink-0 items-center gap-3">
                              <div className="flex items-center gap-2">
                                <span
                                  className={cn(
                                    "font-mono text-[11px]",
                                    flag.enabled
                                      ? "font-medium text-emerald-400"
                                      : "text-muted-foreground",
                                  )}
                                >
                                  {flag.enabled ? "Active" : "Disabled"}
                                </span>
                                <Switch
                                  checked={flag.enabled}
                                  onCheckedChange={(val) => {
                                    setEditFeatureFlags((prev) =>
                                      prev.map((r, i) =>
                                        i === idx ? { ...r, enabled: val } : r,
                                      ),
                                    );
                                  }}
                                />
                              </div>

                              <Button
                                type="button"
                                variant="ghost"
                                size="sm"
                                onClick={() =>
                                  setEditFeatureFlags((prev) =>
                                    prev.filter((_, i) => i !== idx),
                                  )
                                }
                                className="text-muted-foreground hover:text-destructive hover:bg-destructive/10 size-7 p-0 transition-colors"
                              >
                                <Trash className="size-3.5" />
                              </Button>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>

                <SheetFooter className="border-border/60 border-t pt-4">
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onClick={() => setSheetOpen(false)}
                    disabled={isSaving}
                  >
                    Cancel
                  </Button>
                  <Button type="submit" size="sm" disabled={isSaving}>
                    {isSaving ? (
                      <BloomSpinner size={14} speed="fast" className="mr-2" />
                    ) : null}
                    Save Configuration
                  </Button>
                </SheetFooter>
              </form>
            )}
          </SheetContent>
        </Sheet>

        {/* Create Environment Dialog */}
        <Dialog open={createDialogOpen} onOpenChange={setCreateDialogOpen}>
          <DialogContent className="sm:max-w-lg">
            <form onSubmit={handleCreateEnvironment}>
              <DialogHeader>
                <DialogTitle className="flex items-center gap-2">
                  <TreeStructure className="text-primary size-4" />
                  <span>Create Environment</span>
                </DialogTitle>
                <DialogDescription>
                  Configure a new deployment and compilation target for this
                  application.
                </DialogDescription>
              </DialogHeader>

              <div className="space-y-4 py-4">
                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-1.5">
                    <Label htmlFor="new-env-name">Environment Name</Label>
                    <Input
                      id="new-env-name"
                      placeholder="e.g. Staging"
                      value={newName}
                      onChange={(e) => {
                        setNewName(e.target.value);
                        if (!newSlug) {
                          setNewSlug(
                            e.target.value
                              .toLowerCase()
                              .replace(/[^a-z0-9]+/g, "-"),
                          );
                        }
                      }}
                      required
                    />
                  </div>
                  <div className="space-y-1.5">
                    <Label htmlFor="new-env-slug">Slug</Label>
                    <Input
                      id="new-env-slug"
                      placeholder="staging"
                      value={newSlug}
                      onChange={(e) => setNewSlug(e.target.value)}
                      className="font-mono text-xs"
                      required
                    />
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-1.5">
                    <Label htmlFor="new-profile">Build Profile</Label>
                    <Select
                      value={newBuildProfile}
                      onValueChange={(val) => val && setNewBuildProfile(val)}
                    >
                      <SelectTrigger id="new-profile" className="text-xs">
                        <SelectValue placeholder="Build Profile" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="release">Release</SelectItem>
                        <SelectItem value="debug">Debug</SelectItem>
                        <SelectItem value="profile">Profile</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-1.5">
                    <Label htmlFor="new-flavor">Flavor (optional)</Label>
                    <Input
                      id="new-flavor"
                      placeholder="e.g. staging"
                      value={newFlavor}
                      onChange={(e) => setNewFlavor(e.target.value)}
                      className="font-mono text-xs"
                    />
                  </div>
                </div>

                <div className="grid grid-cols-3 gap-2">
                  <div className="space-y-1.5">
                    <Label htmlFor="new-flutter" className="text-[11px]">
                      Flutter
                    </Label>
                    <Input
                      id="new-flutter"
                      value={newFlutterVer}
                      onChange={(e) => setNewFlutterVer(e.target.value)}
                      className="font-mono text-xs"
                    />
                  </div>
                  <div className="space-y-1.5">
                    <Label htmlFor="new-dart" className="text-[11px]">
                      Dart
                    </Label>
                    <Input
                      id="new-dart"
                      value={newDartVer}
                      onChange={(e) => setNewDartVer(e.target.value)}
                      className="font-mono text-xs"
                    />
                  </div>
                  <div className="space-y-1.5">
                    <Label htmlFor="new-bloom" className="text-[11px]">
                      Bloom
                    </Label>
                    <Input
                      id="new-bloom"
                      value={newBloomVer}
                      onChange={(e) => setNewBloomVer(e.target.value)}
                      className="font-mono text-xs"
                    />
                  </div>
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
                <Button type="submit" disabled={isCreating}>
                  {isCreating ? (
                    <BloomSpinner size={14} speed="fast" className="mr-2" />
                  ) : null}
                  Create Environment
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </div>
    </TooltipProvider>
  );
}
