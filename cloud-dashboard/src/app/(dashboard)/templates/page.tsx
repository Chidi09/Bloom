"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import {
  FolderUser,
  Plus,
  ArrowsClockwise,
  UploadSimple,
  Archive,
  Eye,
  GitBranch,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { StatusBadge } from "@/components/status/status-badge";
import { SellerOnboardingCard } from "@/components/billing/seller-onboarding-card";
import { PageHeader } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import { api } from "@/lib/api/client";
import {
  TemplateResponse,
  TemplateVersionResponse,
} from "@/lib/schemas/marketplace";
import { useOrganizationStore } from "@/stores/organization-store";

export default function OrgTemplatesManagementPage() {
  const router = useRouter();
  const { currentOrganizationId } = useOrganizationStore();

  const [templates, setTemplates] = React.useState<TemplateResponse[]>([]);
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Create Template Dialog State
  const [createDialogOpen, setCreateDialogOpen] = React.useState(false);
  const [formName, setFormName] = React.useState("");
  const [formDescription, setFormDescription] = React.useState("");
  const [formVisibility, setFormVisibility] = React.useState<
    "private" | "public"
  >("private");
  const [formIsFree, setFormIsFree] = React.useState(true);
  const [formPriceDollars, setFormPriceDollars] = React.useState("29");
  const [isSubmittingCreate, setIsSubmittingCreate] = React.useState(false);

  // Version Manager Sheet State
  const [versionSheetTemplate, setVersionSheetTemplate] =
    React.useState<TemplateResponse | null>(null);
  const [templateVersions, setTemplateVersions] = React.useState<
    TemplateVersionResponse[]
  >([]);
  const [isLoadingVersions, setIsLoadingVersions] = React.useState(false);

  // New Version Dialog State
  const [newVersionDialogOpen, setNewVersionDialogOpen] = React.useState(false);
  const [newVersionSemver, setNewVersionSemver] = React.useState("");
  const [newVersionChangelog, setNewVersionChangelog] = React.useState("");
  const [newVersionReadme, setNewVersionReadme] = React.useState("");
  const [isSubmittingVersion, setIsSubmittingVersion] = React.useState(false);

  const fetchOrgTemplates = React.useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const res = await api.get<{ results: TemplateResponse[] }>("/templates");
      setTemplates(res?.results ?? []);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to load templates");
    } finally {
      setIsLoading(false);
    }
  }, []);

  React.useEffect(() => {
    const run = async () => {
      await fetchOrgTemplates();
    };
    void run();
  }, [fetchOrgTemplates, currentOrganizationId]);

  const handleCreateTemplate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formName.trim()) return;

    setIsSubmittingCreate(true);
    try {
      const priceAmount = formIsFree
        ? 0
        : Math.round(parseFloat(formPriceDollars || "0") * 100);
      const created = await api.post<TemplateResponse>("/templates", {
        name: formName.trim(),
        description: formDescription.trim() || undefined,
        visibility: formVisibility,
        is_free: formIsFree,
        price_amount: priceAmount,
        price_currency: "usd",
      });
      toast.success(`Template "${created.name}" created`);
      setCreateDialogOpen(false);
      setFormName("");
      setFormDescription("");
      void fetchOrgTemplates();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to create template",
      );
    } finally {
      setIsSubmittingCreate(false);
    }
  };

  const handlePublish = async (tmpl: TemplateResponse) => {
    try {
      await api.post(`/templates/${tmpl.id}/publish`, { visibility: "public" });
      toast.success(`Template "${tmpl.name}" published to Marketplace`);
      void fetchOrgTemplates();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to publish template",
      );
    }
  };

  const handleArchive = async (tmpl: TemplateResponse) => {
    try {
      await api.post(`/templates/${tmpl.id}/archive`, {});
      toast.success(`Template "${tmpl.name}" archived`);
      void fetchOrgTemplates();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to archive template",
      );
    }
  };

  const openVersionManager = async (tmpl: TemplateResponse) => {
    setVersionSheetTemplate(tmpl);
    setIsLoadingVersions(true);
    try {
      const res = await api.get<{ results: TemplateVersionResponse[] }>(
        `/templates/${tmpl.id}/versions`,
      );
      setTemplateVersions(res?.results ?? []);
    } catch {
      toast.error("Failed to load versions");
    } finally {
      setIsLoadingVersions(false);
    }
  };

  const handleCreateVersion = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!versionSheetTemplate || !newVersionSemver.trim()) return;

    setIsSubmittingVersion(true);
    try {
      await api.post(`/templates/${versionSheetTemplate.id}/versions`, {
        version: newVersionSemver.trim(),
        changelog: newVersionChangelog.trim() || undefined,
        readme: newVersionReadme.trim() || undefined,
      });
      toast.success(`Version ${newVersionSemver} published`);
      setNewVersionDialogOpen(false);
      setNewVersionSemver("");
      setNewVersionChangelog("");
      setNewVersionReadme("");
      void openVersionManager(versionSheetTemplate);
      void fetchOrgTemplates();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to create version",
      );
    } finally {
      setIsSubmittingVersion(false);
    }
  };

  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <PageHeader
        breadcrumbs={[
          { label: "Marketplace", href: "/marketplace" },
          { label: "My Templates" },
        ]}
        title="Organization Templates"
        description="Publish and maintain custom starter kits, version releases, and payout models."
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => router.push("/marketplace")}
              className="h-8 gap-1.5 text-xs text-zinc-200"
            >
              <Eye className="size-3.5" />
              <span>Browse Public</span>
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchOrgTemplates()}
              className="h-8 gap-1.5"
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
              <span>Create Template</span>
            </Button>
          </div>
        }
      />

      <SellerOnboardingCard />

      {error && (
        <Alert variant="destructive">
          <AlertTitle>Error loading templates</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchOrgTemplates()}
              className="h-7 text-xs"
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      )}

      {isLoading ? (
        <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-16">
          <BloomSpinner size={28} label="Loading your templates..." />
        </div>
      ) : templates.length === 0 ? (
        <EmptyState
          icon={FolderUser}
          title="No templates created yet"
          description="Create and publish starter templates to share across your organization or monetize on Bloom Marketplace."
          actionNode={
            <Button
              size="sm"
              onClick={() => setCreateDialogOpen(true)}
              className="gap-1.5"
            >
              <Plus className="size-3.5" weight="bold" />
              <span>Create Template</span>
            </Button>
          }
        />
      ) : (
        <div className="border-border/80 bg-card overflow-hidden rounded-lg border">
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="w-[260px]">Template</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Visibility</TableHead>
                  <TableHead>Pricing</TableHead>
                  <TableHead>Latest Version</TableHead>
                  <TableHead>Installs</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {templates.map((tmpl) => {
                  const priceFormatted = tmpl.is_free
                    ? "Free"
                    : `$${(tmpl.price_amount / 100).toFixed(0)} USD`;

                  return (
                    <TableRow
                      key={tmpl.id}
                      className="hover:bg-muted/40 transition-colors"
                    >
                      <TableCell>
                        <div className="space-y-0.5">
                          <p className="text-xs font-semibold text-zinc-100">
                            {tmpl.name}
                          </p>
                          <p className="font-mono text-[11px] text-zinc-500">
                            {tmpl.slug}
                          </p>
                        </div>
                      </TableCell>

                      <TableCell>
                        <StatusBadge status={tmpl.status} size="sm" />
                      </TableCell>

                      <TableCell>
                        <Badge
                          variant="outline"
                          className="font-mono text-[11px] capitalize"
                        >
                          {tmpl.visibility}
                        </Badge>
                      </TableCell>

                      <TableCell className="font-mono text-xs text-zinc-200">
                        {priceFormatted}
                      </TableCell>

                      <TableCell className="font-mono text-xs text-zinc-200">
                        v{tmpl.latest_version || "1.0.0"} ({tmpl.versions_count}{" "}
                        total)
                      </TableCell>

                      <TableCell className="font-mono text-xs text-zinc-400">
                        {tmpl.install_count.toLocaleString()}
                      </TableCell>

                      <TableCell className="text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => void openVersionManager(tmpl)}
                            className="h-7 text-xs"
                          >
                            <GitBranch className="mr-1 size-3" />
                            <span>Versions</span>
                          </Button>

                          {tmpl.status !== "published" && (
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => void handlePublish(tmpl)}
                              className="h-7 text-xs text-emerald-400 hover:bg-emerald-950/30"
                            >
                              <UploadSimple className="mr-1 size-3" />
                              <span>Publish</span>
                            </Button>
                          )}

                          {tmpl.status !== "archived" && (
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => void handleArchive(tmpl)}
                              className="h-7 text-xs text-zinc-400 hover:text-amber-400"
                            >
                              <Archive className="size-3" />
                            </Button>
                          )}
                        </div>
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </div>
        </div>
      )}

      {/* Create Template Dialog */}
      <Dialog open={createDialogOpen} onOpenChange={setCreateDialogOpen}>
        <DialogContent className="border-zinc-800 bg-zinc-950 text-zinc-100 sm:max-w-lg">
          <form onSubmit={handleCreateTemplate}>
            <DialogHeader>
              <DialogTitle>Create New Template</DialogTitle>
              <DialogDescription>
                Define metadata and pricing for a new template project.
              </DialogDescription>
            </DialogHeader>

            <div className="space-y-4 py-4">
              <div className="space-y-1.5">
                <Label htmlFor="tmpl-name" className="text-xs">
                  Template Name
                </Label>
                <Input
                  id="tmpl-name"
                  placeholder="e.g. Flutter Multi-Tenant Starter"
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                  required
                  className="text-xs"
                />
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="tmpl-desc" className="text-xs">
                  Description
                </Label>
                <Textarea
                  id="tmpl-desc"
                  placeholder="Describe framework features, architecture, and included screens..."
                  value={formDescription}
                  onChange={(e) => setFormDescription(e.target.value)}
                  rows={3}
                  className="text-xs"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <Label htmlFor="tmpl-vis" className="text-xs">
                    Visibility Scope
                  </Label>
                  <Select
                    value={formVisibility}
                    onValueChange={(val) =>
                      val && setFormVisibility(val as "private" | "public")
                    }
                  >
                    <SelectTrigger id="tmpl-vis" className="text-xs">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="private" className="text-xs">
                        Private (Org only)
                      </SelectItem>
                      <SelectItem value="public" className="text-xs">
                        Public (Marketplace)
                      </SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                <div className="space-y-1.5">
                  <Label className="text-xs">Pricing Tier</Label>
                  <div className="flex items-center gap-2 pt-2">
                    <Switch
                      id="tmpl-free"
                      checked={formIsFree}
                      onCheckedChange={setFormIsFree}
                    />
                    <Label
                      htmlFor="tmpl-free"
                      className="cursor-pointer text-xs font-normal"
                    >
                      {formIsFree ? "Free Template" : "Paid Commercial"}
                    </Label>
                  </div>
                </div>
              </div>

              {!formIsFree && (
                <div className="space-y-1.5 pt-1">
                  <Label htmlFor="tmpl-price" className="text-xs">
                    Price Amount (USD)
                  </Label>
                  <Input
                    id="tmpl-price"
                    type="number"
                    min="1"
                    step="1"
                    placeholder="29"
                    value={formPriceDollars}
                    onChange={(e) => setFormPriceDollars(e.target.value)}
                    className="font-mono text-xs"
                  />
                </div>
              )}
            </div>

            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => setCreateDialogOpen(false)}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                disabled={isSubmittingCreate || !formName.trim()}
              >
                {isSubmittingCreate ? (
                  <BloomSpinner size={14} speed="fast" className="mr-2" />
                ) : null}
                Create Template
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      {/* Version Manager Slide-over Sheet */}
      <Sheet
        open={versionSheetTemplate !== null}
        onOpenChange={(open) => !open && setVersionSheetTemplate(null)}
      >
        <SheetContent
          side="right"
          className="w-full overflow-y-auto border-zinc-800 bg-[#09090b] text-zinc-100 sm:max-w-xl"
        >
          {versionSheetTemplate && (
            <div className="space-y-6 py-2">
              <SheetHeader>
                <div className="flex items-center justify-between">
                  <SheetTitle className="text-base font-semibold text-zinc-100">
                    Version Management
                  </SheetTitle>
                  <Button
                    size="sm"
                    onClick={() => setNewVersionDialogOpen(true)}
                    className="h-7 gap-1 text-xs"
                  >
                    <Plus className="size-3" weight="bold" />
                    <span>New Version</span>
                  </Button>
                </div>
                <SheetDescription className="text-xs text-zinc-400">
                  Manage releases for &quot;{versionSheetTemplate.name}&quot;.
                </SheetDescription>
              </SheetHeader>

              {isLoadingVersions ? (
                <div className="flex items-center justify-center py-12">
                  <BloomSpinner size={24} label="Loading versions..." />
                </div>
              ) : templateVersions.length === 0 ? (
                <div className="rounded-lg border border-zinc-800 bg-zinc-950 p-6 text-center text-xs text-zinc-500">
                  No versions published yet. Publish your initial v1.0.0
                  release.
                </div>
              ) : (
                <div className="space-y-3">
                  {templateVersions.map((ver) => (
                    <div
                      key={ver.id}
                      className="space-y-2 rounded-lg border border-zinc-800 bg-zinc-950 p-4 font-mono text-xs"
                    >
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-bold text-zinc-100">
                          v{ver.version}
                        </span>
                        <span className="text-[11px] text-zinc-500">
                          {new Date(ver.created_at).toLocaleDateString()}
                        </span>
                      </div>
                      {ver.changelog && (
                        <p className="font-sans text-xs text-zinc-300">
                          {ver.changelog}
                        </p>
                      )}
                      <div className="flex justify-between border-t border-zinc-800/80 pt-2 text-[11px] text-zinc-500">
                        <span>Installs: {ver.install_count}</span>
                        <span>ID: {ver.id}</span>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </SheetContent>
      </Sheet>

      {/* New Version Dialog */}
      <Dialog
        open={newVersionDialogOpen}
        onOpenChange={setNewVersionDialogOpen}
      >
        <DialogContent className="border-zinc-800 bg-zinc-950 text-zinc-100 sm:max-w-md">
          <form onSubmit={handleCreateVersion}>
            <DialogHeader>
              <DialogTitle>Publish New Version</DialogTitle>
              <DialogDescription>
                Release an updated semver release for this template.
              </DialogDescription>
            </DialogHeader>

            <div className="space-y-4 py-4">
              <div className="space-y-1.5">
                <Label htmlFor="ver-num" className="text-xs">
                  Semantic Version
                </Label>
                <Input
                  id="ver-num"
                  placeholder="e.g. 1.1.0"
                  value={newVersionSemver}
                  onChange={(e) => setNewVersionSemver(e.target.value)}
                  className="font-mono text-xs"
                  required
                />
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="ver-change" className="text-xs">
                  Changelog / Release Summary
                </Label>
                <Input
                  id="ver-change"
                  placeholder="e.g. Added dark mode toggle, fixed Supabase auth listener"
                  value={newVersionChangelog}
                  onChange={(e) => setNewVersionChangelog(e.target.value)}
                  className="text-xs"
                />
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="ver-readme" className="text-xs">
                  Documentation / Readme Markdown
                </Label>
                <Textarea
                  id="ver-readme"
                  placeholder="# Quickstart&#10;flutter pub get..."
                  value={newVersionReadme}
                  onChange={(e) => setNewVersionReadme(e.target.value)}
                  rows={4}
                  className="font-mono text-xs"
                />
              </div>
            </div>

            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => setNewVersionDialogOpen(false)}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                disabled={isSubmittingVersion || !newVersionSemver.trim()}
              >
                {isSubmittingVersion ? (
                  <BloomSpinner size={14} speed="fast" className="mr-2" />
                ) : null}
                Publish Version
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
