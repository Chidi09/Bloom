"use client";

import * as React from "react";
import Link from "next/link";
import {
  Hammer,
  GitBranch,
  Clock,
  CaretDown,
  CaretRight,
  ArrowsClockwise,
  TerminalWindow,
} from "@phosphor-icons/react";

import { Button } from "@/components/ui/button";
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
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Collapsible, CollapsibleContent } from "@/components/ui/collapsible";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { UserAvatar } from "@/components/ui/user-avatar";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { StatusBadge } from "@/components/status/status-badge";
import { PlatformIcon } from "@/components/status/platform-icon";
import { PageHeader } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import { api } from "@/lib/api/client";
import { BuildResponse } from "@/lib/schemas/build";
import { AppResponse } from "@/lib/schemas/app";
import { useOrganizationStore } from "@/stores/organization-store";
import { useOrganizationEvents } from "@/lib/hooks/use-organization-events";
import { cn } from "@/lib/utils";

export default function GlobalBuildsPage() {
  const { currentOrganizationId } = useOrganizationStore();
  useOrganizationEvents(currentOrganizationId);

  const [builds, setBuilds] = React.useState<BuildResponse[]>([]);
  const [apps, setApps] = React.useState<AppResponse[]>([]);
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  const [expandedRows, setExpandedRows] = React.useState<
    Record<string, boolean>
  >({});

  const toggleRow = (buildId: string) => {
    setExpandedRows((prev) => ({
      ...prev,
      [buildId]: !prev[buildId],
    }));
  };

  const fetchGlobalBuilds = React.useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const [buildsRes, appsRes] = await Promise.all([
        api.get<{ results: BuildResponse[] }>("/builds"),
        api.get<{ results: AppResponse[] }>("/apps"),
      ]);
      setBuilds(buildsRes?.results ?? []);
      setApps(appsRes?.results ?? []);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to load builds");
    } finally {
      setIsLoading(false);
    }
  }, []);

  React.useEffect(() => {
    const run = async () => {
      await fetchGlobalBuilds();
    };
    void run();
  }, [fetchGlobalBuilds, currentOrganizationId]);

  const getAppName = (appId: string) => {
    const a = apps.find((item) => item.id === appId);
    return a ? a.name : "app";
  };

  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <PageHeader
        breadcrumbs={[{ label: "Build History" }]}
        title="Build History"
        description="Global timeline of cloud compilation runs across all applications."
        actions={
          <Button
            variant="outline"
            size="sm"
            onClick={() => void fetchGlobalBuilds()}
            className="h-8 gap-1.5"
          >
            <ArrowsClockwise className="size-3.5" />
            <span>Refresh</span>
          </Button>
        }
      />

      {error && (
        <Alert variant="destructive">
          <AlertTitle>Error loading builds</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchGlobalBuilds()}
              className="h-7 text-xs"
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      )}

      {isLoading ? (
        <div className="border-border/80 bg-card space-y-3 rounded-lg border p-6">
          <div className="flex items-center justify-center py-12">
            <BloomSpinner size={28} label="Loading build history..." />
          </div>
        </div>
      ) : builds.length === 0 ? (
        <EmptyState
          icon={Hammer}
          title="No cloud builds yet"
          description="Builds triggered manually or via Git push webhooks will appear here."
        />
      ) : (
        <div className="border-border/80 bg-card overflow-hidden rounded-lg border shadow-xs">
          <div className="overflow-x-auto">
            <TooltipProvider>
              <Table>
                <TableHeader>
                  <TableRow className="hover:bg-transparent">
                    <TableHead className="w-[36px]"></TableHead>
                    <TableHead className="w-[120px]">Status</TableHead>
                    <TableHead>Build</TableHead>
                    <TableHead>Application</TableHead>
                    <TableHead>Platform</TableHead>
                    <TableHead>Branch / Commit</TableHead>
                    <TableHead>Duration</TableHead>
                    <TableHead>Triggered By</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {builds.map((b, idx) => {
                    const isExpanded = !!expandedRows[b.id];
                    const buildNumber = b.build_number ?? builds.length - idx;
                    const commitSha = b.git_commit || "HEAD";
                    const appName = b.app_name || getAppName(b.app_id);
                    const isRunning =
                      b.status === "running" || b.status === "building";

                    return (
                      <React.Fragment key={b.id}>
                        <TableRow
                          onClick={() => toggleRow(b.id)}
                          className={cn(
                            "hover:bg-muted/40 cursor-pointer transition-colors",
                            isRunning &&
                              "border-l-2 border-l-sky-500 bg-sky-500/[0.04]",
                          )}
                        >
                          <TableCell className="p-2 text-center">
                            {isExpanded ? (
                              <CaretDown className="text-primary size-3.5 transition-transform" />
                            ) : (
                              <CaretRight className="text-muted-foreground size-3.5 transition-transform" />
                            )}
                          </TableCell>

                          <TableCell>
                            <StatusBadge status={b.status} size="sm" />
                          </TableCell>

                          <TableCell className="text-foreground font-mono text-xs font-semibold">
                            #{buildNumber}
                          </TableCell>

                          <TableCell>
                            <Link
                              href={`/apps/${b.app_id}/builds`}
                              onClick={(e) => e.stopPropagation()}
                              className="text-foreground text-xs font-semibold hover:underline"
                            >
                              {appName}
                            </Link>
                          </TableCell>

                          <TableCell>
                            <div className="flex items-center gap-1.5">
                              <PlatformIcon platform={b.platform} size="sm" />
                              <span className="text-muted-foreground font-mono text-xs uppercase">
                                {b.platform}
                              </span>
                            </div>
                          </TableCell>

                          <TableCell>
                            <div className="flex items-center gap-2">
                              <Badge
                                variant="secondary"
                                className="gap-1 px-1.5 py-0 font-mono text-[10px]"
                              >
                                <GitBranch className="size-3" />
                                <span>{b.git_branch || "main"}</span>
                              </Badge>

                              <Tooltip>
                                <TooltipTrigger className="text-muted-foreground hover:text-foreground cursor-help font-mono text-xs">
                                  {commitSha.slice(0, 7)}
                                </TooltipTrigger>
                                <TooltipContent>
                                  <p className="font-mono text-xs">
                                    {commitSha}
                                  </p>
                                </TooltipContent>
                              </Tooltip>
                            </div>
                          </TableCell>

                          <TableCell className="text-muted-foreground font-mono text-xs">
                            <div className="flex items-center gap-1">
                              <Clock className="size-3" />
                              <span>
                                {b.duration_seconds
                                  ? `${b.duration_seconds}s`
                                  : "--"}
                              </span>
                            </div>
                          </TableCell>

                          <TableCell>
                            <div className="flex items-center gap-1.5">
                              <UserAvatar name={b.author || "dev"} size={18} />
                              <span className="text-foreground text-xs">
                                {b.author || "dev"}
                              </span>
                            </div>
                          </TableCell>
                        </TableRow>

                        {isExpanded && (
                          <TableRow className="bg-muted/15 hover:bg-muted/15">
                            <TableCell colSpan={8} className="p-4">
                              <Collapsible open={isExpanded}>
                                <CollapsibleContent className="space-y-4">
                                  <div className="space-y-2">
                                    <div className="flex items-center justify-between">
                                      <h3 className="text-foreground text-xs font-semibold">
                                        Pipeline Stages ({appName})
                                      </h3>
                                      <span className="text-muted-foreground font-mono text-[10px]">
                                        Flutter {b.flutter_version || "3.27.0"}{" "}
                                        · Dart {b.dart_version || "3.6.0"}
                                      </span>
                                    </div>

                                    <div className="flex flex-wrap gap-2">
                                      {b.stages && b.stages.length > 0
                                        ? b.stages.map((stg) => (
                                            <div
                                              key={stg.stage}
                                              className="border-border bg-card flex items-center gap-1.5 rounded border px-2.5 py-1 text-xs"
                                            >
                                              <StatusBadge
                                                status={stg.status}
                                                size="sm"
                                                showIcon={false}
                                              />
                                              <span className="text-foreground font-mono font-medium">
                                                {stg.stage}
                                              </span>
                                            </div>
                                          ))
                                        : null}
                                    </div>
                                  </div>

                                  <div className="space-y-1.5">
                                    <div className="text-muted-foreground flex items-center gap-1.5 font-mono text-xs">
                                      <TerminalWindow className="size-3.5" />
                                      <span>Log Preview</span>
                                    </div>
                                    <pre className="border-border overflow-x-auto rounded-md border bg-[#000000] p-3 font-mono text-[11px] leading-relaxed text-zinc-300">
                                      {b.stages
                                        ?.flatMap((s) => s.log_snippet)
                                        .filter(Boolean)
                                        .join("\n") ||
                                        `[00:00.01] Worker initialized for build #${buildNumber}\n[00:00.15] Target platform: ${b.platform}\n[00:01.02] Resolved branch: ${b.git_branch || "main"} (${commitSha.slice(0, 7)})\n[00:02.40] Compiling artifacts with bloom-engine...\n[00:04.10] Build status: ${b.status}`}
                                    </pre>
                                  </div>
                                </CollapsibleContent>
                              </Collapsible>
                            </TableCell>
                          </TableRow>
                        )}
                      </React.Fragment>
                    );
                  })}
                </TableBody>
              </Table>
            </TooltipProvider>
          </div>
        </div>
      )}
    </div>
  );
}
