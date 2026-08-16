import * as React from "react";
import { DeviceMobile, Globe } from "@phosphor-icons/react";
import { cn } from "@/lib/utils";

export interface DeviceFrameProps extends React.HTMLAttributes<HTMLDivElement> {
  platform: "ios" | "android" | "web";
  imageUrl?: string | null;
  className?: string;
}

export function DeviceFrame({
  platform,
  imageUrl,
  className,
  ...props
}: DeviceFrameProps) {
  const norm = (platform?.toLowerCase() || "web") as "ios" | "android" | "web";

  if (norm === "ios") {
    return (
      <div
        className={cn(
          "relative flex aspect-[9/18.5] w-11 shrink-0 flex-col items-center justify-center overflow-hidden rounded-[13px] border-[2.5px] border-zinc-700/80 bg-zinc-950 shadow-sm ring-1 ring-zinc-800/80 select-none",
          className,
        )}
        {...props}
      >
        {/* Dynamic Island cutout */}
        <div className="pointer-events-none absolute top-1 left-1/2 z-10 h-1 w-3.5 -translate-x-1/2 rounded-full bg-zinc-950 ring-1 ring-white/10" />

        {/* Screen Area */}
        <div className="relative flex h-full w-full items-center justify-center overflow-hidden rounded-[9px] bg-zinc-950">
          {imageUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={imageUrl}
              alt="iOS deployment preview"
              className="h-full w-full object-cover"
              loading="lazy"
            />
          ) : (
            <div className="bg-muted/40 text-muted-foreground flex h-full w-full items-center justify-center">
              <DeviceMobile className="size-4 opacity-40" />
            </div>
          )}
        </div>
      </div>
    );
  }

  if (norm === "android") {
    return (
      <div
        className={cn(
          "relative flex aspect-[9/18.5] w-11 shrink-0 flex-col items-center justify-center overflow-hidden rounded-[9px] border-2 border-zinc-700/70 bg-zinc-950 shadow-sm ring-1 ring-zinc-800/80 select-none",
          className,
        )}
        {...props}
      >
        {/* Punch-hole camera dot */}
        <div className="pointer-events-none absolute top-1 left-1/2 z-10 size-1.5 -translate-x-1/2 rounded-full bg-zinc-950 ring-1 ring-white/10" />

        {/* Screen Area */}
        <div className="relative flex h-full w-full items-center justify-center overflow-hidden rounded-[6px] bg-zinc-950">
          {imageUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={imageUrl}
              alt="Android deployment preview"
              className="h-full w-full object-cover"
              loading="lazy"
            />
          ) : (
            <div className="bg-muted/40 text-muted-foreground flex h-full w-full items-center justify-center">
              <DeviceMobile className="size-4 opacity-40" />
            </div>
          )}
        </div>
      </div>
    );
  }

  // Web frame
  return (
    <div
      className={cn(
        "relative flex aspect-[16/10] w-14 shrink-0 flex-col overflow-hidden rounded-[6px] border border-zinc-700/80 bg-zinc-950 shadow-sm ring-1 ring-zinc-800/70 select-none",
        className,
      )}
      {...props}
    >
      {/* Browser Chrome Strip */}
      <div className="border-border/60 flex h-2.5 w-full shrink-0 items-center gap-1 border-b bg-zinc-900/90 px-1.5">
        <div className="size-1 rounded-full bg-zinc-600/70" />
        <div className="size-1 rounded-full bg-zinc-600/70" />
        <div className="size-1 rounded-full bg-zinc-600/70" />
      </div>

      {/* Screen Area */}
      <div className="relative flex h-full w-full flex-1 items-center justify-center overflow-hidden bg-zinc-950">
        {imageUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={imageUrl}
            alt="Web deployment preview"
            className="h-full w-full object-cover"
            loading="lazy"
          />
        ) : (
          <div className="bg-muted/40 text-muted-foreground flex h-full w-full items-center justify-center">
            <Globe className="size-4 opacity-40" />
          </div>
        )}
      </div>
    </div>
  );
}
