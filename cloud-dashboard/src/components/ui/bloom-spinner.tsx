"use client";

import * as React from "react";
import { cn } from "@/lib/utils";

export interface BloomSpinnerProps extends React.HTMLAttributes<HTMLDivElement> {
  size?: number;
  label?: string;
  speed?: "fast" | "normal" | "slow";
}

const SPEED_CLASSES = {
  fast: "animate-[spin_0.75s_linear_infinite]",
  normal: "animate-[spin_1.2s_linear_infinite]",
  slow: "animate-[spin_2s_linear_infinite]",
};

export function BloomSpinner({
  size = 24,
  label,
  speed = "normal",
  className,
  ...props
}: BloomSpinnerProps) {
  // Unique gradient IDs to prevent collisions when multiple spinners exist on one page
  const id = React.useId();
  const pinkId = `sp_pink_${id}`;
  const orangeId = `sp_orange_${id}`;
  const cyanId = `sp_cyan_${id}`;
  const blueId = `sp_blue_${id}`;
  const purpleId = `sp_purple_${id}`;

  return (
    <div
      role="status"
      aria-label={label ?? "Loading"}
      className={cn("inline-flex items-center gap-2 select-none", className)}
      {...props}
    >
      <div
        className={cn(
          "relative flex shrink-0 items-center justify-center will-change-transform",
          SPEED_CLASSES[speed],
        )}
        style={{ width: `${size}px`, height: `${size}px` }}
      >
        <svg
          className="h-full w-full"
          viewBox="0 0 200 200"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          {/* Top petal */}
          <path
            d="M100 20 C130 20 145 60 125 90 C110 100 90 100 75 90 C55 60 70 20 100 20 Z"
            fill={`url(#${pinkId})`}
            opacity="0.95"
          />
          {/* Top-right petal */}
          <path
            d="M180 80 C190 110 155 135 125 115 C115 100 105 85 115 70 C145 50 170 50 180 80 Z"
            fill={`url(#${orangeId})`}
            opacity="0.95"
          />
          {/* Bottom-right petal */}
          <path
            d="M140 175 C115 185 85 155 100 125 C110 110 125 105 135 115 C165 135 165 165 140 175 Z"
            fill={`url(#${cyanId})`}
            opacity="0.95"
          />
          {/* Bottom-left petal */}
          <path
            d="M60 175 C35 165 35 135 65 115 C75 105 90 110 100 125 C115 155 85 185 60 175 Z"
            fill={`url(#${blueId})`}
            opacity="0.95"
          />
          {/* Top-left petal */}
          <path
            d="M20 80 C30 50 55 50 85 70 C95 85 85 100 75 115 C45 135 10 110 20 80 Z"
            fill={`url(#${purpleId})`}
            opacity="0.95"
          />
          {/* Center sparkle */}
          <path
            d="M100 82 L104 96 L118 100 L104 104 L100 118 L96 104 L82 100 L96 96 Z"
            fill="#FFFFFF"
          />
          <defs>
            <linearGradient id={pinkId} x1="100" y1="20" x2="100" y2="100">
              <stop stopColor="#FF4B8B" />
              <stop offset="1" stopColor="#FF8BA7" />
            </linearGradient>
            <linearGradient id={orangeId} x1="180" y1="80" x2="110" y2="110">
              <stop stopColor="#FF884D" />
              <stop offset="1" stopColor="#FFA066" />
            </linearGradient>
            <linearGradient id={cyanId} x1="140" y1="175" x2="100" y2="115">
              <stop stopColor="#20C9B0" />
              <stop offset="1" stopColor="#48E5C8" />
            </linearGradient>
            <linearGradient id={blueId} x1="60" y1="175" x2="100" y2="115">
              <stop stopColor="#2563EB" />
              <stop offset="1" stopColor="#60A5FA" />
            </linearGradient>
            <linearGradient id={purpleId} x1="20" y1="80" x2="90" y2="110">
              <stop stopColor="#8B5CF6" />
              <stop offset="1" stopColor="#A855F7" />
            </linearGradient>
          </defs>
        </svg>
      </div>
      {label && <span className="text-muted-foreground text-xs">{label}</span>}
    </div>
  );
}
