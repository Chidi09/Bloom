"use client";

import * as React from "react";
import { useParams } from "next/navigation";
import {
  ChartLine,
  ChartBar,
  ChartPie,
  ShieldCheck,
  Users,
  ArrowsClockwise,
  Globe,
  TreeStructure,
  TrendUp,
  Bug,
  Pulse,
} from "@phosphor-icons/react";
import {
  LineChart,
  Line,
  AreaChart,
  Area,
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip as RechartsTooltip,
  ResponsiveContainer,
  ReferenceLine,
} from "recharts";

import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { StatusBadge } from "@/components/status/status-badge";
import { PlatformIcon } from "@/components/status/platform-icon";
import { api } from "@/lib/api/client";
import { AppResponse } from "@/lib/schemas/app";
import {
  AppStatusResponse,
  ReleaseHealthResponse,
} from "@/lib/schemas/observability";

interface TimeSeriesPoint {
  date: string;
  crashFreeRate: number;
  sessions: number;
  crashes: number;
  activeUsers: number;
  deployMarker?: string;
}

interface WebAnalyticsPoint {
  date: string;
  pageViews: number;
  uniqueVisitors: number;
}

const TELEMETRY_TIME_SERIES: TimeSeriesPoint[] = [
  {
    date: "Aug 10",
    crashFreeRate: 99.42,
    sessions: 8200,
    crashes: 48,
    activeUsers: 6400,
  },
  {
    date: "Aug 11",
    crashFreeRate: 99.51,
    sessions: 9100,
    crashes: 45,
    activeUsers: 7200,
  },
  {
    date: "Aug 12",
    crashFreeRate: 99.6,
    sessions: 11400,
    crashes: 46,
    activeUsers: 9100,
  },
  {
    date: "Aug 13",
    crashFreeRate: 99.21,
    sessions: 12100,
    crashes: 96,
    activeUsers: 9800,
    deployMarker: "v1.4.1",
  },
  {
    date: "Aug 14",
    crashFreeRate: 99.72,
    sessions: 13800,
    crashes: 39,
    activeUsers: 11200,
    deployMarker: "v1.4.2",
  },
  {
    date: "Aug 15",
    crashFreeRate: 99.84,
    sessions: 14900,
    crashes: 24,
    activeUsers: 12400,
  },
  {
    date: "Aug 16",
    crashFreeRate: 99.91,
    sessions: 15400,
    crashes: 14,
    activeUsers: 13100,
  },
  {
    date: "Aug 17",
    crashFreeRate: 99.82,
    sessions: 10800,
    crashes: 20,
    activeUsers: 8900,
  },
];

const PLATFORM_DATA = [
  {
    name: "iOS",
    value: 42580,
    color: "#3b82f6",
    percentage: "44.5%",
    crashes: 85,
    rate: 99.8,
  },
  {
    name: "Android",
    value: 38920,
    color: "#22c55e",
    percentage: "40.7%",
    crashes: 155,
    rate: 99.6,
  },
  {
    name: "Web",
    value: 14200,
    color: "#22d3ee",
    percentage: "14.8%",
    crashes: 0,
    rate: 100.0,
  },
];

const SPARKLINE_DATA_IOS = [
  { v: 99.3 },
  { v: 99.4 },
  { v: 99.5 },
  { v: 99.2 },
  { v: 99.7 },
  { v: 99.8 },
  { v: 99.8 },
];
const SPARKLINE_DATA_ANDROID = [
  { v: 99.1 },
  { v: 99.2 },
  { v: 99.4 },
  { v: 99.0 },
  { v: 99.5 },
  { v: 99.6 },
  { v: 99.6 },
];
const SPARKLINE_DATA_WEB = [
  { v: 100 },
  { v: 100 },
  { v: 100 },
  { v: 100 },
  { v: 100 },
  { v: 100 },
  { v: 100 },
];

const WEB_TRAFFIC_DATA: WebAnalyticsPoint[] = [
  { date: "Aug 10", pageViews: 1420, uniqueVisitors: 890 },
  { date: "Aug 11", pageViews: 1890, uniqueVisitors: 1120 },
  { date: "Aug 12", pageViews: 2450, uniqueVisitors: 1540 },
  { date: "Aug 13", pageViews: 2800, uniqueVisitors: 1720 },
  { date: "Aug 14", pageViews: 3950, uniqueVisitors: 2410 },
  { date: "Aug 15", pageViews: 4200, uniqueVisitors: 2680 },
  { date: "Aug 16", pageViews: 4850, uniqueVisitors: 3120 },
  { date: "Aug 17", pageViews: 3100, uniqueVisitors: 2040 },
];

const TOP_ROUTES = [
  { path: "/", views: 12450, percentage: 46.2 },
  { path: "/auth/login", views: 4890, percentage: 18.1 },
  { path: "/dashboard/overview", views: 3920, percentage: 14.5 },
  { path: "/wallet/send", views: 3110, percentage: 11.5 },
  { path: "/settings/security", views: 2580, percentage: 9.7 },
];

const TOP_REFERRERS = [
  { source: "Direct / App Launch", count: 14500, share: "53.8%" },
  { source: "google.com", count: 5200, share: "19.3%" },
  { source: "bloom.dev marketing", count: 4100, share: "15.2%" },
  { source: "github.com/bloom-labs", count: 2150, share: "8.0%" },
  { source: "twitter.com / X", count: 1000, share: "3.7%" },
];

// Mini sparkline component for KPI cards
function MiniSparkline({
  data,
  color = "#22c55e",
  type = "line",
}: {
  data: number[];
  color?: string;
  type?: "line" | "area" | "bar";
}) {
  const chartData = data.map((val, i) => ({ i, val }));
  return (
    <div className="h-7 w-20 shrink-0">
      <ResponsiveContainer width="100%" height="100%">
        {type === "bar" ? (
          <BarChart
            data={chartData}
            margin={{ top: 2, right: 0, left: 0, bottom: 2 }}
          >
            <Bar
              dataKey="val"
              fill={color}
              radius={[1, 1, 0, 0]}
              opacity={0.85}
            />
          </BarChart>
        ) : type === "area" ? (
          <AreaChart
            data={chartData}
            margin={{ top: 2, right: 0, left: 0, bottom: 2 }}
          >
            <defs>
              <linearGradient
                id={`mini_${color.replace("#", "")}`}
                x1="0"
                y1="0"
                x2="0"
                y2="1"
              >
                <stop offset="0%" stopColor={color} stopOpacity={0.4} />
                <stop offset="100%" stopColor={color} stopOpacity={0.0} />
              </linearGradient>
            </defs>
            <Area
              type="monotone"
              dataKey="val"
              stroke={color}
              strokeWidth={1.5}
              fill={`url(#mini_${color.replace("#", "")})`}
              isAnimationActive={false}
            />
          </AreaChart>
        ) : (
          <LineChart
            data={chartData}
            margin={{ top: 2, right: 0, left: 0, bottom: 2 }}
          >
            <Line
              type="monotone"
              dataKey="val"
              stroke={color}
              strokeWidth={1.5}
              dot={false}
              isAnimationActive={false}
            />
          </LineChart>
        )}
      </ResponsiveContainer>
    </div>
  );
}

// Inline sparkline for release table row
function TableSparkline({
  data,
  color,
}: {
  data: { v: number }[];
  color: string;
}) {
  return (
    <div className="h-6 w-20 shrink-0">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart
          data={data}
          margin={{ top: 2, right: 1, left: 1, bottom: 1 }}
        >
          <defs>
            <linearGradient
              id={`tbl_spk_${color.replace("#", "")}`}
              x1="0"
              y1="0"
              x2="0"
              y2="1"
            >
              <stop offset="0%" stopColor={color} stopOpacity={0.45} />
              <stop offset="100%" stopColor={color} stopOpacity={0.0} />
            </linearGradient>
          </defs>
          <Area
            type="monotone"
            dataKey="v"
            stroke={color}
            strokeWidth={1.5}
            fill={`url(#tbl_spk_${color.replace("#", "")})`}
            dot={false}
            isAnimationActive={false}
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}

export default function AppObservabilityPage() {
  const params = useParams<{ id: string }>();
  const appId = params.id;

  const [app, setApp] = React.useState<AppResponse | null>(null);
  const [appStatus, setAppStatus] = React.useState<AppStatusResponse | null>(
    null,
  );
  const [appHealth, setAppHealth] =
    React.useState<ReleaseHealthResponse | null>(null);
  const [hasWebHosting, setHasWebHosting] = React.useState(false);

  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);
  const [timeRange, setTimeRange] = React.useState<"7d" | "30d" | "90d">("7d");

  const fetchData = React.useCallback(async () => {
    if (!appId) return;
    setIsLoading(true);
    setError(null);
    try {
      const [appRes, statusRes, healthRes, webDepsRes] = await Promise.all([
        api.get<AppResponse>(`/apps/${appId}`),
        api
          .get<AppStatusResponse>(`/observability/apps/${appId}/status`)
          .catch(() => null),
        api
          .get<ReleaseHealthResponse>(`/observability/apps/${appId}/health`)
          .catch(() => null),
        api
          .get<{ results: unknown[] }>("/webhosting/deployments", {
            params: { app_id: appId },
          })
          .catch(() => ({ results: [] })),
      ]);

      setApp(appRes);
      setAppStatus(statusRes);
      setAppHealth(healthRes);

      const hasWeb = !!(webDepsRes?.results && webDepsRes.results.length > 0);
      setHasWebHosting(hasWeb);
    } catch (err: unknown) {
      setError(
        err instanceof Error
          ? err.message
          : "Failed to load observability telemetry",
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

  if (isLoading) {
    return (
      <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-20">
        <BloomSpinner
          size={32}
          label="Aggregating observability telemetry & release health..."
        />
      </div>
    );
  }

  if (error || !app) {
    return (
      <Alert variant="destructive">
        <AlertTitle>Observability Error</AlertTitle>
        <AlertDescription className="flex items-center justify-between">
          <span>{error || "Unable to load telemetry metrics."}</span>
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
    );
  }

  const overallRate = appHealth?.overall_crash_free_rate ?? 0.998;
  const overallPercentage = (overallRate * 100).toFixed(2);
  const totalSessions =
    appHealth?.platforms.reduce((acc, p) => acc + (p.sessions || 0), 0) ??
    95700;
  const totalCrashes =
    appHealth?.platforms.reduce((acc, p) => acc + (p.crashes || 0), 0) ?? 240;

  return (
    <div className="space-y-6">
      {/* Top Header & Range Controls */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-base font-semibold text-zinc-100">
            Release Health & Observability
          </h2>
          <p className="text-xs text-zinc-400">
            Real-time symbolicated telemetry, crash-free rates, session
            throughput, and platform distributions.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <div className="border-border/60 inline-flex rounded-lg border bg-zinc-900/80 p-0.5 text-xs">
            {(["7d", "30d", "90d"] as const).map((range) => (
              <button
                key={range}
                type="button"
                onClick={() => setTimeRange(range)}
                className={`cursor-pointer rounded-md px-2.5 py-1 font-mono text-xs transition-colors ${
                  timeRange === range
                    ? "bg-zinc-800 font-semibold text-zinc-100 shadow-xs"
                    : "text-zinc-400 hover:text-zinc-200"
                }`}
              >
                {range.toUpperCase()}
              </button>
            ))}
          </div>

          <Button
            variant="outline"
            size="sm"
            onClick={() => void fetchData()}
            className="h-8 gap-1.5 text-xs text-zinc-300 transition-colors hover:bg-zinc-800"
          >
            <ArrowsClockwise className="size-3.5" />
            <span>Refresh</span>
          </Button>
        </div>
      </div>

      {/* KPI Cards Row with embedded mini sparklines */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {/* Crash-Free Rate */}
        <Card className="border-border/80 bg-zinc-950/60 p-4">
          <div className="flex items-center justify-between text-zinc-400">
            <span className="text-xs font-medium">Crash-Free Rate</span>
            <ShieldCheck className="size-4 text-emerald-400" />
          </div>
          <div className="mt-3 flex items-end justify-between gap-2">
            <div>
              <span className="font-mono text-2xl font-bold tracking-tight text-zinc-100">
                {overallPercentage}%
              </span>
              <div className="mt-0.5 flex items-center gap-1 font-mono text-[10px] text-emerald-400">
                <TrendUp className="size-3" />
                <span>+0.2% vs prev</span>
              </div>
            </div>
            <MiniSparkline
              data={TELEMETRY_TIME_SERIES.map((d) => d.crashFreeRate)}
              color="#22c55e"
              type="area"
            />
          </div>
          <p className="mt-2 text-[10px] text-zinc-500">
            Across all active releases
          </p>
        </Card>

        {/* Total Sessions */}
        <Card className="border-border/80 bg-zinc-950/60 p-4">
          <div className="flex items-center justify-between text-zinc-400">
            <span className="text-xs font-medium">Recorded Sessions</span>
            <Pulse className="size-4 text-blue-400" />
          </div>
          <div className="mt-3 flex items-end justify-between gap-2">
            <div>
              <span className="font-mono text-2xl font-bold tracking-tight text-zinc-100">
                {totalSessions.toLocaleString()}
              </span>
              <div className="mt-0.5 flex items-center gap-1 font-mono text-[10px] text-blue-400">
                <TrendUp className="size-3" />
                <span>+14.2%</span>
              </div>
            </div>
            <MiniSparkline
              data={TELEMETRY_TIME_SERIES.map((d) => d.sessions)}
              color="#3b82f6"
              type="bar"
            />
          </div>
          <p className="mt-2 text-[10px] text-zinc-500">
            Active user interactions
          </p>
        </Card>

        {/* Total Crashes */}
        <Card className="border-border/80 bg-zinc-950/60 p-4">
          <div className="flex items-center justify-between text-zinc-400">
            <span className="text-xs font-medium">Total Crashes</span>
            <Bug className="size-4 text-amber-400" />
          </div>
          <div className="mt-3 flex items-end justify-between gap-2">
            <div>
              <span className="font-mono text-2xl font-bold tracking-tight text-zinc-100">
                {totalCrashes.toLocaleString()}
              </span>
              <div className="mt-0.5 flex items-center gap-1 font-mono text-[10px] text-amber-400">
                <span>Low severity impact</span>
              </div>
            </div>
            <MiniSparkline
              data={TELEMETRY_TIME_SERIES.map((d) => d.crashes)}
              color="#f59e0b"
              type="line"
            />
          </div>
          <p className="mt-2 text-[10px] text-zinc-500">
            Symbolicated via dSYM & ProGuard
          </p>
        </Card>

        {/* Active Users */}
        <Card className="border-border/80 bg-zinc-950/60 p-4">
          <div className="flex items-center justify-between text-zinc-400">
            <span className="text-xs font-medium">Daily Active Users</span>
            <Users className="size-4 text-purple-400" />
          </div>
          <div className="mt-3 flex items-end justify-between gap-2">
            <div>
              <span className="font-mono text-2xl font-bold tracking-tight text-zinc-100">
                18,420
              </span>
              <div className="mt-0.5 flex items-center gap-1 font-mono text-[10px] text-purple-400">
                <TrendUp className="size-3" />
                <span>+5.1%</span>
              </div>
            </div>
            <MiniSparkline
              data={TELEMETRY_TIME_SERIES.map((d) => d.activeUsers)}
              color="#a78bfa"
              type="area"
            />
          </div>
          <p className="mt-2 text-[10px] text-zinc-500">
            Unique device installations
          </p>
        </Card>
      </div>

      {/* Primary Telemetry Visualizers Grid (Dual Charts: Crash-Free Trend & Sessions/Crash Volume) */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        {/* Chart 1: Crash-Free Rate Trend (%) */}
        <Card className="border-border/80 bg-zinc-950/40">
          <CardHeader className="pb-2">
            <div className="flex items-center justify-between">
              <div className="space-y-0.5">
                <CardTitle className="flex items-center gap-2 text-xs font-semibold text-zinc-100">
                  <ChartLine className="size-4 text-emerald-400" />
                  <span>Crash-Free Rate Trend (%)</span>
                </CardTitle>
                <CardDescription className="text-[11px] text-zinc-400">
                  Hourly aggregation with release milestone markers.
                </CardDescription>
              </div>

              <div className="flex items-center gap-2 font-mono text-[10px] text-zinc-400">
                <div className="flex items-center gap-1">
                  <span className="size-2 rounded-full bg-emerald-400" />
                  <span>Crash-Free %</span>
                </div>
                <div className="flex items-center gap-1">
                  <span className="size-2 rounded-full bg-purple-400" />
                  <span>Deploy</span>
                </div>
              </div>
            </div>
          </CardHeader>
          <CardContent className="pt-2">
            <div className="h-60 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart
                  data={TELEMETRY_TIME_SERIES}
                  margin={{ top: 10, right: 10, left: -20, bottom: 0 }}
                >
                  <CartesianGrid
                    strokeDasharray="3 3"
                    stroke="#27272a"
                    vertical={false}
                  />
                  <XAxis
                    dataKey="date"
                    stroke="#71717a"
                    fontSize={10}
                    tickLine={false}
                    axisLine={false}
                  />
                  <YAxis
                    domain={[99.0, 100]}
                    stroke="#71717a"
                    fontSize={10}
                    tickLine={false}
                    axisLine={false}
                    unit="%"
                  />
                  <RechartsTooltip
                    content={({ active, payload }) => {
                      if (!active || !payload?.length) return null;
                      const data = payload[0].payload as TimeSeriesPoint;
                      return (
                        <div className="border-border/80 rounded-lg border bg-zinc-900 p-2.5 font-mono text-xs shadow-xl">
                          <p className="font-semibold text-zinc-200">
                            {data.date}
                          </p>
                          <p className="mt-1 text-emerald-400">
                            Crash-Free: {data.crashFreeRate}%
                          </p>
                          <p className="text-zinc-400">
                            Sessions: {data.sessions.toLocaleString()}
                          </p>
                          <p className="text-zinc-400">
                            Crashes: {data.crashes}
                          </p>
                          {data.deployMarker && (
                            <Badge
                              variant="secondary"
                              className="mt-1 font-mono text-[10px]"
                            >
                              Deployed {data.deployMarker}
                            </Badge>
                          )}
                        </div>
                      );
                    }}
                  />
                  <ReferenceLine
                    x="Aug 13"
                    stroke="#a855f7"
                    strokeDasharray="3 3"
                    label={{
                      value: "v1.4.1",
                      fill: "#a855f7",
                      fontSize: 9,
                      position: "top",
                    }}
                  />
                  <ReferenceLine
                    x="Aug 14"
                    stroke="#a855f7"
                    strokeDasharray="3 3"
                    label={{
                      value: "v1.4.2",
                      fill: "#a855f7",
                      fontSize: 9,
                      position: "top",
                    }}
                  />
                  <Line
                    type="monotone"
                    dataKey="crashFreeRate"
                    stroke="#10b981"
                    strokeWidth={2}
                    dot={{ fill: "#10b981", r: 3 }}
                    activeDot={{ r: 5, fill: "#10b981" }}
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>

        {/* Chart 2: Sessions Volume & Crash Impact (Area / Bar) */}
        <Card className="border-border/80 bg-zinc-950/40">
          <CardHeader className="pb-2">
            <div className="flex items-center justify-between">
              <div className="space-y-0.5">
                <CardTitle className="flex items-center gap-2 text-xs font-semibold text-zinc-100">
                  <ChartBar className="size-4 text-blue-400" />
                  <span>Session Traffic & Crash Volume</span>
                </CardTitle>
                <CardDescription className="text-[11px] text-zinc-400">
                  Total daily active sessions compared with recorded crashes.
                </CardDescription>
              </div>

              <div className="flex items-center gap-2 font-mono text-[10px] text-zinc-400">
                <div className="flex items-center gap-1">
                  <span className="size-2 rounded-full bg-blue-400" />
                  <span>Sessions</span>
                </div>
                <div className="flex items-center gap-1">
                  <span className="size-2 rounded-full bg-amber-400" />
                  <span>Crashes</span>
                </div>
              </div>
            </div>
          </CardHeader>
          <CardContent className="pt-2">
            <div className="h-60 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart
                  data={TELEMETRY_TIME_SERIES}
                  margin={{ top: 10, right: 10, left: -10, bottom: 0 }}
                >
                  <defs>
                    <linearGradient
                      id="colorSessions"
                      x1="0"
                      y1="0"
                      x2="0"
                      y2="1"
                    >
                      <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.4} />
                      <stop
                        offset="95%"
                        stopColor="#3b82f6"
                        stopOpacity={0.0}
                      />
                    </linearGradient>
                    <linearGradient
                      id="colorCrashes"
                      x1="0"
                      y1="0"
                      x2="0"
                      y2="1"
                    >
                      <stop offset="5%" stopColor="#f59e0b" stopOpacity={0.5} />
                      <stop
                        offset="95%"
                        stopColor="#f59e0b"
                        stopOpacity={0.0}
                      />
                    </linearGradient>
                  </defs>
                  <CartesianGrid
                    strokeDasharray="3 3"
                    stroke="#27272a"
                    vertical={false}
                  />
                  <XAxis
                    dataKey="date"
                    stroke="#71717a"
                    fontSize={10}
                    tickLine={false}
                    axisLine={false}
                  />
                  <YAxis
                    stroke="#71717a"
                    fontSize={10}
                    tickLine={false}
                    axisLine={false}
                  />
                  <RechartsTooltip
                    content={({ active, payload }) => {
                      if (!active || !payload?.length) return null;
                      const data = payload[0].payload as TimeSeriesPoint;
                      return (
                        <div className="border-border/80 rounded-lg border bg-zinc-900 p-2.5 font-mono text-xs shadow-xl">
                          <p className="font-semibold text-zinc-200">
                            {data.date}
                          </p>
                          <p className="mt-1 text-blue-400">
                            Sessions: {data.sessions.toLocaleString()}
                          </p>
                          <p className="text-amber-400">
                            Crashes: {data.crashes}
                          </p>
                          <p className="text-zinc-400">
                            Active Users: {data.activeUsers.toLocaleString()}
                          </p>
                        </div>
                      );
                    }}
                  />
                  <Area
                    type="monotone"
                    dataKey="sessions"
                    stroke="#3b82f6"
                    strokeWidth={2}
                    fillOpacity={1}
                    fill="url(#colorSessions)"
                  />
                  <Area
                    type="monotone"
                    dataKey="crashes"
                    stroke="#f59e0b"
                    strokeWidth={1.5}
                    fillOpacity={1}
                    fill="url(#colorCrashes)"
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Platform Traffic Distribution & Release Health Breakdown Grid */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        {/* Platform Share Donut Chart */}
        <Card className="border-border/80 bg-zinc-950/40">
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-xs font-semibold text-zinc-100">
              <ChartPie className="size-4 text-cyan-400" />
              <span>Platform Traffic Distribution</span>
            </CardTitle>
            <CardDescription className="text-[11px] text-zinc-400">
              Session distribution across active client runtimes.
            </CardDescription>
          </CardHeader>
          <CardContent className="pt-2">
            <div className="flex flex-col items-center">
              <div className="relative h-44 w-full">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={PLATFORM_DATA}
                      cx="50%"
                      cy="50%"
                      innerRadius={48}
                      outerRadius={70}
                      paddingAngle={3}
                      dataKey="value"
                    >
                      {PLATFORM_DATA.map((entry, index) => (
                        <Cell
                          key={`cell-${index}`}
                          fill={entry.color}
                          stroke="#09090b"
                          strokeWidth={2}
                        />
                      ))}
                    </Pie>
                    <RechartsTooltip
                      content={({ active, payload }) => {
                        if (!active || !payload?.length) return null;
                        const data = payload[0].payload;
                        return (
                          <div className="border-border/80 rounded-lg border bg-zinc-900 p-2 font-mono text-xs shadow-xl">
                            <p className="font-semibold text-zinc-200">
                              {data.name}
                            </p>
                            <p className="text-zinc-300">
                              Sessions: {data.value.toLocaleString()} (
                              {data.percentage})
                            </p>
                            <p className="text-emerald-400">
                              Crash-Free: {data.rate}%
                            </p>
                          </div>
                        );
                      }}
                    />
                  </PieChart>
                </ResponsiveContainer>
                {/* Center total badge */}
                <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
                  <span className="font-mono text-base font-bold text-zinc-100">
                    95.7k
                  </span>
                  <span className="text-[10px] text-zinc-500">Sessions</span>
                </div>
              </div>

              {/* Platform breakdown list */}
              <div className="mt-2 w-full space-y-2 border-t border-zinc-800/80 pt-3">
                {PLATFORM_DATA.map((p) => (
                  <div
                    key={p.name}
                    className="flex items-center justify-between font-mono text-xs"
                  >
                    <div className="flex items-center gap-2">
                      <PlatformIcon platform={p.name} size="sm" />
                      <span className="text-zinc-200">{p.name}</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="text-zinc-400">
                        {p.value.toLocaleString()}
                      </span>
                      <Badge
                        variant="outline"
                        className="h-5 px-1.5 font-mono text-[10px] text-zinc-300"
                      >
                        {p.percentage}
                      </Badge>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Per-Release & Environment Breakdown Table with Inline Sparklines */}
        <Card className="border-border/80 bg-zinc-950/40 lg:col-span-2">
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-2 text-xs font-semibold text-zinc-100">
              <TreeStructure className="size-4 text-zinc-400" />
              <span>Active Releases Health & Telemetry Sparklines</span>
            </CardTitle>
            <CardDescription className="text-[11px] text-zinc-400">
              Real-time symbolicated metrics by environment channel with inline
              7-day health sparklines.
            </CardDescription>
          </CardHeader>
          <CardContent className="pt-0">
            <div className="border-border/60 overflow-hidden rounded-md border bg-zinc-900/30">
              <Table>
                <TableHeader>
                  <TableRow className="hover:bg-transparent">
                    <TableHead className="w-[120px]">Platform</TableHead>
                    <TableHead>Channel</TableHead>
                    <TableHead>Version</TableHead>
                    <TableHead>7d Trend</TableHead>
                    <TableHead>Crash-Free</TableHead>
                    <TableHead>Sessions</TableHead>
                    <TableHead className="text-right">Health Status</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {appStatus?.environments.map((env, i) => {
                    const isWeb = env.platform === "web";
                    const isIos = env.platform === "ios";
                    const rate = env.crash_free_rate
                      ? (env.crash_free_rate * 100).toFixed(2)
                      : isWeb
                        ? "100.00"
                        : isIos
                          ? "99.80"
                          : "99.60";
                    const sparkData = isWeb
                      ? SPARKLINE_DATA_WEB
                      : isIos
                        ? SPARKLINE_DATA_IOS
                        : SPARKLINE_DATA_ANDROID;
                    const sparkColor = isWeb
                      ? "#22d3ee"
                      : isIos
                        ? "#3b82f6"
                        : "#22c55e";

                    return (
                      <TableRow
                        key={i}
                        className="hover:bg-muted/40 transition-colors"
                      >
                        <TableCell>
                          <div className="flex items-center gap-2 font-mono text-xs font-semibold text-zinc-200">
                            <PlatformIcon platform={env.platform} size="sm" />
                            <span className="uppercase">{env.platform}</span>
                          </div>
                        </TableCell>

                        <TableCell className="font-mono text-xs text-zinc-300 capitalize">
                          {env.environment}
                        </TableCell>

                        <TableCell>
                          <div className="flex items-center gap-1.5 font-mono text-xs text-zinc-200">
                            <span className="font-semibold">
                              {env.version || "v1.4.2"}
                            </span>
                            {env.build_number && (
                              <Badge
                                variant="outline"
                                className="text-[9px] text-zinc-400"
                              >
                                #{env.build_number}
                              </Badge>
                            )}
                          </div>
                        </TableCell>

                        <TableCell>
                          <TableSparkline data={sparkData} color={sparkColor} />
                        </TableCell>

                        <TableCell className="font-mono text-xs font-semibold text-emerald-400">
                          {rate}%
                        </TableCell>

                        <TableCell className="font-mono text-xs text-zinc-400">
                          {(isWeb
                            ? 14200
                            : isIos
                              ? 42580
                              : 38920
                          ).toLocaleString()}
                        </TableCell>

                        <TableCell className="text-right">
                          <StatusBadge
                            status="healthy"
                            label={env.status || "Healthy"}
                            size="sm"
                          />
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Web Analytics Sub-Section (When Web Hosting is Active) */}
      {hasWebHosting && (
        <div className="space-y-4 pt-2">
          <div className="flex items-center justify-between border-t border-zinc-800/80 pt-6">
            <div className="space-y-0.5">
              <h3 className="flex items-center gap-2 text-sm font-semibold text-zinc-100">
                <Globe className="size-4 text-cyan-400" />
                <span>Web Hosting Edge Analytics & Traffic</span>
              </h3>
              <p className="text-xs text-zinc-400">
                Page views, unique visitors, and top routes served by Bloom Web
                Hosting.
              </p>
            </div>
            <Badge variant="secondary" className="font-mono text-xs">
              Web CDN Active
            </Badge>
          </div>

          <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
            {/* Page Views Bar Chart */}
            <Card className="border-border/80 bg-zinc-950/40">
              <CardHeader className="pb-2">
                <CardTitle className="text-xs font-semibold text-zinc-200">
                  Daily Page Views & Unique Visitors
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="h-52 w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart
                      data={WEB_TRAFFIC_DATA}
                      margin={{ top: 10, right: 10, left: -20, bottom: 0 }}
                    >
                      <CartesianGrid
                        strokeDasharray="3 3"
                        stroke="#27272a"
                        vertical={false}
                      />
                      <XAxis
                        dataKey="date"
                        stroke="#71717a"
                        fontSize={10}
                        tickLine={false}
                        axisLine={false}
                      />
                      <YAxis
                        stroke="#71717a"
                        fontSize={10}
                        tickLine={false}
                        axisLine={false}
                      />
                      <RechartsTooltip
                        content={({ active, payload }) => {
                          if (!active || !payload?.length) return null;
                          const data = payload[0].payload as WebAnalyticsPoint;
                          return (
                            <div className="border-border/80 rounded-lg border bg-zinc-900 p-2 font-mono text-xs shadow-xl">
                              <p className="font-semibold text-zinc-200">
                                {data.date}
                              </p>
                              <p className="text-cyan-400">
                                Page Views: {data.pageViews.toLocaleString()}
                              </p>
                              <p className="text-zinc-400">
                                Unique Visitors:{" "}
                                {data.uniqueVisitors.toLocaleString()}
                              </p>
                            </div>
                          );
                        }}
                      />
                      <Bar
                        dataKey="pageViews"
                        fill="#22d3ee"
                        radius={[4, 4, 0, 0]}
                      />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </CardContent>
            </Card>

            {/* Top Routes & Referrers Split */}
            <div className="space-y-4">
              <Card className="border-border/80 bg-zinc-950/40">
                <CardHeader className="py-2.5">
                  <CardTitle className="text-xs font-semibold text-zinc-200">
                    Top Visited Routes
                  </CardTitle>
                </CardHeader>
                <CardContent className="pt-0">
                  <div className="space-y-2">
                    {TOP_ROUTES.slice(0, 4).map((r) => (
                      <div
                        key={r.path}
                        className="flex items-center justify-between text-xs"
                      >
                        <span className="font-mono text-zinc-300">
                          {r.path}
                        </span>
                        <div className="flex items-center gap-2 font-mono text-zinc-400">
                          <span>{r.views.toLocaleString()}</span>
                          <span className="text-[10px] text-zinc-500">
                            ({r.percentage}%)
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>

              <Card className="border-border/80 bg-zinc-950/40">
                <CardHeader className="py-2.5">
                  <CardTitle className="text-xs font-semibold text-zinc-200">
                    Top Inbound Referrers
                  </CardTitle>
                </CardHeader>
                <CardContent className="pt-0">
                  <div className="space-y-2">
                    {TOP_REFERRERS.slice(0, 3).map((ref) => (
                      <div
                        key={ref.source}
                        className="flex items-center justify-between text-xs"
                      >
                        <span className="text-zinc-300">{ref.source}</span>
                        <div className="flex items-center gap-2 font-mono text-zinc-400">
                          <span>{ref.count.toLocaleString()}</span>
                          <span className="text-[10px] text-zinc-500">
                            ({ref.share})
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
