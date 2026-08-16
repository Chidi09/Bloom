"use client";

import * as React from "react";
import { useParams, useRouter } from "next/navigation";
import {
  UserPlus,
  Trash,
  FloppyDisk,
  WarningOctagon,
  ArrowsClockwise,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { UserAvatar } from "@/components/ui/user-avatar";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { PageHeader } from "@/components/shared/page-header";
import { OrganizationBillingTab } from "@/components/billing/organization-billing-tab";
import { api } from "@/lib/api/client";
import {
  OrganizationResponse,
  MembershipResponse,
} from "@/lib/schemas/organization";
import {
  OrganizationRole,
  OrganizationRoleName,
  hasRole,
} from "@/lib/auth/roles";
import { useOrganizationStore } from "@/stores/organization-store";

const ROLE_OPTIONS: OrganizationRoleName[] = [
  "Viewer",
  "Developer",
  "ReleaseManager",
  "Admin",
  "Owner",
];

export default function OrganizationDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const orgId = params.id;
  const { currentOrganizationId, setCurrentOrganizationId } =
    useOrganizationStore();

  const [org, setOrg] = React.useState<OrganizationResponse | null>(null);
  const [members, setMembers] = React.useState<MembershipResponse[]>([]);
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // General Form State
  const [formName, setFormName] = React.useState("");
  const [formBillingEmail, setFormBillingEmail] = React.useState("");
  const [isSavingGeneral, setIsSavingGeneral] = React.useState(false);

  // Invite Member Dialog State
  const [inviteDialogOpen, setInviteDialogOpen] = React.useState(false);
  const [inviteEmail, setInviteEmail] = React.useState("");
  const [inviteRole, setInviteRole] =
    React.useState<OrganizationRoleName>("Developer");
  const [isInviting, setIsInviting] = React.useState(false);

  // Danger Zone State
  const [deleteConfirmSlug, setDeleteConfirmSlug] = React.useState("");
  const [isDeletingOrg, setIsDeletingOrg] = React.useState(false);

  const currentUserRole = (org?.role as OrganizationRoleName) || "Viewer";

  const fetchOrgDetails = React.useCallback(async () => {
    if (!orgId) return;
    setIsLoading(true);
    setError(null);
    try {
      const [orgRes, membersRes] = await Promise.all([
        api.get<OrganizationResponse>(`/organizations/${orgId}`),
        api.get<{ results: MembershipResponse[] }>(
          `/organizations/${orgId}/members`,
        ),
      ]);
      setOrg(orgRes);
      setFormName(orgRes.name);
      setFormBillingEmail(
        (orgRes as unknown as { billing_email?: string }).billing_email || "",
      );
      setMembers(membersRes?.results ?? []);
    } catch (err: unknown) {
      setError(
        err instanceof Error
          ? err.message
          : "Failed to load organization details",
      );
    } finally {
      setIsLoading(false);
    }
  }, [orgId]);

  React.useEffect(() => {
    const run = async () => {
      await fetchOrgDetails();
    };
    void run();
  }, [fetchOrgDetails]);

  // General Settings Save
  const handleSaveGeneral = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!org) return;

    setIsSavingGeneral(true);
    try {
      const updated = await api.patch<OrganizationResponse>(
        `/organizations/${org.id}`,
        {
          name: formName.trim(),
          billing_email: formBillingEmail.trim() || null,
        },
      );
      setOrg(updated);
      setFormName(updated.name);
      toast.success("Organization settings saved");
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to update organization",
      );
    } finally {
      setIsSavingGeneral(false);
    }
  };

  // Member Invite
  const handleInviteMember = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!inviteEmail.trim() || !org) return;

    setIsInviting(true);
    try {
      await api.post(`/organizations/${org.id}/members`, {
        email: inviteEmail.trim(),
        role: inviteRole,
      });
      toast.success(`Invited ${inviteEmail} as ${inviteRole}`);
      setInviteDialogOpen(false);
      setInviteEmail("");
      setInviteRole("Developer");
      const memRes = await api.get<{ results: MembershipResponse[] }>(
        `/organizations/${org.id}/members`,
      );
      setMembers(memRes?.results ?? []);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to send invitation",
      );
    } finally {
      setIsInviting(false);
    }
  };

  // Member Role Change
  const handleChangeRole = async (memberId: string, newRole: string) => {
    if (!org) return;
    try {
      await api.patch(`/organizations/${org.id}/members/${memberId}`, {
        role: newRole,
      });
      toast.success("Member role updated");
      const memRes = await api.get<{ results: MembershipResponse[] }>(
        `/organizations/${org.id}/members`,
      );
      setMembers(memRes?.results ?? []);
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Failed to change role");
    }
  };

  // Member Remove
  const handleRemoveMember = async (memberId: string) => {
    if (!org) return;
    try {
      await api.delete(`/organizations/${org.id}/members/${memberId}`);
      toast.success("Member removed from organization");
      const memRes = await api.get<{ results: MembershipResponse[] }>(
        `/organizations/${org.id}/members`,
      );
      setMembers(memRes?.results ?? []);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to remove member",
      );
    }
  };

  // Danger Zone: Delete Organization
  const handleDeleteOrganization = async () => {
    if (!org || deleteConfirmSlug !== org.slug) return;
    setIsDeletingOrg(true);
    try {
      await api.delete(`/organizations/${org.id}`);
      toast.success("Organization deleted");
      if (currentOrganizationId === org.id) {
        setCurrentOrganizationId(null);
      }
      router.push("/organizations");
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to delete organization",
      );
      setIsDeletingOrg(false);
    }
  };

  if (isLoading) {
    return (
      <div className="mx-auto flex max-w-5xl items-center justify-center py-12">
        <BloomSpinner size={32} label="Loading organization..." />
      </div>
    );
  }

  if (error || !org) {
    return (
      <div className="mx-auto max-w-5xl space-y-4">
        <Alert variant="destructive">
          <AlertTitle>Failed to load organization</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error || "Organization not found"}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchOrgDetails()}
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      </div>
    );
  }

  const canManageMembers = hasRole(currentUserRole, "Admin");
  const canDeleteOrg = hasRole(currentUserRole, "Owner");

  return (
    <div className="mx-auto max-w-5xl space-y-5">
      <PageHeader
        breadcrumbs={[
          { label: "Organizations", href: "/organizations" },
          { label: org.name },
        ]}
        title={org.name}
        description={`Organization slug: ${org.slug}`}
        badge={
          <Badge variant="outline" className="font-mono text-xs capitalize">
            {org.plan} Plan
          </Badge>
        }
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchOrgDetails()}
              className="h-8 gap-1.5 transition-colors"
            >
              <ArrowsClockwise className="size-3.5" />
              <span>Refresh</span>
            </Button>
          </div>
        }
      />

      <Tabs defaultValue="general" className="w-full space-y-5">
        <TabsList className="bg-muted/40 border-border/80 border p-1">
          <TabsTrigger value="general" className="text-xs transition-colors">
            General
          </TabsTrigger>
          <TabsTrigger value="members" className="text-xs transition-colors">
            Members
          </TabsTrigger>
          <TabsTrigger value="billing" className="text-xs transition-colors">
            Billing
          </TabsTrigger>
          {canDeleteOrg && (
            <TabsTrigger
              value="danger"
              className="text-destructive data-[state=active]:text-destructive text-xs transition-colors"
            >
              Danger Zone
            </TabsTrigger>
          )}
        </TabsList>

        {/* GENERAL TAB */}
        <TabsContent value="general" className="space-y-5">
          <Card className="border-border/80 bg-card">
            <form onSubmit={handleSaveGeneral}>
              <CardHeader>
                <CardTitle className="text-base font-semibold">
                  Organization Profile
                </CardTitle>
                <CardDescription>
                  Update organization details and primary billing email.
                </CardDescription>
              </CardHeader>
              <CardContent className="max-w-md space-y-4">
                <div className="space-y-1.5">
                  <Label htmlFor="org-name">Organization Name</Label>
                  <Input
                    id="org-name"
                    value={formName}
                    onChange={(e) => setFormName(e.target.value)}
                    required
                  />
                </div>
                <div className="space-y-1.5">
                  <Label htmlFor="org-slug">Slug</Label>
                  <Input
                    id="org-slug"
                    value={org.slug}
                    disabled
                    className="bg-muted/30 font-mono text-xs"
                  />
                  <p className="text-muted-foreground text-[11px]">
                    Unique identifier used for URLs and CLI targeting.
                  </p>
                </div>
                <div className="space-y-1.5">
                  <Label htmlFor="org-billing-email">Billing Email</Label>
                  <Input
                    id="org-billing-email"
                    type="email"
                    placeholder="billing@example.com"
                    value={formBillingEmail}
                    onChange={(e) => setFormBillingEmail(e.target.value)}
                  />
                </div>
              </CardContent>
              <CardFooter className="border-border/60 flex justify-between border-t pt-4">
                <p className="text-muted-foreground font-mono text-xs">
                  Created {new Date(org.created_at).toLocaleDateString()}
                </p>
                <Button
                  type="submit"
                  disabled={isSavingGeneral}
                  size="sm"
                  className="gap-1.5"
                >
                  {isSavingGeneral ? (
                    <BloomSpinner size={14} speed="fast" />
                  ) : (
                    <FloppyDisk className="size-3.5" />
                  )}
                  <span>Save Changes</span>
                </Button>
              </CardFooter>
            </form>
          </Card>
        </TabsContent>

        {/* MEMBERS TAB */}
        <TabsContent value="members" className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-foreground text-sm font-semibold">
                Organization Members
              </h2>
              <p className="text-muted-foreground text-xs">
                Manage roles and invitations for teammates in this organization.
              </p>
            </div>
            {canManageMembers && (
              <Button
                size="sm"
                onClick={() => setInviteDialogOpen(true)}
                className="h-8 gap-1.5"
              >
                <UserPlus className="size-3.5" />
                <span>Invite Member</span>
              </Button>
            )}
          </div>

          <div className="border-border/80 bg-card overflow-hidden rounded-lg border shadow-xs">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="w-[300px]">Member</TableHead>
                  <TableHead>Email</TableHead>
                  <TableHead>Role</TableHead>
                  <TableHead>Joined Date</TableHead>
                  {canManageMembers && (
                    <TableHead className="text-right">Actions</TableHead>
                  )}
                </TableRow>
              </TableHeader>
              <TableBody>
                {members.map((member) => {
                  const targetRole = member.role as OrganizationRoleName;
                  // Hard-hide per §21.5 if current user's role is <= target role
                  const canEditThisMember =
                    canManageMembers &&
                    OrganizationRole[currentUserRole] >
                      (OrganizationRole[targetRole] || 0);

                  return (
                    <TableRow
                      key={member.id}
                      className="hover:bg-muted/40 transition-colors duration-150"
                    >
                      <TableCell>
                        <div className="flex items-center gap-3">
                          <UserAvatar
                            name={member.username || member.email}
                            size={28}
                          />
                          <div>
                            <p className="text-foreground text-xs font-semibold">
                              {member.username}
                            </p>
                            <span className="text-muted-foreground font-mono text-[10px]">
                              {member.user_id}
                            </span>
                          </div>
                        </div>
                      </TableCell>

                      <TableCell className="text-muted-foreground font-mono text-xs">
                        {member.email}
                      </TableCell>

                      <TableCell>
                        {canEditThisMember ? (
                          <Select
                            defaultValue={member.role}
                            onValueChange={(val) => {
                              if (val) void handleChangeRole(member.id, val);
                            }}
                          >
                            <SelectTrigger className="h-7 w-32 font-mono text-xs">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              {ROLE_OPTIONS.map((r) => {
                                // Can only assign roles lower than or equal to current role
                                if (
                                  OrganizationRole[r] >=
                                    OrganizationRole[currentUserRole] &&
                                  currentUserRole !== "Owner"
                                ) {
                                  return null;
                                }
                                return (
                                  <SelectItem
                                    key={r}
                                    value={r}
                                    className="font-mono text-xs"
                                  >
                                    {r}
                                  </SelectItem>
                                );
                              })}
                            </SelectContent>
                          </Select>
                        ) : (
                          <Badge
                            variant="outline"
                            className="font-mono text-xs capitalize"
                          >
                            {member.role}
                          </Badge>
                        )}
                      </TableCell>

                      <TableCell className="text-muted-foreground font-mono text-xs">
                        {new Date(member.created_at).toLocaleDateString()}
                      </TableCell>

                      {canManageMembers && (
                        <TableCell className="text-right">
                          {canEditThisMember && (
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => void handleRemoveMember(member.id)}
                              className="text-destructive hover:bg-destructive/10 hover:text-destructive h-7 gap-1 px-2 text-xs transition-colors"
                            >
                              <Trash className="size-3.5" />
                              <span>Remove</span>
                            </Button>
                          )}
                        </TableCell>
                      )}
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </div>
        </TabsContent>

        {/* BILLING TAB */}
        <TabsContent value="billing" className="space-y-6">
          <OrganizationBillingTab
            organizationId={org.id}
            canManageBilling={hasRole(currentUserRole, "Admin")}
          />
        </TabsContent>

        {/* DANGER ZONE TAB */}
        {canDeleteOrg && (
          <TabsContent value="danger" className="space-y-6">
            <Card className="border-destructive/40 bg-destructive/5">
              <CardHeader>
                <div className="text-destructive flex items-center gap-2">
                  <WarningOctagon className="size-5" />
                  <CardTitle className="text-base">
                    Delete Organization
                  </CardTitle>
                </div>
                <CardDescription>
                  Permanently delete &quot;{org.name}&quot; and all associated
                  apps, builds, and signing keys. This action cannot be undone.
                </CardDescription>
              </CardHeader>
              <CardFooter className="border-destructive/20 flex items-center justify-between border-t pt-4">
                <span className="text-muted-foreground text-xs">
                  Requires Owner permissions.
                </span>
                <AlertDialog>
                  <AlertDialogTrigger className="bg-destructive text-destructive-foreground hover:bg-destructive/90 inline-flex cursor-pointer items-center gap-1.5 rounded-md px-3 py-1.5 text-xs font-medium">
                    <Trash className="size-3.5" />
                    <span>Delete Organization</span>
                  </AlertDialogTrigger>
                  <AlertDialogContent>
                    <AlertDialogHeader>
                      <AlertDialogTitle>
                        Are you absolutely sure?
                      </AlertDialogTitle>
                      <AlertDialogDescription className="space-y-3">
                        <p>
                          This action will immediately terminate all active
                          builds, delete repositories mappings, and revoke
                          access for all members.
                        </p>
                        <p className="text-foreground">
                          Please type{" "}
                          <strong className="text-primary font-mono">
                            {org.slug}
                          </strong>{" "}
                          to confirm:
                        </p>
                        <Input
                          placeholder={org.slug}
                          value={deleteConfirmSlug}
                          onChange={(e) => setDeleteConfirmSlug(e.target.value)}
                          className="font-mono text-xs"
                          autoFocus
                        />
                      </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                      <AlertDialogCancel
                        onClick={() => setDeleteConfirmSlug("")}
                      >
                        Cancel
                      </AlertDialogCancel>
                      <AlertDialogAction
                        disabled={
                          deleteConfirmSlug !== org.slug || isDeletingOrg
                        }
                        onClick={handleDeleteOrganization}
                        className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                      >
                        {isDeletingOrg ? (
                          <BloomSpinner
                            size={14}
                            speed="fast"
                            className="mr-2"
                          />
                        ) : null}
                        Delete Forever
                      </AlertDialogAction>
                    </AlertDialogFooter>
                  </AlertDialogContent>
                </AlertDialog>
              </CardFooter>
            </Card>
          </TabsContent>
        )}
      </Tabs>

      {/* Invite Member Dialog */}
      <Dialog open={inviteDialogOpen} onOpenChange={setInviteDialogOpen}>
        <DialogContent className="sm:max-w-md">
          <form onSubmit={handleInviteMember}>
            <DialogHeader>
              <DialogTitle>Invite Team Member</DialogTitle>
              <DialogDescription>
                Send an invitation to join {org.name}.
              </DialogDescription>
            </DialogHeader>

            <div className="space-y-4 py-4">
              <div className="space-y-2">
                <Label htmlFor="invite-email">Email Address</Label>
                <Input
                  id="invite-email"
                  type="email"
                  placeholder="colleague@example.com"
                  value={inviteEmail}
                  onChange={(e) => setInviteEmail(e.target.value)}
                  autoFocus
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="invite-role">Role</Label>
                <Select
                  value={inviteRole}
                  onValueChange={(val) =>
                    setInviteRole(val as OrganizationRoleName)
                  }
                >
                  <SelectTrigger id="invite-role" className="font-mono text-xs">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {ROLE_OPTIONS.map((r) => (
                      <SelectItem
                        key={r}
                        value={r}
                        className="font-mono text-xs"
                      >
                        {r}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => setInviteDialogOpen(false)}
                disabled={isInviting}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                disabled={isInviting || !inviteEmail.trim()}
              >
                {isInviting ? (
                  <BloomSpinner size={14} speed="fast" className="mr-2" />
                ) : null}
                Send Invite
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
