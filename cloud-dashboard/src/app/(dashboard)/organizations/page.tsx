"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import {
  Plus,
  Buildings,
  ArrowRight,
  ArrowsClockwise,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
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
import { PageHeader } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import { api } from "@/lib/api/client";
import { OrganizationResponse } from "@/lib/schemas/organization";
import { useOrganizationStore } from "@/stores/organization-store";

export default function OrganizationsPage() {
  const router = useRouter();
  const { currentOrganizationId, setCurrentOrganizationId } =
    useOrganizationStore();

  const [orgs, setOrgs] = React.useState<OrganizationResponse[]>([]);
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  const [createDialogOpen, setCreateDialogOpen] = React.useState(false);
  const [newOrgName, setNewOrgName] = React.useState("");
  const [isCreating, setIsCreating] = React.useState(false);

  const fetchOrganizations = React.useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const res = await api.get<{ results: OrganizationResponse[] }>(
        "/organizations",
      );
      setOrgs(res?.results ?? []);
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Failed to load organizations",
      );
    } finally {
      setIsLoading(false);
    }
  }, []);

  React.useEffect(() => {
    const run = async () => {
      await fetchOrganizations();
    };
    void run();
  }, [fetchOrganizations]);

  const handleCreateOrg = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newOrgName.trim()) return;

    setIsCreating(true);
    try {
      const created = await api.post<OrganizationResponse>("/organizations", {
        name: newOrgName.trim(),
      });
      toast.success("Organization created successfully");
      setCreateDialogOpen(false);
      setNewOrgName("");
      setCurrentOrganizationId(created.id);
      await fetchOrganizations();
      router.push(`/organizations/${created.id}`);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to create organization",
      );
    } finally {
      setIsCreating(false);
    }
  };

  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <PageHeader
        breadcrumbs={[
          { label: "Workspaces", href: "/organizations" },
          { label: "Organizations" },
        ]}
        title="Organizations"
        description="Manage your Bloom Cloud organizations, access tiers, and teams."
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchOrganizations()}
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
              <span>New Organization</span>
            </Button>
          </div>
        }
      />

      {error && (
        <Alert variant="destructive">
          <AlertTitle>Error loading organizations</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchOrganizations()}
              className="h-7 text-xs"
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      )}

      {isLoading ? (
        <div className="border-border/80 bg-card space-y-2 rounded-lg border p-6">
          <div className="flex items-center justify-center py-12">
            <BloomSpinner size={28} label="Loading organizations..." />
          </div>
        </div>
      ) : orgs.length === 0 ? (
        <EmptyState
          icon={Buildings}
          title="No organizations found"
          description="Create your first organization to start managing apps, builds, and team members."
          actionLabel="Create Organization"
          onAction={() => setCreateDialogOpen(true)}
        />
      ) : (
        <div className="border-border/80 bg-card overflow-hidden rounded-lg border">
          <Table>
            <TableHeader>
              <TableRow className="hover:bg-transparent">
                <TableHead className="w-[300px]">Organization</TableHead>
                <TableHead>Your Role</TableHead>
                <TableHead>Plan Tier</TableHead>
                <TableHead>Created Date</TableHead>
                <TableHead className="text-right">Action</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {orgs.map((org) => {
                const isCurrent = org.id === currentOrganizationId;
                return (
                  <TableRow
                    key={org.id}
                    onClick={() => router.push(`/organizations/${org.id}`)}
                    className="hover:bg-muted/50 cursor-pointer transition-colors"
                  >
                    <TableCell className="font-medium">
                      <div className="flex items-center gap-2.5">
                        <div className="border-border bg-muted/40 text-foreground flex size-8 shrink-0 items-center justify-center rounded-md border font-mono text-xs font-semibold">
                          {org.name.slice(0, 2).toUpperCase()}
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="text-foreground font-semibold">
                              {org.name}
                            </span>
                            {isCurrent && (
                              <Badge
                                variant="secondary"
                                className="px-1.5 py-0 font-mono text-[10px]"
                              >
                                Active
                              </Badge>
                            )}
                          </div>
                          <span className="text-muted-foreground font-mono text-xs">
                            {org.slug}
                          </span>
                        </div>
                      </div>
                    </TableCell>

                    <TableCell>
                      <Badge
                        variant="outline"
                        className="font-mono text-xs capitalize"
                      >
                        {org.role}
                      </Badge>
                    </TableCell>

                    <TableCell>
                      <Badge
                        variant="secondary"
                        className="bg-primary/10 text-primary border-primary/20 font-mono text-xs capitalize"
                      >
                        {org.plan}
                      </Badge>
                    </TableCell>

                    <TableCell className="text-muted-foreground font-mono text-xs">
                      {new Date(org.created_at).toLocaleDateString(undefined, {
                        year: "numeric",
                        month: "short",
                        day: "numeric",
                      })}
                    </TableCell>

                    <TableCell className="text-right">
                      <Button
                        variant="ghost"
                        size="sm"
                        className="text-muted-foreground hover:text-foreground h-7 gap-1 text-xs"
                        onClick={(e) => {
                          e.stopPropagation();
                          router.push(`/organizations/${org.id}`);
                        }}
                      >
                        <span>Manage</span>
                        <ArrowRight className="size-3" />
                      </Button>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </div>
      )}

      {/* Create Org Dialog */}
      <Dialog open={createDialogOpen} onOpenChange={setCreateDialogOpen}>
        <DialogContent className="sm:max-w-md">
          <form onSubmit={handleCreateOrg}>
            <DialogHeader>
              <DialogTitle>Create Organization</DialogTitle>
              <DialogDescription>
                An organization is the top-level container for projects, apps,
                and team billing.
              </DialogDescription>
            </DialogHeader>

            <div className="space-y-4 py-4">
              <div className="space-y-2">
                <Label htmlFor="org-name">Organization Name</Label>
                <Input
                  id="org-name"
                  placeholder="e.g. Acme Corp"
                  value={newOrgName}
                  onChange={(e) => setNewOrgName(e.target.value)}
                  autoFocus
                  required
                />
              </div>
            </div>

            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => setCreateDialogOpen(false)}
                disabled={isCreating}
              >
                Cancel
              </Button>
              <Button type="submit" disabled={isCreating || !newOrgName.trim()}>
                {isCreating ? (
                  <BloomSpinner size={16} speed="fast" className="mr-2" />
                ) : null}
                Create
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
