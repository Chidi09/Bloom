import * as React from "react";
import {
  AppleLogo,
  AndroidLogo,
  Globe,
  DeviceMobile,
  Laptop,
  SquaresFour,
} from "@phosphor-icons/react";
import { cn } from "@/lib/utils";

interface PlatformIconProps extends React.HTMLAttributes<HTMLSpanElement> {
  platform: string;
  size?: "sm" | "md" | "lg";
}

export function PlatformIcon({
  platform,
  size = "md",
  className,
  ...props
}: PlatformIconProps) {
  const norm = platform.toLowerCase();

  const iconSizes = {
    sm: "size-3.5",
    md: "size-4",
    lg: "size-5",
  };

  const iconClass = iconSizes[size];

  let iconNode: React.ReactNode = <DeviceMobile className={iconClass} />;

  if (norm.includes("ios") || norm.includes("apple")) {
    iconNode = <AppleLogo weight="fill" className={iconClass} />;
  } else if (norm.includes("android")) {
    iconNode = <AndroidLogo weight="fill" className={iconClass} />;
  } else if (norm.includes("web")) {
    iconNode = <Globe weight="bold" className={iconClass} />;
  } else if (norm.includes("desktop") || norm.includes("macos") || norm.includes("windows")) {
    iconNode = <Laptop weight="bold" className={iconClass} />;
  } else if (norm === "all") {
    iconNode = <SquaresFour weight="bold" className={iconClass} />;
  }

  return (
    <span
      className={cn("inline-flex items-center justify-center text-muted-foreground", className)}
      title={platform}
      {...props}
    >
      {iconNode}
    </span>
  );
}
