"use client";

import * as React from "react";
import Link from "next/link";
import { useParams, usePathname } from "next/navigation";
import {
  GithubLogo,
  GitBranch,
  ArrowSquareOut,
  Hammer,
  RocketLaunch,
  CloudArrowUp,
  TreeStructure,
  Key,
  ShieldCheck,
  Globe,
  ChartLine,
  Gear,
} from "@phosphor-icons/react";

import { Badge } from "@/components/ui/badge";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { PageHeader } from "@/components/shared/page-header";
import { api } from "@/lib/api/client";
import { AppResponse } from "@/lib/schemas/app";
import { ProjectResponse } from "@/lib/schemas/project";
import { cn } from "@/lib/utils";

interface AppTab {
  label: string;
  href: string;
  segment: string;
  icon: React.ComponentType<{
    className?: string;
    weight?: "regular" | "bold" | "fill";
  }>;
}

export default function AppDetailLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const params = useParams<{ id: string }>();
  const pathname = usePathname();
  const appId = params.id;

  const [app, setApp] = React.useState<AppResponse | null>(null);
  const [project, setProject] = React.useState<ProjectResponse | null>(null);
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    if (!appId) return;

    let cancelled = false;
    async function loadApp() {
      setIsLoading(true);
      setError(null);
      try {
        const appRes = await api.get<AppResponse>(`/apps/${appId}`);
        if (cancelled) return;
        setApp(appRes);

        if (appRes.project_id) {
          const prjRes = await api
            .get<ProjectResponse>(`/projects/${appRes.project_id}`)
            .catch(() => null);
          if (!cancelled && prjRes) setProject(prjRes);
        }
      } catch (err: unknown) {
        if (cancelled) return;
        setError(
          err instanceof Error
            ? err.message
            : "Failed to load application details",
        );
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    }
    void loadApp();

    return () => {
      cancelled = true;
    };
  }, [appId]);

  const APP_TABS: AppTab[] = [
    {
      label: "Builds",
      href: `/apps/${appId}/builds`,
      segment: "builds",
      icon: Hammer,
    },
    {
      label: "Releases",
      href: `/apps/${appId}/releases`,
      segment: "releases",
      icon: RocketLaunch,
    },
    {
      label: "Deployments",
      href: `/apps/${appId}/deployments`,
      segment: "deployments",
      icon: CloudArrowUp,
    },
    {
      label: "Environments",
      href: `/apps/${appId}/environments`,
      segment: "environments",
      icon: TreeStructure,
    },
    {
      label: "Secrets",
      href: `/apps/${appId}/secrets`,
      segment: "secrets",
      icon: Key,
    },
    {
      label: "Signing",
      href: `/apps/${appId}/signing`,
      segment: "signing",
      icon: ShieldCheck,
    },
    {
      label: "Web Hosting",
      href: `/apps/${appId}/webhosting`,
      segment: "webhosting",
      icon: Globe,
    },
    {
      label: "Observability",
      href: `/apps/${appId}/observability`,
      segment: "observability",
      icon: ChartLine,
    },
    {
      label: "Settings",
      href: `/apps/${appId}/settings`,
      segment: "settings",
      icon: Gear,
    },
  ];

  if (isLoading) {
    return (
      <div className="mx-auto flex max-w-6xl items-center justify-center py-12">
        <BloomSpinner size={32} label="Loading application shell..." />
      </div>
    );
  }

  if (error || !app) {
    return (
      <div className="mx-auto max-w-6xl space-y-4">
        <Alert variant="destructive">
          <AlertTitle>Application not found</AlertTitle>
          <AlertDescription>
            {error || "Unable to retrieve application details."}
          </AlertDescription>
        </Alert>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-6xl space-y-5">
      {/* App Header */}
      <PageHeader
        breadcrumbs={[
          { label: "Applications", href: "/apps" },
          ...(project
            ? [{ label: project.name, href: `/projects/${project.id}` }]
            : []),
          { label: app.name },
        ]}
        title={app.name}
        badge={
          <div className="flex items-center gap-2">
            <Badge variant="secondary" className="gap-1 font-mono text-xs">
              <GitBranch className="size-3" />
              <span>{app.default_branch || "main"}</span>
            </Badge>
          </div>
        }
        actions={
          app.repository_url ? (
            <Link
              href={app.repository_url}
              target="_blank"
              className="border-border bg-card text-foreground hover:bg-muted inline-flex items-center gap-1.5 rounded-md border px-3 py-1.5 font-mono text-xs font-medium transition-colors"
            >
              <GithubLogo className="size-4" weight="fill" />
              <span className="max-w-[180px] truncate">
                {app.repository_url.replace("https://github.com/", "")}
              </span>
              <ArrowSquareOut className="text-muted-foreground size-3" />
            </Link>
          ) : null
        }
      />

      {/* Real Route Nav Tabs */}
      <div className="border-border/80 overflow-x-auto border-b">
        <nav className="flex space-x-1 py-0.5 sm:space-x-1.5">
          {APP_TABS.map((tab) => {
            const isActive = pathname.startsWith(tab.href);
            const Icon = tab.icon;
            return (
              <Link
                key={tab.segment}
                href={tab.href}
                className={cn(
                  "inline-flex items-center gap-1.5 border-b-2 px-3 py-2 text-xs font-medium whitespace-nowrap transition-colors duration-150",
                  isActive
                    ? "border-primary text-foreground font-semibold"
                    : "text-muted-foreground hover:text-foreground hover:border-border/60 border-transparent",
                )}
              >
                <Icon
                  className="size-3.5"
                  weight={isActive ? "fill" : "regular"}
                />
                <span>{tab.label}</span>
              </Link>
            );
          })}
        </nav>
      </div>

      {/* Tab Content */}
      <div className="pt-1">{children}</div>
    </div>
  );
}
