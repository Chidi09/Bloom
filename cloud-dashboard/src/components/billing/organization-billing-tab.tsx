"use client";

import * as React from "react";
import {
  CreditCard,
  Check,
  ArrowSquareOut,
  DownloadSimple,
  Sparkle,
  HardDrives,
  Globe,
  Hammer,
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
  SubscribeResponse,
} from "@/lib/schemas/billing";

interface OrganizationBillingTabProps {
  organizationId: string;
  canManageBilling?: boolean;
}

export function OrganizationBillingTab({
  organizationId,
  canManageBilling = true,
}: OrganizationBillingTabProps) {
  const [plans, setPlans] = React.useState<PlanResponse[]>([]);
  const [subscription, setSubscription] =
    React.useState<SubscriptionResponse | null>(null);
  const [invoices, setInvoices] = React.useState<InvoiceResponse[]>([]);
  const [usage, setUsage] = React.useState<UsageSummaryResponse | null>(null);
  const [isLoading, setIsLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);

  // Plan comparison modal
  const [planDialogOpen, setPlanDialogOpen] = React.useState(false);
  const [isSubscribingPlanId, setIsSubscribingPlanId] = React.useState<
    string | null
  >(null);
  const [pendingRedirectUrl, setPendingRedirectUrl] = React.useState<
    string | null
  >(null);

  // Cancel subscription modal
  const [cancelDialogOpen, setCancelDialogOpen] = React.useState(false);
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

  const handleSubscribe = async (planId: string) => {
    setIsSubscribingPlanId(planId);
    try {
      const res = await api.post<SubscribeResponse>("/billing/subscribe", {
        plan_id: planId,
        callback_url: window.location.href,
      });

      if (res?.authorization_url) {
        setPendingRedirectUrl(res.authorization_url);
        toast.info("Payment authorization required. Redirecting...");
      } else {
        toast.success(
          `Subscription upgraded to ${(res?.subscription?.plan_name || planId).toUpperCase()}`,
        );
        setSubscription(res.subscription);
        setPlanDialogOpen(false);
        void fetchBillingData();
      }
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to update subscription",
      );
    } finally {
      setIsSubscribingPlanId(null);
    }
  };

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
        return "bg-emerald-500";
      case "warn":
        return "bg-amber-500";
      case "soft_block":
        return "bg-orange-500";
      case "hard_lock":
        return "bg-red-500";
      default:
        return "bg-emerald-500";
    }
  };

  const getDecisionBadge = (decision?: EnforcementDecision) => {
    switch (decision) {
      case "allow":
        return (
          <Badge
            variant="outline"
            className="border-emerald-500/30 bg-emerald-500/10 font-mono text-[10px] text-emerald-400"
          >
            Within Limit
          </Badge>
        );
      case "warn":
        return (
          <Badge
            variant="outline"
            className="border-amber-500/30 bg-amber-500/10 font-mono text-[10px] text-amber-400"
          >
            Quota Warning (&gt;80%)
          </Badge>
        );
      case "soft_block":
        return (
          <Badge
            variant="outline"
            className="border-orange-500/30 bg-orange-500/10 font-mono text-[10px] text-orange-400"
          >
            Soft Block Grace Period
          </Badge>
        );
      case "hard_lock":
        return (
          <Badge
            variant="outline"
            className="border-red-500/30 bg-red-500/10 font-mono text-[10px] text-red-400"
          >
            Quota Locked
          </Badge>
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
      {/* Webhook-driven payment redirect banner if active */}
      {pendingRedirectUrl && (
        <Card className="border-[#FF4B8B]/40 bg-[#FF4B8B]/10 p-4">
          <div className="flex items-start justify-between gap-4">
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <BloomSpinner size={16} speed="fast" />
                <h4 className="text-sm font-semibold text-zinc-100">
                  Redirecting to complete payment authorization…
                </h4>
              </div>
              <p className="text-xs text-zinc-300">
                Payment confirmation is webhook-driven. Once checkout is
                completed on the hosted gateway, subscription quotas update
                automatically.
              </p>
            </div>
            <div className="flex items-center gap-2">
              <Button
                size="sm"
                onClick={() => window.open(pendingRedirectUrl, "_blank")}
                className="gap-1.5 bg-[#FF4B8B] text-white hover:bg-[#FF4B8B]/90"
              >
                <span>Complete on Gateway</span>
                <ArrowSquareOut className="size-3.5" />
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setPendingRedirectUrl(null)}
                className="h-8 text-xs text-zinc-400"
              >
                Dismiss
              </Button>
            </div>
          </div>
        </Card>
      )}

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
                onClick={() => setPlanDialogOpen(true)}
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
              </CardContent>
            </Card>
          )}
        </div>
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
          <TooltipProvider>
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
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
                      colSpan={6}
                      className="py-6 text-center text-xs text-zinc-500"
                    >
                      No invoices issued yet.
                    </TableCell>
                  </TableRow>
                ) : (
                  invoices.map((inv) => {
                    const formattedAmount = `$${(inv.amount_cents / 100).toFixed(2)} USD`;

                    return (
                      <TableRow key={inv.id} className="hover:bg-zinc-900/40">
                        <TableCell className="font-mono text-xs text-zinc-200">
                          {inv.provider_invoice_id || inv.id}
                        </TableCell>
                        <TableCell className="font-mono text-xs font-semibold text-zinc-100">
                          {formattedAmount}
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
                    );
                  })
                )}
              </TableBody>
            </Table>
          </TooltipProvider>
        </div>
      </div>

      {/* Plan Selection / Comparison Modal */}
      <Dialog open={planDialogOpen} onOpenChange={setPlanDialogOpen}>
        <DialogContent className="max-h-[90vh] overflow-y-auto border-zinc-800 bg-[#09090b] text-zinc-100 sm:max-w-3xl">
          <DialogHeader>
            <DialogTitle className="text-base font-semibold text-zinc-100">
              Upgrade or Change Plan
            </DialogTitle>
            <DialogDescription className="text-xs text-zinc-400">
              Scale your build minutes, automated store tracks, team seats, and
              Shorebird patch pipelines.
            </DialogDescription>
          </DialogHeader>

          <div className="grid grid-cols-1 gap-4 py-4 md:grid-cols-3">
            {plans.map((plan) => {
              const isCurrent =
                subscription?.plan_id === plan.id ||
                subscription?.plan_name?.toLowerCase() ===
                  plan.name.toLowerCase();
              const priceDollars = (plan.price_minor / 100).toFixed(0);

              return (
                <div
                  key={plan.id}
                  className={`flex flex-col justify-between rounded-lg border p-4 transition-all ${
                    plan.name === "pro"
                      ? "border-[#FF4B8B]/60 bg-gradient-to-b from-[#FF4B8B]/10 to-transparent ring-1 ring-[#FF4B8B]/30"
                      : "border-zinc-800 bg-zinc-950"
                  }`}
                >
                  <div className="space-y-3">
                    <div className="flex items-center justify-between">
                      <h4 className="font-bold text-zinc-100 capitalize">
                        {plan.name}
                      </h4>
                      {isCurrent && (
                        <Badge
                          variant="outline"
                          className="border-emerald-500/40 font-mono text-[10px] text-emerald-400"
                        >
                          Current
                        </Badge>
                      )}
                      {!isCurrent && plan.name === "pro" && (
                        <Badge className="bg-[#FF4B8B] font-mono text-[10px] text-white">
                          Popular
                        </Badge>
                      )}
                    </div>

                    <div className="font-mono">
                      <span className="text-2xl font-black text-zinc-100">
                        ${priceDollars}
                      </span>
                      <span className="text-xs text-zinc-400"> / month</span>
                    </div>

                    <p className="text-[11px] leading-snug text-zinc-400">
                      {plan.description}
                    </p>

                    <div className="space-y-2 border-t border-zinc-800/80 pt-3 text-xs">
                      <div className="flex items-center gap-2 text-zinc-300">
                        <Check className="size-3.5 shrink-0 text-emerald-400" />
                        <span>
                          {plan.entitlements.build_minutes_monthly.toLocaleString()}{" "}
                          build mins/mo
                        </span>
                      </div>
                      <div className="flex items-center gap-2 text-zinc-300">
                        <Check className="size-3.5 shrink-0 text-emerald-400" />
                        <span>
                          {plan.entitlements.max_seats} team member seats
                        </span>
                      </div>
                      <div className="flex items-center gap-2 text-zinc-300">
                        <Check className="size-3.5 shrink-0 text-emerald-400" />
                        <span>
                          {plan.entitlements.artifact_storage_gb} GB artifact
                          storage
                        </span>
                      </div>
                      <div className="flex items-center gap-2 text-zinc-300">
                        <Check className="size-3.5 shrink-0 text-emerald-400" />
                        <span>
                          {plan.entitlements.web_bandwidth_gb} GB web bandwidth
                        </span>
                      </div>
                      {plan.entitlements.features?.testflight_deployments && (
                        <div className="flex items-center gap-2 text-zinc-300">
                          <Check className="size-3.5 shrink-0 text-emerald-400" />
                          <span>TestFlight & Play Store automation</span>
                        </div>
                      )}
                      {plan.entitlements.features?.shorebird && (
                        <div className="flex items-center gap-2 text-zinc-300">
                          <Check className="size-3.5 shrink-0 text-emerald-400" />
                          <span>Shorebird Code Push support</span>
                        </div>
                      )}
                      {plan.entitlements.features?.priority_support && (
                        <div className="flex items-center gap-2 text-zinc-300">
                          <Check className="size-3.5 shrink-0 text-emerald-400" />
                          <span>Priority SLA support</span>
                        </div>
                      )}
                    </div>
                  </div>

                  <div className="pt-4">
                    <Button
                      size="sm"
                      disabled={isCurrent || isSubscribingPlanId === plan.id}
                      onClick={() => void handleSubscribe(plan.id)}
                      className={`w-full text-xs font-semibold ${
                        plan.name === "pro"
                          ? "bg-[#FF4B8B] text-white hover:bg-[#FF4B8B]/90"
                          : "border-zinc-700 bg-zinc-800 text-zinc-100 hover:bg-zinc-700"
                      }`}
                    >
                      {isSubscribingPlanId === plan.id ? (
                        <BloomSpinner size={14} speed="fast" />
                      ) : isCurrent ? (
                        "Current Tier"
                      ) : (
                        `Switch to ${plan.name.toUpperCase()}`
                      )}
                    </Button>
                  </div>
                </div>
              );
            })}
          </div>

          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setPlanDialogOpen(false)}
              className="text-xs"
            >
              Close
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

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
