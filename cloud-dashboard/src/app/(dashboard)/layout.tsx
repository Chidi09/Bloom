"use client";

import * as React from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  House,
  DeviceMobile,
  FolderSimple,
  Buildings,
  Hammer,
  Key,
  ShieldCheck,
  SignOut,
  CaretUpDown,
  MagnifyingGlass,
  BookOpen,
  Bell,
  ArrowSquareOut,
  CaretDown,
  GitFork,
  Storefront,
  Scroll,
} from "@phosphor-icons/react";

import { Button } from "@/components/ui/button";
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
import { useAuthStore } from "@/stores/auth-store";
import { useOrganizationStore } from "@/stores/organization-store";
import { api } from "@/lib/api/client";
import { UpgradeModal } from "@/components/billing/upgrade-modal";

interface NavItem {
  label: string;
  href: string;
  icon: React.ComponentType<{
    className?: string;
    weight?: "regular" | "bold" | "fill";
  }>;
  badge?: string;
}

const MAIN_NAV_ITEMS: NavItem[] = [
  { label: "Overview", href: "/overview", icon: House },
  { label: "Projects", href: "/projects", icon: FolderSimple },
  { label: "Applications", href: "/apps", icon: DeviceMobile },
  { label: "Builds", href: "/builds", icon: Hammer },
  { label: "Workflows", href: "/workflows", icon: GitFork },
  { label: "Marketplace", href: "/marketplace", icon: Storefront },
  { label: "Organizations", href: "/organizations", icon: Buildings },
  { label: "Credentials", href: "/credentials", icon: Key },
  { label: "Git Connections", href: "/git-connections", icon: ShieldCheck },
  { label: "Audit Log", href: "/audit-log", icon: Scroll },
];

const SYSTEM_NAV_ITEMS: NavItem[] = [
  { label: "Documentation", href: "https://bloom.dev/docs", icon: BookOpen },
];

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const { setAccessToken } = useAuthStore();
  const { currentOrganizationId } = useOrganizationStore();
  const [upgradeModalOpen, setUpgradeModalOpen] = React.useState(false);
  const [buildBadge, setBuildBadge] = React.useState<{
    count: number;
    color: "red" | "yellow";
  } | null>(null);
  const [appCount, setAppCount] = React.useState<number | null>(null);
  const [projectCount, setProjectCount] = React.useState<number | null>(null);
  const [credentialBadge, setCredentialBadge] = React.useState<{
    count: number;
    color: "red" | "yellow";
  } | null>(null);

  React.useEffect(() => {
    const run = async () => {
      if (!currentOrganizationId) {
        setBuildBadge(null);
        return;
      }
      try {
        const res = await api.get<{ results: { status: string }[] }>("/builds");
        const builds = res?.results ?? [];
        const failed = builds.filter((b) => b.status === "failed").length;
        const active = builds.filter((b) =>
          ["pending", "queued", "running"].includes(b.status),
        ).length;
        const attention = failed + active;
        if (attention === 0) {
          setBuildBadge(null);
          return;
        }
        setBuildBadge({
          count: attention,
          color: failed > active ? "red" : "yellow",
        });
      } catch {
        setBuildBadge(null);
      }
    };
    void run();
  }, [currentOrganizationId]);

  React.useEffect(() => {
    const run = async () => {
      if (!currentOrganizationId) {
        setAppCount(null);
        setProjectCount(null);
        return;
      }
      try {
        const [appsRes, projectsRes] = await Promise.all([
          api.get<{ results: unknown[] }>("/apps"),
          api.get<{ results: unknown[] }>("/projects"),
        ]);
        setAppCount(appsRes?.results?.length ?? 0);
        setProjectCount(projectsRes?.results?.length ?? 0);
      } catch {
        setAppCount(null);
        setProjectCount(null);
      }
    };
    void run();
  }, [currentOrganizationId]);

  React.useEffect(() => {
    const run = async () => {
      if (!currentOrganizationId) {
        setCredentialBadge(null);
        return;
      }
      try {
        const res = await api.get<{
          results: { expires_at?: string | null }[];
        }>("/credentials");
        const credentials = res?.results ?? [];
        const now = Date.now();
        const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
        let expired = 0;
        let expiringSoon = 0;
        for (const c of credentials) {
          if (!c.expires_at) continue;
          const diff = new Date(c.expires_at).getTime() - now;
          if (diff <= 0) expired += 1;
          else if (diff <= thirtyDaysMs) expiringSoon += 1;
        }
        const attention = expired + expiringSoon;
        if (attention === 0) {
          setCredentialBadge(null);
          return;
        }
        setCredentialBadge({
          count: attention,
          color: expired > 0 ? "red" : "yellow",
        });
      } catch {
        setCredentialBadge(null);
      }
    };
    void run();
  }, [currentOrganizationId]);

  const [orgs, setOrgs] = React.useState<
    Array<{ id: string; name: string; slug: string; plan?: string }>
  >([
    {
      id: "00000000-0000-0000-0000-000000000010",
      name: "Bloom Labs",
      slug: "bloom-labs",
      plan: "Hobby",
    },
  ]);
  const [userProfile, setUserProfile] = React.useState<{
    email: string;
    username: string;
  }>({
    email: "dev@bloom.dev",
    username: "chidi09",
  });

  React.useEffect(() => {
    api
      .get<{ email: string; username: string }>("/auth/me")
      .then((data) => {
        if (data) setUserProfile(data);
      })
      .catch(() => undefined);

    api
      .get<{
        results: Array<{
          id: string;
          name: string;
          slug: string;
          plan?: string;
        }>;
      }>("/organizations")
      .then((data) => {
        if (data?.results?.length) {
          setOrgs(data.results);
          if (!currentOrganizationId) {
            useOrganizationStore
              .getState()
              .setCurrentOrganizationId(data.results[0].id);
          }
        }
      })
      .catch(() => undefined);
  }, [currentOrganizationId]);

  const activeOrg = orgs.find((o) => o.id === currentOrganizationId) || orgs[0];

  const handleSignOut = async () => {
    try {
      await api.post("/auth/logout", {});
    } catch {
      // ignore
    }
    setAccessToken(null);
    useOrganizationStore.getState().setCurrentOrganizationId(null);
    router.push("/auth/login");
  };

  return (
    <div className="flex h-screen overflow-hidden bg-[#000000] font-sans text-zinc-100 antialiased">
      {/* Vercel-style Left Navigation Sidebar */}
      <aside className="border-border/60 flex w-60 shrink-0 flex-col border-r bg-[#09090b]">
        {/* Workspace Selector */}
        <div className="border-border/40 border-b p-3">
          <DropdownMenu>
            <DropdownMenuTrigger className="flex w-full cursor-pointer items-center justify-between rounded-md p-1.5 text-left transition-colors hover:bg-zinc-800/60">
              <div className="flex items-center gap-2 overflow-hidden">
                <UserAvatar name={activeOrg?.name || "Bloom Labs"} size={22} />
                <div className="truncate">
                  <p className="truncate text-xs font-medium text-zinc-100">
                    {activeOrg?.name || "chidi09's project..."}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-1">
                <span className="rounded bg-zinc-800 px-1.5 py-0.5 font-mono text-[10px] text-zinc-400">
                  {activeOrg?.plan || "Hobby"}
                </span>
                <CaretUpDown className="size-3 shrink-0 text-zinc-500" />
              </div>
            </DropdownMenuTrigger>

            <DropdownMenuContent
              align="start"
              className="w-56 border-zinc-800 bg-zinc-900 text-zinc-200"
            >
              <DropdownMenuGroup>
                <DropdownMenuLabel className="text-[11px] text-zinc-400">
                  Workspaces
                </DropdownMenuLabel>
                {orgs.map((org) => (
                  <DropdownMenuItem
                    key={org.id}
                    onClick={() =>
                      useOrganizationStore
                        .getState()
                        .setCurrentOrganizationId(org.id)
                    }
                    className="cursor-pointer text-xs hover:bg-zinc-800 focus:bg-zinc-800"
                  >
                    <span className="truncate">{org.name}</span>
                  </DropdownMenuItem>
                ))}
              </DropdownMenuGroup>
              <DropdownMenuSeparator className="bg-zinc-800" />
              <DropdownMenuItem
                onClick={() => router.push("/organizations")}
                className="cursor-pointer text-xs text-zinc-300 hover:bg-zinc-800 focus:bg-zinc-800"
              >
                Manage all organizations
              </DropdownMenuItem>
              <DropdownMenuItem
                onClick={() => router.push("/onboarding")}
                className="cursor-pointer text-xs font-medium text-[#FF4B8B] hover:bg-zinc-800 focus:bg-zinc-800"
              >
                + Create new workspace
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>

          {/* Find Search Input (F) */}
          <div className="relative mt-2">
            <MagnifyingGlass className="absolute top-2 left-2.5 size-3 text-zinc-500" />
            <input
              type="text"
              placeholder="Find"
              className="w-full rounded-md border border-zinc-800/80 bg-zinc-900/60 py-1 pr-6 pl-7 text-xs text-zinc-200 placeholder:text-zinc-500 focus:border-zinc-700 focus:outline-none"
            />
            <kbd className="absolute top-1.5 right-2 rounded border border-zinc-800 bg-zinc-900 px-1 font-mono text-[9px] text-zinc-500">
              F
            </kbd>
          </div>
        </div>

        {/* Main Nav Items */}
        <div className="flex-1 space-y-4 overflow-y-auto px-2 py-3">
          <nav className="space-y-0.5 text-xs">
            {MAIN_NAV_ITEMS.map((item) => {
              const isActive =
                pathname === item.href ||
                (item.href !== "/overview" && pathname.startsWith(item.href));
              const Icon = item.icon;
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`flex items-center justify-between rounded-md px-2 py-1.5 transition-colors ${
                    isActive
                      ? "bg-zinc-800/80 font-medium text-zinc-100"
                      : "text-zinc-400 hover:bg-zinc-800/40 hover:text-zinc-200"
                  }`}
                >
                  <div className="flex items-center gap-2.5">
                    <Icon
                      className="size-4 shrink-0"
                      weight={isActive ? "fill" : "regular"}
                    />
                    <span>{item.label}</span>
                  </div>
                  {item.href === "/builds" && buildBadge && (
                    <span
                      className={`py-0.2 rounded px-1.5 font-mono text-[9px] font-semibold ${
                        buildBadge.color === "red"
                          ? "bg-red-500/15 text-red-400"
                          : "bg-amber-500/15 text-amber-400"
                      }`}
                    >
                      {buildBadge.count}
                    </span>
                  )}
                  {item.href === "/credentials" && credentialBadge && (
                    <span
                      className={`py-0.2 rounded px-1.5 font-mono text-[9px] font-semibold ${
                        credentialBadge.color === "red"
                          ? "bg-red-500/15 text-red-400"
                          : "bg-amber-500/15 text-amber-400"
                      }`}
                    >
                      {credentialBadge.count}
                    </span>
                  )}
                  {item.href === "/apps" &&
                    appCount !== null &&
                    appCount > 0 && (
                      <span className="py-0.2 rounded bg-zinc-800 px-1.5 font-mono text-[9px] text-zinc-400">
                        {appCount}
                      </span>
                    )}
                  {item.href === "/projects" &&
                    projectCount !== null &&
                    projectCount > 0 && (
                      <span className="py-0.2 rounded bg-zinc-800 px-1.5 font-mono text-[9px] text-zinc-400">
                        {projectCount}
                      </span>
                    )}
                </Link>
              );
            })}
          </nav>

          <div className="border-t border-zinc-800/60 pt-3">
            <nav className="space-y-0.5 text-xs">
              {SYSTEM_NAV_ITEMS.map((item) => {
                const isActive = pathname === item.href;
                const Icon = item.icon;
                const isExternal = item.href.startsWith("http");
                return (
                  <Link
                    key={item.label}
                    href={item.href}
                    target={isExternal ? "_blank" : undefined}
                    className={`flex items-center justify-between rounded-md px-2 py-1.5 transition-colors ${
                      isActive
                        ? "bg-zinc-800/80 font-medium text-zinc-100"
                        : "text-zinc-400 hover:bg-zinc-800/40 hover:text-zinc-200"
                    }`}
                  >
                    <div className="flex items-center gap-2.5">
                      <Icon
                        className="size-4 shrink-0"
                        weight={isActive ? "fill" : "regular"}
                      />
                      <span>{item.label}</span>
                    </div>
                    {isExternal && (
                      <ArrowSquareOut className="size-3 text-zinc-500" />
                    )}
                  </Link>
                );
              })}
            </nav>
          </div>
        </div>

        {/* Promo / Upgrade Card */}
        <div className="p-3">
          <div className="space-y-2 rounded-lg border border-zinc-800/80 bg-zinc-900/50 p-3 text-xs">
            <div className="flex items-center justify-between">
              <span className="font-semibold text-zinc-200">
                Bloom Cloud Pro
              </span>
              <span className="py-0.2 rounded bg-[#FF4B8B]/20 px-1.5 text-[9px] font-semibold text-[#FF4B8B]">
                Trial
              </span>
            </div>
            <p className="text-[11px] text-zinc-400">
              5,000 build mins, automated store rollouts & team seats.
            </p>
            <Button
              size="sm"
              variant="outline"
              onClick={() => setUpgradeModalOpen(true)}
              className="h-7 w-full cursor-pointer border-zinc-700 bg-zinc-800/60 text-xs text-zinc-200 hover:bg-zinc-800"
            >
              Explore Plans ↗
            </Button>
          </div>
        </div>

        {/* User Footer Profile */}
        <div className="border-t border-zinc-800/60 p-2.5">
          <div className="flex items-center justify-between">
            <DropdownMenu>
              <DropdownMenuTrigger className="flex cursor-pointer items-center gap-2 overflow-hidden rounded-md p-1 text-left transition-colors hover:bg-zinc-800/50">
                <UserAvatar
                  name={userProfile.username}
                  src={
                    userProfile.username === "chidi09" ||
                    userProfile.username === "dev"
                      ? "https://github.com/Chidi09.png"
                      : undefined
                  }
                  size={24}
                />
                <div className="truncate">
                  <p className="truncate text-xs font-medium text-zinc-200">
                    {userProfile.username}
                  </p>
                </div>
              </DropdownMenuTrigger>

              <DropdownMenuContent
                align="end"
                className="w-48 border-zinc-800 bg-zinc-900 text-zinc-200"
              >
                <DropdownMenuGroup>
                  <DropdownMenuLabel className="text-xs text-zinc-400">
                    {userProfile.email}
                  </DropdownMenuLabel>
                </DropdownMenuGroup>
                <DropdownMenuSeparator className="bg-zinc-800" />
                <DropdownMenuItem
                  onClick={() => router.push("/account")}
                  className="cursor-pointer text-xs"
                >
                  Settings
                </DropdownMenuItem>
                <DropdownMenuItem
                  onClick={handleSignOut}
                  className="cursor-pointer text-xs text-red-400"
                >
                  <SignOut className="mr-1.5 size-3.5" />
                  Sign out
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>

            <div className="flex items-center gap-1 text-zinc-500">
              <button
                type="button"
                aria-label="Notifications"
                className="cursor-pointer rounded-md p-1 transition-colors hover:text-zinc-300"
              >
                <Bell className="size-3.5" />
              </button>
            </div>
          </div>
        </div>
      </aside>

      {/* Main App Container */}
      <div className="flex flex-1 flex-col overflow-hidden">
        {/* Top Header Bar */}
        <header className="flex h-12 shrink-0 items-center justify-between border-b border-zinc-800/60 bg-[#09090b]/80 px-6 backdrop-blur-md">
          <div className="flex items-center gap-3">
            <button
              type="button"
              className="flex cursor-pointer items-center gap-1.5 text-xs font-medium text-zinc-300 transition-colors hover:text-zinc-100"
            >
              <span>All Projects</span>
              <CaretDown className="size-3 text-zinc-500" />
            </button>
          </div>

          <div className="flex items-center gap-3">
            <span className="text-xs font-medium text-zinc-400">Overview</span>
          </div>
        </header>

        {/* Dynamic Page Content */}
        <main className="flex-1 overflow-y-auto bg-[#000000] p-6">
          {children}
        </main>
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
