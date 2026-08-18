import * as React from "react";
import Image from "next/image";
import { cn } from "@/lib/utils";
import { PlatformIcon } from "@/components/status/platform-icon";

interface AppIconProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** App-provided icon extracted from its build artifact (launcher icon / favicon). */
  iconUrl?: string | null;
  name: string;
  size?: "sm" | "md" | "lg";
}

const PIXEL_SIZE = { sm: 20, md: 28, lg: 40 };
const CONTAINER_SIZE = { sm: "size-5", md: "size-7", lg: "size-10" };

/**
 * Renders the app's real icon when the backend has extracted one from a
 * build (iOS/Android launcher icon or web favicon); falls back to a
 * generic platform glyph until one is available.
 */
export function AppIcon({
  iconUrl,
  name,
  size = "md",
  className,
  ...props
}: AppIconProps) {
  const [errored, setErrored] = React.useState(false);

  if (iconUrl && !errored) {
    return (
      <span
        className={cn(
          "border-border/80 bg-muted/50 inline-flex shrink-0 items-center justify-center overflow-hidden rounded-md border shadow-xs",
          CONTAINER_SIZE[size],
          className,
        )}
        {...props}
      >
        <Image
          src={iconUrl}
          alt={`${name} icon`}
          width={PIXEL_SIZE[size]}
          height={PIXEL_SIZE[size]}
          className="h-full w-full object-cover"
          unoptimized
          onError={() => setErrored(true)}
        />
      </span>
    );
  }

  return (
    <span
      className={cn(
        "border-border/80 bg-muted/50 text-foreground inline-flex shrink-0 items-center justify-center rounded-md border shadow-xs",
        CONTAINER_SIZE[size],
        className,
      )}
      {...props}
    >
      <PlatformIcon platform="all" size={size === "lg" ? "lg" : "md"} />
    </span>
  );
}
