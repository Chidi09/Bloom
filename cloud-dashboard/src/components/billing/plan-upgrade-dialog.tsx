"use client";

import * as React from "react";
import { Check } from "@phosphor-icons/react";
import { toast } from "sonner";

import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { api } from "@/lib/api/client";
import {
  PlanResponse,
  SubscriptionResponse,
  SubscribeResponse,
} from "@/lib/schemas/billing";
import { useUiStore } from "@/stores/ui-store";
import { useOrganizationStore } from "@/stores/organization-store";

// Global, data-driven plan comparison + upgrade dialog. Reads/writes the real
// billing API, always knows the current subscription, and can be opened from
// anywhere in the dashboard (sidebar, overview widgets, etc.) without
// navigating to the organization settings page.
export function PlanUpgradeDialog() {
  const open = useUiStore((s) => s.planUpgradeDialogOpen);
  const setOpen = useUiStore((s) => s.setPlanUpgradeDialogOpen);
  const organizationId = useOrganizationStore((s) => s.currentOrganizationId);

  const [plans, setPlans] = React.useState<PlanResponse[]>([]);
  const [subscription, setSubscription] =
    React.useState<SubscriptionResponse | null>(null);
  const [isLoading, setIsLoading] = React.useState(false);
  const [isSubscribingPlanId, setIsSubscribingPlanId] = React.useState<
    string | null
  >(null);

  React.useEffect(() => {
    if (!open || !organizationId) return;
    const run = async () => {
      setIsLoading(true);
      try {
        const [plansRes, subRes] = await Promise.all([
          api.get<PlanResponse[]>("/billing/plans"),
          api.get<SubscriptionResponse>("/billing/subscription"),
        ]);
        setPlans(Array.isArray(plansRes) ? plansRes : []);
        setSubscription(subRes);
      } catch (err: unknown) {
        toast.error(
          err instanceof Error ? err.message : "Failed to load plans",
        );
      } finally {
        setIsLoading(false);
      }
    };
    void run();
  }, [open, organizationId]);

  const handleSubscribe = async (planId: string) => {
    setIsSubscribingPlanId(planId);
    try {
      const res = await api.post<SubscribeResponse>("/billing/subscribe", {
        plan_id: planId,
        callback_url: window.location.href,
      });

      if (res?.authorization_url) {
        toast.info("Payment authorization required. Redirecting...");
        window.open(res.authorization_url, "_blank");
      } else {
        toast.success(
          `Subscription upgraded to ${(res?.subscription?.plan_name || planId).toUpperCase()}`,
        );
        setSubscription(res.subscription);
        setOpen(false);
      }
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to update subscription",
      );
    } finally {
      setIsSubscribingPlanId(null);
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
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

        {isLoading && plans.length === 0 ? (
          <div className="flex items-center justify-center py-12">
            <BloomSpinner size={20} speed="fast" />
          </div>
        ) : (
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

                    <div className="border-t border-zinc-800/80 pt-3 text-[10px] text-zinc-500">
                      {plan.entitlements.overage?.enabled ? (
                        <p>
                          Pay-as-you-go past quota: $
                          {(
                            plan.entitlements.overage.build_minute_cents / 100
                          ).toFixed(2)}
                          /build min · $
                          {(
                            plan.entitlements.overage.storage_gb_cents / 100
                          ).toFixed(2)}
                          /GB storage · $
                          {(
                            plan.entitlements.overage.bandwidth_gb_cents / 100
                          ).toFixed(2)}
                          /GB bandwidth
                        </p>
                      ) : (
                        <p>No overage — usage is capped at plan quota</p>
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
        )}

        <DialogFooter>
          <Button
            variant="outline"
            onClick={() => setOpen(false)}
            className="text-xs"
          >
            Close
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
