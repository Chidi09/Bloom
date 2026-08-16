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

  if (
    norm === "success" ||
    norm === "healthy" ||
    norm === "approved" ||
    norm === "completed" ||
    norm === "active" ||
    norm === "published" ||
    norm === "succeeded" ||
    norm === "paid" ||
    norm === "allow"
  ) {
    colorClasses =
      "bg-[var(--status-success-bg)] text-[var(--status-success)] border-[var(--status-success)]/30";
    icon = (
      <CheckCircle
        weight="bold"
        className={size === "sm" ? "size-3 shrink-0" : "size-3.5 shrink-0"}
      />
    );
    defaultLabel =
      norm === "healthy"
        ? "Healthy"
        : norm === "approved"
          ? "Approved"
          : norm === "completed"
            ? "Completed"
            : norm === "active"
              ? "Active"
              : norm === "published"
                ? "Published"
                : norm === "succeeded"
                  ? "Succeeded"
                  : norm === "paid"
                    ? "Paid"
                    : norm === "allow"
                      ? "Allowed"
                      : "Success";
  } else if (norm === "running" || norm === "building") {
    colorClasses =
      "bg-[var(--status-running-bg)] text-[var(--status-running)] border-[var(--status-running)]/30 animate-pulse";
    icon = (
      <ArrowsClockwise
        weight="bold"
        className={cn(
          size === "sm" ? "size-3 shrink-0" : "size-3.5 shrink-0",
          "animate-spin",
        )}
      />
    );
    defaultLabel = "Running";
  } else if (norm === "trialing" || norm === "sent" || norm === "rolling_out") {
    colorClasses =
      "bg-[var(--status-info-bg)] text-[var(--status-info)] border-[var(--status-info)]/30";
    icon = (
      <Clock
        weight="regular"
        className={size === "sm" ? "size-3 shrink-0" : "size-3.5 shrink-0"}
      />
    );
    defaultLabel =
      norm === "trialing" ? "Trialing" : norm === "sent" ? "Sent" : "Rolling Out";
  } else if (
    norm === "blocked" ||
    norm === "warning" ||
    norm === "warn" ||
    norm === "soft_block" ||
    norm === "past_due"
  ) {
    colorClasses =
      "bg-[var(--status-warning-bg)] text-[var(--status-warning)] border-[var(--status-warning)]/30";
    icon = (
      <WarningCircle
        weight="bold"
        className={size === "sm" ? "size-3 shrink-0" : "size-3.5 shrink-0"}
      />
    );
    defaultLabel =
      norm === "blocked"
        ? "Blocked"
        : norm === "warn"
          ? "Warning"
          : norm === "soft_block"
            ? "Soft Block"
            : norm === "past_due"
              ? "Past Due"
              : "Warning";
  } else if (
    norm === "failed" ||
    norm === "error" ||
    norm === "rejected" ||
    norm === "hard_lock" ||
    norm === "locked" ||
    norm === "overdue" ||
    norm === "void"
  ) {
    colorClasses =
      "bg-[var(--status-error-bg)] text-[var(--status-error)] border-[var(--status-error)]/30";
    icon = (
      <XCircle
        weight="bold"
        className={size === "sm" ? "size-3 shrink-0" : "size-3.5 shrink-0"}
      />
    );
    defaultLabel =
      norm === "rejected"
        ? "Rejected"
        : norm === "hard_lock" || norm === "locked"
          ? "Locked"
          : norm === "overdue"
            ? "Overdue"
            : norm === "void"
              ? "Void"
              : "Failed";
  } else if (
    norm === "queued" ||
    norm === "pending" ||
    norm === "draft" ||
    norm === "private"
  ) {
    colorClasses =
      "bg-[var(--status-pending-bg)] text-[var(--status-pending)] border-[var(--status-pending)]/30";
    icon = (
      <Clock
        weight="regular"
        className={size === "sm" ? "size-3 shrink-0" : "size-3.5 shrink-0"}
      />
    );
    defaultLabel =
      norm === "queued"
        ? "Queued"
        : norm === "draft"
          ? "Draft"
          : norm === "private"
            ? "Private"
            : "Pending";
  } else if (
    norm === "cancelled" ||
    norm === "rolled_back" ||
    norm === "skipped" ||
    norm === "refunded" ||
    norm === "archived" ||
    norm === "hidden"
  ) {
    colorClasses =
      "bg-[var(--status-pending-bg)] text-[var(--status-pending)] border-[var(--status-pending)]/30";
    icon = (
      <Prohibit
        weight="regular"
        className={size === "sm" ? "size-3 shrink-0" : "size-3.5 shrink-0"}
      />
    );
    defaultLabel =
      norm === "rolled_back"
        ? "Rolled back"
        : norm === "skipped"
          ? "Skipped"
          : norm === "refunded"
            ? "Refunded"
            : norm === "archived"
              ? "Archived"
              : norm === "hidden"
                ? "Hidden"
                : "Cancelled";
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
