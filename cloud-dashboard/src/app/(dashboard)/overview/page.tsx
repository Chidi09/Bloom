"use client";

import * as React from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  MagnifyingGlass,
  SlidersHorizontal,
  SquaresFour,
  List as ListIcon,
  Plus,
  CaretDown,
  Info,
  CheckCircle,
  WarningCircle,
  ArrowSquareOut,
  TerminalWindow,
  Hammer,
  Play,
  Check,
} from "@phosphor-icons/react";

import { Button } from "@/components/ui/button";
import { BloomFlowerIcon } from "@/components/auth/bloom-logo";
import { FlutterIcon } from "@/components/ui/flutter-icon";
import { CircularProgress } from "@/components/ui/circular-progress";
import { UserAvatar } from "@/components/ui/user-avatar";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { api } from "@/lib/api/client";
import { useOrganizationStore } from "@/stores/organization-store";
import { useUiStore } from "@/stores/ui-store";

interface AppItem {
  id: string;
  name: string;
  slug: string;
  framework?: string;
  platforms?: string[];
  latest_release?: string;
  crash_free_rate?: number;
  default_branch?: string;
  repository_url?: string | null;
  domain?: string;
  last_commit_message?: string;
  last_commit_author?: string;
  last_commit_time?: string;
  status?: "healthy" | "warning" | "error";
}

interface UsageSummary {
  plan_name: string;
  build_minutes_used: number;
  build_minutes_limit: number;
  artifact_storage_gb_used: number;
  artifact_storage_gb_limit: number;
  web_bandwidth_gb_used: number;
  web_bandwidth_gb_limit: number;
  deploy_count: number;
}

export default function OverviewPage() {
  const router = useRouter();
  const setPlanUpgradeDialogOpen = useUiStore(
    (s) => s.setPlanUpgradeDialogOpen,
  );
  const { currentOrganizationId } = useOrganizationStore();
  const searchInputRef = React.useRef<HTMLInputElement>(null);

  const [searchQuery, setSearchQuery] = React.useState("");
  const [viewMode, setViewMode] = React.useState<"grid" | "list">("grid");
  const [sortBy, setSortBy] = React.useState<"recent" | "alpha">("recent");
  const [frameworkFilter, setFrameworkFilter] = React.useState<
    "all" | "bloom" | "flutter"
  >("all");
  const [checklistDismissed, setChecklistDismissed] = React.useState(false);
  const [isTriggeringBuild, setIsTriggeringBuild] = React.useState(false);

  const [apps, setApps] = React.useState<AppItem[]>([]);
  const [usage, setUsage] = React.useState<UsageSummary | null>(null);
  const [isLoadingOverview, setIsLoadingOverview] = React.useState(true);
  const [overviewError, setOverviewError] = React.useState<string | null>(null);

  React.useEffect(() => {
    // Keyboard shortcut / to focus search
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "/" && document.activeElement !== searchInputRef.current) {
        e.preventDefault();
        searchInputRef.current?.focus();
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, []);

  React.useEffect(() => {
    if (!currentOrganizationId) return;

    let cancelled = false;
    async function loadOverview() {
      setIsLoadingOverview(true);
      setOverviewError(null);
      try {
        const [appsRes, usageRes] = await Promise.all([
          api.get<{ results: AppItem[] }>("/apps"),
          api.get<UsageSummary>("/billing/usage"),
        ]);
        if (cancelled) return;
        setApps(appsRes?.results ?? []);
        setUsage(usageRes ?? null);
      } catch (err: unknown) {
        if (cancelled) return;
        setOverviewError(
          err instanceof Error ? err.message : "Failed to load dashboard data.",
        );
      } finally {
        if (!cancelled) setIsLoadingOverview(false);
      }
    }
    void loadOverview();

    return () => {
      cancelled = true;
    };
  }, [currentOrganizationId]);

  const displayUsage: UsageSummary = usage ?? {
    plan_name: "free",
    build_minutes_used: 0,
    build_minutes_limit: 0,
    artifact_storage_gb_used: 0,
    artifact_storage_gb_limit: 0,
    web_bandwidth_gb_used: 0,
    web_bandwidth_gb_limit: 0,
    deploy_count: 0,
  };

  const filteredApps = apps
    .filter((a) => {
      const matchesSearch =
        a.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        a.domain?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        a.last_commit_message
          ?.toLowerCase()
          .includes(searchQuery.toLowerCase());
      const matchesFramework =
        frameworkFilter === "all" ? true : a.framework === frameworkFilter;
      return matchesSearch && matchesFramework;
    })
    .sort((a, b) => {
      if (sortBy === "alpha") return a.name.localeCompare(b.name);
      return 0; // default order is recent
    });

  const handleTriggerFirstBuild = async () => {
    const targetApp = apps[0];
    if (!targetApp) return;

    setIsTriggeringBuild(true);
    try {
      const envRes = await api.get<{ results: { id: string }[] }>(
        "/environments",
        { params: { app_id: targetApp.id } },
      );

      let environmentId = envRes?.results?.[0]?.id;
      if (!environmentId) {
        const createdEnv = await api.post<{ id: string }>("/environments", {
          app_id: targetApp.id,
          name: "Production",
          slug: "production",
          api_config: { env_vars: [], feature_flags: [] },
        });
        environmentId = createdEnv.id;
      }

      await api.post("/builds", {
        app_id: targetApp.id,
        environment_id: environmentId,
        platform: "all",
      });
      router.push("/builds");
    } catch (err: unknown) {
      setOverviewError(
        err instanceof Error ? err.message : "Failed to trigger build.",
      );
    } finally {
      setIsTriggeringBuild(false);
    }
  };

  return (
    <div className="mx-auto max-w-7xl space-y-5">
      {/* Top Toolbar Row */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        {/* Search Projects Input (with / shortcut) */}
        <div className="relative max-w-md flex-1">
          <MagnifyingGlass className="absolute top-2.5 left-3 size-3.5 text-zinc-500" />
          <input
            ref={searchInputRef}
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search Projects"
            className="w-full rounded-md border border-zinc-800 bg-[#09090b] py-1.5 pr-8 pl-8 text-xs text-zinc-100 placeholder:text-zinc-500 focus:border-zinc-700 focus:outline-none"
          />
          <kbd className="absolute top-2 right-2.5 rounded border border-zinc-800 bg-zinc-900 px-1.5 font-mono text-[10px] text-zinc-500">
            /
          </kbd>
        </div>

        {/* Right Toolbar Actions */}
        <div className="flex items-center gap-2">
          {/* Filter & Sort Menu */}
          <DropdownMenu>
            <DropdownMenuTrigger
              className="inline-flex h-8 cursor-pointer items-center justify-center rounded-md border border-zinc-800 bg-[#09090b] px-2.5 text-zinc-400 transition-colors hover:bg-zinc-800 hover:text-zinc-100"
              title="Filter & Sort"
            >
              <SlidersHorizontal className="size-3.5" />
            </DropdownMenuTrigger>
            <DropdownMenuContent
              align="end"
              className="w-48 border-zinc-800 bg-zinc-950 text-zinc-200"
            >
              <DropdownMenuGroup>
                <DropdownMenuLabel className="text-[11px] text-zinc-400">
                  Sort by
                </DropdownMenuLabel>
                <DropdownMenuItem
                  onClick={() => setSortBy("recent")}
                  className="flex cursor-pointer justify-between text-xs"
                >
                  <span>Recent activity</span>
                  {sortBy === "recent" && (
                    <Check className="text-primary size-3" />
                  )}
                </DropdownMenuItem>
                <DropdownMenuItem
                  onClick={() => setSortBy("alpha")}
                  className="flex cursor-pointer justify-between text-xs"
                >
                  <span>Alphabetical (A-Z)</span>
                  {sortBy === "alpha" && (
                    <Check className="text-primary size-3" />
                  )}
                </DropdownMenuItem>
              </DropdownMenuGroup>

              <DropdownMenuSeparator className="bg-zinc-800" />
              <DropdownMenuGroup>
                <DropdownMenuLabel className="text-[11px] text-zinc-400">
                  Framework
                </DropdownMenuLabel>
                <DropdownMenuItem
                  onClick={() => setFrameworkFilter("all")}
                  className="flex cursor-pointer justify-between text-xs"
                >
                  <span>All Frameworks</span>
                  {frameworkFilter === "all" && (
                    <Check className="text-primary size-3" />
                  )}
                </DropdownMenuItem>
                <DropdownMenuItem
                  onClick={() => setFrameworkFilter("bloom")}
                  className="flex cursor-pointer justify-between text-xs"
                >
                  <span>Bloom Framework only</span>
                  {frameworkFilter === "bloom" && (
                    <Check className="text-primary size-3" />
                  )}
                </DropdownMenuItem>
                <DropdownMenuItem
                  onClick={() => setFrameworkFilter("flutter")}
                  className="flex cursor-pointer justify-between text-xs"
                >
                  <span>Standard Flutter only</span>
                  {frameworkFilter === "flutter" && (
                    <Check className="text-primary size-3" />
                  )}
                </DropdownMenuItem>
              </DropdownMenuGroup>
            </DropdownMenuContent>
          </DropdownMenu>

          {/* Grid / List View Toggle */}
          <div className="flex items-center rounded-md border border-zinc-800 bg-[#09090b] p-0.5">
            <button
              type="button"
              onClick={() => setViewMode("grid")}
              className={`cursor-pointer rounded p-1.5 transition-colors ${
                viewMode === "grid"
                  ? "bg-zinc-800 text-zinc-100"
                  : "text-zinc-500 hover:text-zinc-300"
              }`}
              title="Grid view"
            >
              <SquaresFour className="size-3.5" />
            </button>
            <button
              type="button"
              onClick={() => setViewMode("list")}
              className={`cursor-pointer rounded p-1.5 transition-colors ${
                viewMode === "list"
                  ? "bg-zinc-800 text-zinc-100"
                  : "text-zinc-500 hover:text-zinc-300"
              }`}
              title="List view"
            >
              <ListIcon className="size-3.5" />
            </button>
          </div>

          {/* Add New Dropdown */}
          <DropdownMenu>
            <DropdownMenuTrigger className="inline-flex h-8 cursor-pointer items-center justify-center gap-1.5 rounded-md bg-zinc-100 px-2.5 text-xs font-medium text-zinc-950 transition-colors hover:bg-zinc-200">
              <Plus className="size-3.5" weight="bold" />
              <span>Add New</span>
              <CaretDown className="size-3 text-zinc-600" />
            </DropdownMenuTrigger>
            <DropdownMenuContent
              align="end"
              className="w-48 border-zinc-800 bg-zinc-950 text-zinc-200"
            >
              <DropdownMenuItem
                onClick={() => router.push("/onboarding?step=app")}
                className="cursor-pointer text-xs font-medium text-zinc-100"
              >
                + New Project
              </DropdownMenuItem>
              <DropdownMenuItem
                onClick={() => router.push("/onboarding?step=app")}
                className="cursor-pointer text-xs"
              >
                + New Application
              </DropdownMenuItem>
              <DropdownMenuSeparator className="bg-zinc-800" />
              <DropdownMenuItem
                onClick={() =>
                  router.push(`/organizations/${currentOrganizationId}?tab=billing`)
                }
                className="cursor-pointer text-xs text-zinc-400"
              >
                Connect Custom Domain
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>

      {/* Slim Next Recommended Action & Setup Tracker */}
      {!checklistDismissed && (
        <div className="flex flex-col justify-between gap-3 rounded-lg border border-zinc-800/80 bg-gradient-to-r from-zinc-900/90 via-zinc-900/60 to-zinc-900/90 p-3.5 text-xs text-zinc-200 sm:flex-row sm:items-center">
          <div className="space-y-1">
            <div className="flex items-center gap-2">
              <span className="flex size-2 animate-pulse rounded-full bg-[#20C9B0]" />
              <span className="font-semibold text-zinc-100">
                Next Step: Trigger your first cloud build for
                &apos;bloom-platform&apos;
              </span>
            </div>
            <div className="flex flex-wrap items-center gap-3 text-[11px] text-zinc-400">
              <span className="flex items-center gap-1 font-medium text-emerald-400">
                <CheckCircle className="size-3.5" weight="fill" /> Workspace
                Created
              </span>
              <span className="flex items-center gap-1 font-medium text-emerald-400">
                <CheckCircle className="size-3.5" weight="fill" /> App
                Initialized
              </span>
              <span className="flex items-center gap-1 text-zinc-400">
                <TerminalWindow className="size-3.5" /> Authenticate CLI
              </span>
              <span className="flex items-center gap-1 text-zinc-400">
                <Hammer className="size-3.5" /> Trigger Build
              </span>
            </div>
          </div>

          <div className="flex shrink-0 items-center gap-2">
            <Button
              size="sm"
              onClick={handleTriggerFirstBuild}
              disabled={isTriggeringBuild}
              className="h-7 cursor-pointer gap-1 bg-zinc-100 text-xs font-medium text-zinc-950 hover:bg-zinc-200"
            >
              <Play className="size-3" weight="fill" />
              <span>Run Cloud Build</span>
            </Button>
            <button
              type="button"
              onClick={() => setChecklistDismissed(true)}
              className="cursor-pointer px-1.5 text-xs text-zinc-500 transition-colors hover:text-zinc-300"
            >
              Dismiss
            </button>
          </div>
        </div>
      )}

      {/* Two-Column Vercel Layout */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
        {/* Left Column (Usage, Alerts, Recent Previews) — 5 cols */}
        <div className="space-y-5 lg:col-span-5">
          {/* Usage Card (Last 30 days) */}
          <div className="space-y-2">
            <h2 className="text-xs font-semibold text-zinc-400">Usage</h2>
            <div className="space-y-4 rounded-lg border border-zinc-800/80 bg-[#09090b] p-4 text-xs">
              <div className="flex items-center justify-between">
                <span className="font-semibold text-zinc-200">
                  Last 30 days
                </span>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => setPlanUpgradeDialogOpen(true)}
                  className="h-6 cursor-pointer border-zinc-700 bg-zinc-800/80 px-2.5 text-[11px] font-medium text-zinc-100 hover:bg-zinc-800"
                >
                  Upgrade
                </Button>
              </div>

              <div className="space-y-3.5 text-xs">
                {/* Metric 1: Build Minutes */}
                <div className="flex items-center justify-between text-zinc-300">
                  <div className="flex items-center gap-2.5">
                    <CircularProgress
                      value={displayUsage.build_minutes_used}
                      max={displayUsage.build_minutes_limit}
                      color="#3B82F6"
                      size={16}
                      strokeWidth={2.5}
                    />
                    <span className="font-sans text-zinc-300">
                      Build Minutes
                    </span>
                    <Info className="size-3 cursor-help text-zinc-500 hover:text-zinc-300" />
                  </div>
                  <span className="font-mono text-[11px] text-zinc-400">
                    {displayUsage.build_minutes_used}m /{" "}
                    {displayUsage.build_minutes_limit}m
                  </span>
                </div>

                {/* Metric 2: Fast Data Transfer */}
                <div className="flex items-center justify-between text-zinc-300">
                  <div className="flex items-center gap-2.5">
                    <CircularProgress
                      value={displayUsage.web_bandwidth_gb_used}
                      max={displayUsage.web_bandwidth_gb_limit}
                      color="#20C9B0"
                      size={16}
                      strokeWidth={2.5}
                    />
                    <span className="font-sans text-zinc-300">
                      Fast Data Transfer
                    </span>
                    <Info className="size-3 cursor-help text-zinc-500 hover:text-zinc-300" />
                  </div>
                  <span className="font-mono text-[11px] text-zinc-400">
                    {displayUsage.web_bandwidth_gb_used} GB /{" "}
                    {displayUsage.web_bandwidth_gb_limit} GB
                  </span>
                </div>

                {/* Metric 3: Artifact Storage */}
                <div className="flex items-center justify-between text-zinc-300">
                  <div className="flex items-center gap-2.5">
                    <CircularProgress
                      value={displayUsage.artifact_storage_gb_used}
                      max={displayUsage.artifact_storage_gb_limit}
                      color="#8B5CF6"
                      size={16}
                      strokeWidth={2.5}
                    />
                    <span className="font-sans text-zinc-300">
                      Artifact Storage
                    </span>
                    <Info className="size-3 cursor-help text-zinc-500 hover:text-zinc-300" />
                  </div>
                  <span className="font-mono text-[11px] text-zinc-400">
                    {displayUsage.artifact_storage_gb_used} GB /{" "}
                    {displayUsage.artifact_storage_gb_limit} GB
                  </span>
                </div>

                {/* Metric 4: OTA Updates */}
                <div className="flex items-center justify-between text-zinc-300">
                  <div className="flex items-center gap-2.5">
                    <CircularProgress
                      value={14.2}
                      max={100}
                      color="#FF4B8B"
                      size={16}
                      strokeWidth={2.5}
                    />
                    <span className="font-sans text-zinc-300">
                      Bloom OTA Invocations
                    </span>
                    <Info className="size-3 cursor-help text-zinc-500 hover:text-zinc-300" />
                  </div>
                  <span className="font-mono text-[11px] text-zinc-400">
                    14.2K / 100K
                  </span>
                </div>
              </div>

              <div className="flex justify-center border-t border-zinc-800/60 pt-2">
                <button
                  type="button"
                  onClick={() =>
                    router.push(
                      `/organizations/${currentOrganizationId}?tab=billing`,
                    )
                  }
                  className="flex cursor-pointer items-center gap-1 text-[11px] text-zinc-500 transition-colors hover:text-zinc-300"
                >
                  <span>View detailed usage breakdown</span>
                  <CaretDown className="size-3" />
                </button>
              </div>
            </div>
          </div>

          {/* Alerts / Pro Anomalies Card */}
          <div className="space-y-2">
            <h2 className="text-xs font-semibold text-zinc-400">Alerts</h2>
            <div className="space-y-3 rounded-lg border border-zinc-800/80 bg-[#09090b] p-5 text-center">
              <div className="space-y-1">
                <h3 className="text-xs font-semibold text-zinc-200">
                  Get alerted for anomalies
                </h3>
                <p className="mx-auto max-w-xs text-[11px] text-zinc-400">
                  Automatically monitor your mobile rollouts and cloud builds
                  for crash spikes.
                </p>
              </div>
              <Button
                size="sm"
                onClick={() => setPlanUpgradeDialogOpen(true)}
                className="h-7 cursor-pointer bg-zinc-100 text-xs font-medium text-zinc-950 hover:bg-zinc-200"
              >
                Upgrade to Pro
              </Button>
            </div>
          </div>

          {/* Recent Previews Card */}
          <div className="space-y-2">
            <h2 className="text-xs font-semibold text-zinc-400">
              Recent Previews
            </h2>
            <div className="space-y-2.5 rounded-lg border border-zinc-800/80 bg-[#09090b] p-3.5 text-xs">
              <div className="flex items-center gap-2 overflow-hidden">
                <BloomFlowerIcon className="size-4 shrink-0" />
                <span className="font-mono text-[11px] text-[#20C9B0]">
                  main
                </span>
                <span className="truncate text-[11px] text-zinc-400">
                  feat(mobile): add signals reactive state & offline sync queue
                </span>
              </div>
              <div className="flex items-center justify-between border-t border-zinc-800/50 pt-1 text-[11px] text-zinc-500">
                <span className="cursor-pointer transition-colors hover:text-zinc-300">
                  › 3 Target Platforms
                </span>
                <Link
                  href="https://github.com/Chidi09/bloom-platform"
                  target="_blank"
                  className="flex items-center gap-1 transition-colors hover:text-zinc-300"
                >
                  <span>GitHub Source</span>
                  <ArrowSquareOut className="size-3" />
                </Link>
              </div>
            </div>
          </div>
        </div>

        {/* Right Column (Projects & Applications) — 7 cols */}
        <div className="space-y-2 lg:col-span-7">
          <div className="flex items-center justify-between">
            <h2 className="text-xs font-semibold text-zinc-400">
              Projects ({filteredApps.length})
            </h2>
            {frameworkFilter !== "all" && (
              <span className="text-primary font-mono text-[11px] capitalize">
                Filter: {frameworkFilter}
              </span>
            )}
          </div>

          {isLoadingOverview ? (
            <div className="space-y-3">
              {[0, 1, 2].map((i) => (
                <div
                  key={i}
                  className="h-20 animate-pulse rounded-lg border border-zinc-800/80 bg-zinc-900/40"
                />
              ))}
            </div>
          ) : overviewError ? (
            <div className="border-destructive/30 bg-destructive/10 text-destructive rounded-lg border p-4 text-xs">
              {overviewError}
            </div>
          ) : filteredApps.length === 0 ? (
            <div className="rounded-lg border border-zinc-800/80 bg-[#09090b] p-8 text-center text-xs text-zinc-400">
              {apps.length === 0 ? (
                <>
                  <p className="mb-3">No applications yet.</p>
                  <Button
                    size="sm"
                    onClick={() => router.push("/onboarding?step=app")}
                  >
                    Create your first app
                  </Button>
                </>
              ) : (
                <p>No applications match your search or filter.</p>
              )}
            </div>
          ) : viewMode === "grid" ? (
            <div className="space-y-3">
              {filteredApps.map((app) => {
                const isBloom = app.framework === "bloom";
                return (
                  <div
                    key={app.id}
                    className="group space-y-3 rounded-lg border border-zinc-800/80 bg-[#09090b] p-4 text-xs transition-all hover:border-zinc-700"
                  >
                    {/* Top Row: Icon + Name + Domain + Status */}
                    <div className="flex items-start justify-between">
                      <div className="flex items-center gap-3">
                        {/* App / Framework Icon */}
                        <div className="flex size-8 shrink-0 items-center justify-center rounded-full border border-zinc-800 bg-zinc-900">
                          {isBloom ? (
                            <BloomFlowerIcon className="size-4" />
                          ) : (
                            <FlutterIcon className="size-4" />
                          )}
                        </div>

                        <div>
                          <div className="flex items-center gap-2">
                            <Link
                              href={`/apps/${app.id}`}
                              className="text-sm font-bold text-zinc-100 hover:underline"
                            >
                              {app.name}
                            </Link>
                          </div>
                          {app.domain && (
                            <Link
                              href={`https://${app.domain}`}
                              target="_blank"
                              className="flex items-center gap-1 text-xs text-zinc-400 transition-colors hover:text-zinc-200"
                            >
                              <span>{app.domain}</span>
                              <ArrowSquareOut className="size-2.5 text-zinc-500" />
                            </Link>
                          )}
                        </div>
                      </div>

                      {/* Status Badge */}
                      <div>
                        {app.status === "warning" ? (
                          <div
                            className="flex size-5 items-center justify-center rounded-full border border-amber-500/30 bg-amber-500/10 text-amber-400"
                            title="Requires attention"
                          >
                            <WarningCircle className="size-3.5" weight="bold" />
                          </div>
                        ) : (
                          <div
                            className="flex size-5 items-center justify-center rounded-full border border-emerald-500/30 bg-emerald-500/10 text-emerald-400"
                            title="Healthy & Deployed"
                          >
                            <Check className="size-3" weight="bold" />
                          </div>
                        )}
                      </div>
                    </div>

                    {/* Middle Row: Latest Git Commit Message */}
                    {app.last_commit_message && (
                      <div className="flex items-start gap-1.5 pl-0.5 text-xs text-zinc-300">
                        <span className="font-mono text-zinc-600 select-none">
                          --o
                        </span>
                        <span className="truncate">
                          {app.last_commit_message}
                        </span>
                      </div>
                    )}

                    {/* Bottom Row: Git Author, Repo, Time, and Target Chips */}
                    <div className="flex flex-wrap items-center justify-between border-t border-zinc-800/40 pt-1 text-[11px] text-zinc-500">
                      <div className="flex items-center gap-2">
                        {app.last_commit_author ? (
                          <div className="flex items-center gap-1.5">
                            <UserAvatar
                              name={
                                app.last_commit_author.split("/")[0] || "dev"
                              }
                              src={
                                app.last_commit_author
                                  .toLowerCase()
                                  .includes("chidi09")
                                  ? "https://github.com/Chidi09.png"
                                  : undefined
                              }
                              size={16}
                            />
                            <span className="text-zinc-400">
                              {app.last_commit_author} ·{" "}
                              {app.last_commit_time || "recent"}
                            </span>
                          </div>
                        ) : (
                          <span className="text-primary cursor-pointer hover:underline">
                            Connect Git Repository · 20h ago
                          </span>
                        )}
                      </div>

                      <div className="flex items-center gap-1 font-mono text-[10px] text-zinc-400">
                        {app.platforms?.map((p) => (
                          <span
                            key={p}
                            className="py-0.2 rounded border border-zinc-800 bg-zinc-900 px-1.5 uppercase"
                          >
                            {p}
                          </span>
                        ))}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            /* VIEW MODE: DENSE LIST ROWS */
            <div className="divide-y divide-zinc-800/60 overflow-hidden rounded-lg border border-zinc-800/80 bg-[#09090b]">
              {filteredApps.map((app) => {
                const isBloom = app.framework === "bloom";
                return (
                  <div
                    key={app.id}
                    className="flex items-center justify-between gap-3 p-3 text-xs transition-colors hover:bg-zinc-900/60"
                  >
                    {/* Left: Icon + Title + Domain */}
                    <div className="flex max-w-[240px] min-w-[180px] items-center gap-3">
                      <div className="flex size-7 shrink-0 items-center justify-center rounded-full border border-zinc-800 bg-zinc-900">
                        {isBloom ? (
                          <BloomFlowerIcon className="size-3.5" />
                        ) : (
                          <FlutterIcon className="size-3.5" />
                        )}
                      </div>
                      <div className="truncate">
                        <Link
                          href={`/apps/${app.id}`}
                          className="block truncate font-semibold text-zinc-100 hover:underline"
                        >
                          {app.name}
                        </Link>
                        {app.domain && (
                          <p className="truncate text-[11px] text-zinc-500">
                            {app.domain}
                          </p>
                        )}
                      </div>
                    </div>

                    {/* Commit Message & Author */}
                    <div className="hidden flex-1 items-center gap-2 overflow-hidden px-2 md:flex">
                      <UserAvatar
                        name={app.last_commit_author?.split("/")[0] || "dev"}
                        src={
                          app.last_commit_author
                            ?.toLowerCase()
                            .includes("chidi09")
                            ? "https://github.com/Chidi09.png"
                            : undefined
                        }
                        size={14}
                      />
                      <span className="truncate text-[11px] text-zinc-400">
                        {app.last_commit_message || "No recent commits"}
                      </span>
                    </div>

                    {/* Targets & Status */}
                    <div className="flex shrink-0 items-center gap-3">
                      <div className="hidden items-center gap-1 font-mono text-[9px] text-zinc-400 sm:flex">
                        {app.platforms?.map((p) => (
                          <span
                            key={p}
                            className="py-0.2 rounded border border-zinc-800 bg-zinc-900 px-1 uppercase"
                          >
                            {p}
                          </span>
                        ))}
                      </div>

                      {app.status === "warning" ? (
                        <div
                          className="flex size-4 items-center justify-center rounded-full border border-amber-500/30 bg-amber-500/10 text-amber-400"
                          title="Requires attention"
                        >
                          <WarningCircle className="size-3" weight="bold" />
                        </div>
                      ) : (
                        <div
                          className="flex size-4 items-center justify-center rounded-full border border-emerald-500/30 bg-emerald-500/10 text-emerald-400"
                          title="Healthy & Deployed"
                        >
                          <Check className="size-2.5" weight="bold" />
                        </div>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
