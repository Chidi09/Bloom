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
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { api } from "@/lib/api/client";
import { useOrganizationStore } from "@/stores/organization-store";
import { UpgradeModal } from "@/components/billing/upgrade-modal";

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
  const { currentOrganizationId } = useOrganizationStore();
  const searchInputRef = React.useRef<HTMLInputElement>(null);

  const [searchQuery, setSearchQuery] = React.useState("");
  const [viewMode, setViewMode] = React.useState<"grid" | "list">("grid");
  const [sortBy, setSortBy] = React.useState<"recent" | "alpha">("recent");
  const [frameworkFilter, setFrameworkFilter] = React.useState<"all" | "bloom" | "flutter">("all");
  const [checklistDismissed, setChecklistDismissed] = React.useState(false);
  const [upgradeModalOpen, setUpgradeModalOpen] = React.useState(false);
  const [isTriggeringBuild, setIsTriggeringBuild] = React.useState(false);

  const [apps, setApps] = React.useState<AppItem[]>([
    {
      id: "app-1",
      name: "variantrade-v2",
      slug: "variantrade-v2",
      framework: "bloom",
      platforms: ["web", "ios", "android"],
      domain: "www.variantrades.com",
      last_commit_message: "feat(site): add /payment/success and /payment/cancel landing pages",
      last_commit_author: "Chidi09/variantrade",
      last_commit_time: "Aug 11",
      status: "warning",
    },
    {
      id: "app-2",
      name: "fascord",
      slug: "fascord",
      framework: "bloom",
      platforms: ["web", "desktop"],
      domain: "fascord.vercel.app",
      last_commit_message: "Remove old default app router favicon.ico so public/ ones take precedence",
      last_commit_author: "Chidi09/Fascord",
      last_commit_time: "Jun 8",
      status: "healthy",
    },
    {
      id: "app-3",
      name: "bloom-platform",
      slug: "bloom-platform",
      framework: "bloom",
      platforms: ["web", "ios", "android", "desktop"],
      domain: "bloom-platform-ten.vercel.app",
      last_commit_message: "feat(mobile): add signals reactive state & offline sync queue",
      last_commit_author: "Chidi09/bloom-platform",
      last_commit_time: "20h ago",
      status: "healthy",
    },
    {
      id: "app-4",
      name: "greathopefoundation",
      slug: "greathopefoundation",
      framework: "flutter",
      platforms: ["web"],
      domain: "greathopefoundation.vercel.app",
      last_commit_message: "site: add Google Search Console verification file and sitemap",
      last_commit_author: "Chidi09/greathopefoundation",
      last_commit_time: "2d ago",
      status: "healthy",
    },
  ]);

  const [usage, setUsage] = React.useState<UsageSummary>({
    plan_name: "free",
    build_minutes_used: 245,
    build_minutes_limit: 1000,
    artifact_storage_gb_used: 1.2,
    artifact_storage_gb_limit: 5.0,
    web_bandwidth_gb_used: 7.13,
    web_bandwidth_gb_limit: 50.0,
    deploy_count: 28,
  });

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
    Promise.all([
      api.get<{ results: AppItem[] }>("/apps"),
      api.get<UsageSummary>("/billing/usage"),
    ])
      .then(([appsRes, usageRes]) => {
        if (appsRes?.results && appsRes.results.length > 0) {
          setApps(appsRes.results);
        }
        if (usageRes) {
          setUsage(usageRes);
        }
      })
      .catch(() => undefined);
  }, [currentOrganizationId]);

  const filteredApps = apps
    .filter((a) => {
      const matchesSearch =
        a.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        a.domain?.toLowerCase().includes(searchQuery.toLowerCase()) ||
        a.last_commit_message?.toLowerCase().includes(searchQuery.toLowerCase());
      const matchesFramework =
        frameworkFilter === "all" ? true : a.framework === frameworkFilter;
      return matchesSearch && matchesFramework;
    })
    .sort((a, b) => {
      if (sortBy === "alpha") return a.name.localeCompare(b.name);
      return 0; // default order is recent
    });

  const handleTriggerFirstBuild = async () => {
    setIsTriggeringBuild(true);
    try {
      await api.post("/apps/app-1/builds", {});
      router.push("/builds");
    } catch {
      // ignore
    } finally {
      setIsTriggeringBuild(false);
    }
  };

  return (
    <div className="max-w-7xl mx-auto space-y-5">
      {/* Top Toolbar Row */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        {/* Search Projects Input (with / shortcut) */}
        <div className="relative flex-1 max-w-md">
          <MagnifyingGlass className="absolute left-3 top-2.5 size-3.5 text-zinc-500" />
          <input
            ref={searchInputRef}
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search Projects"
            className="w-full rounded-md border border-zinc-800 bg-[#09090b] py-1.5 pl-8 pr-8 text-xs text-zinc-100 placeholder:text-zinc-500 focus:border-zinc-700 focus:outline-none"
          />
          <kbd className="absolute right-2.5 top-2 rounded border border-zinc-800 bg-zinc-900 px-1.5 text-[10px] font-mono text-zinc-500">
            /
          </kbd>
        </div>

        {/* Right Toolbar Actions */}
        <div className="flex items-center gap-2">
          {/* Filter & Sort Menu */}
          <DropdownMenu>
            <DropdownMenuTrigger
              className="h-8 px-2.5 inline-flex items-center justify-center rounded-md border border-zinc-800 bg-[#09090b] text-zinc-400 hover:text-zinc-100 hover:bg-zinc-800 cursor-pointer transition-colors"
              title="Filter & Sort"
            >
              <SlidersHorizontal className="size-3.5" />
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-48 bg-zinc-900 border-zinc-800 text-zinc-200">
              <DropdownMenuLabel className="text-[11px] text-zinc-400">Sort by</DropdownMenuLabel>
              <DropdownMenuItem
                onClick={() => setSortBy("recent")}
                className="text-xs cursor-pointer flex justify-between"
              >
                <span>Recent activity</span>
                {sortBy === "recent" && <Check className="size-3 text-primary" />}
              </DropdownMenuItem>
              <DropdownMenuItem
                onClick={() => setSortBy("alpha")}
                className="text-xs cursor-pointer flex justify-between"
              >
                <span>Alphabetical (A-Z)</span>
                {sortBy === "alpha" && <Check className="size-3 text-primary" />}
              </DropdownMenuItem>

              <DropdownMenuSeparator className="bg-zinc-800" />
              <DropdownMenuLabel className="text-[11px] text-zinc-400">Framework</DropdownMenuLabel>
              <DropdownMenuItem
                onClick={() => setFrameworkFilter("all")}
                className="text-xs cursor-pointer flex justify-between"
              >
                <span>All Frameworks</span>
                {frameworkFilter === "all" && <Check className="size-3 text-primary" />}
              </DropdownMenuItem>
              <DropdownMenuItem
                onClick={() => setFrameworkFilter("bloom")}
                className="text-xs cursor-pointer flex justify-between"
              >
                <span>Bloom Framework only</span>
                {frameworkFilter === "bloom" && <Check className="size-3 text-primary" />}
              </DropdownMenuItem>
              <DropdownMenuItem
                onClick={() => setFrameworkFilter("flutter")}
                className="text-xs cursor-pointer flex justify-between"
              >
                <span>Standard Flutter only</span>
                {frameworkFilter === "flutter" && <Check className="size-3 text-primary" />}
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>

          {/* Grid / List View Toggle */}
          <div className="flex items-center rounded-md border border-zinc-800 bg-[#09090b] p-0.5">
            <button
              type="button"
              onClick={() => setViewMode("grid")}
              className={`p-1.5 rounded transition-colors cursor-pointer ${
                viewMode === "grid" ? "bg-zinc-800 text-zinc-100" : "text-zinc-500 hover:text-zinc-300"
              }`}
              title="Grid view"
            >
              <SquaresFour className="size-3.5" />
            </button>
            <button
              type="button"
              onClick={() => setViewMode("list")}
              className={`p-1.5 rounded transition-colors cursor-pointer ${
                viewMode === "list" ? "bg-zinc-800 text-zinc-100" : "text-zinc-500 hover:text-zinc-300"
              }`}
              title="List view"
            >
              <ListIcon className="size-3.5" />
            </button>
          </div>

          {/* Add New Dropdown */}
          <DropdownMenu>
            <DropdownMenuTrigger
              className="h-8 px-2.5 inline-flex items-center justify-center rounded-md text-xs font-medium bg-zinc-100 text-zinc-950 hover:bg-zinc-200 cursor-pointer gap-1.5 transition-colors"
            >
              <Plus className="size-3.5" weight="bold" />
              <span>Add New</span>
              <CaretDown className="size-3 text-zinc-600" />
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-48 bg-zinc-900 border-zinc-800 text-zinc-200">
              <DropdownMenuItem
                onClick={() => router.push("/onboarding")}
                className="text-xs cursor-pointer font-medium text-zinc-100"
              >
                + New Project
              </DropdownMenuItem>
              <DropdownMenuItem
                onClick={() => router.push("/onboarding")}
                className="text-xs cursor-pointer"
              >
                + New Application
              </DropdownMenuItem>
              <DropdownMenuSeparator className="bg-zinc-800" />
              <DropdownMenuItem
                onClick={() => setUpgradeModalOpen(true)}
                className="text-xs cursor-pointer text-zinc-400"
              >
                Connect Custom Domain
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>

      {/* Slim Next Recommended Action & Setup Tracker */}
      {!checklistDismissed && (
        <div className="rounded-lg border border-zinc-800/80 bg-gradient-to-r from-zinc-900/90 via-zinc-900/60 to-zinc-900/90 p-3.5 text-xs text-zinc-200 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div className="space-y-1">
            <div className="flex items-center gap-2">
              <span className="flex size-2 rounded-full bg-[#20C9B0] animate-pulse" />
              <span className="font-semibold text-zinc-100">
                Next Step: Trigger your first cloud build for &apos;bloom-platform&apos;
              </span>
            </div>
            <div className="flex flex-wrap items-center gap-3 text-[11px] text-zinc-400">
              <span className="flex items-center gap-1 text-emerald-400 font-medium">
                <CheckCircle className="size-3.5" weight="fill" /> Workspace Created
              </span>
              <span className="flex items-center gap-1 text-emerald-400 font-medium">
                <CheckCircle className="size-3.5" weight="fill" /> App Initialized
              </span>
              <span className="flex items-center gap-1 text-zinc-400">
                <TerminalWindow className="size-3.5" /> Authenticate CLI
              </span>
              <span className="flex items-center gap-1 text-zinc-400">
                <Hammer className="size-3.5" /> Trigger Build
              </span>
            </div>
          </div>

          <div className="flex items-center gap-2 shrink-0">
            <Button
              size="sm"
              onClick={handleTriggerFirstBuild}
              disabled={isTriggeringBuild}
              className="h-7 text-xs bg-zinc-100 text-zinc-950 hover:bg-zinc-200 font-medium cursor-pointer gap-1"
            >
              <Play className="size-3" weight="fill" />
              <span>Run Cloud Build</span>
            </Button>
            <button
              type="button"
              onClick={() => setChecklistDismissed(true)}
              className="text-zinc-500 hover:text-zinc-300 text-xs px-1.5 transition-colors cursor-pointer"
            >
              Dismiss
            </button>
          </div>
        </div>
      )}

      {/* Two-Column Vercel Layout */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
        {/* Left Column (Usage, Alerts, Recent Previews) — 5 cols */}
        <div className="lg:col-span-5 space-y-5">
          {/* Usage Card (Last 30 days) */}
          <div className="space-y-2">
            <h2 className="text-xs font-semibold text-zinc-400">Usage</h2>
            <div className="rounded-lg border border-zinc-800/80 bg-[#09090b] p-4 text-xs space-y-4">
              <div className="flex items-center justify-between">
                <span className="font-semibold text-zinc-200">Last 30 days</span>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => setUpgradeModalOpen(true)}
                  className="h-6 px-2.5 text-[11px] font-medium border-zinc-700 bg-zinc-800/80 hover:bg-zinc-800 text-zinc-100 cursor-pointer"
                >
                  Upgrade
                </Button>
              </div>

              <div className="space-y-3.5 text-xs">
                {/* Metric 1: Build Minutes */}
                <div className="flex items-center justify-between text-zinc-300">
                  <div className="flex items-center gap-2.5">
                    <CircularProgress
                      value={usage.build_minutes_used}
                      max={usage.build_minutes_limit}
                      color="#3B82F6"
                      size={16}
                      strokeWidth={2.5}
                    />
                    <span className="font-sans text-zinc-300">Build Minutes</span>
                    <Info className="size-3 text-zinc-500 hover:text-zinc-300 cursor-help" />
                  </div>
                  <span className="text-zinc-400 font-mono text-[11px]">
                    {usage.build_minutes_used}m / {usage.build_minutes_limit}m
                  </span>
                </div>

                {/* Metric 2: Fast Data Transfer */}
                <div className="flex items-center justify-between text-zinc-300">
                  <div className="flex items-center gap-2.5">
                    <CircularProgress
                      value={usage.web_bandwidth_gb_used}
                      max={usage.web_bandwidth_gb_limit}
                      color="#20C9B0"
                      size={16}
                      strokeWidth={2.5}
                    />
                    <span className="font-sans text-zinc-300">Fast Data Transfer</span>
                    <Info className="size-3 text-zinc-500 hover:text-zinc-300 cursor-help" />
                  </div>
                  <span className="text-zinc-400 font-mono text-[11px]">
                    {usage.web_bandwidth_gb_used} GB / {usage.web_bandwidth_gb_limit} GB
                  </span>
                </div>

                {/* Metric 3: Artifact Storage */}
                <div className="flex items-center justify-between text-zinc-300">
                  <div className="flex items-center gap-2.5">
                    <CircularProgress
                      value={usage.artifact_storage_gb_used}
                      max={usage.artifact_storage_gb_limit}
                      color="#8B5CF6"
                      size={16}
                      strokeWidth={2.5}
                    />
                    <span className="font-sans text-zinc-300">Artifact Storage</span>
                    <Info className="size-3 text-zinc-500 hover:text-zinc-300 cursor-help" />
                  </div>
                  <span className="text-zinc-400 font-mono text-[11px]">
                    {usage.artifact_storage_gb_used} GB / {usage.artifact_storage_gb_limit} GB
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
                    <span className="font-sans text-zinc-300">Bloom OTA Invocations</span>
                    <Info className="size-3 text-zinc-500 hover:text-zinc-300 cursor-help" />
                  </div>
                  <span className="text-zinc-400 font-mono text-[11px]">
                    14.2K / 100K
                  </span>
                </div>
              </div>

              <div className="pt-2 border-t border-zinc-800/60 flex justify-center">
                <button
                  type="button"
                  onClick={() => router.push("/usage")}
                  className="text-zinc-500 hover:text-zinc-300 text-[11px] flex items-center gap-1 transition-colors cursor-pointer"
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
            <div className="rounded-lg border border-zinc-800/80 bg-[#09090b] p-5 text-center space-y-3">
              <div className="space-y-1">
                <h3 className="text-xs font-semibold text-zinc-200">Get alerted for anomalies</h3>
                <p className="text-[11px] text-zinc-400 max-w-xs mx-auto">
                  Automatically monitor your mobile rollouts and cloud builds for crash spikes.
                </p>
              </div>
              <Button
                size="sm"
                onClick={() => setUpgradeModalOpen(true)}
                className="h-7 text-xs bg-zinc-100 text-zinc-950 hover:bg-zinc-200 font-medium cursor-pointer"
              >
                Upgrade to Pro
              </Button>
            </div>
          </div>

          {/* Recent Previews Card */}
          <div className="space-y-2">
            <h2 className="text-xs font-semibold text-zinc-400">Recent Previews</h2>
            <div className="rounded-lg border border-zinc-800/80 bg-[#09090b] p-3.5 text-xs space-y-2.5">
              <div className="flex items-center gap-2 overflow-hidden">
                <BloomFlowerIcon className="size-4 shrink-0" />
                <span className="font-mono text-[11px] text-[#20C9B0]">main</span>
                <span className="text-zinc-400 truncate text-[11px]">
                  feat(mobile): add signals reactive state & offline sync queue
                </span>
              </div>
              <div className="flex items-center justify-between text-[11px] text-zinc-500 pt-1 border-t border-zinc-800/50">
                <span className="hover:text-zinc-300 cursor-pointer transition-colors">
                  › 3 Target Platforms
                </span>
                <Link
                  href="https://github.com/Chidi09/bloom-platform"
                  target="_blank"
                  className="flex items-center gap-1 hover:text-zinc-300 transition-colors"
                >
                  <span>GitHub Source</span>
                  <ArrowSquareOut className="size-3" />
                </Link>
              </div>
            </div>
          </div>
        </div>

        {/* Right Column (Projects & Applications) — 7 cols */}
        <div className="lg:col-span-7 space-y-2">
          <div className="flex items-center justify-between">
            <h2 className="text-xs font-semibold text-zinc-400">Projects ({filteredApps.length})</h2>
            {frameworkFilter !== "all" && (
              <span className="text-[11px] text-primary capitalize font-mono">
                Filter: {frameworkFilter}
              </span>
            )}
          </div>

          {/* VIEW MODE: GRID CARDS */}
          {viewMode === "grid" ? (
            <div className="space-y-3">
              {filteredApps.map((app) => {
                const isBloom = app.framework === "bloom";
                return (
                  <div
                    key={app.id}
                    className="group rounded-lg border border-zinc-800/80 bg-[#09090b] p-4 text-xs transition-all hover:border-zinc-700 space-y-3"
                  >
                    {/* Top Row: Icon + Name + Domain + Status */}
                    <div className="flex items-start justify-between">
                      <div className="flex items-center gap-3">
                        {/* App / Framework Icon */}
                        <div className="flex size-8 shrink-0 items-center justify-center rounded-full bg-zinc-900 border border-zinc-800">
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
                              className="font-bold text-zinc-100 hover:underline text-sm"
                            >
                              {app.name}
                            </Link>
                          </div>
                          {app.domain && (
                            <Link
                              href={`https://${app.domain}`}
                              target="_blank"
                              className="text-zinc-400 hover:text-zinc-200 text-xs flex items-center gap-1 transition-colors"
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
                            className="flex size-5 items-center justify-center rounded-full bg-amber-500/10 text-amber-400 border border-amber-500/30"
                            title="Requires attention"
                          >
                            <WarningCircle className="size-3.5" weight="bold" />
                          </div>
                        ) : (
                          <div
                            className="flex size-5 items-center justify-center rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/30"
                            title="Healthy & Deployed"
                          >
                            <Check className="size-3" weight="bold" />
                          </div>
                        )}
                      </div>
                    </div>

                    {/* Middle Row: Latest Git Commit Message */}
                    {app.last_commit_message && (
                      <div className="text-zinc-300 text-xs flex items-start gap-1.5 pl-0.5">
                        <span className="text-zinc-600 font-mono select-none">--o</span>
                        <span className="truncate">{app.last_commit_message}</span>
                      </div>
                    )}

                    {/* Bottom Row: Git Author, Repo, Time, and Target Chips */}
                    <div className="flex flex-wrap items-center justify-between text-[11px] text-zinc-500 pt-1 border-t border-zinc-800/40">
                      <div className="flex items-center gap-2">
                        {app.last_commit_author ? (
                          <div className="flex items-center gap-1.5">
                            <UserAvatar
                              name={app.last_commit_author.split("/")[0] || "dev"}
                              src={
                                app.last_commit_author.toLowerCase().includes("chidi09")
                                  ? "https://github.com/Chidi09.png"
                                  : undefined
                              }
                              size={16}
                            />
                            <span className="text-zinc-400">
                              {app.last_commit_author} · {app.last_commit_time || "recent"}
                            </span>
                          </div>
                        ) : (
                          <span className="text-primary hover:underline cursor-pointer">
                            Connect Git Repository · 20h ago
                          </span>
                        )}
                      </div>

                      <div className="flex items-center gap-1 text-[10px] font-mono text-zinc-400">
                        {app.platforms?.map((p) => (
                          <span
                            key={p}
                            className="rounded bg-zinc-900 border border-zinc-800 px-1.5 py-0.2 uppercase"
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
            <div className="rounded-lg border border-zinc-800/80 bg-[#09090b] divide-y divide-zinc-800/60 overflow-hidden">
              {filteredApps.map((app) => {
                const isBloom = app.framework === "bloom";
                return (
                  <div
                    key={app.id}
                    className="p-3 hover:bg-zinc-900/60 transition-colors flex items-center justify-between gap-3 text-xs"
                  >
                    {/* Left: Icon + Title + Domain */}
                    <div className="flex items-center gap-3 min-w-[180px] max-w-[240px]">
                      <div className="flex size-7 shrink-0 items-center justify-center rounded-full bg-zinc-900 border border-zinc-800">
                        {isBloom ? (
                          <BloomFlowerIcon className="size-3.5" />
                        ) : (
                          <FlutterIcon className="size-3.5" />
                        )}
                      </div>
                      <div className="truncate">
                        <Link
                          href={`/apps/${app.id}`}
                          className="font-semibold text-zinc-100 hover:underline block truncate"
                        >
                          {app.name}
                        </Link>
                        {app.domain && (
                          <p className="text-[11px] text-zinc-500 truncate">{app.domain}</p>
                        )}
                      </div>
                    </div>

                    {/* Commit Message & Author */}
                    <div className="hidden md:flex flex-1 items-center gap-2 overflow-hidden px-2">
                      <UserAvatar
                        name={app.last_commit_author?.split("/")[0] || "dev"}
                        src={
                          app.last_commit_author?.toLowerCase().includes("chidi09")
                            ? "https://github.com/Chidi09.png"
                            : undefined
                        }
                        size={14}
                      />
                      <span className="text-zinc-400 truncate text-[11px]">
                        {app.last_commit_message || "No recent commits"}
                      </span>
                    </div>

                    {/* Targets & Status */}
                    <div className="flex items-center gap-3 shrink-0">
                      <div className="hidden sm:flex items-center gap-1 text-[9px] font-mono text-zinc-400">
                        {app.platforms?.map((p) => (
                          <span
                            key={p}
                            className="rounded bg-zinc-900 border border-zinc-800 px-1 py-0.2 uppercase"
                          >
                            {p}
                          </span>
                        ))}
                      </div>

                      {app.status === "warning" ? (
                        <div
                          className="flex size-4 items-center justify-center rounded-full bg-amber-500/10 text-amber-400 border border-amber-500/30"
                          title="Requires attention"
                        >
                          <WarningCircle className="size-3" weight="bold" />
                        </div>
                      ) : (
                        <div
                          className="flex size-4 items-center justify-center rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/30"
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

      {/* Global Pro Upgrade Modal */}
      <UpgradeModal
        open={upgradeModalOpen}
        onOpenChange={setUpgradeModalOpen}
        featureTitle="Unlock Bloom Cloud Pro"
        featureDescription="Scale your mobile and fullstack Flutter builds with Store deployment automation and higher concurrency."
      />
    </div>
  );
}
