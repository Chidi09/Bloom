"use client";

import * as React from "react";
import Image from "next/image";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { z } from "zod";
import { GithubLogo, WarningCircle } from "@phosphor-icons/react";
import { BloomSpinner } from "@/components/ui/bloom-spinner";

import {
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
  CardFooter,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";
import { Separator } from "@/components/ui/separator";
import {
  Tooltip,
  TooltipTrigger,
  TooltipContent,
} from "@/components/ui/tooltip";
import { api } from "@/lib/api/client";
import { ApiError } from "@/lib/api/errors";
import { useAuthStore } from "@/stores/auth-store";
import { useOrganizationStore } from "@/stores/organization-store";
import { useAuthPreferenceStore } from "@/stores/auth-preference-store";
import { AuthMethodBadge } from "@/components/auth/auth-method-badge";

const loginSchema = z.object({
  email: z
    .string()
    .min(1, "Email is required")
    .email("Please enter a valid email address"),
  password: z.string().min(1, "Password is required"),
});

export default function LoginPage() {
  const router = useRouter();

  const [email, setEmail] = React.useState("");
  const [password, setPassword] = React.useState("");
  const [fieldErrors, setFieldErrors] = React.useState<{
    email?: string;
    password?: string;
  }>({});
  const [errorMsg, setErrorMsg] = React.useState<string | null>(null);
  const [isRateLimited, setIsRateLimited] = React.useState(false);
  const [rateLimitCountdown, setRateLimitCountdown] = React.useState<
    number | null
  >(null);
  const [isLoading, setIsLoading] = React.useState(false);

  React.useEffect(() => {
    if (rateLimitCountdown === null || rateLimitCountdown <= 0) return;
    const timer = setInterval(() => {
      setRateLimitCountdown((prev) => {
        if (prev === null || prev <= 1) {
          setIsRateLimited(false);
          setErrorMsg(null);
          return null;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(timer);
  }, [rateLimitCountdown]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (rateLimitCountdown !== null && rateLimitCountdown > 0) return;
    setErrorMsg(null);
    setIsRateLimited(false);

    // Validate with Zod
    const result = loginSchema.safeParse({ email, password });
    if (!result.success) {
      const formatted = result.error.format();
      setFieldErrors({
        email: formatted.email?._errors[0],
        password: formatted.password?._errors[0],
      });
      return;
    }
    setFieldErrors({});

    setIsLoading(true);
    try {
      const response = await api.post<{
        access_token: string;
        refresh_token: string;
      }>(
        "/auth/login",
        {
          username: email.trim(),
          password,
        },
        { skipOrgHeader: true },
      );

      if (response?.access_token) {
        useAuthStore.getState().setTokens({
          accessToken: response.access_token,
          refreshToken: response.refresh_token,
        });
        useAuthPreferenceStore.getState().recordAuthMethodUsage("email");
        const currentOrg =
          useOrganizationStore.getState().currentOrganizationId;
        router.push(currentOrg ? "/overview" : "/onboarding");
      } else {
        throw new Error("No access token returned from server.");
      }
    } catch (err: unknown) {
      if (err instanceof ApiError) {
        if (err.status === 429) {
          setIsRateLimited(true);
          setRateLimitCountdown(60);
          setErrorMsg(
            "Too many sign-in attempts. Rate limit is 10 requests per minute. Please wait before trying again.",
          );
        } else {
          setErrorMsg(err.message || "Invalid email or password.");
        }
      } else if (err instanceof Error) {
        setErrorMsg(err.message);
      } else {
        setErrorMsg("An unexpected authentication error occurred.");
      }
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Card className="border-border bg-card shadow-sm">
      <CardHeader className="space-y-1">
        <CardTitle className="font-heading text-xl font-semibold tracking-tight">
          Welcome back
        </CardTitle>
        <CardDescription className="text-muted-foreground text-xs">
          Sign in to manage your Flutter &amp; Dart applications on Bloom Cloud.
        </CardDescription>
      </CardHeader>

      <CardContent className="space-y-4">
        {errorMsg && (
          <Alert variant="destructive" className="animate-in fade-in-50">
            <WarningCircle className="size-4 shrink-0" weight="regular" />
            <AlertTitle className="text-xs font-semibold">
              {isRateLimited ? "Rate limit reached" : "Authentication failed"}
            </AlertTitle>
            <AlertDescription className="text-xs">
              {isRateLimited && rateLimitCountdown !== null
                ? `Too many sign-in attempts. Rate limit is 10 requests per minute. Please wait ${rateLimitCountdown}s before trying again.`
                : errorMsg}
            </AlertDescription>
          </Alert>
        )}

        <form
          id="login-form"
          noValidate
          onSubmit={handleSubmit}
          className="space-y-3.5"
        >
          <div className="space-y-1.5">
            <div className="flex items-center justify-between">
              <Label htmlFor="email" className="text-xs font-medium">
                Email
              </Label>
              <AuthMethodBadge method="email" />
            </div>
            <Input
              id="email"
              name="email"
              type="email"
              placeholder="name@work-email.com"
              autoComplete="email"
              autoFocus
              disabled={
                isLoading ||
                (rateLimitCountdown !== null && rateLimitCountdown > 0)
              }
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              aria-invalid={!!fieldErrors.email}
              className="h-8 text-xs"
            />
            {fieldErrors.email && (
              <p className="text-destructive text-[11px] font-medium">
                {fieldErrors.email}
              </p>
            )}
          </div>

          <div className="space-y-1.5">
            <div className="flex items-center justify-between">
              <Label htmlFor="password" className="text-xs font-medium">
                Password
              </Label>
              <a
                href="mailto:support@bloom.dev?subject=Password%20Reset%20Request"
                className="text-muted-foreground hover:text-foreground text-[11px] transition-colors hover:underline"
              >
                Forgot password?
              </a>
            </div>
            <Input
              id="password"
              name="password"
              type="password"
              placeholder="••••••••"
              autoComplete="current-password"
              disabled={
                isLoading ||
                (rateLimitCountdown !== null && rateLimitCountdown > 0)
              }
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              aria-invalid={!!fieldErrors.password}
              className="h-8 text-xs"
            />
            {fieldErrors.password && (
              <p className="text-destructive text-[11px] font-medium">
                {fieldErrors.password}
              </p>
            )}
          </div>

          <Button
            type="submit"
            disabled={
              isLoading ||
              (rateLimitCountdown !== null && rateLimitCountdown > 0)
            }
            className="mt-1 h-8 w-full cursor-pointer text-xs font-medium"
          >
            {isLoading ? (
              <span className="flex items-center gap-2">
                <BloomSpinner size={14} speed="fast" />
                Signing in…
              </span>
            ) : rateLimitCountdown !== null && rateLimitCountdown > 0 ? (
              `Retry in ${rateLimitCountdown}s`
            ) : (
              "Sign in"
            )}
          </Button>
        </form>

        <div className="relative my-4">
          <div className="absolute inset-0 flex items-center">
            <Separator />
          </div>
          <div className="text-muted-foreground relative flex justify-center text-[10px] tracking-wider uppercase">
            <span className="bg-card px-2">or continue with</span>
          </div>
        </div>

        {/* Social sign-in affordances (honest non-functional coming soon) */}
        <div className="grid grid-cols-2 gap-2">
          <Tooltip>
            <TooltipTrigger
              render={
                <Button
                  type="button"
                  variant="outline"
                  disabled
                  className="border-border h-8 w-full cursor-not-allowed gap-2 text-xs opacity-60"
                />
              }
            >
              <Image
                src="/auth/google-logo.png"
                alt="Google logo"
                width={14}
                height={14}
                className="size-3.5 shrink-0"
              />
              <span>Google</span>
              <AuthMethodBadge method="google" />
            </TooltipTrigger>
            <TooltipContent>
              <p>Google authentication coming soon</p>
            </TooltipContent>
          </Tooltip>

          <Tooltip>
            <TooltipTrigger
              render={
                <Button
                  type="button"
                  variant="outline"
                  disabled
                  className="border-border h-8 w-full cursor-not-allowed gap-2 text-xs opacity-60"
                />
              }
            >
              <GithubLogo className="size-3.5 shrink-0" weight="regular" />
              <span>GitHub</span>
              <AuthMethodBadge method="github" />
            </TooltipTrigger>
            <TooltipContent>
              <p>GitHub authentication coming soon</p>
            </TooltipContent>
          </Tooltip>
        </div>
      </CardContent>

      <CardFooter className="border-border/50 flex justify-center border-t pt-3 pb-3">
        <p className="text-muted-foreground text-xs">
          Need an account?{" "}
          <Link
            href="/auth/register"
            className="text-foreground ml-1 font-medium hover:underline"
          >
            Register
          </Link>
        </p>
      </CardFooter>
    </Card>
  );
}
