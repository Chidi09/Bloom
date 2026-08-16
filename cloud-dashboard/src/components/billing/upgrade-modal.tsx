"use client";

import * as React from "react";
import { Check } from "@phosphor-icons/react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

interface UpgradeModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  featureTitle?: string;
  featureDescription?: string;
}

export function UpgradeModal({
  open,
  onOpenChange,
  featureTitle = "Unlock Pro Tier Capabilities",
  featureDescription = "Scale your Flutter and Bloom Framework cloud deployments with priority concurrency and store automation.",
}: UpgradeModalProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-xl border-border bg-card p-6">
        <DialogHeader className="space-y-2 text-left">
          <div className="flex items-center gap-2">
            <Badge variant="outline" className="border-primary/40 bg-primary/10 text-primary text-xs">
              Bloom Cloud Pro
            </Badge>
          </div>
          <DialogTitle className="font-heading text-lg font-bold tracking-tight">
            {featureTitle}
          </DialogTitle>
          <DialogDescription className="text-xs text-muted-foreground">
            {featureDescription}
          </DialogDescription>
        </DialogHeader>

        {/* Plan Comparison Grid */}
        <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
          {/* Free Tier */}
          <div className="rounded-lg border border-border/80 bg-muted/20 p-4 space-y-3">
            <div className="flex items-baseline justify-between">
              <span className="text-sm font-semibold">Free (Hobby)</span>
              <span className="text-xs font-mono text-muted-foreground">$0 / mo</span>
            </div>
            <p className="text-[11px] text-muted-foreground">
              Generous baseline for indie hackers and solo developers.
            </p>
            <ul className="space-y-1.5 text-xs text-muted-foreground">
              <li className="flex items-center gap-2">
                <Check className="size-3.5 text-status-success shrink-0" />
                <span>1,000 build minutes / month</span>
              </li>
              <li className="flex items-center gap-2">
                <Check className="size-3.5 text-status-success shrink-0" />
                <span>Bloom Framework OTA updates</span>
              </li>
              <li className="flex items-center gap-2">
                <Check className="size-3.5 text-status-success shrink-0" />
                <span>1 concurrent build worker</span>
              </li>
              <li className="flex items-center gap-2">
                <Check className="size-3.5 text-status-success shrink-0" />
                <span>Manual APK / IPA downloads</span>
              </li>
            </ul>
            <Button variant="outline" disabled className="w-full h-8 text-xs">
              Current Plan
            </Button>
          </div>

          {/* Pro Tier (Highlight) */}
          <div className="rounded-lg border border-primary/40 bg-primary/5 p-4 space-y-3 relative overflow-hidden">
            <div className="flex items-baseline justify-between">
              <div className="flex items-center gap-1.5">
                <span className="text-sm font-bold text-foreground">Pro</span>
                <span className="rounded bg-primary/20 px-1 py-0.2 text-[9px] font-semibold text-primary">
                  POPULAR
                </span>
              </div>
              <span className="text-xs font-mono font-bold text-foreground">$29 / mo</span>
            </div>
            <p className="text-[11px] text-muted-foreground">
              For growing teams requiring store automation and higher concurrency.
            </p>
            <ul className="space-y-1.5 text-xs text-foreground">
              <li className="flex items-center gap-2">
                <Check className="size-3.5 text-primary shrink-0" />
                <span className="font-medium">5,000 build minutes / month</span>
              </li>
              <li className="flex items-center gap-2">
                <Check className="size-3.5 text-primary shrink-0" />
                <span>Automated TestFlight & Google Play</span>
              </li>
              <li className="flex items-center gap-2">
                <Check className="size-3.5 text-primary shrink-0" />
                <span>Shorebird Code Push & Live Patches</span>
              </li>
              <li className="flex items-center gap-2">
                <Check className="size-3.5 text-primary shrink-0" />
                <span>Unlimited team seats & RBAC</span>
              </li>
            </ul>
            <Button
              className="w-full h-8 text-xs font-medium cursor-pointer"
              onClick={() => onOpenChange(false)}
            >
              Start 14-Day Free Pro Trial
            </Button>
          </div>
        </div>

        <div className="mt-2 text-center">
          <p className="text-[11px] text-muted-foreground">
            Looking for dedicated HSM signing and custom SSO?{" "}
            <a href="mailto:sales@bloom.dev" className="text-primary hover:underline">
              Contact Enterprise
            </a>
          </p>
        </div>
      </DialogContent>
    </Dialog>
  );
}
