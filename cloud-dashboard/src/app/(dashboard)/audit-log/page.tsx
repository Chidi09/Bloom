"use client";

import * as React from "react";
import {
  Scroll,
  ArrowsClockwise,
  MagnifyingGlass,
  Calendar as CalendarIcon,
  CaretDown,
  CaretRight,
  ShieldCheck,
  Key,
  GitFork,
  CreditCard,
  Lock,
  X,
} from "@phosphor-icons/react";
import { format } from "date-fns";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { Calendar } from "@/components/ui/calendar";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { UserAvatar } from "@/components/ui/user-avatar";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { PageHeader } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import { api } from "@/lib/api/client";
import { AuditLogEntry } from "@/lib/schemas/audit-log";
import { useOrganizationStore } from "@/stores/organization-store";

const ACTION_CATEGORIES = [
  { label: "All Actions", value: "all" },
  { label: "Secrets (secret.*)", value: "secret" },
  { label: "Signing Keys (signing_identity.*)", value: "signing" },
  { label: "Workflows (workflow.*)", value: "workflow" },
  { label: "Members (member.*)", value: "member" },
  { label: "Billing & Invoices (billing.*)", value: "billing" },
];

export default function AuditLogPage() {
  const { currentOrganizationId } = useOrganizationStore();

  const [logs, setLogs] = React.useState<AuditLogEntry[]>([]);
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Filters
  const [actionFilter, setActionFilter] = React.useState("all");
  const [actorQuery, setActorQuery] = React.useState("");
  const [selectedDate, setSelectedDate] = React.useState<Date | undefined>(
    undefined,
  );
  const [datePopoverOpen, setDatePopoverOpen] = React.useState(false);

  // Expanded rows map
  const [expandedRows, setExpandedRows] = React.useState<
    Record<string, boolean>
  >({});

  const toggleRow = (id: string) => {
    setExpandedRows((prev) => ({
      ...prev,
      [id]: !prev[id],
    }));
  };

  const fetchAuditLogs = React.useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const params: Record<string, string | undefined> = {};
      if (actionFilter !== "all") params.action = actionFilter;
      if (actorQuery.trim()) params.actor = actorQuery.trim();
      if (selectedDate) {
        params.from = new Date(selectedDate.setHours(0, 0, 0, 0)).toISOString();
        params.to = new Date(
          selectedDate.setHours(23, 59, 59, 999),
        ).toISOString();
      }

      const res = await api.get<{ results: AuditLogEntry[] }>("/audit-log", {
        params,
      });
      setLogs(res?.results ?? []);
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Failed to load audit logs",
      );
    } finally {
      setIsLoading(false);
    }
  }, [actionFilter, actorQuery, selectedDate]);

  React.useEffect(() => {
    const run = async () => {
      await fetchAuditLogs();
    };
    void run();
  }, [fetchAuditLogs, currentOrganizationId]);

  const clearFilters = () => {
    setActionFilter("all");
    setActorQuery("");
    setSelectedDate(undefined);
  };

  const hasActiveFilters =
    actionFilter !== "all" ||
    actorQuery.trim() !== "" ||
    selectedDate !== undefined;

  const getActionBadge = (action: string) => {
    if (action.startsWith("secret.")) {
      return (
        <Badge
          variant="outline"
          className="gap-1 border-amber-500/30 bg-amber-500/10 font-mono text-[11px] text-amber-400"
        >
          <Key className="size-3 shrink-0" />
          <span>{action}</span>
        </Badge>
      );
    }
    if (action.startsWith("signing")) {
      return (
        <Badge
          variant="outline"
          className="gap-1 border-purple-500/30 bg-purple-500/10 font-mono text-[11px] text-purple-400"
        >
          <ShieldCheck className="size-3 shrink-0" />
          <span>{action}</span>
        </Badge>
      );
    }
    if (action.startsWith("workflow.")) {
      return (
        <Badge
          variant="outline"
          className="gap-1 border-blue-500/30 bg-blue-500/10 font-mono text-[11px] text-blue-400"
        >
          <GitFork className="size-3 shrink-0" />
          <span>{action}</span>
        </Badge>
      );
    }
    if (action.startsWith("billing.")) {
      return (
        <Badge
          variant="outline"
          className="gap-1 border-emerald-500/30 bg-emerald-500/10 font-mono text-[11px] text-emerald-400"
        >
          <CreditCard className="size-3 shrink-0" />
          <span>{action}</span>
        </Badge>
      );
    }
    return (
      <Badge variant="outline" className="font-mono text-[11px] text-zinc-300">
        {action}
      </Badge>
    );
  };

  const renderActor = (actor: AuditLogEntry["actor"]) => {
    if (typeof actor === "string") {
      return (
        <div className="flex items-center gap-2">
          <UserAvatar name={actor} size={20} />
          <span className="text-xs font-medium text-zinc-200">{actor}</span>
        </div>
      );
    }
    return (
      <div className="flex items-center gap-2">
        <UserAvatar name={actor.name || actor.email} size={20} />
        <div>
          <p className="text-xs font-medium text-zinc-200">{actor.name}</p>
          <p className="font-mono text-[10px] text-zinc-500">{actor.email}</p>
        </div>
      </div>
    );
  };

  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <PageHeader
        breadcrumbs={[{ label: "Audit Log" }]}
        title="Audit Log"
        description="Immutable record of administrative operations, cryptographic operations, secrets mutations, and security events."
        actions={
          <Button
            variant="outline"
            size="sm"
            onClick={() => void fetchAuditLogs()}
            className="h-8 gap-1.5"
          >
            <ArrowsClockwise className="size-3.5" />
            <span>Refresh</span>
          </Button>
        }
      />

      {error && (
        <Alert variant="destructive">
          <AlertTitle>Failed to load audit log</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchAuditLogs()}
              className="h-7 text-xs"
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      )}

      {/* Filter Bar */}
      <div className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-zinc-800 bg-[#09090b] p-3">
        <div className="flex flex-wrap items-center gap-2.5">
          {/* Action Category Filter */}
          <Select
            value={actionFilter}
            onValueChange={(v) => v && setActionFilter(v)}
          >
            <SelectTrigger className="h-8 w-44 text-xs font-medium">
              <SelectValue placeholder="Action Type" />
            </SelectTrigger>
            <SelectContent>
              {ACTION_CATEGORIES.map((cat) => (
                <SelectItem
                  key={cat.value}
                  value={cat.value}
                  className="text-xs"
                >
                  {cat.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>

          {/* Actor Query Input */}
          <div className="relative">
            <MagnifyingGlass className="absolute top-2 left-2.5 size-3.5 text-zinc-500" />
            <Input
              type="text"
              placeholder="Filter by actor..."
              value={actorQuery}
              onChange={(e) => setActorQuery(e.target.value)}
              className="h-8 w-44 pl-8 text-xs"
            />
          </div>

          {/* Date Picker Filter */}
          <Popover open={datePopoverOpen} onOpenChange={setDatePopoverOpen}>
            <PopoverTrigger className="inline-flex h-8 items-center gap-1.5 rounded-md border border-zinc-800 bg-zinc-900 px-3 text-xs text-zinc-300 hover:bg-zinc-800">
              <CalendarIcon className="size-3.5 text-zinc-500" />
              <span>
                {selectedDate
                  ? format(selectedDate, "MMM d, yyyy")
                  : "Date Range"}
              </span>
            </PopoverTrigger>
            <PopoverContent
              align="start"
              className="w-auto border-zinc-800 bg-zinc-950 p-0"
            >
              <Calendar
                mode="single"
                selected={selectedDate}
                onSelect={(d) => {
                  setSelectedDate(d);
                  setDatePopoverOpen(false);
                }}
              />
            </PopoverContent>
          </Popover>

          {hasActiveFilters && (
            <Button
              variant="ghost"
              size="sm"
              onClick={clearFilters}
              className="h-8 gap-1 px-2 text-xs text-zinc-400 hover:text-zinc-200"
            >
              <X className="size-3" />
              <span>Clear filters</span>
            </Button>
          )}
        </div>

        <div className="font-mono text-xs text-zinc-500">
          Showing{" "}
          <span className="font-semibold text-zinc-300">{logs.length}</span>{" "}
          security events
        </div>
      </div>

      {isLoading ? (
        <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-16">
          <BloomSpinner size={28} label="Loading audit logs..." />
        </div>
      ) : logs.length === 0 ? (
        <EmptyState
          icon={Scroll}
          title="No audit events found"
          description={
            hasActiveFilters
              ? "No events match the selected action, actor, or date filters."
              : "Administrative and security actions will be recorded here automatically."
          }
          actionNode={
            hasActiveFilters ? (
              <Button variant="outline" size="sm" onClick={clearFilters}>
                Reset Filters
              </Button>
            ) : undefined
          }
        />
      ) : (
        <div className="border-border/80 bg-card overflow-hidden rounded-lg border">
          <Table>
            <TableHeader>
              <TableRow className="hover:bg-transparent">
                <TableHead className="w-[36px]"></TableHead>
                <TableHead className="w-[180px]">Action</TableHead>
                <TableHead>Actor</TableHead>
                <TableHead>Resource</TableHead>
                <TableHead>IP Address</TableHead>
                <TableHead className="text-right">Timestamp</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {logs.map((entry) => {
                const isExpanded = !!expandedRows[entry.id];
                const hasDiff =
                  entry.before_snapshot !== null ||
                  entry.after_snapshot !== null;

                return (
                  <React.Fragment key={entry.id}>
                    <TableRow
                      onClick={() => toggleRow(entry.id)}
                      className="hover:bg-muted/40 cursor-pointer transition-colors"
                    >
                      <TableCell className="p-2 text-center">
                        {isExpanded ? (
                          <CaretDown className="text-muted-foreground size-3.5" />
                        ) : (
                          <CaretRight className="text-muted-foreground size-3.5" />
                        )}
                      </TableCell>

                      <TableCell>{getActionBadge(entry.action)}</TableCell>

                      <TableCell>{renderActor(entry.actor)}</TableCell>

                      <TableCell>
                        <div className="space-y-0.5 font-mono text-xs">
                          <span className="text-zinc-400 capitalize">
                            {entry.resource_type}:
                          </span>
                          <span className="ml-1.5 font-medium text-zinc-200">
                            {entry.resource_id}
                          </span>
                        </div>
                      </TableCell>

                      <TableCell className="font-mono text-xs text-zinc-400">
                        {entry.ip_address}
                      </TableCell>

                      <TableCell className="text-right font-mono text-xs text-zinc-400">
                        {new Date(entry.created_at).toLocaleString([], {
                          year: "numeric",
                          month: "short",
                          day: "numeric",
                          hour: "2-digit",
                          minute: "2-digit",
                          second: "2-digit",
                        })}
                      </TableCell>
                    </TableRow>

                    {/* Expandable Two-Column Diff Row */}
                    {isExpanded && (
                      <TableRow className="bg-zinc-950/80 hover:bg-zinc-950/80">
                        <TableCell colSpan={6} className="p-4">
                          <div className="space-y-3">
                            <div className="flex items-center justify-between border-b border-zinc-800 pb-2">
                              <div className="flex items-center gap-2">
                                <Lock className="size-3.5 text-zinc-500" />
                                <span className="font-mono text-xs font-medium text-zinc-300">
                                  State Snapshot & Redacted Payload Diff
                                </span>
                              </div>
                              <span className="font-mono text-[10px] text-zinc-500">
                                Event ID: {entry.id}
                              </span>
                            </div>

                            {hasDiff ? (
                              <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                                {/* Before Snapshot */}
                                <div className="space-y-1.5">
                                  <div className="flex items-center justify-between text-[11px] font-medium text-zinc-400">
                                    <span>Before State</span>
                                    {entry.before_snapshot === null && (
                                      <span className="font-mono text-zinc-600">
                                        (None / Created)
                                      </span>
                                    )}
                                  </div>
                                  <pre className="max-h-56 overflow-y-auto rounded border border-zinc-800 bg-black p-3 font-mono text-xs leading-relaxed text-zinc-300">
                                    {entry.before_snapshot !== null
                                      ? JSON.stringify(
                                          entry.before_snapshot,
                                          null,
                                          2,
                                        )
                                      : "null"}
                                  </pre>
                                </div>

                                {/* After Snapshot */}
                                <div className="space-y-1.5">
                                  <div className="flex items-center justify-between text-[11px] font-medium text-zinc-400">
                                    <span>After State</span>
                                    {entry.after_snapshot === null && (
                                      <span className="font-mono text-zinc-600">
                                        (Deleted)
                                      </span>
                                    )}
                                  </div>
                                  <pre className="max-h-56 overflow-y-auto rounded border border-zinc-800 bg-black p-3 font-mono text-xs leading-relaxed text-zinc-300">
                                    {entry.after_snapshot !== null
                                      ? JSON.stringify(
                                          entry.after_snapshot,
                                          null,
                                          2,
                                        )
                                      : "null"}
                                  </pre>
                                </div>
                              </div>
                            ) : (
                              <p className="font-mono text-xs text-zinc-500">
                                No state diff captured for this action type.
                              </p>
                            )}
                          </div>
                        </TableCell>
                      </TableRow>
                    )}
                  </React.Fragment>
                );
              })}
            </TableBody>
          </Table>
        </div>
      )}
    </div>
  );
}
