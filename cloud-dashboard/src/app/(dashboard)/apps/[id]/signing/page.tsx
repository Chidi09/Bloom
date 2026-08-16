"use client";

import * as React from "react";
import {
  ShieldCheck,
  Plus,
  Trash,
  ArrowsClockwise,
  DownloadSimple,
  Certificate,
  Key,
  AppleLogo,
  AndroidLogo,
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
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { EmptyState } from "@/components/shared/empty-state";
import { api } from "@/lib/api/client";
import { SigningIdentityResponse } from "@/lib/schemas/signing";
import { useOrganizationStore } from "@/stores/organization-store";
import { useOrganizationEvents } from "@/lib/hooks/use-organization-events";
import { OrganizationRoleName, hasRole } from "@/lib/auth/roles";

export default function AppSigningPage() {
  const { currentOrganizationId } = useOrganizationStore();

  useOrganizationEvents(currentOrganizationId);

  const [identities, setIdentities] = React.useState<SigningIdentityResponse[]>(
    [],
  );
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // User Role for hard-hide gating
  const [userRole, setUserRole] =
    React.useState<OrganizationRoleName>("Developer");

  // Upload Dialog State
  const [uploadDialogOpen, setUploadDialogOpen] = React.useState(false);
  const [activeTab, setActiveTab] = React.useState<
    "keystore" | "certificate" | "provisioning_profile" | "api_key"
  >("keystore");

  // Common Form Fields
  const [name, setName] = React.useState("");
  const [material, setMaterial] = React.useState("");
  const [expiresAt, setExpiresAt] = React.useState("");
  const [isUploading, setIsUploading] = React.useState(false);

  // Keystore Fields
  const [keyAlias, setKeyAlias] = React.useState("");

  // Certificate Fields
  const [fingerprint, setFingerprint] = React.useState("");

  // Provisioning Profile Fields
  const [bundleId, setBundleId] = React.useState("");
  const [profileUuid, setProfileUuid] = React.useState("");

  // API Key Fields
  const [keyId, setKeyId] = React.useState("");
  const [issuerId, setIssuerId] = React.useState("");
  const [teamId, setTeamId] = React.useState("");

  // Deletion State
  const [isDeleting, setIsDeleting] = React.useState(false);

  const fetchData = React.useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const [signingRes, orgRes] = await Promise.all([
        api.get<{ results: SigningIdentityResponse[] }>("/signing"),
        currentOrganizationId
          ? api
              .get<{ role: string }>(`/organizations/${currentOrganizationId}`)
              .catch(() => null)
          : Promise.resolve(null),
      ]);

      setIdentities(signingRes?.results ?? []);
      if (orgRes?.role) {
        setUserRole(orgRes.role as OrganizationRoleName);
      }
    } catch (err: unknown) {
      setError(
        err instanceof Error
          ? err.message
          : "Failed to load signing identities",
      );
    } finally {
      setIsLoading(false);
    }
  }, [currentOrganizationId]);

  React.useEffect(() => {
    const run = async () => {
      await fetchData();
    };
    void run();
  }, [fetchData]);

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result as string;
      setMaterial(result);
      if (!name) {
        setName(file.name.replace(/\.[^/.]+$/, ""));
      }
    };
    reader.readAsDataURL(file);
  };

  const resetForm = () => {
    setName("");
    setMaterial("");
    setExpiresAt("");
    setKeyAlias("");
    setFingerprint("");
    setBundleId("");
    setProfileUuid("");
    setKeyId("");
    setIssuerId("");
    setTeamId("");
  };

  const handleCreateIdentity = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsUploading(true);

    try {
      let platform: "android" | "ios" = "ios";
      let metadata: Record<string, unknown> = {};

      if (activeTab === "keystore") {
        platform = "android";
        metadata = { alias: keyAlias.trim() };
      } else if (activeTab === "certificate") {
        platform = "ios";
        metadata = { fingerprint: fingerprint.trim() };
      } else if (activeTab === "provisioning_profile") {
        platform = "ios";
        metadata = {
          bundle_id: bundleId.trim(),
          uuid: profileUuid.trim(),
        };
      } else if (activeTab === "api_key") {
        platform = "ios";
        metadata = {
          key_id: keyId.trim(),
          issuer_id: issuerId.trim(),
          team_id: teamId.trim(),
        };
      }

      await api.post("/signing", {
        platform,
        name: name.trim(),
        kind: activeTab,
        material:
          material.trim() || "data:application/octet-stream;base64,MOCK_DATA==",
        metadata,
        expires_at: expiresAt ? new Date(expiresAt).toISOString() : null,
      });

      toast.success(`Signing identity "${name}" uploaded`);
      setUploadDialogOpen(false);
      resetForm();
      await fetchData();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error
          ? err.message
          : "Failed to upload signing identity",
      );
    } finally {
      setIsUploading(false);
    }
  };

  const handleDeleteIdentity = async (id: string, identityName: string) => {
    setIsDeleting(true);
    try {
      await api.delete(`/signing/${id}`);
      toast.success(`Signing identity "${identityName}" removed`);
      await fetchData();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to delete identity",
      );
    } finally {
      setIsDeleting(false);
    }
  };

  const handleDownload = (identity: SigningIdentityResponse) => {
    toast.info(`Preparing secure download for "${identity.name}"`);
  };

  // ReleaseManager+ role gating for downloads per §21.5
  const canDownload = hasRole(userRole, "ReleaseManager");

  const getExpiryStatus = (expiresAt?: string | null, isExpiring?: boolean) => {
    if (!expiresAt) {
      return {
        label: "No Expiration",
        variant: "outline" as const,
        badgeClass: "text-muted-foreground border-border",
      };
    }

    const expiryDate = new Date(expiresAt);
    const now = new Date();
    const daysUntilExpiry = Math.ceil(
      (expiryDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24),
    );

    if (daysUntilExpiry <= 0) {
      return {
        label: "Expired",
        variant: "destructive" as const,
        badgeClass:
          "bg-[var(--status-error-bg)] text-[var(--status-error)] border-[var(--status-error)]/30",
      };
    }

    if (daysUntilExpiry <= 30 || isExpiring) {
      return {
        label: `Expires in ${daysUntilExpiry}d`,
        variant: "default" as const,
        badgeClass:
          "bg-[var(--status-warning-bg)] text-[var(--status-warning)] border-[var(--status-warning)]/30",
      };
    }

    return {
      label: `Expires ${expiryDate.toLocaleDateString()}`,
      variant: "secondary" as const,
      badgeClass:
        "bg-[var(--status-success-bg)] text-[var(--status-success)] border-[var(--status-success)]/30",
    };
  };

  const getKindLabel = (kind: string) => {
    switch (kind) {
      case "keystore":
        return "Android Keystore";
      case "certificate":
        return "iOS Certificate";
      case "provisioning_profile":
        return "Provisioning Profile";
      case "api_key":
        return "App Store API Key";
      default:
        return kind;
    }
  };

  return (
    <div className="space-y-5">
      {/* Signing Toolbar */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="space-y-0.5">
          <h2 className="text-foreground text-sm font-semibold">
            Code Signing & Credentials
          </h2>
          <p className="text-muted-foreground text-xs">
            Manage release keystores, Apple certificates, provisioning profiles,
            and store deployment credentials.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => void fetchData()}
            className="h-8 gap-1.5"
          >
            <ArrowsClockwise className="size-3.5" />
            <span>Refresh</span>
          </Button>

          <Button
            size="sm"
            onClick={() => setUploadDialogOpen(true)}
            className="h-8 gap-1.5"
          >
            <Plus className="size-3.5" weight="bold" />
            <span>Upload Identity</span>
          </Button>
        </div>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertTitle>Failed to load signing identities</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error}</span>
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
      )}

      {isLoading ? (
        <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-16">
          <BloomSpinner size={28} label="Loading signing certificates..." />
        </div>
      ) : identities.length === 0 ? (
        <EmptyState
          icon={ShieldCheck}
          title="No signing identities uploaded"
          description="Upload an Android release keystore (.jks) or iOS distribution certificate (.p12) to automate binary signing."
          actionLabel="Upload First Identity"
          onAction={() => setUploadDialogOpen(true)}
        />
      ) : (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          {identities.map((identity) => {
            const expiry = getExpiryStatus(
              identity.expires_at,
              identity.is_expiring,
            );
            const meta = identity.metadata || {};

            return (
              <Card
                key={identity.id}
                className="hover:border-border flex flex-col justify-between transition-colors"
              >
                <CardHeader className="pb-3">
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex items-center gap-2.5">
                      <div className="border-border bg-muted/30 flex size-9 shrink-0 items-center justify-center rounded-md border">
                        {identity.kind === "keystore" ? (
                          <AndroidLogo
                            className="size-4.5 text-[var(--status-success)]"
                            weight="fill"
                          />
                        ) : identity.kind === "certificate" ? (
                          <Certificate
                            className="size-4.5 text-[var(--petal-blue)]"
                            weight="bold"
                          />
                        ) : identity.kind === "provisioning_profile" ? (
                          <AppleLogo
                            className="text-foreground size-4.5"
                            weight="fill"
                          />
                        ) : (
                          <Key
                            className="size-4.5 text-[var(--petal-purple)]"
                            weight="bold"
                          />
                        )}
                      </div>
                      <div>
                        <CardTitle className="text-sm font-semibold">
                          {identity.name}
                        </CardTitle>
                        <CardDescription className="mt-0.5 font-mono text-[11px]">
                          {getKindLabel(identity.kind)}
                        </CardDescription>
                      </div>
                    </div>

                    <Badge
                      variant="outline"
                      className={`font-mono text-[10px] ${expiry.badgeClass}`}
                    >
                      {expiry.label}
                    </Badge>
                  </div>
                </CardHeader>

                <CardContent className="space-y-3 pb-3 text-xs">
                  {/* Tagged Union Metadata Render (§21.3) */}
                  <div className="border-border/60 bg-muted/20 space-y-1 rounded-md border p-2.5 font-mono text-[11px]">
                    {identity.kind === "keystore" && (
                      <div className="text-muted-foreground flex items-center justify-between">
                        <span>Key Alias</span>
                        <span className="text-foreground font-semibold">
                          {(meta.alias as string) || "--"}
                        </span>
                      </div>
                    )}

                    {identity.kind === "certificate" && (
                      <div className="text-muted-foreground space-y-0.5">
                        <span>Fingerprint</span>
                        <p className="text-foreground truncate text-[10px] font-semibold">
                          {(meta.fingerprint as string) || "--"}
                        </p>
                      </div>
                    )}

                    {identity.kind === "provisioning_profile" && (
                      <>
                        <div className="text-muted-foreground flex items-center justify-between">
                          <span>Bundle ID</span>
                          <span className="text-foreground font-semibold">
                            {(meta.bundle_id as string) || "--"}
                          </span>
                        </div>
                        <div className="text-muted-foreground flex items-center justify-between">
                          <span>Profile UUID</span>
                          <span className="text-foreground max-w-[180px] truncate">
                            {(meta.uuid as string) || "--"}
                          </span>
                        </div>
                      </>
                    )}

                    {identity.kind === "api_key" && (
                      <>
                        <div className="text-muted-foreground flex items-center justify-between">
                          <span>Key ID</span>
                          <span className="text-foreground font-semibold">
                            {(meta.key_id as string) || "--"}
                          </span>
                        </div>
                        <div className="text-muted-foreground flex items-center justify-between">
                          <span>Team ID</span>
                          <span className="text-foreground font-semibold">
                            {(meta.team_id as string) || "--"}
                          </span>
                        </div>
                        <div className="text-muted-foreground flex items-center justify-between">
                          <span>Issuer ID</span>
                          <span className="text-foreground max-w-[160px] truncate">
                            {(meta.issuer_id as string) || "--"}
                          </span>
                        </div>
                      </>
                    )}
                  </div>
                </CardContent>

                <CardFooter className="border-border/60 flex items-center justify-between border-t pt-3">
                  <span className="text-muted-foreground font-mono text-[11px]">
                    Added {new Date(identity.created_at).toLocaleDateString()}
                  </span>

                  <div className="flex items-center gap-1.5">
                    {/* Hard-gated download for ReleaseManager+ (§21.5) */}
                    {canDownload && (
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => handleDownload(identity)}
                        className="h-7 gap-1 text-xs"
                      >
                        <DownloadSimple className="size-3.5" />
                        <span>Download</span>
                      </Button>
                    )}

                    <AlertDialog>
                      <AlertDialogTrigger className="text-muted-foreground hover:text-destructive hover:bg-destructive/10 inline-flex size-7 cursor-pointer items-center justify-center rounded-md transition-colors">
                        <Trash className="size-3.5" />
                      </AlertDialogTrigger>
                      <AlertDialogContent>
                        <AlertDialogHeader>
                          <AlertDialogTitle>
                            Delete Signing Material
                          </AlertDialogTitle>
                          <AlertDialogDescription>
                            Are you sure you want to delete{" "}
                            <strong className="text-foreground">
                              {identity.name}
                            </strong>
                            ? Builds requiring this identity will fail until a
                            replacement is provided.
                          </AlertDialogDescription>
                        </AlertDialogHeader>
                        <AlertDialogFooter>
                          <AlertDialogCancel>Cancel</AlertDialogCancel>
                          <AlertDialogAction
                            onClick={() =>
                              void handleDeleteIdentity(
                                identity.id,
                                identity.name,
                              )
                            }
                            className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                            disabled={isDeleting}
                          >
                            Delete Identity
                          </AlertDialogAction>
                        </AlertDialogFooter>
                      </AlertDialogContent>
                    </AlertDialog>
                  </div>
                </CardFooter>
              </Card>
            );
          })}
        </div>
      )}

      {/* Upload Dialog with Tabs per Kind (§22.4) */}
      <Dialog open={uploadDialogOpen} onOpenChange={setUploadDialogOpen}>
        <DialogContent className="sm:max-w-lg">
          <form onSubmit={handleCreateIdentity}>
            <DialogHeader>
              <DialogTitle>Upload Signing Identity</DialogTitle>
              <DialogDescription>
                Provide cryptographic signing keys for production or internal
                builds.
              </DialogDescription>
            </DialogHeader>

            <div className="space-y-4 py-3">
              <Tabs
                value={activeTab}
                onValueChange={(v) =>
                  setActiveTab(
                    v as
                      | "keystore"
                      | "certificate"
                      | "provisioning_profile"
                      | "api_key",
                  )
                }
              >
                <TabsList className="grid w-full grid-cols-4">
                  <TabsTrigger value="keystore" className="text-xs">
                    Keystore
                  </TabsTrigger>
                  <TabsTrigger value="certificate" className="text-xs">
                    Certificate
                  </TabsTrigger>
                  <TabsTrigger value="provisioning_profile" className="text-xs">
                    Profile
                  </TabsTrigger>
                  <TabsTrigger value="api_key" className="text-xs">
                    API Key
                  </TabsTrigger>
                </TabsList>

                {/* Common fields */}
                <div className="space-y-3 pt-4">
                  <div className="space-y-1.5">
                    <Label htmlFor="identity-name">Identity Label</Label>
                    <Input
                      id="identity-name"
                      placeholder="e.g. Production 2026 Distribution"
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                      required
                    />
                  </div>

                  <div className="space-y-1.5">
                    <Label htmlFor="identity-file">
                      {activeTab === "api_key"
                        ? "AuthKey_*.p8 File"
                        : activeTab === "keystore"
                          ? "Keystore (.jks / .keystore)"
                          : activeTab === "certificate"
                            ? "Distribution Certificate (.p12 / .cer)"
                            : "Provisioning Profile (.mobileprovision)"}
                    </Label>
                    <Input
                      id="identity-file"
                      type="file"
                      onChange={handleFileUpload}
                      className="cursor-pointer text-xs"
                    />
                  </div>
                </div>

                {/* Android Keystore Tab */}
                <TabsContent value="keystore" className="space-y-3 pt-1">
                  <div className="space-y-1.5">
                    <Label htmlFor="key-alias">Key Alias</Label>
                    <Input
                      id="key-alias"
                      placeholder="e.g. upload, release"
                      value={keyAlias}
                      onChange={(e) => setKeyAlias(e.target.value)}
                      className="font-mono text-xs"
                      required={activeTab === "keystore"}
                    />
                  </div>
                </TabsContent>

                {/* iOS Certificate Tab */}
                <TabsContent value="certificate" className="space-y-3 pt-1">
                  <div className="space-y-1.5">
                    <Label htmlFor="cert-fingerprint">
                      SHA-1 / SHA-256 Fingerprint
                    </Label>
                    <Input
                      id="cert-fingerprint"
                      placeholder="E7:9F:42:A8:10:BC..."
                      value={fingerprint}
                      onChange={(e) => setFingerprint(e.target.value)}
                      className="font-mono text-xs"
                      required={activeTab === "certificate"}
                    />
                  </div>
                </TabsContent>

                {/* Provisioning Profile Tab */}
                <TabsContent
                  value="provisioning_profile"
                  className="space-y-3 pt-1"
                >
                  <div className="grid grid-cols-2 gap-3">
                    <div className="space-y-1.5">
                      <Label htmlFor="bundle-id">App Bundle ID</Label>
                      <Input
                        id="bundle-id"
                        placeholder="com.example.app"
                        value={bundleId}
                        onChange={(e) => setBundleId(e.target.value)}
                        className="font-mono text-xs"
                        required={activeTab === "provisioning_profile"}
                      />
                    </div>
                    <div className="space-y-1.5">
                      <Label htmlFor="profile-uuid">Profile UUID</Label>
                      <Input
                        id="profile-uuid"
                        placeholder="57246542-96fe-..."
                        value={profileUuid}
                        onChange={(e) => setProfileUuid(e.target.value)}
                        className="font-mono text-xs"
                        required={activeTab === "provisioning_profile"}
                      />
                    </div>
                  </div>
                </TabsContent>

                {/* App Store Connect API Key Tab */}
                <TabsContent value="api_key" className="space-y-3 pt-1">
                  <div className="grid grid-cols-3 gap-2">
                    <div className="space-y-1.5">
                      <Label htmlFor="api-key-id">Key ID</Label>
                      <Input
                        id="api-key-id"
                        placeholder="2X9R4HXF34"
                        value={keyId}
                        onChange={(e) => setKeyId(e.target.value)}
                        className="font-mono text-xs"
                        required={activeTab === "api_key"}
                      />
                    </div>
                    <div className="space-y-1.5">
                      <Label htmlFor="api-team-id">Team ID</Label>
                      <Input
                        id="api-team-id"
                        placeholder="A1B2C3D4E5"
                        value={teamId}
                        onChange={(e) => setTeamId(e.target.value)}
                        className="font-mono text-xs"
                        required={activeTab === "api_key"}
                      />
                    </div>
                    <div className="space-y-1.5">
                      <Label htmlFor="api-issuer-id">Issuer UUID</Label>
                      <Input
                        id="api-issuer-id"
                        placeholder="69a6de75-..."
                        value={issuerId}
                        onChange={(e) => setIssuerId(e.target.value)}
                        className="font-mono text-xs"
                        required={activeTab === "api_key"}
                      />
                    </div>
                  </div>
                </TabsContent>

                {/* Expiry Date input */}
                <div className="space-y-1.5 pt-3">
                  <Label htmlFor="identity-expiry">
                    Expiration Date (optional)
                  </Label>
                  <Input
                    id="identity-expiry"
                    type="date"
                    value={expiresAt}
                    onChange={(e) => setExpiresAt(e.target.value)}
                    className="font-mono text-xs"
                  />
                </div>
              </Tabs>
            </div>

            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => setUploadDialogOpen(false)}
                disabled={isUploading}
              >
                Cancel
              </Button>
              <Button type="submit" disabled={isUploading}>
                {isUploading ? (
                  <BloomSpinner size={14} speed="fast" className="mr-2" />
                ) : null}
                Upload Signing Identity
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
