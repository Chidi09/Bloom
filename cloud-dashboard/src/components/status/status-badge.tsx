import * as React from "react";
import {
  CheckCircle,
  XCircle,
  Clock,
  Prohibit,
  WarningCircle,
  ArrowsClockwise,
} from "@phosphor-icons/react";
import { cn } from "@/lib/utils";

export type StatusType =
  | "success"
  | "running"
  | "queued"
  | "pending"
  | "failed"
  | "cancelled"
  | "warning"
  | "error"
  | "healthy"
  | "draft"
  | "approved"
  | "rejected"
  | "rolled_back"
  | string;

interface StatusBadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  status: StatusType;
  label?: string;
  size?: "sm" | "md";
  showIcon?: boolean;
}

export function StatusBadge({
  status,
  label,
  size = "md",
  showIcon = true,
  className,
  ...props
}: StatusBadgeProps) {
  const norm = status.toLowerCase();

  let colorClasses = "bg-muted text-muted-foreground border-border";
  let icon: React.ReactNode = null;
  let defaultLabel = status;

  if (norm === "success" || norm === "healthy" || norm === "approved" || norm === "completed") {
    colorClasses = "bg-[var(--status-success-bg)] text-[var(--status-success)] border-[var(--status-success)]/30";
    icon = <CheckCircle weight="bold" className={size === "sm" ? "size-3 shrink-0" : "size-3.5 shrink-0"} />;
    defaultLabel = norm === "healthy" ? "Healthy" : norm === "approved" ? "Approved" : "Success";
  } else if (norm === "running" || norm === "building") {
    colorClasses = "bg-[var(--status-running-bg)] text-[var(--status-running)] border-[var(--status-running)]/30 animate-pulse";
    icon = <ArrowsClockwise weight="bold" className={cn(size === "sm" ? "size-3 shrink-0" : "size-3.5 shrink-0", "animate-spin")} />;
    defaultLabel = "Running";
  } else if (norm === "queued" || norm === "pending" || norm === "draft") {
    colorClasses = "bg-[var(--status-pending-bg)] text-[var(--status-pending)] border-[var(--status-pending)]/30";
    icon = <Clock weight="regular" className={size === "sm" ? "size-3 shrink-0" : "size-3.5 shrink-0"} />;
    defaultLabel = norm === "queued" ? "Queued" : norm === "draft" ? "Draft" : "Pending";
  } else if (norm === "failed" || norm === "error" || norm === "rejected") {
    colorClasses = "bg-[var(--status-error-bg)] text-[var(--status-error)] border-[var(--status-error)]/30";
    icon = <XCircle weight="bold" className={size === "sm" ? "size-3 shrink-0" : "size-3.5 shrink-0"} />;
    defaultLabel = norm === "rejected" ? "Rejected" : "Failed";
  } else if (norm === "warning") {
    colorClasses = "bg-[var(--status-warning-bg)] text-[var(--status-warning)] border-[var(--status-warning)]/30";
    icon = <WarningCircle weight="bold" className={size === "sm" ? "size-3 shrink-0" : "size-3.5 shrink-0"} />;
    defaultLabel = "Warning";
  } else if (norm === "cancelled" || norm === "rolled_back") {
    colorClasses = "bg-[var(--status-pending-bg)] text-[var(--status-pending)] border-[var(--status-pending)]/30";
    icon = <Prohibit weight="regular" className={size === "sm" ? "size-3 shrink-0" : "size-3.5 shrink-0"} />;
    defaultLabel = norm === "rolled_back" ? "Rolled back" : "Cancelled";
  }

  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-full border font-mono font-medium tracking-tight",
        size === "sm" ? "px-2 py-0.5 text-[10px]" : "px-2.5 py-0.5 text-xs",
        colorClasses,
        className,
      )}
      {...props}
    >
      {showIcon && icon}
      <span>{label || defaultLabel}</span>
    </span>
  );
}
