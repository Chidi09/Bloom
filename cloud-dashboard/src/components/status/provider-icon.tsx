import * as React from "react";
import Image from "next/image";
import {
  GithubLogo,
  GitlabLogo,
  AppleLogo,
  Globe,
} from "@phosphor-icons/react";
import { cn } from "@/lib/utils";

export type ProviderName =
  | "bitbucket"
  | "github"
  | "gitlab"
  | "cloudflare"
  | "namecheap"
  | "godaddy"
  | "aws"
  | "route53"
  | "google"
  | "google_domains"
  | "google_play"
  | "porkbun"
  | "vercel"
  | "digitalocean"
  | "fastly"
  | "shorebird"
  | "apple"
  | string;

const DOMAIN_MAP: Record<string, string> = {
  bitbucket: "bitbucket.org",
  cloudflare: "cloudflare.com",
  namecheap: "namecheap.com",
  godaddy: "godaddy.com",
  aws: "aws.amazon.com",
  route53: "aws.amazon.com",
  google: "domains.google",
  google_domains: "domains.google",
  porkbun: "porkbun.com",
  vercel: "vercel.com",
  digitalocean: "digitalocean.com",
  fastly: "fastly.com",
  shorebird: "shorebird.dev",
};

interface ProviderIconProps extends React.HTMLAttributes<HTMLSpanElement> {
  provider: ProviderName;
  domain?: string;
  size?: "xs" | "sm" | "md" | "lg" | number;
  alt?: string;
}

export function ProviderIcon({
  provider,
  domain,
  size = "md",
  alt,
  className,
  ...props
}: ProviderIconProps) {
  const norm = provider.toLowerCase().replace(/\s+/g, "_");

  const pixelSize =
    typeof size === "number"
      ? size
      : size === "xs"
        ? 12
        : size === "sm"
          ? 16
          : size === "lg"
            ? 24
            : 20;

  const sizeClass =
    typeof size === "number"
      ? ""
      : size === "xs"
        ? "size-3"
        : size === "sm"
          ? "size-4"
          : size === "lg"
            ? "size-6"
            : "size-5";

  // Check phosphor native icons first
  if (norm === "github") {
    return (
      <span className={cn("inline-flex shrink-0 items-center justify-center", sizeClass, className)} {...props}>
        <GithubLogo className="h-full w-full" weight="fill" />
      </span>
    );
  }

  if (norm === "gitlab") {
    return (
      <span className={cn("inline-flex shrink-0 items-center justify-center text-orange-500", sizeClass, className)} {...props}>
        <GitlabLogo className="h-full w-full" weight="fill" />
      </span>
    );
  }

  if (norm === "apple" || norm.includes("app_store")) {
    return (
      <span className={cn("inline-flex shrink-0 items-center justify-center text-zinc-100", sizeClass, className)} {...props}>
        <AppleLogo className="h-full w-full" weight="fill" />
      </span>
    );
  }

  if (norm === "google_play") {
    return (
      <span className={cn("inline-flex shrink-0 items-center justify-center", sizeClass, className)} {...props}>
        <Image
          src="/auth/google-logo.png"
          alt={alt || "Google Play"}
          width={pixelSize}
          height={pixelSize}
          className="object-contain"
        />
      </span>
    );
  }

  // Check mapped domain or domain prop
  const targetDomain = domain || DOMAIN_MAP[norm];

  if (targetDomain) {
    const faviconUrl = `https://www.google.com/s2/favicons?domain=${targetDomain}&sz=64`;
    return (
      <span className={cn("inline-flex shrink-0 items-center justify-center overflow-hidden rounded-[2px]", sizeClass, className)} {...props}>
        <Image
          src={faviconUrl}
          alt={alt || provider}
          width={pixelSize}
          height={pixelSize}
          className="object-contain"
          unoptimized
        />
      </span>
    );
  }

  // Fallbacks
  return (
    <span className={cn("inline-flex shrink-0 items-center justify-center text-muted-foreground", sizeClass, className)} {...props}>
      <Globe className="h-full w-full" weight="bold" />
    </span>
  );
}
