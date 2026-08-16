"use client";

import * as React from "react";
import {
  CurrencyDollar,
  ArrowsClockwise,
  ArrowSquareOut,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CardDescription,
} from "@/components/ui/card";
import { StatusBadge } from "@/components/status/status-badge";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { api } from "@/lib/api/client";
import { SellerAccountResponse } from "@/lib/schemas/marketplace";
import { useOrganizationStore } from "@/stores/organization-store";

export function SellerOnboardingCard() {
  const { currentOrganizationId } = useOrganizationStore();
  const [account, setAccount] = React.useState<SellerAccountResponse | null>(
    null,
  );
  const [isLoading, setIsLoading] = React.useState(true);
  const [isConnecting, setIsConnecting] = React.useState(false);
  const [isRefreshing, setIsRefreshing] = React.useState(false);

  const fetchAccount = React.useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await api.get<SellerAccountResponse>(
        "/marketplace/seller/account",
      );
      setAccount(res);
    } catch {
      setAccount(null);
    } finally {
      setIsLoading(false);
    }
  }, []);

  React.useEffect(() => {
    const run = async () => {
      await fetchAccount();
    };
    void run();
  }, [fetchAccount, currentOrganizationId]);

  const handleConnect = async () => {
    setIsConnecting(true);
    try {
      const link = await api.post<{ url: string; expires_at: number }>(
        "/marketplace/seller/onboarding",
        {
          refresh_url:
            typeof window !== "undefined" ? window.location.href : "",
          return_url: typeof window !== "undefined" ? window.location.href : "",
        },
      );
      toast.info("Redirecting to Stripe Connect onboarding...");
      if (typeof window !== "undefined") {
        window.open(link.url, "_blank", "noopener,noreferrer");
      }
      void fetchAccount();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error
          ? err.message
          : "Failed to start payout onboarding",
      );
    } finally {
      setIsConnecting(false);
    }
  };

  const handleRefresh = async () => {
    setIsRefreshing(true);
    try {
      const res = await api.post<SellerAccountResponse>(
        "/marketplace/seller/refresh",
        {},
      );
      setAccount(res);
      toast.success("Payout account status refreshed");
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Failed to refresh payout status",
      );
    } finally {
      setIsRefreshing(false);
    }
  };

  if (isLoading) {
    return (
      <Card className="border-zinc-800 bg-[#09090b]">
        <CardContent className="flex items-center justify-center py-8">
          <BloomSpinner size={24} label="Checking payout account..." />
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="border-zinc-800 bg-[#09090b]">
      <CardHeader className="flex flex-row items-center justify-between gap-4">
        <div className="flex items-start gap-3">
          <div className="flex size-9 shrink-0 items-center justify-center rounded-full border border-zinc-800 bg-zinc-900 text-emerald-400">
            <CurrencyDollar className="size-4" weight="bold" />
          </div>
          <div>
            <CardTitle className="text-sm font-semibold text-zinc-100">
              Seller Payout Account
            </CardTitle>
            <CardDescription className="text-xs text-zinc-400">
              Connect a Stripe payout account to sell paid templates on the
              marketplace.
            </CardDescription>
          </div>
        </div>
        {account && (
          <StatusBadge
            status={account.payouts_enabled ? "active" : "pending"}
            label={
              account.payouts_enabled ? "Payouts Enabled" : "Setup Incomplete"
            }
            size="sm"
          />
        )}
      </CardHeader>
      <CardContent className="flex items-center gap-2 pt-0">
        {!account ? (
          <Button
            size="sm"
            onClick={() => void handleConnect()}
            disabled={isConnecting}
            className="h-8 gap-1.5 text-xs"
          >
            {isConnecting ? (
              <BloomSpinner size={12} speed="fast" />
            ) : (
              <ArrowSquareOut className="size-3.5" />
            )}
            <span>Connect Payout Account</span>
          </Button>
        ) : (
          <>
            {!account.payouts_enabled && (
              <Button
                size="sm"
                variant="outline"
                onClick={() => void handleConnect()}
                disabled={isConnecting}
                className="h-8 gap-1.5 text-xs"
              >
                {isConnecting ? (
                  <BloomSpinner size={12} speed="fast" />
                ) : (
                  <ArrowSquareOut className="size-3.5" />
                )}
                <span>Continue Setup</span>
              </Button>
            )}
            <Button
              size="sm"
              variant="ghost"
              onClick={() => void handleRefresh()}
              disabled={isRefreshing}
              className="h-8 gap-1.5 text-xs text-zinc-400"
            >
              {isRefreshing ? (
                <BloomSpinner size={12} speed="fast" />
              ) : (
                <ArrowsClockwise className="size-3.5" />
              )}
              <span>Refresh Status</span>
            </Button>
          </>
        )}
      </CardContent>
    </Card>
  );
}
