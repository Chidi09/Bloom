import * as React from "react";
import Link from "next/link";
import { cn } from "@/lib/utils";

interface BloomLogoProps {
  className?: string;
  size?: number;
  showSubtitle?: boolean;
  showWordmark?: boolean;
  layout?: "horizontal" | "vertical";
}

export function BloomFlowerIcon({
  className = "size-5",
  size,
}: {
  className?: string;
  size?: number;
}) {
  return (
    <div
      className={cn("relative flex shrink-0 items-center justify-center", className)}
      style={size ? { width: `${size}px`, height: `${size}px` } : undefined}
    >
      <svg
        className="h-full w-full"
        viewBox="0 0 200 200"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          d="M100 20 C130 20 145 60 125 90 C110 100 90 100 75 90 C55 60 70 20 100 20 Z"
          fill="url(#p_pink)"
          opacity="0.95"
        />
        <path
          d="M180 80 C190 110 155 135 125 115 C115 100 105 85 115 70 C145 50 170 50 180 80 Z"
          fill="url(#p_orange)"
          opacity="0.95"
        />
        <path
          d="M140 175 C115 185 85 155 100 125 C110 110 125 105 135 115 C165 135 165 165 140 175 Z"
          fill="url(#p_cyan)"
          opacity="0.95"
        />
        <path
          d="M60 175 C35 165 35 135 65 115 C75 105 90 110 100 125 C115 155 85 185 60 175 Z"
          fill="url(#p_blue)"
          opacity="0.95"
        />
        <path
          d="M20 80 C30 50 55 50 85 70 C95 85 85 100 75 115 C45 135 10 110 20 80 Z"
          fill="url(#p_purple)"
          opacity="0.95"
        />
        <path
          d="M100 82 L104 96 L118 100 L104 104 L100 118 L96 104 L82 100 L96 96 Z"
          fill="#FFFFFF"
        />
        <defs>
          <linearGradient id="p_pink" x1="100" y1="20" x2="100" y2="100">
            <stop stopColor="#FF4B8B" />
            <stop offset="1" stopColor="#FF8BA7" />
          </linearGradient>
          <linearGradient id="p_orange" x1="180" y1="80" x2="110" y2="110">
            <stop stopColor="#FF884D" />
            <stop offset="1" stopColor="#FFA066" />
          </linearGradient>
          <linearGradient id="p_cyan" x1="140" y1="175" x2="100" y2="115">
            <stop stopColor="#20C9B0" />
            <stop offset="1" stopColor="#48E5C8" />
          </linearGradient>
          <linearGradient id="p_blue" x1="60" y1="175" x2="100" y2="115">
            <stop stopColor="#2563EB" />
            <stop offset="1" stopColor="#60A5FA" />
          </linearGradient>
          <linearGradient id="p_purple" x1="20" y1="80" x2="90" y2="110">
            <stop stopColor="#8B5CF6" />
            <stop offset="1" stopColor="#A855F7" />
          </linearGradient>
        </defs>
      </svg>
    </div>
  );
}

export function BloomLogo({
  className,
  size = 40,
  showSubtitle = true,
  showWordmark = true,
  layout = "vertical",
}: BloomLogoProps) {
  const isVertical = layout === "vertical";

  if (!showWordmark) {
    return <BloomFlowerIcon size={size} className={className} />;
  }

  return (
    <Link
      href="/"
      className={cn(
        "group focus-visible:ring-ring inline-flex rounded-md select-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:outline-none",
        isVertical
          ? "flex-col items-center justify-center gap-2 text-center"
          : "items-center gap-3",
        className,
      )}
      aria-label="Bloom homepage"
    >
      <div
        className="relative flex shrink-0 items-center justify-center transition-transform duration-500 group-hover:rotate-12"
        style={{ width: `${size}px`, height: `${size}px` }}
      >
        <svg
          className="h-full w-full"
          viewBox="0 0 200 200"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            d="M100 20 C130 20 145 60 125 90 C110 100 90 100 75 90 C55 60 70 20 100 20 Z"
            fill="url(#p_pink)"
            opacity="0.95"
          />
          <path
            d="M180 80 C190 110 155 135 125 115 C115 100 105 85 115 70 C145 50 170 50 180 80 Z"
            fill="url(#p_orange)"
            opacity="0.95"
          />
          <path
            d="M140 175 C115 185 85 155 100 125 C110 110 125 105 135 115 C165 135 165 165 140 175 Z"
            fill="url(#p_cyan)"
            opacity="0.95"
          />
          <path
            d="M60 175 C35 165 35 135 65 115 C75 105 90 110 100 125 C115 155 85 185 60 175 Z"
            fill="url(#p_blue)"
            opacity="0.95"
          />
          <path
            d="M20 80 C30 50 55 50 85 70 C95 85 85 100 75 115 C45 135 10 110 20 80 Z"
            fill="url(#p_purple)"
            opacity="0.95"
          />
          <path
            d="M100 82 L104 96 L118 100 L104 104 L100 118 L96 104 L82 100 L96 96 Z"
            fill="#FFFFFF"
          />
          <defs>
            <linearGradient id="p_pink" x1="100" y1="20" x2="100" y2="100">
              <stop stopColor="#FF4B8B" />
              <stop offset="1" stopColor="#FF8BA7" />
            </linearGradient>
            <linearGradient id="p_orange" x1="180" y1="80" x2="110" y2="110">
              <stop stopColor="#FF884D" />
              <stop offset="1" stopColor="#FFA066" />
            </linearGradient>
            <linearGradient id="p_cyan" x1="140" y1="175" x2="100" y2="115">
              <stop stopColor="#20C9B0" />
              <stop offset="1" stopColor="#48E5C8" />
            </linearGradient>
            <linearGradient id="p_blue" x1="60" y1="175" x2="100" y2="115">
              <stop stopColor="#2563EB" />
              <stop offset="1" stopColor="#60A5FA" />
            </linearGradient>
            <linearGradient id="p_purple" x1="20" y1="80" x2="90" y2="110">
              <stop stopColor="#8B5CF6" />
              <stop offset="1" stopColor="#A855F7" />
            </linearGradient>
          </defs>
        </svg>
      </div>
      <div className={cn("flex flex-col", isVertical ? "items-center" : "")}>
        <span
          className={cn(
            "font-heading text-foreground leading-none font-bold tracking-tight",
            isVertical ? "text-2xl" : "text-xl",
          )}
        >
          bloom
        </span>
        {showSubtitle && (
          <span className="text-muted-foreground mt-1 flex items-center gap-1 font-mono text-[9px] font-semibold tracking-[0.18em] uppercase">
            <span className="text-[#A78BFA]">BUILD</span>
            <span className="text-[#FF4B8B]">•</span>
            <span className="text-[#3B82F6]">SHIP</span>
            <span className="text-[#20C9B0]">•</span>
            <span className="text-[#FF884D]">BLOOM</span>
          </span>
        )}
      </div>
    </Link>
  );
}
