"use client";

import * as React from "react";
import { useParams, useRouter } from "next/navigation";
import {
  Key,
  Plus,
  Trash,
  ArrowsClockwise,
  UploadSimple,
  ClockCounterClockwise,
  LockSimple,
  FileCode,
  DotsThreeVertical,
  PencilSimple,
  ArrowCounterClockwise,
} from "@phosphor-icons/react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import { Textarea } from "@/components/ui/textarea";
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
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
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
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { EmptyState } from "@/components/shared/empty-state";
import { api } from "@/lib/api/client";
import { SecretResponse } from "@/lib/schemas/secret";
import { EnvironmentResponse } from "@/lib/schemas/environment";
import { useOrganizationStore } from "@/stores/organization-store";
import { useOrganizationEvents } from "@/lib/hooks/use-organization-events";

interface ParsedEnvPair {
  key: string;
  value: string;
  is_json: boolean;
}

export default function AppSecretsPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const appId = params.id;
  const { currentOrganizationId } = useOrganizationStore();

  useOrganizationEvents(currentOrganizationId);

  const [environments, setEnvironments] = React.useState<EnvironmentResponse[]>(
    [],
  );
  const [selectedEnvId, setSelectedEnvId] = React.useState<string>("");
  const [secrets, setSecrets] = React.useState<SecretResponse[]>([]);
  const [isLoading, setIsLoading] = React.useState(true);
  const [isSecretsLoading, setIsSecretsLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  // Add / Edit Sheet State
  const [sheetOpen, setSheetOpen] = React.useState(false);
  const [editingSecret, setEditingSecret] =
    React.useState<SecretResponse | null>(null);
  const [secretKey, setSecretKey] = React.useState("");
  const [secretValue, setSecretValue] = React.useState("");
  const [isJson, setIsJson] = React.useState(false);
  const [isSaving, setIsSaving] = React.useState(false);

  // Rollback Dialog State
  const [rollbackOpen, setRollbackOpen] = React.useState(false);
  const [targetSecret, setTargetSecret] = React.useState<SecretResponse | null>(
    null,
  );
  const [rollbackVersion, setRollbackVersion] = React.useState<number>(1);
  const [isRollingBack, setIsRollingBack] = React.useState(false);

  // Delete Alert State
  const [deleteAlertOpen, setDeleteAlertOpen] = React.useState(false);
  const [deletingSecret, setDeletingSecret] =
    React.useState<SecretResponse | null>(null);
  const [isDeleting, setIsDeleting] = React.useState(false);

  // Bulk Import State
  const [importOpen, setImportOpen] = React.useState(false);
  const [rawEnvText, setRawEnvText] = React.useState("");
  const [parsedPairs, setParsedPairs] = React.useState<ParsedEnvPair[]>([]);
  const [isImporting, setIsImporting] = React.useState(false);

  const fetchEnvironments = React.useCallback(async () => {
    if (!appId) return;
    setIsLoading(true);
    setError(null);
    try {
      const res = await api.get<{ results: EnvironmentResponse[] }>(
        "/environments",
        { params: { app_id: appId } },
      );
      const envs = res?.results ?? [];
      setEnvironments(envs);
      if (envs.length > 0) {
        setSelectedEnvId((curr) => curr || envs[0].id);
      }
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Failed to load environments",
      );
    } finally {
      setIsLoading(false);
    }
  }, [appId]);

  const fetchSecrets = React.useCallback(async (envId: string) => {
    if (!envId) {
      setSecrets([]);
      return;
    }
    setIsSecretsLoading(true);
    try {
      const res = await api.get<{ results: SecretResponse[] }>("/secrets", {
        params: { environment_id: envId },
      });
      setSecrets(res?.results ?? []);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error
          ? err.message
          : "Failed to load environment secrets",
      );
    } finally {
      setIsSecretsLoading(false);
    }
  }, []);

  React.useEffect(() => {
    const run = async () => {
      await fetchEnvironments();
    };
    void run();
  }, [fetchEnvironments]);

  React.useEffect(() => {
    if (!selectedEnvId) return;
    const run = async () => {
      await fetchSecrets(selectedEnvId);
    };
    void run();
  }, [selectedEnvId, fetchSecrets]);

  const openAddSecret = () => {
    setEditingSecret(null);
    setSecretKey("");
    setSecretValue("");
    setIsJson(false);
    setSheetOpen(true);
  };

  const openEditSecret = (sec: SecretResponse) => {
    setEditingSecret(sec);
    setSecretKey(sec.key);
    setSecretValue(""); // Never prefill plaintext
    setIsJson(sec.is_json);
    setSheetOpen(true);
  };

  const handleSaveSecret = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedEnvId) {
      toast.error("Please select an environment first");
      return;
    }

    setIsSaving(true);
    try {
      if (editingSecret) {
        // Update existing secret (creates new version)
        await api.patch(`/secrets/${editingSecret.id}`, {
          value: secretValue.trim() || undefined,
          is_json: isJson,
        });
        toast.success(`Secret "${editingSecret.key}" updated to next version`);
      } else {
        // Create new secret
        await api.post("/secrets", {
          environment_id: selectedEnvId,
          key: secretKey.trim().toUpperCase(),
          value: secretValue.trim(),
          is_json: isJson,
        });
        toast.success(`Secret "${secretKey.trim().toUpperCase()}" created`);
      }

      setSheetOpen(false);
      setEditingSecret(null);
      setSecretKey("");
      setSecretValue("");
      await fetchSecrets(selectedEnvId);
    } catch (err: unknown) {
      toast.error(err instanceof Error ? err.message : "Failed to save secret");
    } finally {
      setIsSaving(false);
    }
  };

  const handleRollback = async (versionToRestore?: number) => {
    if (!targetSecret) return;

    const v = versionToRestore ?? rollbackVersion;
    setIsRollingBack(true);
    try {
      await api.post(`/secrets/${targetSecret.id}/rollback`, {
        version: v,
      });
      toast.success(`Secret "${targetSecret.key}" restored to version v${v}`);
      setRollbackOpen(false);
      setTargetSecret(null);
      await fetchSecrets(selectedEnvId);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to rollback secret",
      );
    } finally {
      setIsRollingBack(false);
    }
  };

  const handleDeleteSecret = async () => {
    if (!deletingSecret) return;

    setIsDeleting(true);
    try {
      await api.delete(`/secrets/${deletingSecret.id}`);
      toast.success(`Secret "${deletingSecret.key}" removed`);
      setDeleteAlertOpen(false);
      setDeletingSecret(null);
      await fetchSecrets(selectedEnvId);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to delete secret",
      );
    } finally {
      setIsDeleting(false);
    }
  };

  // Parse .env text into key-value pairs
  const handleParseEnvText = (text: string) => {
    setRawEnvText(text);
    const lines = text.split("\n");
    const pairs: ParsedEnvPair[] = [];

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;

      const eqIdx = trimmed.indexOf("=");
      if (eqIdx === -1) continue;

      const k = trimmed.slice(0, eqIdx).trim();
      let v = trimmed.slice(eqIdx + 1).trim();

      // strip quotes if wrapped
      if (
        (v.startsWith('"') && v.endsWith('"')) ||
        (v.startsWith("'") && v.endsWith("'"))
      ) {
        v = v.slice(1, -1);
      }

      let isJsonVal = false;
      try {
        if (v.startsWith("{") || v.startsWith("[")) {
          JSON.parse(v);
          isJsonVal = true;
        }
      } catch {
        isJsonVal = false;
      }

      if (k) {
        pairs.push({ key: k, value: v, is_json: isJsonVal });
      }
    }
    setParsedPairs(pairs);
  };

  const handleCommitBulkImport = async () => {
    if (!selectedEnvId || parsedPairs.length === 0) return;

    setIsImporting(true);
    try {
      await Promise.all(
        parsedPairs.map((p) =>
          api.post("/secrets", {
            environment_id: selectedEnvId,
            key: p.key,
            value: p.value,
            is_json: p.is_json,
          }),
        ),
      );

      toast.success(`Successfully imported ${parsedPairs.length} secrets`);
      setImportOpen(false);
      setRawEnvText("");
      setParsedPairs([]);
      await fetchSecrets(selectedEnvId);
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to import secrets",
      );
    } finally {
      setIsImporting(false);
    }
  };

  return (
    <div className="space-y-4">
      {/* Secrets Header Toolbar */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="space-y-0.5">
          <h2 className="text-foreground text-sm font-semibold">
            Secrets & Key Management
          </h2>
          <p className="text-muted-foreground text-xs">
            Secure write-only credentials and API tokens injected directly into
            isolated build containers.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          {/* Environment Picker */}
          {environments.length > 0 ? (
            <Select
              value={selectedEnvId}
              onValueChange={(val) => {
                if (val) setSelectedEnvId(val);
              }}
            >
              <SelectTrigger className="h-8 w-[160px] font-mono text-xs">
                <SelectValue placeholder="Environment">
                  {environments.find((e) => e.id === selectedEnvId)?.name ||
                    "Environment"}
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                {environments.map((env) => (
                  <SelectItem
                    key={env.id}
                    value={env.id}
                    className="font-mono text-xs"
                  >
                    {env.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          ) : null}

          <Button
            variant="outline"
            size="sm"
            onClick={() => void fetchSecrets(selectedEnvId)}
            className="h-8 gap-1.5 transition-colors"
            disabled={!selectedEnvId || isSecretsLoading}
          >
            <ArrowsClockwise className="size-3.5" />
            <span>Refresh</span>
          </Button>

          <Button
            variant="outline"
            size="sm"
            onClick={() => setImportOpen(true)}
            className="h-8 gap-1.5 transition-colors"
            disabled={!selectedEnvId}
          >
            <UploadSimple className="size-3.5" />
            <span>Import .env</span>
          </Button>

          <Button
            size="sm"
            onClick={openAddSecret}
            className="h-8 gap-1.5"
            disabled={!selectedEnvId}
          >
            <Plus className="size-3.5" weight="bold" />
            <span>Add Secret</span>
          </Button>
        </div>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertTitle>Failed to load secrets</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchEnvironments()}
              className="h-7 text-xs"
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      )}

      {isLoading ? (
        <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-16">
          <BloomSpinner size={28} label="Loading secrets vault..." />
        </div>
      ) : environments.length === 0 ? (
        <EmptyState
          icon={Key}
          title="No environments found"
          description="You need at least one target environment before adding environment-scoped encrypted secrets."
          actionLabel="Create Environment"
          onAction={() => {
            router.push(`/apps/${appId}/environments`);
          }}
        />
      ) : isSecretsLoading ? (
        <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-16">
          <BloomSpinner size={24} label="Decrypting vault metadata..." />
        </div>
      ) : secrets.length === 0 ? (
        <EmptyState
          icon={Key}
          title="No secrets configured"
          description="Add API tokens, private service keys, or database credentials for this environment."
          actionLabel="Add First Secret"
          onAction={openAddSecret}
        />
      ) : (
        <div className="border-border/80 bg-card overflow-hidden rounded-lg border shadow-xs">
          <div className="overflow-x-auto">
            <TooltipProvider>
              <Table>
                <TableHeader>
                  <TableRow className="hover:bg-transparent">
                    <TableHead className="w-[40px]"></TableHead>
                    <TableHead>Key Name</TableHead>
                    <TableHead>Encrypted Value</TableHead>
                    <TableHead className="w-[90px]">Format</TableHead>
                    <TableHead className="w-[90px]">Version</TableHead>
                    <TableHead>Last Updated</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {secrets.map((sec) => (
                    <TableRow
                      key={sec.id}
                      className="hover:bg-muted/40 group transition-colors duration-150"
                    >
                      <TableCell className="text-muted-foreground p-3 text-center">
                        <LockSimple className="size-3.5" />
                      </TableCell>

                      <TableCell className="text-foreground font-mono text-xs font-semibold">
                        {sec.key}
                      </TableCell>

                      <TableCell>
                        <Tooltip>
                          <TooltipTrigger className="bg-muted/50 border-border/60 text-muted-foreground inline-flex cursor-help items-center gap-1.5 rounded-md border px-2 py-0.5 font-mono text-[11px]">
                            <span>••••••••••••</span>
                            <span className="text-muted-foreground/80 text-[10px]">
                              (write-only)
                            </span>
                          </TooltipTrigger>
                          <TooltipContent>
                            <p className="text-xs">
                              Decrypted only in worker builds. Never exposed
                              over client API.
                            </p>
                          </TooltipContent>
                        </Tooltip>
                      </TableCell>

                      <TableCell>
                        {sec.is_json ? (
                          <Badge
                            variant="secondary"
                            className="bg-muted/60 text-foreground border-border/40 gap-1 font-mono text-[10px]"
                          >
                            <FileCode className="size-3" />
                            <span>JSON</span>
                          </Badge>
                        ) : (
                          <span className="text-muted-foreground font-mono text-xs">
                            Text
                          </span>
                        )}
                      </TableCell>

                      <TableCell>
                        <Badge
                          variant="outline"
                          className="text-foreground font-mono text-[10px]"
                        >
                          v{sec.version}
                        </Badge>
                      </TableCell>

                      <TableCell className="text-muted-foreground font-mono text-xs">
                        {new Date(sec.updated_at).toLocaleDateString()}
                      </TableCell>

                      <TableCell className="text-right">
                        <DropdownMenu>
                          <DropdownMenuTrigger className="hover:bg-muted/80 text-muted-foreground hover:text-foreground inline-flex size-7 cursor-pointer items-center justify-center rounded-md transition-colors">
                            <DotsThreeVertical className="size-4" />
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end">
                            <DropdownMenuItem
                              onClick={() => openEditSecret(sec)}
                              className="cursor-pointer gap-1.5 text-xs"
                            >
                              <PencilSimple className="size-3.5" />
                              <span>Update value</span>
                            </DropdownMenuItem>

                            {sec.version > 1 && (
                              <DropdownMenuItem
                                onClick={() => {
                                  setTargetSecret(sec);
                                  setRollbackVersion(sec.version - 1);
                                  setRollbackOpen(true);
                                }}
                                className="cursor-pointer gap-1.5 text-xs"
                              >
                                <ClockCounterClockwise className="size-3.5" />
                                <span>Rollback version</span>
                              </DropdownMenuItem>
                            )}

                            <DropdownMenuItem
                              onClick={() => {
                                setDeletingSecret(sec);
                                setDeleteAlertOpen(true);
                              }}
                              className="text-destructive cursor-pointer gap-1.5 text-xs"
                            >
                              <Trash className="size-3.5" />
                              <span>Delete</span>
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TooltipProvider>
          </div>
        </div>
      )}

      {/* Add / Edit Secret Sheet */}
      <Sheet open={sheetOpen} onOpenChange={setSheetOpen}>
        <SheetContent side="right" className="w-full sm:max-w-md">
          <form onSubmit={handleSaveSecret} className="space-y-6">
            <SheetHeader>
              <SheetTitle className="flex items-center gap-2 text-base">
                <Key className="size-4" />
                <span>
                  {editingSecret ? `Update ${editingSecret.key}` : "Add Secret"}
                </span>
              </SheetTitle>
              <SheetDescription>
                {editingSecret
                  ? "Writing a new value creates an immutable next version in the vault."
                  : "Values are encrypted with AES-256 before storage and only accessible to build runners."}
              </SheetDescription>
            </SheetHeader>

            <div className="space-y-4">
              <div className="space-y-1.5">
                <Label htmlFor="secret-key">Key Name</Label>
                <Input
                  id="secret-key"
                  placeholder="e.g. STRIPE_API_KEY"
                  value={secretKey}
                  onChange={(e) => setSecretKey(e.target.value)}
                  disabled={!!editingSecret}
                  className="font-mono text-xs uppercase"
                  required
                />
              </div>

              <div className="space-y-1.5">
                <Label htmlFor="secret-value">
                  {editingSecret ? "New Secret Value" : "Secret Value"}
                </Label>
                <Textarea
                  id="secret-value"
                  placeholder="Paste private key, JWT token, or connection string"
                  value={secretValue}
                  onChange={(e) => setSecretValue(e.target.value)}
                  rows={5}
                  className="font-mono text-xs leading-relaxed"
                  required={!editingSecret}
                />
                {editingSecret ? (
                  <p className="text-muted-foreground text-[11px]">
                    Leave blank to preserve the existing value and only update
                    format flags.
                  </p>
                ) : null}
              </div>

              <div className="border-border/60 bg-muted/20 flex items-center justify-between rounded-md border p-3">
                <div className="space-y-0.5">
                  <Label htmlFor="is-json" className="text-xs font-semibold">
                    Parse as JSON document
                  </Label>
                  <p className="text-muted-foreground text-[11px]">
                    Validates and structures the secret as parsed JSON object.
                  </p>
                </div>
                <Switch
                  id="is-json"
                  checked={isJson}
                  onCheckedChange={setIsJson}
                />
              </div>
            </div>

            <SheetFooter className="border-border/60 border-t pt-4">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => setSheetOpen(false)}
                disabled={isSaving}
              >
                Cancel
              </Button>
              <Button type="submit" size="sm" disabled={isSaving}>
                {isSaving ? (
                  <BloomSpinner size={14} speed="fast" className="mr-2" />
                ) : null}
                {editingSecret ? "Save New Version" : "Save Secret"}
              </Button>
            </SheetFooter>
          </form>
        </SheetContent>
      </Sheet>

      {/* Rollback & Version History Timeline Dialog */}
      <Dialog open={rollbackOpen} onOpenChange={setRollbackOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2 text-base">
              <ClockCounterClockwise className="text-primary size-4" />
              <span>Version History & Rollback</span>
            </DialogTitle>
            <DialogDescription className="text-xs">
              Chronological immutable versions for secret{" "}
              <strong className="text-foreground font-mono">
                {targetSecret?.key}
              </strong>
              .
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4 py-2">
            {targetSecret && (
              <div className="before:bg-border/80 relative space-y-4 pl-6 before:absolute before:top-2 before:bottom-2 before:left-[11px] before:w-0.5">
                {Array.from(
                  { length: targetSecret.version },
                  (_, i) => targetSecret.version - i,
                ).map((ver) => {
                  const isCurrent = ver === targetSecret.version;
                  return (
                    <div
                      key={ver}
                      className="relative flex items-start justify-between gap-3"
                    >
                      {/* Timeline Node */}
                      <div
                        className={cn(
                          "ring-background absolute top-1 -left-6 flex size-3 items-center justify-center rounded-full ring-4",
                          isCurrent
                            ? "bg-primary"
                            : "border-border/80 bg-muted-foreground/30 border",
                        )}
                      />

                      <div className="min-w-0 flex-1 space-y-0.5">
                        <div className="flex items-center gap-2">
                          <Badge
                            variant={isCurrent ? "default" : "outline"}
                            className={cn(
                              "px-1.5 py-0 font-mono text-[10px]",
                              isCurrent
                                ? "bg-primary text-primary-foreground font-semibold"
                                : "text-muted-foreground border-border/80",
                            )}
                          >
                            v{ver}
                          </Badge>
                          {isCurrent && (
                            <span className="text-[11px] font-medium text-emerald-400">
                              Active Version
                            </span>
                          )}
                        </div>
                        <p className="text-muted-foreground text-[11px]">
                          {isCurrent
                            ? `Updated ${new Date(targetSecret.updated_at).toLocaleDateString()}`
                            : `Historical snapshot`}
                        </p>
                      </div>

                      {!isCurrent && (
                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          disabled={isRollingBack}
                          onClick={() => void handleRollback(ver)}
                          className="h-7 shrink-0 gap-1.5 text-xs hover:border-amber-500/40 hover:bg-amber-500/10 hover:text-amber-300"
                        >
                          <ArrowCounterClockwise className="size-3" />
                          <span>Restore</span>
                        </Button>
                      )}
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          <DialogFooter className="border-border/60 border-t pt-3">
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => setRollbackOpen(false)}
              disabled={isRollingBack}
              className="w-full text-xs sm:w-auto"
            >
              Close
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation */}
      <AlertDialog open={deleteAlertOpen} onOpenChange={setDeleteAlertOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete Secret</AlertDialogTitle>
            <AlertDialogDescription>
              Are you sure you want to permanently delete secret{" "}
              <strong className="text-foreground">{deletingSecret?.key}</strong>
              ? Builds requiring this variable may fail.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={isDeleting}>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDeleteSecret}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
              disabled={isDeleting}
            >
              {isDeleting ? (
                <BloomSpinner size={14} speed="fast" className="mr-2" />
              ) : null}
              Delete Secret
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Bulk Import Dialog */}
      <Dialog open={importOpen} onOpenChange={setImportOpen}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>Bulk Import (.env)</DialogTitle>
            <DialogDescription>
              Paste standard .env key=value pairs to batch import into this
              environment.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4 py-2">
            <Textarea
              placeholder={`API_KEY=sk_live_123456\nDATABASE_URL=postgres://...\nCONFIG_JSON={"enabled":true}`}
              value={rawEnvText}
              onChange={(e) => handleParseEnvText(e.target.value)}
              rows={6}
              className="font-mono text-xs leading-relaxed"
            />

            {parsedPairs.length > 0 && (
              <div className="space-y-2">
                <div className="flex items-center justify-between text-xs">
                  <span className="text-foreground font-semibold">
                    Parsed Preview ({parsedPairs.length} secrets detected)
                  </span>
                  <span className="text-muted-foreground font-mono text-[10px]">
                    Encrypted on save
                  </span>
                </div>
                <div className="border-border/80 max-h-[160px] overflow-auto rounded-md border">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead className="text-xs">Key</TableHead>
                        <TableHead className="text-xs">Format</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {parsedPairs.map((p, idx) => (
                        <TableRow key={idx}>
                          <TableCell className="p-2 font-mono text-xs">
                            {p.key}
                          </TableCell>
                          <TableCell className="text-muted-foreground p-2 font-mono text-[11px]">
                            {p.is_json ? "JSON" : "Text"}
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </div>
              </div>
            )}
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => setImportOpen(false)}
              disabled={isImporting}
            >
              Cancel
            </Button>
            <Button
              onClick={handleCommitBulkImport}
              disabled={parsedPairs.length === 0 || isImporting}
            >
              {isImporting ? (
                <BloomSpinner size={14} speed="fast" className="mr-2" />
              ) : null}
              Import {parsedPairs.length} Secrets
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
