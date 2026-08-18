"use client";

import * as React from "react";
import {
  CreditCard,
  DownloadSimple,
  Sparkle,
  HardDrives,
  Globe,
  Hammer,
  CaretDown,
  CaretRight,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
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
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Checkbox } from "@/components/ui/checkbox";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { StatusBadge } from "@/components/status/status-badge";
import { api } from "@/lib/api/client";
import {
  PlanResponse,
  SubscriptionResponse,
  InvoiceResponse,
  UsageSummaryResponse,
  EnforcementDecision,
} from "@/lib/schemas/billing";
import { useUiStore } from "@/stores/ui-store";

interface OrganizationBillingTabProps {
  organizationId: string;
  canManageBilling?: boolean;
  openPlanDialog?: boolean;
}

export function OrganizationBillingTab({
  organizationId,
  canManageBilling = true,
  openPlanDialog = false,
}: OrganizationBillingTabProps) {
  const [plans, setPlans] = React.useState<PlanResponse[]>([]);
  const [subscription, setSubscription] =
    React.useState<SubscriptionResponse | null>(null);
  const [invoices, setInvoices] = React.useState<InvoiceResponse[]>([]);
  const [usage, setUsage] = React.useState<UsageSummaryResponse | null>(null);
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  const setPlanUpgradeDialogOpen = useUiStore(
    (s) => s.setPlanUpgradeDialogOpen,
  );

  React.useEffect(() => {
    if (openPlanDialog) setPlanUpgradeDialogOpen(true);
  }, [openPlanDialog, setPlanUpgradeDialogOpen]);

  // Cancel subscription modal
  const [cancelDialogOpen, setCancelDialogOpen] = React.useState(false);
  const [expandedInvoiceId, setExpandedInvoiceId] = React.useState<
    string | null
  >(null);
  const [cancelReason, setCancelReason] = React.useState("");
  const [cancelImmediately, setCancelImmediately] = React.useState(false);
  const [isCancelling, setIsCancelling] = React.useState(false);

  const fetchBillingData = React.useCallback(async () => {
    if (!organizationId) return;
    setIsLoading(true);
    setError(null);
    try {
      const [plansRes, subRes, invsRes, usageRes] = await Promise.all([
        api.get<PlanResponse[]>("/billing/plans"),
        api.get<SubscriptionResponse>("/billing/subscription"),
        api.get<InvoiceResponse[]>("/billing/invoices"),
        api.get<UsageSummaryResponse>("/billing/usage"),
      ]);
      setPlans(Array.isArray(plansRes) ? plansRes : []);
      setSubscription(subRes);
      setInvoices(Array.isArray(invsRes) ? invsRes : []);
      setUsage(usageRes);
    } catch (err: unknown) {
      setError(
        err instanceof Error ? err.message : "Failed to load billing details",
      );
    } finally {
      setIsLoading(false);
    }
  }, [organizationId]);

  React.useEffect(() => {
    const run = async () => {
      await fetchBillingData();
    };
    void run();
  }, [fetchBillingData]);

  const handleCancelSubscription = async () => {
    setIsCancelling(true);
    try {
      const updated = await api.post<SubscriptionResponse>("/billing/cancel", {
        reason: cancelReason.trim() || undefined,
        immediately: cancelImmediately,
      });
      toast.success(
        cancelImmediately
          ? "Subscription cancelled immediately."
          : "Subscription will cancel at the end of the billing period.",
      );
      setSubscription(updated);
      setCancelDialogOpen(false);
      setCancelReason("");
      void fetchBillingData();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to cancel subscription",
      );
    } finally {
      setIsCancelling(false);
    }
  };

  const getDecisionBarColor = (decision?: EnforcementDecision) => {
    switch (decision) {
      case "allow":
        return "bg-emerald-500 shadow-[0_0_6px_rgba(16,185,129,0.4)]";
      case "warn":
        return "bg-amber-400 shadow-[0_0_6px_rgba(251,191,36,0.4)]";
      case "soft_block":
        return "bg-orange-500 shadow-[0_0_6px_rgba(249,115,22,0.4)]";
      case "hard_lock":
        return "bg-rose-500 shadow-[0_0_8px_rgba(244,63,94,0.5)]";
      default:
        return "bg-emerald-500";
    }
  };

  const getDecisionBadge = (decision?: EnforcementDecision) => {
    switch (decision) {
      case "allow":
        return <StatusBadge status="allow" label="Within Limit" size="sm" />;
      case "warn":
        return (
          <StatusBadge status="warn" label="Quota Warning (>80%)" size="sm" />
        );
      case "soft_block":
        return (
          <StatusBadge
            status="soft_block"
            label="Soft Block Grace Period"
            size="sm"
          />
        );
      case "hard_lock":
        return (
          <StatusBadge status="hard_lock" label="Quota Locked" size="sm" />
        );
      default:
        return null;
    }
  };

  const currentPlanObj = plans.find(
    (p) =>
      p.id === subscription?.plan_id ||
      p.name.toLowerCase() === subscription?.plan_name?.toLowerCase(),
  );

  if (isLoading && !subscription) {
    return (
      <div className="flex items-center justify-center py-16">
        <BloomSpinner size={28} label="Loading billing & quotas..." />
      </div>
    );
  }

  if (error && !subscription) {
    return (
      <Alert variant="destructive">
        <AlertTitle>Error loading billing</AlertTitle>
        <AlertDescription className="flex items-center justify-between">
          <span>{error}</span>
          <Button
            variant="outline"
            size="sm"
            onClick={() => void fetchBillingData()}
          >
            Retry
          </Button>
        </AlertDescription>
      </Alert>
    );
  }

  return (
    <div className="space-y-6">
      {/* SECTION 1: Current Plan Overview Card */}
      <Card className="border-zinc-800 bg-[#09090b]">
        <CardHeader className="flex flex-row items-center justify-between pb-3">
          <div className="space-y-1">
            <div className="flex items-center gap-2">
              <CreditCard className="size-4 text-zinc-400" />
              <CardTitle className="text-sm font-semibold text-zinc-100">
                Current Subscription
              </CardTitle>
              {subscription && (
                <StatusBadge status={subscription.status} size="sm" />
              )}
            </div>
            <CardDescription className="text-xs text-zinc-400">
              Active tier entitlements, billing period dates, and upgrade
              options.
            </CardDescription>
          </div>

          {canManageBilling && (
            <div className="flex items-center gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setPlanUpgradeDialogOpen(true)}
                className="h-8 gap-1.5 text-xs text-zinc-200"
              >
                <Sparkle className="size-3.5 text-[#FF4B8B]" />
                <span>Change Plan</span>
              </Button>
              {subscription?.status === "active" && (
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setCancelDialogOpen(true)}
                  className="h-8 text-xs text-red-400 hover:bg-red-950/30 hover:text-red-300"
                >
                  Cancel
                </Button>
              )}
            </div>
          )}
        </CardHeader>

        <CardContent className="grid grid-cols-1 gap-4 pt-2 md:grid-cols-3">
          <div className="space-y-1 rounded-lg border border-zinc-800/80 bg-zinc-950 p-3 font-mono">
            <span className="text-[11px] text-zinc-500">Plan Tier</span>
            <p className="text-base font-bold text-zinc-100 uppercase">
              {subscription?.plan_name || "PRO"}
            </p>
            <p className="font-sans text-xs text-zinc-400">
              {currentPlanObj
                ? `$${(currentPlanObj.price_minor / 100).toFixed(0)} / month`
                : "$29 / month"}
            </p>
          </div>

          <div className="space-y-1 rounded-lg border border-zinc-800/80 bg-zinc-950 p-3 font-mono">
            <span className="text-[11px] text-zinc-500">Current Period</span>
            <p className="text-xs text-zinc-200">
              {subscription?.current_period_start
                ? new Date(
                    subscription.current_period_start,
                  ).toLocaleDateString()
                : "--"}
              {" → "}
              {subscription?.current_period_end
                ? new Date(subscription.current_period_end).toLocaleDateString()
                : "--"}
            </p>
            <p className="text-[11px] text-zinc-500">Renews automatically</p>
          </div>

          <div className="space-y-1 rounded-lg border border-zinc-800/80 bg-zinc-950 p-3 font-mono">
            <span className="text-[11px] text-zinc-500">Payment Provider</span>
            <p className="text-xs text-zinc-200">
              {subscription?.provider_customer_id
                ? `Stripe (${subscription.provider_customer_id.slice(0, 10)}...)`
                : "Standard Invoicing"}
            </p>
            <p className="text-[11px] text-emerald-400">
              All invoices in good standing
            </p>
          </div>
        </CardContent>
      </Card>

      {/* SECTION 2: Usage & Quotas */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-sm font-semibold text-zinc-100">
              Usage & Entitlement Limits
            </h3>
            <p className="text-xs text-zinc-400">
              Live consumption against included plan allowances for current
              cycle.
            </p>
          </div>
          {usage?.enforcement &&
            getDecisionBadge(usage.enforcement.overall_decision)}
        </div>

        <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
          {/* Build Minutes */}
          {usage && (
            <Card className="border-zinc-800 bg-[#09090b]">
              <CardHeader className="pb-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-1.5 text-xs font-medium text-zinc-300">
                    <Hammer className="size-4 text-zinc-500" />
                    <span>Build Minutes</span>
                  </div>
                  {getDecisionBadge(usage.enforcement.build_minutes_decision)}
                </div>
              </CardHeader>
              <CardContent className="space-y-2">
                <div className="flex items-baseline justify-between font-mono">
                  <span className="text-lg font-bold text-zinc-100">
                    {usage.build_minutes_used.toLocaleString()}
                  </span>
                  <span className="text-xs text-zinc-500">
                    / {usage.build_minutes_limit.toLocaleString()} mins
                  </span>
                </div>

                {/* Progress bar */}
                <div className="h-1.5 w-full overflow-hidden rounded-full bg-zinc-800">
                  <div
                    className={`h-full transition-all ${getDecisionBarColor(usage.enforcement.build_minutes_decision)}`}
                    style={{
                      width: `${Math.min(100, Math.round((usage.build_minutes_used / (usage.build_minutes_limit || 1)) * 100))}%`,
                    }}
                  />
                </div>

                <div className="flex justify-between font-mono text-[11px] text-zinc-400">
                  <span>
                    {Math.round(
                      (usage.build_minutes_used /
                        (usage.build_minutes_limit || 1)) *
                        100,
                    )}
                    % consumed
                  </span>
                  <span>
                    {Math.max(
                      0,
                      usage.build_minutes_limit - usage.build_minutes_used,
                    )}{" "}
                    mins left
                  </span>
                </div>

                {usage.overage.build_minutes_over > 0 && (
                  <div className="flex items-center justify-between rounded-md bg-[#FF4B8B]/10 px-2 py-1.5 font-mono text-[11px] text-[#FF4B8B]">
                    <span>
                      {usage.overage.build_minutes_over.toLocaleString()} min
                      overage
                    </span>
                    <span className="font-semibold">
                      +$
                      {(usage.overage.build_minutes_cost_cents / 100).toFixed(
                        2,
                      )}
                    </span>
                  </div>
                )}
              </CardContent>
            </Card>
          )}

          {/* Artifact Storage */}
          {usage && (
            <Card className="border-zinc-800 bg-[#09090b]">
              <CardHeader className="pb-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-1.5 text-xs font-medium text-zinc-300">
                    <HardDrives className="size-4 text-zinc-500" />
                    <span>Artifact Storage</span>
                  </div>
                  {getDecisionBadge(usage.enforcement.storage_decision)}
                </div>
              </CardHeader>
              <CardContent className="space-y-2">
                <div className="flex items-baseline justify-between font-mono">
                  <span className="text-lg font-bold text-zinc-100">
                    {usage.artifact_storage_gb_used} GB
                  </span>
                  <span className="text-xs text-zinc-500">
                    / {usage.artifact_storage_gb_limit} GB
                  </span>
                </div>

                <div className="h-1.5 w-full overflow-hidden rounded-full bg-zinc-800">
                  <div
                    className={`h-full transition-all ${getDecisionBarColor(usage.enforcement.storage_decision)}`}
                    style={{
                      width: `${Math.min(100, Math.round((usage.artifact_storage_gb_used / (usage.artifact_storage_gb_limit || 1)) * 100))}%`,
                    }}
                  />
                </div>

                <div className="flex justify-between font-mono text-[11px] text-zinc-400">
                  <span>
                    {Math.round(
                      (usage.artifact_storage_gb_used /
                        (usage.artifact_storage_gb_limit || 1)) *
                        100,
                    )}
                    % consumed
                  </span>
                  <span>
                    {Math.max(
                      0,
                      usage.artifact_storage_gb_limit -
                        usage.artifact_storage_gb_used,
                    )}{" "}
                    GB free
                  </span>
                </div>

                {usage.overage.storage_gb_over > 0 && (
                  <div className="flex items-center justify-between rounded-md bg-[#FF4B8B]/10 px-2 py-1.5 font-mono text-[11px] text-[#FF4B8B]">
                    <span>{usage.overage.storage_gb_over} GB overage</span>
                    <span className="font-semibold">
                      +$
                      {(usage.overage.storage_cost_cents / 100).toFixed(2)}
                    </span>
                  </div>
                )}
              </CardContent>
            </Card>
          )}

          {/* Web Bandwidth */}
          {usage && (
            <Card className="border-zinc-800 bg-[#09090b]">
              <CardHeader className="pb-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-1.5 text-xs font-medium text-zinc-300">
                    <Globe className="size-4 text-zinc-500" />
                    <span>Web Bandwidth</span>
                  </div>
                  {getDecisionBadge(usage.enforcement.bandwidth_decision)}
                </div>
              </CardHeader>
              <CardContent className="space-y-2">
                <div className="flex items-baseline justify-between font-mono">
                  <span className="text-lg font-bold text-zinc-100">
                    {usage.web_bandwidth_gb_used} GB
                  </span>
                  <span className="text-xs text-zinc-500">
                    / {usage.web_bandwidth_gb_limit} GB
                  </span>
                </div>

                <div className="h-1.5 w-full overflow-hidden rounded-full bg-zinc-800">
                  <div
                    className={`h-full transition-all ${getDecisionBarColor(usage.enforcement.bandwidth_decision)}`}
                    style={{
                      width: `${Math.min(100, Math.round((usage.web_bandwidth_gb_used / (usage.web_bandwidth_gb_limit || 1)) * 100))}%`,
                    }}
                  />
                </div>

                <div className="flex justify-between font-mono text-[11px] text-zinc-400">
                  <span>
                    {Math.round(
                      (usage.web_bandwidth_gb_used /
                        (usage.web_bandwidth_gb_limit || 1)) *
                        100,
                    )}
                    % consumed
                  </span>
                  <span>{usage.deploy_count} total deployments</span>
                </div>

                {usage.overage.bandwidth_gb_over > 0 && (
                  <div className="flex items-center justify-between rounded-md bg-[#FF4B8B]/10 px-2 py-1.5 font-mono text-[11px] text-[#FF4B8B]">
                    <span>{usage.overage.bandwidth_gb_over} GB overage</span>
                    <span className="font-semibold">
                      +$
                      {(usage.overage.bandwidth_cost_cents / 100).toFixed(2)}
                    </span>
                  </div>
                )}
              </CardContent>
            </Card>
          )}
        </div>

        {usage?.overage.enabled && usage.overage.total_cost_cents > 0 && (
          <div className="flex items-center justify-between rounded-lg border border-[#FF4B8B]/40 bg-[#FF4B8B]/5 px-4 py-2.5">
            <div className="flex items-center gap-2 text-xs text-zinc-300">
              <Sparkle className="size-3.5 text-[#FF4B8B]" />
              <span>
                Pay-as-you-go overage this cycle — billed automatically at
                period close.
              </span>
            </div>
            <span className="font-mono text-sm font-bold text-[#FF4B8B]">
              +${(usage.overage.total_cost_cents / 100).toFixed(2)}
            </span>
          </div>
        )}
      </div>

      {/* SECTION 3: Invoices History Table */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-sm font-semibold text-zinc-100">
              Invoices & Receipts
            </h3>
            <p className="text-xs text-zinc-400">
              Itemized billing history and automated payment records.
            </p>
          </div>
        </div>

        <div className="overflow-hidden rounded-lg border border-zinc-800 bg-[#09090b]">
          <div className="overflow-x-auto">
            <TooltipProvider>
              <Table>
                <TableHeader>
                  <TableRow className="hover:bg-transparent">
                    <TableHead className="w-6" />
                    <TableHead className="w-[180px]">Invoice ID</TableHead>
                    <TableHead>Amount</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Due Date</TableHead>
                    <TableHead>Paid At</TableHead>
                    <TableHead className="text-right">Receipt</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {invoices.length === 0 ? (
                    <TableRow>
                      <TableCell
                        colSpan={7}
                        className="py-6 text-center text-xs text-zinc-500"
                      >
                        No invoices issued yet.
                      </TableCell>
                    </TableRow>
                  ) : (
                    invoices.map((inv) => {
                      const formattedAmount = `$${(inv.amount_cents / 100).toFixed(2)} USD`;
                      const isExpanded = expandedInvoiceId === inv.id;
                      const hasOverage = inv.line_items.some(
                        (li) => li.kind === "overage" && li.amount_cents > 0,
                      );

                      return (
                        <React.Fragment key={inv.id}>
                          <TableRow
                            className="cursor-pointer transition-colors hover:bg-zinc-900/40"
                            onClick={() =>
                              setExpandedInvoiceId(isExpanded ? null : inv.id)
                            }
                          >
                            <TableCell className="text-zinc-500">
                              {isExpanded ? (
                                <CaretDown className="size-3.5" />
                              ) : (
                                <CaretRight className="size-3.5" />
                              )}
                            </TableCell>
                            <TableCell className="font-mono text-xs text-zinc-200">
                              {inv.provider_invoice_id || inv.id}
                            </TableCell>
                            <TableCell className="font-mono text-xs font-semibold text-zinc-100">
                              <div className="flex items-center gap-1.5">
                                {formattedAmount}
                                {hasOverage && (
                                  <Badge
                                    variant="outline"
                                    className="border-[#FF4B8B]/40 px-1 py-0 text-[9px] text-[#FF4B8B]"
                                  >
                                    overage
                                  </Badge>
                                )}
                              </div>
                            </TableCell>
                            <TableCell>
                              <StatusBadge status={inv.status} size="sm" />
                            </TableCell>
                            <TableCell className="font-mono text-xs text-zinc-400">
                              {inv.due_date}
                            </TableCell>
                            <TableCell className="font-mono text-xs text-zinc-400">
                              {inv.paid_at
                                ? new Date(inv.paid_at).toLocaleDateString()
                                : "--"}
                            </TableCell>
                            <TableCell className="text-right">
                              <Tooltip>
                                <TooltipTrigger
                                  className="inline-flex h-7 w-7 cursor-not-allowed items-center justify-center rounded-md p-0 text-zinc-400 opacity-50"
                                  disabled
                                  onClick={(e) => e.stopPropagation()}
                                >
                                  <DownloadSimple className="size-3.5" />
                                </TooltipTrigger>
                                <TooltipContent>
                                  <p className="text-xs">
                                    PDF download not yet available
                                  </p>
                                </TooltipContent>
                              </Tooltip>
                            </TableCell>
                          </TableRow>
                          {isExpanded && (
                            <TableRow className="hover:bg-transparent">
                              <TableCell colSpan={7} className="bg-zinc-950/60 p-0">
                                <div className="space-y-1.5 px-6 py-3">
                                  {inv.line_items.length === 0 ? (
                                    <p className="text-[11px] text-zinc-500">
                                      No line item breakdown available.
                                    </p>
                                  ) : (
                                    inv.line_items.map((li, idx) => (
                                      <div
                                        key={idx}
                                        className="flex items-center justify-between text-[11px]"
                                      >
                                        <span className="text-zinc-400">
                                          {li.description}
                                        </span>
                                        <span
                                          className={`font-mono ${li.kind === "overage" ? "text-[#FF4B8B]" : "text-zinc-300"}`}
                                        >
                                          ${(li.amount_cents / 100).toFixed(2)}
                                        </span>
                                      </div>
                                    ))
                                  )}
                                </div>
                              </TableCell>
                            </TableRow>
                          )}
                        </React.Fragment>
                      );
                    })
                  )}
                </TableBody>
              </Table>
            </TooltipProvider>
          </div>
        </div>
      </div>

      {/* Cancel Subscription AlertDialog */}
      <AlertDialog open={cancelDialogOpen} onOpenChange={setCancelDialogOpen}>
        <AlertDialogContent className="border-zinc-800 bg-zinc-900 text-zinc-100">
          <AlertDialogHeader>
            <AlertDialogTitle className="text-base font-semibold text-zinc-100">
              Cancel Subscription?
            </AlertDialogTitle>
            <AlertDialogDescription className="space-y-3 text-xs text-zinc-400">
              <p>
                Cancelling will revert your organization to the Free plan quota
                limits upon completion.
              </p>
            </AlertDialogDescription>
          </AlertDialogHeader>

          <div className="space-y-3 py-2">
            <div className="space-y-1.5">
              <Label htmlFor="cancel-reason" className="text-xs text-zinc-300">
                Reason for cancelling (Optional)
              </Label>
              <Textarea
                id="cancel-reason"
                placeholder="Let us know how we can improve..."
                value={cancelReason}
                onChange={(e) => setCancelReason(e.target.value)}
                rows={2}
                className="text-xs"
              />
            </div>

            <div className="flex items-center gap-2 pt-1">
              <Checkbox
                id="cancel-imm"
                checked={cancelImmediately}
                onCheckedChange={(c) => setCancelImmediately(!!c)}
              />
              <Label
                htmlFor="cancel-imm"
                className="cursor-pointer text-xs font-normal text-zinc-300"
              >
                Cancel immediately (revert to Free plan today instead of period
                end)
              </Label>
            </div>
          </div>

          <AlertDialogFooter>
            <AlertDialogCancel
              disabled={isCancelling}
              className="border-zinc-700 bg-zinc-800 text-xs text-zinc-200"
            >
              Keep Subscription
            </AlertDialogCancel>
            <AlertDialogAction
              disabled={isCancelling}
              onClick={() => void handleCancelSubscription()}
              className="bg-red-600 text-xs text-white hover:bg-red-700"
            >
              {isCancelling ? (
                <BloomSpinner size={14} speed="fast" className="mr-2" />
              ) : null}
              Confirm Cancellation
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
