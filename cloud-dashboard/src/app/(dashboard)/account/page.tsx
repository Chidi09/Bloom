"use client";

import * as React from "react";
import {
  User,
  Key,
  ShieldCheck,
  Plus,
  Trash,
  Copy,
  Check,
  LockKey,
  EnvelopeSimple,
  IdentificationBadge,
  ArrowsClockwise,
  UploadSimple,
  X,
  Eye,
  EyeSlash,
  ShieldWarning,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
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
} from "@/components/ui/alert-dialog";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  CardFooter,
} from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { EmptyState } from "@/components/shared/empty-state";
import { PageHeader } from "@/components/shared/page-header";
import { UserAvatar } from "@/components/ui/user-avatar";
import { api } from "@/lib/api/client";
import { cn } from "@/lib/utils";
import { MeResponse, ApiTokenResponse } from "@/lib/schemas/account";

const TIMEZONES = [
  { value: "UTC", label: "UTC (Coordinated Universal Time)" },
  {
    value: "America/New_York",
    label: "America/New_York (EST/EDT - Eastern Time)",
  },
  {
    value: "America/Chicago",
    label: "America/Chicago (CST/CDT - Central Time)",
  },
  {
    value: "America/Denver",
    label: "America/Denver (MST/MDT - Mountain Time)",
  },
  {
    value: "America/Los_Angeles",
    label: "America/Los_Angeles (PST/PDT - Pacific Time)",
  },
  { value: "Europe/London", label: "Europe/London (GMT/BST)" },
  { value: "Europe/Berlin", label: "Europe/Berlin (CET/CEST)" },
  { value: "Asia/Tokyo", label: "Asia/Tokyo (JST)" },
  { value: "Asia/Singapore", label: "Asia/Singapore (SGT)" },
  { value: "Australia/Sydney", label: "Australia/Sydney (AEST/AEDT)" },
  { value: "Africa/Lagos", label: "Africa/Lagos (WAT)" },
];

export default function AccountSettingsPage() {
  const [activeTab, setActiveTab] = React.useState<
    "profile" | "tokens" | "security"
  >("profile");

  const [profile, setProfile] = React.useState<MeResponse | null>(null);
  const [tokens, setTokens] = React.useState<ApiTokenResponse[]>([]);
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Profile Form State
  const [displayName, setDisplayName] = React.useState("");
  const [avatarUrl, setAvatarUrl] = React.useState("");
  const [timezone, setTimezone] = React.useState("UTC");
  const [isSavingProfile, setIsSavingProfile] = React.useState(false);
  const [showUrlInput, setShowUrlInput] = React.useState(false);
  const fileInputRef = React.useRef<HTMLInputElement>(null);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (file.size > 2 * 1024 * 1024) {
      toast.error("Avatar image must be smaller than 2MB");
      return;
    }

    const reader = new FileReader();
    reader.onload = (event) => {
      const dataUrl = event.target?.result as string;
      setAvatarUrl(dataUrl);
      toast.success("Avatar image loaded into preview!");
    };
    reader.readAsDataURL(file);
  };

  const handleRemoveAvatar = () => {
    setAvatarUrl("");
    if (fileInputRef.current) {
      fileInputRef.current.value = "";
    }
    toast.info("Avatar reset to default");
  };

  // API Token Create Dialog State
  const [tokenDialogOpen, setTokenDialogOpen] = React.useState(false);
  const [newTokenName, setNewTokenName] = React.useState("");
  const [isCreatingToken, setIsCreatingToken] = React.useState(false);
  const [createdRawToken, setCreatedRawToken] = React.useState<string | null>(
    null,
  );
  const [copiedToken, setCopiedToken] = React.useState(false);
  const [showTokenMask, setShowTokenMask] = React.useState(false);

  // Revoke Token State
  const [tokenToRevoke, setTokenToRevoke] =
    React.useState<ApiTokenResponse | null>(null);
  const [isRevokingToken, setIsRevokingToken] = React.useState(false);

  // Password Change State
  const [currentPassword, setCurrentPassword] = React.useState("");
  const [newPassword, setNewPassword] = React.useState("");
  const [confirmPassword, setConfirmPassword] = React.useState("");
  const [isChangingPassword, setIsChangingPassword] = React.useState(false);

  const fetchData = React.useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const [meRes, tokensRes] = await Promise.all([
        api.get<MeResponse>("/auth/me"),
        api
          .get<{ results: ApiTokenResponse[] }>("/auth/tokens")
          .catch(() => ({ results: [] })),
      ]);

      setProfile(meRes);
      setDisplayName(meRes.display_name || "");
      setAvatarUrl(meRes.avatar_url || "");
      setTimezone(meRes.timezone || "UTC");
      setTokens(tokensRes.results ?? []);
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Failed to load account settings",
      );
    } finally {
      setIsLoading(false);
    }
  }, []);

  React.useEffect(() => {
    const run = async () => {
      await fetchData();
    };
    void run();
  }, [fetchData]);

  const handleSaveProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSavingProfile(true);
    try {
      const updated = await api.patch<MeResponse>("/auth/me", {
        display_name: displayName.trim(),
        avatar_url: avatarUrl.trim() || null,
        timezone,
      });
      setProfile(updated);
      toast.success("Profile preferences saved successfully");
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to update profile",
      );
    } finally {
      setIsSavingProfile(false);
    }
  };

  const handleCreateToken = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTokenName.trim()) return;

    setIsCreatingToken(true);
    try {
      const res = await api.post<{
        id: string;
        name: string;
        token: string;
        created_at: string;
        last_used_at: string | null;
      }>("/auth/token", {
        name: newTokenName.trim(),
      });

      setTokens((prev) => [
        {
          id: res.id,
          name: res.name,
          created_at: res.created_at,
          last_used_at: res.last_used_at,
        },
        ...prev,
      ]);
      setCreatedRawToken(res.token);
      toast.success("API token created. Make sure to copy it now!");
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to create API token",
      );
    } finally {
      setIsCreatingToken(false);
    }
  };

  const handleCloseTokenDialog = () => {
    setTokenDialogOpen(false);
    setNewTokenName("");
    setCreatedRawToken(null);
    setCopiedToken(false);
  };

  const handleRevokeToken = async () => {
    if (!tokenToRevoke) return;
    setIsRevokingToken(true);
    try {
      await api.delete(`/auth/token/${tokenToRevoke.id}`);
      toast.success(`API token "${tokenToRevoke.name}" revoked.`);
      setTokens((prev) => prev.filter((t) => t.id !== tokenToRevoke.id));
      setTokenToRevoke(null);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to revoke token",
      );
    } finally {
      setIsRevokingToken(false);
    }
  };

  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    if (newPassword.length < 8) {
      toast.error("New password must be at least 8 characters");
      return;
    }
    if (newPassword !== confirmPassword) {
      toast.error("New password and confirmation do not match");
      return;
    }

    setIsChangingPassword(true);
    try {
      await api.post("/auth/change-password", {
        current_password: currentPassword,
        new_password: newPassword,
      });
      toast.success("Password updated successfully");
      setCurrentPassword("");
      setNewPassword("");
      setConfirmPassword("");
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to update password",
      );
    } finally {
      setIsChangingPassword(false);
    }
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedToken(true);
    toast.success("API token copied to clipboard");
    setTimeout(() => setCopiedToken(false), 3000);
  };

  return (
    <div className="mx-auto max-w-4xl space-y-6">
      <PageHeader
        breadcrumbs={[
          { label: "Account", href: "/account" },
          { label: "Personal Settings" },
        ]}
        title="Account Settings"
        description="Manage your personal profile, personal access tokens, and login credentials."
        actions={
          <Button
            variant="outline"
            size="sm"
            onClick={() => void fetchData()}
            className="h-8 gap-1.5 text-xs text-zinc-300 transition-colors hover:bg-zinc-800"
          >
            <ArrowsClockwise className="size-3.5" />
            <span>Refresh</span>
          </Button>
        }
      />

      {error && (
        <Alert variant="destructive">
          <AlertTitle>Error loading settings</AlertTitle>
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

      <Tabs
        value={activeTab}
        onValueChange={(v) =>
          setActiveTab(v as "profile" | "tokens" | "security")
        }
        className="space-y-4"
      >
        <TabsList className="border-border/60 bg-zinc-900/80 p-1">
          <TabsTrigger value="profile" className="cursor-pointer gap-2 text-xs">
            <User className="size-3.5" />
            <span>Profile</span>
          </TabsTrigger>
          <TabsTrigger value="tokens" className="cursor-pointer gap-2 text-xs">
            <Key className="size-3.5" />
            <span>API Tokens ({tokens.length})</span>
          </TabsTrigger>
          <TabsTrigger
            value="security"
            className="cursor-pointer gap-2 text-xs"
          >
            <ShieldCheck className="size-3.5" />
            <span>Security & Password</span>
          </TabsTrigger>
        </TabsList>

        {/* Profile Tab */}
        <TabsContent value="profile" className="mt-0 space-y-4">
          {isLoading ? (
            <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-16">
              <BloomSpinner size={28} label="Loading profile preferences..." />
            </div>
          ) : (
            <form onSubmit={handleSaveProfile}>
              <Card className="border-border/80 bg-zinc-950/40">
                <CardHeader>
                  <CardTitle className="text-sm font-semibold text-zinc-100">
                    Personal Information
                  </CardTitle>
                  <CardDescription className="text-xs text-zinc-400">
                    Update your public display name, avatar, and preferred
                    operational timezone.
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  {/* Avatar Upload & Preview Section */}
                  <div className="flex flex-col gap-4 rounded-lg border border-zinc-800/80 bg-zinc-900/30 p-4 sm:flex-row sm:items-center">
                    <div className="relative shrink-0">
                      <UserAvatar
                        name={displayName || profile?.username || "Developer"}
                        src={
                          avatarUrl ||
                          (profile?.username === "dev"
                            ? "https://github.com/Chidi09.png"
                            : undefined)
                        }
                        size={64}
                        className="ring-2 ring-zinc-700"
                      />
                    </div>

                    <div className="flex-1 space-y-2">
                      <div>
                        <Label className="text-xs font-semibold text-zinc-200">
                          Profile Photo
                        </Label>
                        <p className="text-[11px] text-zinc-400">
                          Upload a photo or avatar image (PNG, JPG, or WebP, max
                          2MB).
                        </p>
                      </div>

                      <div className="flex flex-wrap items-center gap-2">
                        <input
                          ref={fileInputRef}
                          type="file"
                          accept="image/png,image/jpeg,image/webp,image/gif"
                          onChange={handleFileChange}
                          className="hidden"
                          aria-label="Upload profile photo"
                        />

                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          onClick={() => fileInputRef.current?.click()}
                          className="h-8 gap-1.5 border-zinc-700 bg-zinc-950 text-xs font-medium text-zinc-100 hover:bg-zinc-800"
                        >
                          <UploadSimple className="size-3.5" />
                          <span>Upload Image</span>
                        </Button>

                        {avatarUrl && (
                          <Button
                            type="button"
                            variant="ghost"
                            size="sm"
                            onClick={handleRemoveAvatar}
                            className="h-8 gap-1 text-xs text-zinc-400 hover:bg-zinc-800 hover:text-red-400"
                          >
                            <X className="size-3.5" />
                            <span>Remove</span>
                          </Button>
                        )}

                        <button
                          type="button"
                          onClick={() => setShowUrlInput(!showUrlInput)}
                          className="text-[11px] text-zinc-400 underline-offset-4 hover:text-zinc-200 hover:underline"
                        >
                          {showUrlInput
                            ? "Hide image URL"
                            : "Use custom image URL"}
                        </button>
                      </div>

                      {showUrlInput && (
                        <div className="pt-2">
                          <Input
                            id="avatar-url"
                            value={avatarUrl}
                            onChange={(e) => setAvatarUrl(e.target.value)}
                            placeholder="https://example.com/avatar.png"
                            className="border-zinc-700 bg-zinc-950 font-mono text-xs text-zinc-100"
                          />
                        </div>
                      )}
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <div className="space-y-1.5">
                      <Label
                        htmlFor="display-name"
                        className="text-xs font-medium text-zinc-300"
                      >
                        Display Name
                      </Label>
                      <div className="relative">
                        <IdentificationBadge className="absolute top-2.5 left-2.5 size-4 text-zinc-500" />
                        <Input
                          id="display-name"
                          value={displayName}
                          onChange={(e) => setDisplayName(e.target.value)}
                          placeholder="e.g. Chidi Anagor"
                          className="border-zinc-700 bg-zinc-900/60 pl-8 text-xs text-zinc-100"
                        />
                      </div>
                    </div>

                    <div className="space-y-1.5">
                      <Label
                        htmlFor="username"
                        className="text-xs font-medium text-zinc-300"
                      >
                        Username
                      </Label>
                      <Input
                        id="username"
                        value={profile?.username || ""}
                        disabled
                        className="border-zinc-800 bg-zinc-900/30 font-mono text-xs text-zinc-400"
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                    <div className="space-y-1.5">
                      <Label
                        htmlFor="email"
                        className="text-xs font-medium text-zinc-300"
                      >
                        Email Address
                      </Label>
                      <div className="relative">
                        <EnvelopeSimple className="absolute top-2.5 left-2.5 size-4 text-zinc-500" />
                        <Input
                          id="email"
                          value={profile?.email || ""}
                          disabled
                          className="border-zinc-800 bg-zinc-900/30 pl-8 font-mono text-xs text-zinc-400"
                        />
                      </div>
                    </div>

                    <div className="space-y-1.5">
                      <Label
                        htmlFor="timezone-select"
                        className="text-xs font-medium text-zinc-300"
                      >
                        Operational Timezone
                      </Label>
                      <Select
                        value={timezone}
                        onValueChange={(v) => v && setTimezone(v)}
                      >
                        <SelectTrigger
                          id="timezone-select"
                          className="border-zinc-700 bg-zinc-900/60 text-xs text-zinc-100"
                        >
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent className="border-zinc-800 bg-zinc-900 text-zinc-100">
                          {TIMEZONES.map((tz) => (
                            <SelectItem
                              key={tz.value}
                              value={tz.value}
                              className="text-xs"
                            >
                              {tz.label}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                  </div>
                </CardContent>
                <CardFooter className="flex justify-end border-t border-zinc-800/80 pt-4">
                  <Button
                    type="submit"
                    size="sm"
                    disabled={isSavingProfile}
                    className="bg-zinc-100 text-xs font-semibold text-zinc-950 hover:bg-zinc-200"
                  >
                    {isSavingProfile ? (
                      <BloomSpinner size={14} className="mr-2" />
                    ) : null}
                    Save Profile Changes
                  </Button>
                </CardFooter>
              </Card>
            </form>
          )}
        </TabsContent>

        {/* API Tokens Tab */}
        <TabsContent value="tokens" className="mt-0 space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-sm font-semibold text-zinc-100">
                Personal Access Tokens
              </h3>
              <p className="text-xs text-zinc-400">
                API tokens authenticate the Bloom CLI and automation pipelines
                with your account permissions.
              </p>
            </div>
            <Button
              size="sm"
              onClick={() => {
                setNewTokenName("");
                setCreatedRawToken(null);
                setTokenDialogOpen(true);
              }}
              className="h-8 gap-1.5 bg-zinc-100 text-xs font-semibold text-zinc-950 hover:bg-zinc-200"
            >
              <Plus className="size-3.5" weight="bold" />
              <span>Create Token</span>
            </Button>
          </div>

          {isLoading ? (
            <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-16">
              <BloomSpinner size={28} label="Loading API tokens..." />
            </div>
          ) : tokens.length === 0 ? (
            <EmptyState
              icon={Key}
              title="No API tokens created"
              description="Create a long-lived machine token to authenticate with the Bloom CLI from your terminal."
              actionLabel="Create Token"
              onAction={() => setTokenDialogOpen(true)}
            />
          ) : (
            <div className="border-border/80 bg-card overflow-hidden rounded-lg border shadow-xs">
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow className="hover:bg-transparent">
                      <TableHead className="w-[300px]">
                        Token Label / Name
                      </TableHead>
                      <TableHead>Created Date</TableHead>
                      <TableHead>Last Used</TableHead>
                      <TableHead className="text-right">Actions</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {tokens.map((token) => (
                      <TableRow
                        key={token.id}
                        className="hover:bg-muted/40 transition-colors"
                      >
                        <TableCell>
                          <div className="flex items-center gap-2.5">
                            <Key className="size-4 text-zinc-400" />
                            <span className="font-mono text-xs font-semibold text-zinc-100">
                              {token.name}
                            </span>
                          </div>
                        </TableCell>

                        <TableCell className="font-mono text-xs text-zinc-400">
                          {new Date(token.created_at).toLocaleDateString()}
                        </TableCell>

                        <TableCell className="font-mono text-xs text-zinc-400">
                          {token.last_used_at
                            ? new Date(token.last_used_at).toLocaleDateString()
                            : "Never"}
                        </TableCell>

                        <TableCell className="text-right">
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => setTokenToRevoke(token)}
                            className="h-7 gap-1 text-xs text-red-400 hover:bg-red-950/40 hover:text-red-300"
                          >
                            <Trash className="size-3.5" />
                            <span>Revoke</span>
                          </Button>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            </div>
          )}
        </TabsContent>

        {/* Security & Password Tab */}
        <TabsContent value="security" className="mt-0 space-y-4">
          <form onSubmit={handleChangePassword}>
            <Card className="border-border/80 bg-zinc-950/40">
              <CardHeader>
                <CardTitle className="text-sm font-semibold text-zinc-100">
                  Change Password
                </CardTitle>
                <CardDescription className="text-xs text-zinc-400">
                  Ensure your account uses a secure password of at least 8
                  characters.
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-1.5">
                  <Label
                    htmlFor="curr-pass"
                    className="text-xs font-medium text-zinc-300"
                  >
                    Current Password
                  </Label>
                  <div className="relative">
                    <LockKey className="absolute top-2.5 left-2.5 size-4 text-zinc-500" />
                    <Input
                      id="curr-pass"
                      type="password"
                      value={currentPassword}
                      onChange={(e) => setCurrentPassword(e.target.value)}
                      placeholder="••••••••••••"
                      className="border-zinc-700 bg-zinc-900/60 pl-8 font-mono text-xs text-zinc-100"
                      required
                    />
                  </div>
                </div>

                <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                  <div className="space-y-1.5">
                    <Label
                      htmlFor="new-pass"
                      className="text-xs font-medium text-zinc-300"
                    >
                      New Password
                    </Label>
                    <div className="relative">
                      <LockKey className="absolute top-2.5 left-2.5 size-4 text-zinc-500" />
                      <Input
                        id="new-pass"
                        type="password"
                        value={newPassword}
                        onChange={(e) => setNewPassword(e.target.value)}
                        placeholder="••••••••••••"
                        className="border-zinc-700 bg-zinc-900/60 pl-8 font-mono text-xs text-zinc-100"
                        required
                        minLength={8}
                      />
                    </div>
                  </div>

                  <div className="space-y-1.5">
                    <Label
                      htmlFor="conf-pass"
                      className="text-xs font-medium text-zinc-300"
                    >
                      Confirm New Password
                    </Label>
                    <div className="relative">
                      <LockKey className="absolute top-2.5 left-2.5 size-4 text-zinc-500" />
                      <Input
                        id="conf-pass"
                        type="password"
                        value={confirmPassword}
                        onChange={(e) => setConfirmPassword(e.target.value)}
                        placeholder="••••••••••••"
                        className="border-zinc-700 bg-zinc-900/60 pl-8 font-mono text-xs text-zinc-100"
                        required
                        minLength={8}
                      />
                    </div>
                  </div>
                </div>
              </CardContent>
              <CardFooter className="flex justify-end border-t border-zinc-800/80 pt-4">
                <Button
                  type="submit"
                  size="sm"
                  disabled={
                    isChangingPassword ||
                    !currentPassword ||
                    !newPassword ||
                    !confirmPassword
                  }
                  className="bg-zinc-100 text-xs font-semibold text-zinc-950 hover:bg-zinc-200"
                >
                  {isChangingPassword ? (
                    <BloomSpinner size={14} className="mr-2" />
                  ) : null}
                  Update Password
                </Button>
              </CardFooter>
            </Card>
          </form>

          {/* Active Authentication Summary */}
          <Card className="border-border/80 bg-zinc-950/40">
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-semibold text-zinc-100">
                Authentication Protocols
              </CardTitle>
              <CardDescription className="text-xs text-zinc-400">
                JWT Bearer Tokens and HMAC SHA-256 signatures are enforced for
                all requests.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="flex items-center justify-between rounded-md border border-zinc-800 bg-zinc-900/40 p-3 text-xs">
                <div className="flex items-center gap-2.5">
                  <ShieldCheck
                    className="size-4 text-emerald-400"
                    weight="fill"
                  />
                  <div>
                    <span className="font-semibold text-zinc-200">
                      Device & CLI Code Authentication
                    </span>
                    <p className="text-[11px] text-zinc-400">
                      RFC 8628 OAuth 2.0 device flow available for CLI terminal
                      sessions.
                    </p>
                  </div>
                </div>
                <Badge
                  variant="outline"
                  className="border-emerald-500/30 font-mono text-[10px] text-emerald-400"
                >
                  Active
                </Badge>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      {/* Create API Token Dialog */}
      <Dialog
        open={tokenDialogOpen}
        onOpenChange={(open) => !open && handleCloseTokenDialog()}
      >
        <DialogContent className="border-zinc-800 bg-zinc-900 text-zinc-100 sm:max-w-md">
          {!createdRawToken ? (
            <form onSubmit={handleCreateToken} className="space-y-4">
              <DialogHeader>
                <DialogTitle className="flex items-center gap-2 text-base">
                  <Key className="size-4 text-zinc-400" />
                  <span>Create API Token</span>
                </DialogTitle>
                <DialogDescription className="text-xs text-zinc-400">
                  Generate a personal machine token to authenticate CLI builds
                  and scripts.
                </DialogDescription>
              </DialogHeader>

              <div className="space-y-2 py-2">
                <Label
                  htmlFor="token-name"
                  className="text-xs font-medium text-zinc-300"
                >
                  Token Description / Label
                </Label>
                <Input
                  id="token-name"
                  value={newTokenName}
                  onChange={(e) => setNewTokenName(e.target.value)}
                  placeholder="e.g. CI/CD Runner - GitHub Actions"
                  className="border-zinc-700 bg-zinc-950 font-mono text-xs"
                  required
                />
              </div>

              <DialogFooter className="border-t border-zinc-800 pt-3">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={handleCloseTokenDialog}
                  disabled={isCreatingToken}
                  className="text-xs"
                >
                  Cancel
                </Button>
                <Button
                  type="submit"
                  size="sm"
                  disabled={isCreatingToken || !newTokenName.trim()}
                  className="bg-zinc-100 text-xs font-semibold text-zinc-950 hover:bg-zinc-200"
                >
                  {isCreatingToken ? (
                    <BloomSpinner size={14} className="mr-2" />
                  ) : null}
                  Generate Token
                </Button>
              </DialogFooter>
            </form>
          ) : (
            <div className="space-y-5">
              <DialogHeader>
                <div className="flex items-center gap-2">
                  <div className="flex size-8 shrink-0 items-center justify-center rounded-md border border-amber-500/30 bg-amber-500/10 text-amber-400">
                    <ShieldWarning className="size-4" weight="fill" />
                  </div>
                  <div>
                    <DialogTitle className="text-base font-semibold text-zinc-100">
                      Personal API Token Created
                    </DialogTitle>
                    <DialogDescription className="text-xs text-zinc-400">
                      Copy and store this token now — it will never be displayed
                      again.
                    </DialogDescription>
                  </div>
                </div>
              </DialogHeader>

              {/* Security Card */}
              <div className="rounded-xl border border-amber-500/40 bg-gradient-to-b from-amber-500/[0.08] via-zinc-950 to-zinc-950 p-4 shadow-[0_0_24px_-8px_rgba(245,158,11,0.2)]">
                <div className="flex items-center justify-between border-b border-amber-500/20 pb-2">
                  <div className="flex items-center gap-1.5 font-mono text-[11px] text-amber-400">
                    <LockKey className="size-3.5" />
                    <span>SECRET ACCESS KEY</span>
                  </div>
                  <Badge
                    variant="outline"
                    className="border-amber-500/40 bg-amber-500/10 font-mono text-[10px] text-amber-300 uppercase"
                  >
                    Single Reveal
                  </Badge>
                </div>

                <div className="mt-3 flex items-center justify-between gap-3 rounded-lg border border-zinc-800 bg-zinc-900/90 p-3 font-mono text-xs">
                  <div className="min-w-0 flex-1 break-all">
                    {showTokenMask ? (
                      <span className="tracking-widest text-zinc-500 select-none">
                        ••••••••••••••••••••••••••••••••••••••••
                      </span>
                    ) : (
                      <span className="font-semibold text-zinc-100 selection:bg-amber-500/30">
                        {createdRawToken}
                      </span>
                    )}
                  </div>

                  <div className="flex shrink-0 items-center gap-1">
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon-sm"
                      onClick={() => setShowTokenMask(!showTokenMask)}
                      className="size-7 text-zinc-400 hover:text-zinc-100"
                      title={showTokenMask ? "Reveal token" : "Mask token"}
                    >
                      {showTokenMask ? (
                        <Eye className="size-3.5" />
                      ) : (
                        <EyeSlash className="size-3.5" />
                      )}
                    </Button>

                    <Button
                      type="button"
                      size="sm"
                      onClick={() =>
                        createdRawToken && copyToClipboard(createdRawToken)
                      }
                      className={cn(
                        "h-7 gap-1.5 text-xs font-semibold transition-all",
                        copiedToken
                          ? "border border-emerald-500/40 bg-emerald-500/20 text-emerald-300 hover:bg-emerald-500/30"
                          : "bg-zinc-100 text-zinc-950 hover:bg-zinc-200",
                      )}
                    >
                      {copiedToken ? (
                        <>
                          <Check className="size-3.5 text-emerald-400" />
                          <span>Copied!</span>
                        </>
                      ) : (
                        <>
                          <Copy className="size-3.5" />
                          <span>Copy Token</span>
                        </>
                      )}
                    </Button>
                  </div>
                </div>

                <p className="mt-2.5 text-[11px] leading-relaxed text-zinc-400">
                  <span className="font-semibold text-amber-300/90">
                    Warning:
                  </span>{" "}
                  Bloom Cloud encrypts stored credentials with SHA-256 hashes
                  and cannot recover raw secret tokens. If lost, you will need
                  to revoke and generate a new key.
                </p>
              </div>

              <DialogFooter className="border-t border-zinc-800 pt-3">
                <Button
                  size="sm"
                  onClick={handleCloseTokenDialog}
                  className="w-full bg-zinc-100 text-xs font-semibold text-zinc-950 hover:bg-zinc-200"
                >
                  I have safely saved this token
                </Button>
              </DialogFooter>
            </div>
          )}
        </DialogContent>
      </Dialog>

      {/* Revoke API Token Alert Dialog */}
      <AlertDialog
        open={!!tokenToRevoke}
        onOpenChange={(open) => !open && setTokenToRevoke(null)}
      >
        <AlertDialogContent className="border-zinc-800 bg-zinc-900 text-zinc-100">
          <AlertDialogHeader>
            <AlertDialogTitle className="text-base">
              Revoke API Token?
            </AlertDialogTitle>
            <AlertDialogDescription className="text-xs text-zinc-400">
              Are you sure you want to revoke token{" "}
              <strong className="font-mono text-zinc-200">
                {tokenToRevoke?.name}
              </strong>
              ? Any CLI session or automation pipeline using this token will be
              immediately rejected.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={isRevokingToken} className="text-xs">
              Cancel
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={handleRevokeToken}
              disabled={isRevokingToken}
              className="bg-red-600 text-xs font-semibold text-white hover:bg-red-700"
            >
              {isRevokingToken ? (
                <BloomSpinner size={14} className="mr-2" />
              ) : null}
              Revoke Token
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
