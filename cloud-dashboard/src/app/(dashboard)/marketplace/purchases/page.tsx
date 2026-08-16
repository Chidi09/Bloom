"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import {
  Bag,
  Storefront,
  ArrowsClockwise,
  ArrowCounterClockwise,
} from "@phosphor-icons/react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
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
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { StatusBadge } from "@/components/status/status-badge";
import { PageHeader } from "@/components/shared/page-header";
import { EmptyState } from "@/components/shared/empty-state";
import { api } from "@/lib/api/client";
import { PurchaseResponse } from "@/lib/schemas/marketplace";
import { OrganizationRoleName, hasRole } from "@/lib/auth/roles";
import { useOrganizationStore } from "@/stores/organization-store";

export default function MarketplacePurchasesPage() {
  const router = useRouter();
  const { currentOrganizationId } = useOrganizationStore();

  const [purchases, setPurchases] = React.useState<PurchaseResponse[]>([]);
  const [nextCursor, setNextCursor] = React.useState<string | null>(null);
  const [isLoading, setIsLoading] = React.useState(true);
  const [isLoadingMore, setIsLoadingMore] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  // Refund Dialog State
  const [refundPurchaseId, setRefundPurchaseId] = React.useState<string | null>(
    null,
  );
  const [refundReason, setRefundReason] = React.useState("");
  const [isRefunding, setIsRefunding] = React.useState(false);

  // Current user's role in the organization
  const [currentUserRole] = React.useState<OrganizationRoleName>("Admin");

  const fetchPurchases = React.useCallback(async (cursor?: string) => {
    if (!cursor) {
      setIsLoading(true);
      setError(null);
    } else {
      setIsLoadingMore(true);
    }

    try {
      const res = await api.get<{
        results: PurchaseResponse[];
        next_cursor?: string | null;
      }>("/marketplace/purchases", {
        params: cursor ? { cursor } : undefined,
      });

      const items = res?.results ?? [];
      if (cursor) {
        setPurchases((prev) => [...prev, ...items]);
      } else {
        setPurchases(items);
      }
      setNextCursor(res?.next_cursor || null);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to load purchases");
    } finally {
      setIsLoading(false);
      setIsLoadingMore(false);
    }
  }, []);

  React.useEffect(() => {
    const run = async () => {
      await fetchPurchases();
    };
    void run();
  }, [fetchPurchases, currentOrganizationId]);

  const handleRefund = async () => {
    if (!refundPurchaseId) return;
    setIsRefunding(true);
    try {
      await api.post(`/marketplace/purchases/${refundPurchaseId}/refund`, {
        reason: refundReason.trim() || undefined,
      });
      toast.success("Purchase refund issued successfully");
      setRefundPurchaseId(null);
      setRefundReason("");
      void fetchPurchases();
    } catch (err: unknown) {
      toast.error(
        err instanceof Error ? err.message : "Refund processing failed",
      );
    } finally {
      setIsRefunding(false);
    }
  };

  const canRefund = hasRole(currentUserRole, "Admin");

  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <PageHeader
        breadcrumbs={[
          { label: "Marketplace", href: "/marketplace" },
          { label: "Purchases" },
        ]}
        title="Purchase History"
        description="Buyer entitlement history and commercial starter template licenses."
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => router.push("/marketplace")}
              className="h-8 gap-1.5 text-xs text-zinc-200"
            >
              <Storefront className="size-3.5" />
              <span>Browse Marketplace</span>
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchPurchases()}
              className="h-8 gap-1.5"
            >
              <ArrowsClockwise className="size-3.5" />
              <span>Refresh</span>
            </Button>
          </div>
        }
      />

      {error && (
        <Alert variant="destructive">
          <AlertTitle>Error loading purchase history</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error}</span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => void fetchPurchases()}
              className="h-7 text-xs"
            >
              Retry
            </Button>
          </AlertDescription>
        </Alert>
      )}

      {isLoading ? (
        <div className="border-border/80 bg-card flex items-center justify-center rounded-lg border py-16">
          <BloomSpinner size={28} label="Loading purchase history..." />
        </div>
      ) : purchases.length === 0 ? (
        <EmptyState
          icon={Bag}
          title="No purchases recorded"
          description="Templates purchased or installed from the Marketplace will appear here with lifetime licenses."
          actionNode={
            <Button
              size="sm"
              onClick={() => router.push("/marketplace")}
              className="gap-1.5"
            >
              <Storefront className="size-3.5" />
              <span>Explore Marketplace</span>
            </Button>
          }
        />
      ) : (
        <div className="space-y-4">
          <div className="border-border/80 bg-card overflow-hidden rounded-lg border">
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow className="hover:bg-transparent">
                    <TableHead className="w-[240px]">Template</TableHead>
                    <TableHead>Purchase ID</TableHead>
                    <TableHead>Price / Amount</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Purchase Date</TableHead>
                    {canRefund && (
                      <TableHead className="text-right">Actions</TableHead>
                    )}
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {purchases.map((p) => {
                    const formattedAmount =
                      p.amount === 0
                        ? "Free"
                        : `$${(p.amount / 100).toFixed(2)} ${p.currency.toUpperCase()}`;

                    return (
                      <TableRow
                        key={p.id}
                        className="hover:bg-muted/40 transition-colors"
                      >
                        <TableCell>
                          <div className="space-y-0.5">
                            <p
                              onClick={() =>
                                router.push(`/marketplace/${p.template_id}`)
                              }
                              className="cursor-pointer text-xs font-semibold text-zinc-100 transition-colors hover:text-[#FF4B8B]"
                            >
                              {p.template_name}
                            </p>
                            <p className="font-mono text-[10px] text-zinc-500">
                              Seller: {p.seller_organization_id}
                            </p>
                          </div>
                        </TableCell>

                        <TableCell className="font-mono text-xs text-zinc-400">
                          {p.id}
                        </TableCell>

                        <TableCell className="font-mono text-xs font-semibold text-zinc-200">
                          {formattedAmount}
                        </TableCell>

                        <TableCell>
                          <StatusBadge status={p.status} size="sm" />
                        </TableCell>

                        <TableCell className="font-mono text-xs text-zinc-400">
                          {new Date(p.created_at).toLocaleDateString([], {
                            year: "numeric",
                            month: "short",
                            day: "numeric",
                          })}
                        </TableCell>

                        {canRefund && (
                          <TableCell className="text-right">
                            {p.status === "succeeded" && p.amount > 0 && (
                              <AlertDialog>
                                <AlertDialogTrigger
                                  onClick={() => setRefundPurchaseId(p.id)}
                                  className="inline-flex h-7 items-center justify-center rounded border border-zinc-800 bg-zinc-900 px-2.5 text-xs text-zinc-400 transition-colors hover:bg-red-950/30 hover:text-red-300"
                                >
                                  <ArrowCounterClockwise className="mr-1 size-3" />
                                  Refund
                                </AlertDialogTrigger>
                                <AlertDialogContent className="border-zinc-800 bg-zinc-900 text-zinc-100">
                                  <AlertDialogHeader>
                                    <AlertDialogTitle>
                                      Refund Template Purchase?
                                    </AlertDialogTitle>
                                    <AlertDialogDescription className="text-xs text-zinc-400">
                                      This will revoke the license and refund $
                                      {(p.amount / 100).toFixed(2)} back to the
                                      original payment source.
                                    </AlertDialogDescription>
                                  </AlertDialogHeader>

                                  <div className="space-y-1.5 py-2">
                                    <Label
                                      htmlFor="ref-reason"
                                      className="text-xs text-zinc-300"
                                    >
                                      Refund Reason (Optional)
                                    </Label>
                                    <Input
                                      id="ref-reason"
                                      placeholder="e.g. Incompatible flutter version"
                                      value={refundReason}
                                      onChange={(e) =>
                                        setRefundReason(e.target.value)
                                      }
                                      className="text-xs"
                                    />
                                  </div>

                                  <AlertDialogFooter>
                                    <AlertDialogCancel
                                      disabled={isRefunding}
                                      className="border-zinc-700 bg-zinc-800 text-xs text-zinc-200"
                                    >
                                      Cancel
                                    </AlertDialogCancel>
                                    <AlertDialogAction
                                      disabled={isRefunding}
                                      onClick={() => void handleRefund()}
                                      className="bg-red-600 text-xs text-white hover:bg-red-700"
                                    >
                                      {isRefunding ? (
                                        <BloomSpinner
                                          size={14}
                                          speed="fast"
                                          className="mr-2"
                                        />
                                      ) : null}
                                      Confirm Refund
                                    </AlertDialogAction>
                                  </AlertDialogFooter>
                                </AlertDialogContent>
                              </AlertDialog>
                            )}
                          </TableCell>
                        )}
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </div>
          </div>

          {/* Cursor Pagination: Load More Footer (NO page numbers per spec) */}
          {nextCursor && (
            <div className="flex justify-center pt-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => void fetchPurchases(nextCursor)}
                disabled={isLoadingMore}
                className="h-8 gap-1.5 text-xs text-zinc-300"
              >
                {isLoadingMore ? <BloomSpinner size={14} speed="fast" /> : null}
                <span>Load More Purchases</span>
              </Button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
