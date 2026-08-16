"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import {
  Storefront,
  MagnifyingGlass,
  Star,
  DownloadSimple,
  Sparkle,
  Bag,
  ArrowsClockwise,
  FolderUser,
} from "@phosphor-icons/react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { ProviderIcon } from "@/components/status/provider-icon";
import { PlatformIcon } from "@/components/status/platform-icon";
import { PageHeader } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import { api } from "@/lib/api/client";
import { TemplateResponse } from "@/lib/schemas/marketplace";

const CATEGORIES = [
  { label: "All Categories", value: "all" },
  { label: "SaaS & Cloud", value: "saas" },
  { label: "E-Commerce", value: "ecommerce" },
  { label: "Fintech & Banking", value: "fintech" },
  { label: "Developer Tooling", value: "devtool" },
];

export default function MarketplaceBrowsePage() {
  const router = useRouter();

  const [templates, setTemplates] = React.useState<TemplateResponse[]>([]);
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Search & Filter state
  const [searchQuery, setSearchQuery] = React.useState("");
  const [categoryFilter, setCategoryFilter] = React.useState("all");

  const fetchTemplates = React.useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const params: Record<string, string | undefined> = {};
      if (searchQuery.trim()) params.q = searchQuery.trim();
      if (categoryFilter !== "all") params.category = categoryFilter;

      const res = await api.get<TemplateResponse[]>("/marketplace/templates", {
        params,
      });
      setTemplates(Array.isArray(res) ? res : []);
    } catch (err: unknown) {
      setError(
        err instanceof Error
          ? err.message
          : "Failed to load marketplace templates",
      );
    } finally {
      setIsLoading(false);
    }
  }, [searchQuery, categoryFilter]);

  React.useEffect(() => {
    const run = async () => {
      await fetchTemplates();
    };
    void run();
  }, [fetchTemplates]);

  const renderRatingStars = (milliRating: number, count: number) => {
    const stars = (milliRating / 1000).toFixed(1);
    return (
      <div className="flex items-center gap-1 font-mono text-xs text-amber-400">
        <Star
          className="size-3.5 fill-amber-400 text-amber-400"
          weight="fill"
        />
        <span className="font-bold text-zinc-100">{stars}</span>
        <span className="text-zinc-500">({count})</span>
      </div>
    );
  };

  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <PageHeader
        breadcrumbs={[{ label: "Marketplace" }]}
        title="Marketplace"
        description="Discover vetted Flutter starter templates, fullstack kits, and production architectures."
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => router.push("/marketplace/purchases")}
              className="h-8 gap-1.5 text-xs text-zinc-200"
            >
              <Bag className="size-3.5 text-zinc-400" />
              <span>Purchases</span>
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => router.push("/templates")}
              className="h-8 gap-1.5 text-xs text-zinc-200"
            >
              <FolderUser className="size-3.5 text-zinc-400" />
              <span>My Templates</span>
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchTemplates()}
              className="h-8 gap-1.5"
            >
              <ArrowsClockwise className="size-3.5" />
              <span>Refresh</span>
            </Button>
          </div>
        }
      />

      {error && (
        <Alert variant="destructive">
          <AlertTitle>Failed to load marketplace</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchTemplates()}
              className="h-7 text-xs"
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      )}

      {/* Filter and Search Bar */}
      <div className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-zinc-800 bg-[#09090b] p-3">
        <div className="flex flex-wrap items-center gap-2.5">
          <div className="relative">
            <MagnifyingGlass className="absolute top-2 left-2.5 size-3.5 text-zinc-500" />
            <Input
              type="text"
              placeholder="Search templates, kits, stacks..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="h-8 w-64 pl-8 text-xs"
            />
          </div>

          <Select
            value={categoryFilter}
            onValueChange={(v) => v && setCategoryFilter(v)}
          >
            <SelectTrigger className="h-8 w-44 text-xs font-medium">
              <SelectValue placeholder="Category" />
            </SelectTrigger>
            <SelectContent>
              {CATEGORIES.map((cat) => (
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
        </div>

        <div className="font-mono text-xs text-zinc-500">
          Showing{" "}
          <span className="font-semibold text-zinc-200">
            {templates.length}
          </span>{" "}
          templates
        </div>
      </div>

      {/* Templates Grid */}
      {isLoading ? (
        <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-20">
          <BloomSpinner size={32} label="Loading marketplace templates..." />
        </div>
      ) : templates.length === 0 ? (
        <EmptyState
          icon={Storefront}
          title="No templates found"
          description="Try adjusting your search keywords or category filters."
          actionNode={
            searchQuery || categoryFilter !== "all" ? (
              <Button
                variant="outline"
                size="sm"
                onClick={() => {
                  setSearchQuery("");
                  setCategoryFilter("all");
                }}
              >
                Clear Filters
              </Button>
            ) : undefined
          }
        />
      ) : (
        <div className="grid grid-cols-1 gap-5 md:grid-cols-2 lg:grid-cols-2">
          {templates.map((tmpl) => {
            const isFeatured =
              tmpl.is_featured ||
              tmpl.is_editorial_featured ||
              tmpl.is_paid_featured;
            const iconProvider =
              (tmpl.metadata as { icon_provider?: string })?.icon_provider ||
              "flutter";
            const platforms = (tmpl.metadata as { platforms?: string[] })
              ?.platforms || ["ios", "android", "web"];
            const tags = (tmpl.metadata as { tags?: string[] })?.tags || [];
            const priceLabel = tmpl.is_free
              ? "Free"
              : `$${(tmpl.price_amount / 100).toFixed(0)}`;

            return (
              <Card
                key={tmpl.id}
                onClick={() => router.push(`/marketplace/${tmpl.id}`)}
                className={`group flex cursor-pointer flex-col justify-between border-zinc-800/80 bg-[#09090b] transition-all duration-200 hover:-translate-y-0.5 hover:border-zinc-700 hover:bg-zinc-900/40 hover:shadow-[0_4px_20px_rgba(0,0,0,0.6)] ${
                  isFeatured
                    ? "border-[#FF4B8B]/40 shadow-[0_0_15px_rgba(255,75,139,0.06)] ring-1 ring-[#FF4B8B]/30"
                    : ""
                }`}
              >
                <CardHeader className="space-y-3 pb-3">
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex items-center gap-3">
                      <div className="flex size-10 shrink-0 items-center justify-center rounded-lg border border-zinc-800 bg-zinc-950 p-2 shadow-inner transition-colors group-hover:border-zinc-700">
                        <ProviderIcon provider={iconProvider} size="md" />
                      </div>
                      <div>
                        <CardTitle className="text-sm font-bold text-zinc-100 transition-colors group-hover:text-[#FF4B8B]">
                          {tmpl.name}
                        </CardTitle>
                        <div className="flex items-center gap-2 font-mono text-[11px] text-zinc-500">
                          <span>v{tmpl.latest_version || "1.0.0"}</span>
                          <span>•</span>
                          <span>{tmpl.slug}</span>
                        </div>
                      </div>
                    </div>

                    <div className="flex flex-col items-end gap-1.5">
                      {tmpl.is_free ? (
                        <Badge
                          variant="outline"
                          className="border-emerald-500/40 bg-emerald-500/10 font-mono text-[11px] font-bold text-emerald-400"
                        >
                          FREE
                        </Badge>
                      ) : (
                        <Badge className="border border-zinc-700 bg-zinc-800 font-mono text-xs font-bold text-zinc-100">
                          {priceLabel}
                        </Badge>
                      )}

                      {tmpl.is_editorial_featured && (
                        <Badge
                          variant="outline"
                          className="gap-1 border-[#FF4B8B]/50 bg-gradient-to-r from-[#FF4B8B]/20 to-[#FF4B8B]/5 font-mono text-[9px] font-semibold text-[#FF4B8B] shadow-[0_0_8px_rgba(255,75,139,0.2)]"
                        >
                          <Sparkle className="size-2.5" weight="fill" />
                          <span>Featured</span>
                        </Badge>
                      )}
                    </div>
                  </div>

                  <CardDescription className="line-clamp-2 text-xs leading-relaxed text-zinc-400">
                    {tmpl.description}
                  </CardDescription>

                  {/* Tags */}
                  {tags.length > 0 && (
                    <div className="flex flex-wrap gap-1.5 pt-1">
                      {tags.slice(0, 4).map((tag) => (
                        <span
                          key={tag}
                          className="rounded border border-zinc-800 bg-zinc-900/80 px-1.5 py-0.5 font-mono text-[10px] text-zinc-400 transition-colors group-hover:border-zinc-700"
                        >
                          #{tag}
                        </span>
                      ))}
                    </div>
                  )}
                </CardHeader>

                <CardFooter className="flex items-center justify-between border-t border-zinc-800/60 bg-zinc-950/60 px-5 py-3 text-xs">
                  <div className="flex items-center gap-4">
                    {renderRatingStars(
                      tmpl.rating_bayesian_milli,
                      tmpl.rating_count,
                    )}

                    <div className="flex items-center gap-1 font-mono text-[11px] text-zinc-400">
                      <DownloadSimple className="size-3 text-zinc-500" />
                      <span>
                        {tmpl.install_count.toLocaleString()} installs
                      </span>
                    </div>
                  </div>

                  <div className="flex items-center gap-1.5">
                    {platforms.map((p) => (
                      <PlatformIcon key={p} platform={p} size="sm" />
                    ))}
                  </div>
                </CardFooter>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
