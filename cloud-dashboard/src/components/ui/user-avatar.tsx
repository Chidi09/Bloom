"use client";

import * as React from "react";

interface UserAvatarProps {
  name?: string;
  src?: string | null;
  size?: number;
  className?: string;
  hueShift?: number; // Optional manual hue rotation in degrees (0-360)
}

function getDeterministicHue(seed: string): number {
  let hash = 0;
  for (let i = 0; i < seed.length; i++) {
    hash = seed.charCodeAt(i) + ((hash << 5) - hash);
  }
  return Math.abs(hash) % 360;
}

export function UserAvatar({
  name = "user",
  src,
  size = 24,
  className = "",
  hueShift,
}: UserAvatarProps) {
  const [imgError, setImgError] = React.useState(false);
  const hue = hueShift !== undefined ? hueShift : getDeterministicHue(name);

  // If a valid custom src is provided and not errored
  if (src && !imgError) {
    return (
      <div
        className={`relative inline-flex shrink-0 items-center justify-center overflow-hidden rounded-full border border-zinc-800 bg-zinc-900 ${className}`}
        style={{ width: size, height: size }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={src}
          alt={name}
          width={size}
          height={size}
          onError={() => setImgError(true)}
          className="h-full w-full object-cover rounded-full"
        />
      </div>
    );
  }

  // Default holographic 3D orb with deterministic CSS hue rotation
  return (
    <div
      className={`relative inline-flex shrink-0 items-center justify-center overflow-hidden rounded-full border border-zinc-700/60 bg-zinc-950 shadow-sm ${className}`}
      style={{
        width: size,
        height: size,
      }}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src="/avatars/default-orb.jpg"
        alt={name}
        width={size}
        height={size}
        className="h-full w-full object-cover rounded-full"
        style={{
          filter: `hue-rotate(${hue}deg) saturate(1.3) contrast(1.1)`,
        }}
      />
    </div>
  );
}
