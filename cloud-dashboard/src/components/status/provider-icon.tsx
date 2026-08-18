import * as React from "react";
import Image from "next/image";
import {
  GithubLogo,
  GitlabLogo,
  AppleLogo,
  Globe,
} from "@phosphor-icons/react";
import { cn } from "@/lib/utils";
import { BloomFlowerIcon } from "@/components/auth/bloom-logo";

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
  | "squarespace"
  | "apple"
  | string;

// Only exceptions live here: brands whose domain isn't `<name>.com`
// (different TLD, subdomain, or a name that doesn't match the brand at
// all). Everything else is computed on the fly in `resolveDomain()`.
const DOMAIN_OVERRIDES: Record<string, string> = {
  bitbucket: "bitbucket.org",
  aws: "aws.amazon.com",
  route53: "aws.amazon.com",
  google: "domains.google",
  google_domains: "domains.google",
  shorebird: "shorebird.dev",
  flutter: "flutter.dev",
  firebase: "firebase.google.com",
  sentry: "sentry.io",
  postmark: "postmarkapp.com",
};

/** `stripe` -> `stripe.com`, `google_domains` -> override lookup, etc. */
function resolveDomain(id: string): string {
  if (DOMAIN_OVERRIDES[id]) return DOMAIN_OVERRIDES[id];
  return `${id.replace(/_/g, "")}.com`;
}

// Segments that show up in env/secret var names but are never the
// provider itself — stripped out before guessing a provider id.
const NON_PROVIDER_TOKENS = new Set([
  "api",
  "key",
  "secret",
  "token",
  "url",
  "id",
  "public",
  "private",
  "client",
  "webhook",
  "signing",
  "endpoint",
  "base",
  "access",
  "auth",
  "app",
  "env",
  "database",
  "db",
  "test",
  "live",
  "prod",
  "production",
  "dev",
  "staging",
  "sandbox",
  "region",
  "bucket",
  "name",
  "password",
  "user",
  "username",
  "host",
  "port",
]);

/**
 * Best-effort detection of a third-party provider from an env/secret var
 * key, e.g. `STRIPE_SECRET_KEY` -> "stripe", `NEXT_PUBLIC_PAYSTACK_KEY`
 * -> "paystack". No hardcoded provider list — any leftover token is
 * treated as a candidate brand id and its favicon is resolved via
 * `resolveDomain()`. Returns null only when nothing meaningful remains.
 */
export function detectEnvVarProvider(key: string): string | null {
  if (!key) return null;
  const tokens = key
    .trim()
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter(Boolean)
    .filter((t) => !NON_PROVIDER_TOKENS.has(t) && !/^\d+$/.test(t));

  const candidate = tokens.find((t) => t.length >= 3);
  return candidate ?? null;
}

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
      <span
        className={cn(
          "inline-flex shrink-0 items-center justify-center",
          sizeClass,
          className,
        )}
        {...props}
      >
        <GithubLogo className="h-full w-full" weight="fill" />
      </span>
    );
  }

  if (norm === "gitlab") {
    return (
      <span
        className={cn(
          "inline-flex shrink-0 items-center justify-center text-orange-500",
          sizeClass,
          className,
        )}
        {...props}
      >
        <GitlabLogo className="h-full w-full" weight="fill" />
      </span>
    );
  }

  if (norm === "apple" || norm.includes("app_store")) {
    return (
      <span
        className={cn(
          "inline-flex shrink-0 items-center justify-center text-zinc-100",
          sizeClass,
          className,
        )}
        {...props}
      >
        <AppleLogo className="h-full w-full" weight="fill" />
      </span>
    );
  }

  if (norm === "bloom" || norm === "bloom_ui") {
    return (
      <span
        className={cn(
          "inline-flex shrink-0 items-center justify-center",
          sizeClass,
          className,
        )}
        {...props}
      >
        <BloomFlowerIcon className="h-full w-full" />
      </span>
    );
  }

  if (norm === "google_play") {
    return (
      <span
        className={cn(
          "inline-flex shrink-0 items-center justify-center",
          sizeClass,
          className,
        )}
        {...props}
      >
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

  // Explicit domain prop wins; otherwise compute one from the provider id.
  const targetDomain = domain || resolveDomain(norm);
  const faviconUrl = `https://www.google.com/s2/favicons?domain=${targetDomain}&sz=64`;

  return (
    <ProviderFavicon
      src={faviconUrl}
      alt={alt || provider}
      pixelSize={pixelSize}
      sizeClass={sizeClass}
      className={className}
      {...props}
    />
  );
}

interface ProviderFaviconProps extends React.HTMLAttributes<HTMLSpanElement> {
  src: string;
  alt: string;
  pixelSize: number;
  sizeClass: string;
}

/**
 * Renders a computed favicon lookup, falling back to a generic globe
 * glyph if the guessed domain doesn't actually resolve to an icon.
 */
function ProviderFavicon({
  src,
  alt,
  pixelSize,
  sizeClass,
  className,
  ...props
}: ProviderFaviconProps) {
  const [errored, setErrored] = React.useState(false);

  if (errored) {
    return (
      <span
        className={cn(
          "text-muted-foreground inline-flex shrink-0 items-center justify-center",
          sizeClass,
          className,
        )}
        {...props}
      >
        <Globe className="h-full w-full" weight="bold" />
      </span>
    );
  }

  return (
    <span
      className={cn(
        "inline-flex shrink-0 items-center justify-center overflow-hidden rounded-[2px]",
        sizeClass,
        className,
      )}
      {...props}
    >
      <Image
        src={src}
        alt={alt}
        width={pixelSize}
        height={pixelSize}
        className="object-contain"
        unoptimized
        onError={() => setErrored(true)}
      />
    </span>
  );
}
