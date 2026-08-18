"use client";

import { TooltipProvider } from "@/components/ui/tooltip";
import { Toaster } from "@/components/ui/sonner";
import { QueryProvider } from "@/providers/query-provider";
import { MswProvider } from "@/mocks/msw-provider";
import { PlanUpgradeDialog } from "@/components/billing/plan-upgrade-dialog";

export function AppProviders({ children }: { children: React.ReactNode }) {
  return (
    <MswProvider>
      <QueryProvider>
        <TooltipProvider delay={200}>
          {children}
          <Toaster />
          <PlanUpgradeDialog />
        </TooltipProvider>
      </QueryProvider>
    </MswProvider>
  );
}
