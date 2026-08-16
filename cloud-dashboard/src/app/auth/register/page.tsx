"use client";

import * as React from "react";
import Image from "next/image";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { z } from "zod";
import { GithubLogo, WarningCircle, CheckCircle } from "@phosphor-icons/react";
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
import { useAuthPreferenceStore } from "@/stores/auth-preference-store";
import { AuthMethodBadge } from "@/components/auth/auth-method-badge";

const registerSchema = z.object({
  name: z.string().min(1, "Name is required").max(100, "Name is too long"),
  email: z
    .string()
    .min(1, "Email is required")
    .email("Please enter a valid email address"),
  password: z.string().min(8, "Password must be at least 8 characters"),
});

interface PasswordEvaluation {
  level: "empty" | "weak" | "fair" | "strong";
  label: string;
  hint: string;
  colorClass: string;
}

function evaluatePassword(pwd: string): PasswordEvaluation {
  if (!pwd) {
    return {
      level: "empty",
      label: "",
      hint: "Use at least 8 characters with a mix of letters and numbers.",
      colorClass: "text-muted-foreground",
    };
  }

  let score = 0;
  if (pwd.length >= 8) score += 1;
  if (pwd.length >= 12) score += 1;
  if (/[A-Z]/.test(pwd) && /[a-z]/.test(pwd)) score += 1;
  if (/[0-9]/.test(pwd)) score += 1;
  if (/[^A-Za-z0-9]/.test(pwd)) score += 1;

  if (score <= 1) {
    return {
      level: "weak",
      label: "Weak",
      hint: "Too short. Use at least 8 characters.",
      colorClass: "text-destructive",
    };
  }
  if (score <= 3) {
    return {
      level: "fair",
      label: "Fair",
      hint: "Add numbers and uppercase letters to strengthen.",
      colorClass: "text-status-warning",
    };
  }
  return {
    level: "strong",
    label: "Strong",
    hint: "Great password! Meets all security criteria.",
    colorClass: "text-status-success",
  };
}

export default function RegisterPage() {
  const router = useRouter();

  const [name, setName] = React.useState("");
  const [email, setEmail] = React.useState("");
  const [password, setPassword] = React.useState("");
  const [fieldErrors, setFieldErrors] = React.useState<{
    name?: string;
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

  const pwdEvaluation = React.useMemo(
    () => evaluatePassword(password),
    [password],
  );

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (rateLimitCountdown !== null && rateLimitCountdown > 0) return;
    setErrorMsg(null);
    setIsRateLimited(false);

    // Validate with Zod
    const result = registerSchema.safeParse({ name, email, password });
    if (!result.success) {
      const formatted = result.error.format();
      setFieldErrors({
        name: formatted.name?._errors[0],
        email: formatted.email?._errors[0],
        password: formatted.password?._errors[0],
      });
      return;
    }
    setFieldErrors({});

    setIsLoading(true);
    try {
      // 1. Submit registration request (backend expects { email, username, password } and returns MeResponse)
      await api.post<{
        id: string;
        email: string;
        username: string;
        display_name?: string | null;
      }>(
        "/auth/register",
        {
          username: email.trim(),
          email: email.trim(),
          password,
        },
        { skipOrgHeader: true },
      );

      // 2. Authenticate using the registered credentials to receive JWT tokens
      const loginRes = await api.post<{
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

      if (loginRes?.access_token) {
        useAuthStore.getState().setTokens({
          accessToken: loginRes.access_token,
          refreshToken: loginRes.refresh_token,
        });
        useAuthPreferenceStore.getState().recordAuthMethodUsage("email");
        router.push("/onboarding");
      } else {
        throw new Error(
          "Account created, but authentication token could not be obtained.",
        );
      }
    } catch (err: unknown) {
      if (err instanceof ApiError) {
        if (err.status === 429) {
          setIsRateLimited(true);
          setRateLimitCountdown(60);
          setErrorMsg(
            "Too many registration attempts. Rate limit is 5 requests per minute. Please wait before trying again.",
          );
        } else {
          setErrorMsg(
            err.message || "Registration failed. Please verify your details.",
          );
        }
      } else if (err instanceof Error) {
        setErrorMsg(err.message);
      } else {
        setErrorMsg("An unexpected registration error occurred.");
      }
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Card className="border-border bg-card shadow-sm">
      <CardHeader className="space-y-1">
        <CardTitle className="font-heading text-xl font-semibold tracking-tight">
          Create your account
        </CardTitle>
        <CardDescription className="text-muted-foreground text-xs">
          Deploy and observe your Dart &amp; Flutter apps in minutes.
        </CardDescription>
      </CardHeader>

      <CardContent className="space-y-4">
        {errorMsg && (
          <Alert variant="destructive" className="animate-in fade-in-50">
            <WarningCircle className="size-4 shrink-0" weight="regular" />
            <AlertTitle className="text-xs font-semibold">
              {isRateLimited ? "Rate limit reached" : "Registration failed"}
            </AlertTitle>
            <AlertDescription className="text-xs">
              {isRateLimited && rateLimitCountdown !== null
                ? `Too many registration attempts. Rate limit is 5 requests per minute. Please wait ${rateLimitCountdown}s before trying again.`
                : errorMsg}
            </AlertDescription>
          </Alert>
        )}

        <form
          id="register-form"
          noValidate
          onSubmit={handleSubmit}
          className="space-y-3.5"
        >
          <div className="space-y-1.5">
            <Label htmlFor="name" className="text-xs font-medium">
              Full name
            </Label>
            <Input
              id="name"
              name="name"
              type="text"
              placeholder="Ada Lovelace"
              autoComplete="name"
              autoFocus
              disabled={
                isLoading ||
                (rateLimitCountdown !== null && rateLimitCountdown > 0)
              }
              value={name}
              onChange={(e) => setName(e.target.value)}
              aria-invalid={!!fieldErrors.name}
              className="h-8 text-xs"
            />
            {fieldErrors.name && (
              <p className="text-destructive text-[11px] font-medium">
                {fieldErrors.name}
              </p>
            )}
          </div>

          <div className="space-y-1.5">
            <div className="flex items-center justify-between">
              <Label htmlFor="email" className="text-xs font-medium">
                Work email
              </Label>
              <AuthMethodBadge method="email" />
            </div>
            <Input
              id="email"
              name="email"
              type="email"
              placeholder="name@company.com"
              autoComplete="email"
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
            <Label htmlFor="password" className="text-xs font-medium">
              Password
            </Label>
            <Input
              id="password"
              name="password"
              type="password"
              placeholder="••••••••"
              autoComplete="new-password"
              disabled={
                isLoading ||
                (rateLimitCountdown !== null && rateLimitCountdown > 0)
              }
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              aria-invalid={!!fieldErrors.password}
              className="h-8 text-xs"
            />
            {fieldErrors.password ? (
              <p className="text-destructive text-[11px] font-medium">
                {fieldErrors.password}
              </p>
            ) : (
              <div className="flex items-center justify-between pt-0.5 text-[11px]">
                <span className="text-muted-foreground">
                  {pwdEvaluation.hint}
                </span>
                {pwdEvaluation.label && (
                  <span
                    className={`font-medium ${pwdEvaluation.colorClass} flex items-center gap-1`}
                  >
                    {pwdEvaluation.level === "strong" && (
                      <CheckCircle className="size-3" weight="bold" />
                    )}
                    {pwdEvaluation.label}
                  </span>
                )}
              </div>
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
                Creating account…
              </span>
            ) : rateLimitCountdown !== null && rateLimitCountdown > 0 ? (
              `Retry in ${rateLimitCountdown}s`
            ) : (
              "Create account"
            )}
          </Button>
        </form>

        <div className="relative my-4">
          <div className="absolute inset-0 flex items-center">
            <Separator />
          </div>
          <div className="text-muted-foreground relative flex justify-center text-[10px] tracking-wider uppercase">
            <span className="bg-card px-2">or register with</span>
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
              <p>Google registration coming soon</p>
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
              <p>GitHub registration coming soon</p>
            </TooltipContent>
          </Tooltip>
        </div>
      </CardContent>

      <CardFooter className="border-border/50 flex justify-center border-t pt-3 pb-3">
        <p className="text-muted-foreground text-xs">
          Already have an account?{" "}
          <Link
            href="/auth/login"
            className="text-foreground ml-1 font-medium hover:underline"
          >
            Log in
          </Link>
        </p>
      </CardFooter>
    </Card>
  );
}
