"use client";

import * as React from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import {
  House,
  DeviceMobile,
  Hammer,
  RocketLaunch,
  Key,
  ShieldCheck,
  ChartLine,
  Gear,
  SignOut,
  CaretUpDown,
  MagnifyingGlass,
  BookOpen,
  Bell,
  ArrowSquareOut,
  CaretDown,
} from "@phosphor-icons/react";

import { Button } from "@/components/ui/button";
import { UserAvatar } from "@/components/ui/user-avatar";
import {
  DropdownMenu,
  DropdownMenuContent,
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
  icon: React.ComponentType<{ className?: string; weight?: "regular" | "bold" | "fill" }>;
  badge?: string;
}

const MAIN_NAV_ITEMS: NavItem[] = [
  { label: "Overview", href: "/overview", icon: House },
  { label: "Applications", href: "/apps", icon: DeviceMobile },
  { label: "Builds", href: "/builds", icon: Hammer },
  { label: "Releases & Deploy", href: "/releases", icon: RocketLaunch },
  { label: "Environment & Secrets", href: "/secrets", icon: Key },
  { label: "Signing & Certificates", href: "/signing", icon: ShieldCheck },
];

const SYSTEM_NAV_ITEMS: NavItem[] = [
  { label: "Usage & Limits", href: "/usage", icon: ChartLine },
  { label: "Documentation", href: "https://bloom.dev/docs", icon: BookOpen },
  { label: "Settings", href: "/settings", icon: Gear },
];

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const { setAccessToken } = useAuthStore();
  const { currentOrganizationId } = useOrganizationStore();
  const [upgradeModalOpen, setUpgradeModalOpen] = React.useState(false);

  const [orgs, setOrgs] = React.useState<Array<{ id: string; name: string; slug: string; plan?: string }>>([
    { id: "00000000-0000-0000-0000-000000000010", name: "Bloom Labs", slug: "bloom-labs", plan: "Hobby" },
  ]);
  const [userProfile, setUserProfile] = React.useState<{ email: string; username: string }>({
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
      .get<{ results: Array<{ id: string; name: string; slug: string; plan?: string }> }>("/organizations")
      .then((data) => {
        if (data?.results?.length) {
          setOrgs(data.results);
          if (!currentOrganizationId) {
            useOrganizationStore.getState().setCurrentOrganizationId(data.results[0].id);
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
    <div className="bg-[#000000] text-zinc-100 flex min-h-screen font-sans antialiased">
      {/* Vercel-style Left Navigation Sidebar */}
      <aside className="border-border/60 bg-[#09090b] flex w-60 shrink-0 flex-col border-r">
        {/* Workspace Selector */}
        <div className="p-3 border-b border-border/40">
          <DropdownMenu>
            <DropdownMenuTrigger className="hover:bg-zinc-800/60 flex w-full items-center justify-between rounded-md p-1.5 text-left transition-colors cursor-pointer">
              <div className="flex items-center gap-2 overflow-hidden">
                <UserAvatar name={activeOrg?.name || "Bloom Labs"} size={22} />
                <div className="truncate">
                  <p className="truncate text-xs font-medium text-zinc-100">
                    {activeOrg?.name || "chidi09's project..."}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-1">
                <span className="rounded bg-zinc-800 px-1.5 py-0.5 text-[10px] text-zinc-400 font-mono">
                  {activeOrg?.plan || "Hobby"}
                </span>
                <CaretUpDown className="text-zinc-500 size-3 shrink-0" />
              </div>
            </DropdownMenuTrigger>

            <DropdownMenuContent align="start" className="w-56 bg-zinc-900 border-zinc-800 text-zinc-200">
              <DropdownMenuLabel className="text-[11px] text-zinc-400">Workspaces</DropdownMenuLabel>
              {orgs.map((org) => (
                <DropdownMenuItem
                  key={org.id}
                  onClick={() => useOrganizationStore.getState().setCurrentOrganizationId(org.id)}
                  className="text-xs cursor-pointer hover:bg-zinc-800 focus:bg-zinc-800"
                >
                  <span className="truncate">{org.name}</span>
                </DropdownMenuItem>
              ))}
              <DropdownMenuSeparator className="bg-zinc-800" />
              <DropdownMenuItem
                onClick={() => router.push("/onboarding")}
                className="text-xs cursor-pointer font-medium text-[#FF4B8B] hover:bg-zinc-800 focus:bg-zinc-800"
              >
                + Create new workspace
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>

          {/* Find Search Input (F) */}
          <div className="mt-2 relative">
            <MagnifyingGlass className="absolute left-2.5 top-2 size-3 text-zinc-500" />
            <input
              type="text"
              placeholder="Find"
              className="w-full rounded-md border border-zinc-800/80 bg-zinc-900/60 py-1 pl-7 pr-6 text-xs text-zinc-200 placeholder:text-zinc-500 focus:border-zinc-700 focus:outline-none"
            />
            <kbd className="absolute right-2 top-1.5 rounded border border-zinc-800 bg-zinc-900 px-1 text-[9px] font-mono text-zinc-500">
              F
            </kbd>
          </div>
        </div>

        {/* Main Nav Items */}
        <div className="flex-1 overflow-y-auto px-2 py-3 space-y-4">
          <nav className="space-y-0.5 text-xs">
            {MAIN_NAV_ITEMS.map((item) => {
              const isActive = pathname === item.href || (item.href !== "/overview" && pathname.startsWith(item.href));
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
                    <Icon className="size-4 shrink-0" weight={isActive ? "fill" : "regular"} />
                    <span>{item.label}</span>
                  </div>
                  {item.badge && (
                    <span className="rounded bg-zinc-800 px-1.5 py-0.2 text-[9px] text-zinc-400 font-mono">
                      {item.badge}
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
                      <Icon className="size-4 shrink-0" weight={isActive ? "fill" : "regular"} />
                      <span>{item.label}</span>
                    </div>
                    {isExternal && <ArrowSquareOut className="size-3 text-zinc-500" />}
                  </Link>
                );
              })}
            </nav>
          </div>
        </div>

        {/* Promo / Upgrade Card */}
        <div className="p-3">
          <div className="rounded-lg border border-zinc-800/80 bg-zinc-900/50 p-3 text-xs space-y-2">
            <div className="flex items-center justify-between">
              <span className="font-semibold text-zinc-200">Bloom Cloud Pro</span>
              <span className="rounded bg-[#FF4B8B]/20 text-[#FF4B8B] px-1.5 py-0.2 text-[9px] font-semibold">
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
              className="w-full h-7 text-xs border-zinc-700 bg-zinc-800/60 hover:bg-zinc-800 text-zinc-200 cursor-pointer"
            >
              Explore Plans ↗
            </Button>
          </div>
        </div>

        {/* User Footer Profile */}
        <div className="border-t border-zinc-800/60 p-2.5">
          <div className="flex items-center justify-between">
            <DropdownMenu>
              <DropdownMenuTrigger className="flex items-center gap-2 hover:bg-zinc-800/50 p-1 rounded-md transition-colors cursor-pointer text-left overflow-hidden">
                <UserAvatar
                  name={userProfile.username}
                  src={userProfile.username === "chidi09" || userProfile.username === "dev" ? "https://github.com/Chidi09.png" : undefined}
                  size={24}
                />
                <div className="truncate">
                  <p className="truncate text-xs font-medium text-zinc-200">{userProfile.username}</p>
                </div>
              </DropdownMenuTrigger>

              <DropdownMenuContent align="end" className="w-48 bg-zinc-900 border-zinc-800 text-zinc-200">
                <DropdownMenuLabel className="text-xs text-zinc-400">
                  {userProfile.email}
                </DropdownMenuLabel>
                <DropdownMenuSeparator className="bg-zinc-800" />
                <DropdownMenuItem onClick={() => router.push("/settings")} className="text-xs cursor-pointer">
                  Settings
                </DropdownMenuItem>
                <DropdownMenuItem onClick={handleSignOut} className="text-xs text-red-400 cursor-pointer">
                  <SignOut className="size-3.5 mr-1.5" />
                  Sign out
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>

            <div className="flex items-center gap-1 text-zinc-500">
              <button
                type="button"
                aria-label="Notifications"
                className="hover:text-zinc-300 p-1 rounded-md transition-colors cursor-pointer"
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
        <header className="border-b border-zinc-800/60 bg-[#09090b]/80 flex h-12 shrink-0 items-center justify-between px-6 backdrop-blur-md">
          <div className="flex items-center gap-3">
            <button
              type="button"
              className="flex items-center gap-1.5 text-xs font-medium text-zinc-300 hover:text-zinc-100 transition-colors cursor-pointer"
            >
              <span>All Projects</span>
              <CaretDown className="size-3 text-zinc-500" />
            </button>
          </div>

          <div className="flex items-center gap-3">
            <span className="text-xs text-zinc-400 font-medium">Overview</span>
          </div>
        </header>

        {/* Dynamic Page Content */}
        <main className="flex-1 overflow-y-auto p-6 bg-[#000000]">{children}</main>
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
