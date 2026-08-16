"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { z } from "zod";
import {
  Buildings,
  CheckCircle,
  Copy,
  Check,
  ArrowRight,
  ArrowLeft,
  WarningCircle,
  AppleLogo,
  AndroidLogo,
  Globe,
  Desktop,
  Sparkle,
  Terminal,
  WindowsLogo,
  Lightning,
  Rocket,
  Wrench,
  Target,
  DeviceMobile,
} from "@phosphor-icons/react";

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
import { Badge } from "@/components/ui/badge";
import { BloomLogo } from "@/components/auth/bloom-logo";
import { BloomSpinner } from "@/components/ui/bloom-spinner";
import { FlutterIcon } from "@/components/ui/flutter-icon";
import { api } from "@/lib/api/client";
import { ApiError } from "@/lib/api/errors";
import { useOrganizationStore } from "@/stores/organization-store";

// Step 1: Organization validation
const orgSchema = z.object({
  name: z
    .string()
    .min(2, "Workspace name must be at least 2 characters")
    .max(50, "Workspace name is too long"),
});

// Step 2: Project & App validation
const appSetupSchema = z.object({
  projectName: z
    .string()
    .min(2, "Project name must be at least 2 characters")
    .max(50, "Project name is too long"),
  appName: z
    .string()
    .min(2, "App name must be at least 2 characters")
    .max(50, "App name is too long")
    .regex(
      /^[a-z0-9_-]+$/i,
      "App name can only contain letters, numbers, hyphens, and underscores",
    ),
  repositoryUrl: z
    .string()
    .url("Please enter a valid URL (e.g. https://github.com/org/repo)")
    .optional()
    .or(z.literal("")),
});

type FrameworkChoice = "bloom" | "flutter";
type PlatformTarget = "ios" | "android" | "web" | "desktop";
type OsChoice = "macos" | "windows";

export default function OnboardingPage() {
  const router = useRouter();
  const [currentStep, setCurrentStep] = React.useState<1 | 2 | 3>(1);

  // Step 1 state (Organization)
  const [orgName, setOrgName] = React.useState("");

  // Step 2 state (Project & App)
  const [frameworkChoice, setFrameworkChoice] =
    React.useState<FrameworkChoice>("bloom");
  const [projectName, setProjectName] = React.useState("Main");
  const [appName, setAppName] = React.useState("my_bloom_app");
  const [repositoryUrl, setRepositoryUrl] = React.useState("");
  const [selectedPlatforms, setSelectedPlatforms] = React.useState<
    PlatformTarget[]
  >(["ios", "android", "web"]);

  // Step 3 state (CLI)
  const [selectedOs, setSelectedOs] = React.useState<OsChoice>("macos");
  const [isCliConnected, setIsCliConnected] = React.useState(false);
  const [copiedSnippet, setCopiedSnippet] = React.useState<string | null>(null);

  // Loading & error states
  const [isLoading, setIsLoading] = React.useState(false);
  const [errorMsg, setErrorMsg] = React.useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = React.useState<
    Record<string, string | undefined>
  >({});

  // Computed slug for live preview
  const derivedSlug = React.useMemo(() => {
    if (!orgName.trim()) return "my-team";
    return orgName
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/(^-|-$)/g, "");
  }, [orgName]);

  const togglePlatform = (platform: PlatformTarget) => {
    setSelectedPlatforms((prev) =>
      prev.includes(platform)
        ? prev.filter((p) => p !== platform)
        : [...prev, platform],
    );
  };

  const handleCopy = (text: string, id: string) => {
    navigator.clipboard.writeText(text);
    setCopiedSnippet(id);
    setTimeout(() => setCopiedSnippet(null), 2000);
  };

  // Step 1: Submit Organization creation
  const handleOrgSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);
    setFieldErrors({});

    const result = orgSchema.safeParse({ name: orgName });
    if (!result.success) {
      const formatted = result.error.format();
      setFieldErrors({ name: formatted.name?._errors[0] });
      return;
    }

    setIsLoading(true);
    try {
      const res = await api.post<{ id: string; name: string; slug: string }>(
        "/organizations",
        { name: orgName.trim() },
        { skipOrgHeader: true },
      );

      if (res?.id) {
        useOrganizationStore.getState().setCurrentOrganizationId(res.id);
        setCurrentStep(2);
      } else {
        throw new Error("Failed to create organization. No ID returned.");
      }
    } catch (err: unknown) {
      if (err instanceof ApiError) {
        setErrorMsg(err.message || "Failed to create organization.");
      } else if (err instanceof Error) {
        setErrorMsg(err.message);
      } else {
        setErrorMsg("An unexpected error occurred while creating workspace.");
      }
    } finally {
      setIsLoading(false);
    }
  };

  // Step 2: Submit Project & App creation
  const handleAppSetupSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);
    setFieldErrors({});

    const result = appSetupSchema.safeParse({
      projectName,
      appName,
      repositoryUrl: repositoryUrl.trim(),
    });

    if (!result.success) {
      const formatted = result.error.format();
      setFieldErrors({
        projectName: formatted.projectName?._errors[0],
        appName: formatted.appName?._errors[0],
        repositoryUrl: formatted.repositoryUrl?._errors[0],
      });
      return;
    }

    setIsLoading(true);
    try {
      // 1. Create Project
      const projectRes = await api.post<{ id: string; name: string }>(
        "/projects",
        {
          name: projectName.trim(),
          description:
            frameworkChoice === "bloom"
              ? "Bloom Framework Project"
              : "Standard Flutter Project",
        },
      );

      if (!projectRes?.id) {
        throw new Error("Failed to initialize project container.");
      }

      // 2. Create App inside Project
      await api.post<{ id: string; name: string }>("/apps", {
        project_id: projectRes.id,
        name: appName.trim(),
        repository_url: repositoryUrl.trim() || undefined,
        default_branch: "main",
      });

      setCurrentStep(3);
    } catch (err: unknown) {
      if (err instanceof ApiError) {
        setErrorMsg(err.message || "Failed to create application.");
      } else if (err instanceof Error) {
        setErrorMsg(err.message);
      } else {
        setErrorMsg("An unexpected error occurred during project setup.");
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleSkipToStep3 = () => {
    setErrorMsg(null);
    setCurrentStep(3);
  };

  const handleFinishOnboarding = () => {
    router.push("/overview");
  };

  // Stepper progress width calculation
  const progressPercent =
    currentStep === 1 ? "w-1/3" : currentStep === 2 ? "w-2/3" : "w-full";

  return (
    <div className="bg-background flex min-h-screen w-full flex-col items-center justify-center p-4 selection:bg-[#FF4B8B]/20 sm:p-8">
      {/* Top Brand */}
      <div className="mb-6 flex flex-col items-center">
        <BloomLogo layout="vertical" size={38} />
      </div>

      {/* Main Container */}
      <div className="w-full max-w-xl">
        {/* Animated Progress Rail */}
        <div className="bg-muted/60 mb-3 h-1 w-full overflow-hidden rounded-full">
          <div
            className={`h-full bg-gradient-to-r from-[#FF4B8B] via-[#8B5CF6] to-[#20C9B0] transition-all duration-500 ease-out ${progressPercent}`}
          />
        </div>

        {/* Step Indicator Header */}
        <div className="mb-4 flex items-center justify-between px-2 text-xs">
          <div className="flex items-center gap-1.5">
            <span
              className={`flex size-5 items-center justify-center rounded-full text-[10px] font-semibold transition-colors ${
                currentStep >= 1
                  ? "bg-foreground text-background"
                  : "bg-muted text-muted-foreground"
              }`}
            >
              1
            </span>
            <span
              className={
                currentStep === 1
                  ? "text-foreground font-medium"
                  : "text-muted-foreground"
              }
            >
              Workspace
            </span>
          </div>

          <div className="bg-border h-px w-8" />

          <div className="flex items-center gap-1.5">
            <span
              className={`flex size-5 items-center justify-center rounded-full text-[10px] font-semibold transition-colors ${
                currentStep >= 2
                  ? "bg-foreground text-background"
                  : "bg-muted text-muted-foreground"
              }`}
            >
              2
            </span>
            <span
              className={
                currentStep === 2
                  ? "text-foreground font-medium"
                  : "text-muted-foreground"
              }
            >
              App Setup
            </span>
          </div>

          <div className="bg-border h-px w-8" />

          <div className="flex items-center gap-1.5">
            <span
              className={`flex size-5 items-center justify-center rounded-full text-[10px] font-semibold transition-colors ${
                currentStep >= 3
                  ? "bg-foreground text-background"
                  : "bg-muted text-muted-foreground"
              }`}
            >
              3
            </span>
            <span
              className={
                currentStep === 3
                  ? "text-foreground font-medium"
                  : "text-muted-foreground"
              }
            >
              CLI Quickstart
            </span>
          </div>
        </div>

        {/* Card Body with Smooth Enter Animation */}
        <Card className="border-border bg-card shadow-sm transition-all duration-300">
          {/* ================= STEP 1: Workspace ================= */}
          {currentStep === 1 && (
            <div className="animate-in fade-in-50 duration-300">
              <CardHeader className="space-y-1">
                <CardTitle className="font-heading text-lg font-semibold tracking-tight">
                  Create your team workspace
                </CardTitle>
                <CardDescription className="text-muted-foreground text-xs">
                  Organizations own your Bloom applications, environments,
                  secrets, and cloud builds.
                </CardDescription>
              </CardHeader>

              <CardContent className="space-y-4">
                {errorMsg && (
                  <Alert variant="destructive">
                    <WarningCircle className="size-4 shrink-0" />
                    <AlertTitle className="text-xs font-semibold">
                      Workspace error
                    </AlertTitle>
                    <AlertDescription className="text-xs">
                      {errorMsg}
                    </AlertDescription>
                  </Alert>
                )}

                <form
                  id="org-form"
                  noValidate
                  onSubmit={handleOrgSubmit}
                  className="space-y-3.5"
                >
                  <div className="space-y-1.5">
                    <Label htmlFor="orgName" className="text-xs font-medium">
                      Organization or Team Name
                    </Label>
                    <Input
                      id="orgName"
                      placeholder="e.g. Bloom Labs, Acme Studio"
                      autoFocus
                      disabled={isLoading}
                      value={orgName}
                      onChange={(e) => setOrgName(e.target.value)}
                      aria-invalid={!!fieldErrors.name}
                      className="h-8 text-xs"
                    />
                    {fieldErrors.name && (
                      <p className="text-destructive text-[11px] font-medium">
                        {fieldErrors.name}
                      </p>
                    )}

                    {/* Live Workspace URL Preview Pill */}
                    <div className="border-border/60 bg-muted/30 text-muted-foreground mt-2 flex items-center justify-between rounded-md border px-2.5 py-1.5 font-mono text-[11px]">
                      <span className="truncate">
                        console.bloom.dev/
                        <span className="text-foreground font-semibold">
                          {derivedSlug}
                        </span>
                      </span>
                      <span className="text-status-success flex shrink-0 items-center gap-1 font-sans text-[10px]">
                        <Check className="size-3" />
                        Available
                      </span>
                    </div>
                  </div>

                  <div className="border-border/60 bg-muted/40 text-muted-foreground space-y-1 rounded-md border p-3 text-[11px]">
                    <div className="text-foreground flex items-center gap-1.5 font-medium">
                      <Buildings className="text-primary size-3.5 shrink-0" />
                      <span>Single-Tenant Security &amp; Member Access</span>
                    </div>
                    <p>
                      You will be assigned the <strong>Owner</strong> role. You
                      can invite team members and link repositories once
                      created.
                    </p>
                  </div>

                  <Button
                    type="submit"
                    disabled={isLoading || !orgName.trim()}
                    className="mt-2 h-8 w-full cursor-pointer text-xs font-medium"
                  >
                    {isLoading ? (
                      <span className="flex items-center gap-2">
                        <BloomSpinner size={14} speed="fast" />
                        Creating workspace…
                      </span>
                    ) : (
                      <span className="flex items-center gap-1.5">
                        Continue to App Setup
                        <ArrowRight className="size-3.5" />
                      </span>
                    )}
                  </Button>
                </form>
              </CardContent>
            </div>
          )}

          {/* ================= STEP 2: App Setup ================= */}
          {currentStep === 2 && (
            <div className="animate-in fade-in-50 duration-300">
              <CardHeader className="space-y-1">
                <CardTitle className="font-heading text-lg font-semibold tracking-tight">
                  Set up your first application
                </CardTitle>
                <CardDescription className="text-muted-foreground text-xs">
                  Choose the Bloom Framework or configure a standard Flutter /
                  Dart application.
                </CardDescription>
              </CardHeader>

              <CardContent className="space-y-4">
                {errorMsg && (
                  <Alert variant="destructive">
                    <WarningCircle className="size-4 shrink-0" />
                    <AlertTitle className="text-xs font-semibold">
                      Setup error
                    </AlertTitle>
                    <AlertDescription className="text-xs">
                      {errorMsg}
                    </AlertDescription>
                  </Alert>
                )}

                {/* Framework Selector with Glowing Bloom Option */}
                <div className="space-y-2">
                  <Label className="text-xs font-medium">
                    Framework &amp; Architecture
                  </Label>
                  <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2">
                    {/* Bloom Framework Card with Glow Effect */}
                    <button
                      type="button"
                      onClick={() => {
                        setFrameworkChoice("bloom");
                        if (appName === "flutter_app") setAppName("bloom_app");
                      }}
                      className={`relative flex cursor-pointer flex-col items-start rounded-xl p-3.5 text-left transition-all duration-300 ${
                        frameworkChoice === "bloom"
                          ? "via-card to-card border border-[#FF4B8B]/70 bg-gradient-to-b from-[#FF4B8B]/12 shadow-[0_0_24px_-4px_rgba(255,75,139,0.35)] ring-1 ring-[#FF4B8B]/50"
                          : "border-border bg-card hover:bg-muted/40 border"
                      }`}
                    >
                      <div className="flex w-full items-center justify-between">
                        <div className="flex items-center gap-1.5">
                          <BloomLogo size={18} showWordmark={false} />
                          <span className="font-heading text-xs font-semibold">
                            Bloom Framework
                          </span>
                        </div>
                        <Badge
                          variant="secondary"
                          className="flex items-center gap-1 border-[#FF4B8B]/30 bg-[#FF4B8B]/15 px-1.5 py-0 text-[9px] text-[#FF4B8B]"
                        >
                          <Sparkle
                            className="size-2.5 animate-pulse"
                            weight="fill"
                          />
                          Recommended
                        </Badge>
                      </div>

                      <p className="text-muted-foreground mt-1.5 text-[11px] leading-snug">
                        Full-stack Flutter with signals reactivity, DI, OTA live
                        updates, and prebuilds.
                      </p>

                      {/* Micro Feature Badges */}
                      <div className="mt-2.5 flex flex-wrap gap-1">
                        <span className="inline-flex items-center gap-1 rounded bg-[#FF4B8B]/10 px-1.5 py-0.5 font-mono text-[9px] text-[#FF4B8B]">
                          <Lightning className="size-2.5" weight="fill" />
                          Signals
                        </span>
                        <span className="inline-flex items-center gap-1 rounded bg-[#8B5CF6]/10 px-1.5 py-0.5 font-mono text-[9px] text-[#8B5CF6]">
                          <Rocket className="size-2.5" weight="fill" />
                          Live OTA
                        </span>
                        <span className="inline-flex items-center gap-1 rounded bg-[#20C9B0]/10 px-1.5 py-0.5 font-mono text-[9px] text-[#20C9B0]">
                          <Wrench className="size-2.5" weight="fill" />
                          Prebuilds
                        </span>
                      </div>
                    </button>

                    {/* Standard Flutter Card */}
                    <button
                      type="button"
                      onClick={() => {
                        setFrameworkChoice("flutter");
                        if (appName === "bloom_app") setAppName("flutter_app");
                      }}
                      className={`relative flex cursor-pointer flex-col items-start rounded-xl p-3.5 text-left transition-all duration-300 ${
                        frameworkChoice === "flutter"
                          ? "via-card to-card border border-[#02569B]/70 bg-gradient-to-b from-[#02569B]/15 shadow-[0_0_20px_-4px_rgba(2,86,155,0.35)] ring-1 ring-[#02569B]/50"
                          : "border-border bg-card hover:bg-muted/40 border"
                      }`}
                    >
                      <div className="flex w-full items-center justify-between">
                        <div className="flex items-center gap-1.5">
                          <FlutterIcon className="size-4" />
                          <span className="font-heading text-xs font-semibold">
                            Standard Flutter
                          </span>
                        </div>
                      </div>

                      <p className="text-muted-foreground mt-1.5 text-[11px] leading-snug">
                        Existing vanilla Flutter or standalone Dart project
                        without Bloom conventions.
                      </p>

                      {/* Micro Feature Badges */}
                      <div className="mt-2.5 flex flex-wrap gap-1">
                        <span className="inline-flex items-center gap-1 rounded bg-[#02569B]/15 px-1.5 py-0.5 font-mono text-[9px] text-[#29B6F6]">
                          <Target className="size-2.5" weight="fill" />
                          pubspec.yaml
                        </span>
                        <span className="bg-muted text-muted-foreground inline-flex items-center gap-1 rounded px-1.5 py-0.5 font-mono text-[9px]">
                          <DeviceMobile className="size-2.5" weight="fill" />
                          Multi-target
                        </span>
                      </div>
                    </button>
                  </div>
                </div>

                {/* Platform Target Selection Chips */}
                <div className="space-y-1.5">
                  <Label className="text-xs font-medium">
                    Target Platforms
                  </Label>
                  <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
                    {/* iOS */}
                    <button
                      type="button"
                      onClick={() => togglePlatform("ios")}
                      className={`flex cursor-pointer items-center justify-center gap-1.5 rounded-lg border py-1.5 text-xs transition-all ${
                        selectedPlatforms.includes("ios")
                          ? "border-foreground bg-foreground text-background font-medium"
                          : "border-border bg-card text-muted-foreground hover:text-foreground"
                      }`}
                    >
                      <AppleLogo className="size-3.5" weight="fill" />
                      <span>iOS</span>
                    </button>

                    {/* Android */}
                    <button
                      type="button"
                      onClick={() => togglePlatform("android")}
                      className={`flex cursor-pointer items-center justify-center gap-1.5 rounded-lg border py-1.5 text-xs transition-all ${
                        selectedPlatforms.includes("android")
                          ? "border-foreground bg-foreground text-background font-medium"
                          : "border-border bg-card text-muted-foreground hover:text-foreground"
                      }`}
                    >
                      <AndroidLogo className="size-3.5" weight="fill" />
                      <span>Android</span>
                    </button>

                    {/* Web */}
                    <button
                      type="button"
                      onClick={() => togglePlatform("web")}
                      className={`flex cursor-pointer items-center justify-center gap-1.5 rounded-lg border py-1.5 text-xs transition-all ${
                        selectedPlatforms.includes("web")
                          ? "border-foreground bg-foreground text-background font-medium"
                          : "border-border bg-card text-muted-foreground hover:text-foreground"
                      }`}
                    >
                      <Globe className="size-3.5" />
                      <span>Web</span>
                    </button>

                    {/* Desktop */}
                    <button
                      type="button"
                      onClick={() => togglePlatform("desktop")}
                      className={`flex cursor-pointer items-center justify-center gap-1.5 rounded-lg border py-1.5 text-xs transition-all ${
                        selectedPlatforms.includes("desktop")
                          ? "border-foreground bg-foreground text-background font-medium"
                          : "border-border bg-card text-muted-foreground hover:text-foreground"
                      }`}
                    >
                      <Desktop className="size-3.5" />
                      <span>Desktop</span>
                    </button>
                  </div>
                </div>

                <form
                  id="app-form"
                  noValidate
                  onSubmit={handleAppSetupSubmit}
                  className="space-y-3"
                >
                  <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                    <div className="space-y-1.5">
                      <Label
                        htmlFor="projectName"
                        className="text-xs font-medium"
                      >
                        Project Name
                      </Label>
                      <Input
                        id="projectName"
                        placeholder="e.g. Mobile Suite"
                        disabled={isLoading}
                        value={projectName}
                        onChange={(e) => setProjectName(e.target.value)}
                        aria-invalid={!!fieldErrors.projectName}
                        className="h-8 text-xs"
                      />
                      {fieldErrors.projectName && (
                        <p className="text-destructive text-[11px] font-medium">
                          {fieldErrors.projectName}
                        </p>
                      )}
                    </div>

                    <div className="space-y-1.5">
                      <Label htmlFor="appName" className="text-xs font-medium">
                        App Slug
                      </Label>
                      <Input
                        id="appName"
                        placeholder="e.g. bloom_app"
                        disabled={isLoading}
                        value={appName}
                        onChange={(e) => setAppName(e.target.value)}
                        aria-invalid={!!fieldErrors.appName}
                        className="h-8 font-mono text-xs"
                      />
                      {fieldErrors.appName && (
                        <p className="text-destructive text-[11px] font-medium">
                          {fieldErrors.appName}
                        </p>
                      )}
                    </div>
                  </div>

                  <div className="space-y-1.5">
                    <Label
                      htmlFor="repoUrl"
                      className="flex items-center justify-between text-xs font-medium"
                    >
                      <span>Git Repository URL (Optional)</span>
                      <span className="text-muted-foreground text-[10px] font-normal">
                        Can be linked later
                      </span>
                    </Label>
                    <Input
                      id="repoUrl"
                      placeholder="https://github.com/org/my-app"
                      disabled={isLoading}
                      value={repositoryUrl}
                      onChange={(e) => setRepositoryUrl(e.target.value)}
                      aria-invalid={!!fieldErrors.repositoryUrl}
                      className="h-8 font-mono text-xs"
                    />
                    {fieldErrors.repositoryUrl && (
                      <p className="text-destructive text-[11px] font-medium">
                        {fieldErrors.repositoryUrl}
                      </p>
                    )}
                  </div>

                  <div className="flex items-center justify-between pt-2">
                    <Button
                      type="button"
                      variant="ghost"
                      onClick={handleSkipToStep3}
                      disabled={isLoading}
                      className="text-muted-foreground hover:text-foreground h-8 text-xs"
                    >
                      Skip project creation for now
                    </Button>

                    <Button
                      type="submit"
                      disabled={isLoading || !appName.trim()}
                      className="h-8 cursor-pointer text-xs font-medium"
                    >
                      {isLoading ? (
                        <span className="flex items-center gap-2">
                          <BloomSpinner size={14} speed="fast" />
                          Configuring app…
                        </span>
                      ) : (
                        <span className="flex items-center gap-1.5">
                          Create App &amp; Continue
                          <ArrowRight className="size-3.5" />
                        </span>
                      )}
                    </Button>
                  </div>
                </form>
              </CardContent>
            </div>
          )}

          {/* ================= STEP 3: CLI Quickstart ================= */}
          {currentStep === 3 && (
            <div className="animate-in fade-in-50 duration-300">
              <CardHeader className="space-y-1">
                <div className="flex items-center justify-between">
                  <CardTitle className="font-heading text-lg font-semibold tracking-tight">
                    Connect local terminal
                  </CardTitle>

                  {/* OS Switcher Tabs */}
                  <div className="border-border/80 bg-muted/40 flex items-center rounded-lg border p-0.5 text-[11px]">
                    <button
                      type="button"
                      onClick={() => setSelectedOs("macos")}
                      className={`flex cursor-pointer items-center gap-1 rounded-md px-2 py-0.5 transition-all ${
                        selectedOs === "macos"
                          ? "bg-card text-foreground font-medium shadow-xs"
                          : "text-muted-foreground hover:text-foreground"
                      }`}
                    >
                      <Terminal className="size-3" />
                      <span>macOS / Linux</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => setSelectedOs("windows")}
                      className={`flex cursor-pointer items-center gap-1 rounded-md px-2 py-0.5 transition-all ${
                        selectedOs === "windows"
                          ? "bg-card text-foreground font-medium shadow-xs"
                          : "text-muted-foreground hover:text-foreground"
                      }`}
                    >
                      <WindowsLogo className="size-3" weight="fill" />
                      <span>Windows</span>
                    </button>
                  </div>
                </div>
                <CardDescription className="text-muted-foreground text-xs">
                  Run the Bloom toolchain locally to build, test, and deploy
                  directly to your cloud workspace.
                </CardDescription>
              </CardHeader>

              <CardContent className="space-y-3.5">
                {/* One-Click Chained Copy Banner */}
                <div className="border-border/80 bg-muted/40 flex items-center justify-between rounded-lg border px-3 py-2 text-xs">
                  <div className="flex items-center gap-2">
                    <Lightning
                      className="size-4 text-[#FF4B8B]"
                      weight="fill"
                    />
                    <span className="font-medium">Quick One-Liner</span>
                  </div>
                  <button
                    type="button"
                    onClick={() =>
                      handleCopy(
                        selectedOs === "macos"
                          ? "dart pub global activate bloom && bloom login && bloom init"
                          : "dart pub global activate bloom; bloom login; bloom init",
                        "cmd-all",
                      )
                    }
                    className="border-border/80 bg-card hover:bg-accent flex cursor-pointer items-center gap-1.5 rounded-md border px-2 py-1 text-[11px] font-medium transition-all"
                  >
                    {copiedSnippet === "cmd-all" ? (
                      <>
                        <Check className="text-status-success size-3" />
                        <span className="text-status-success">Copied All!</span>
                      </>
                    ) : (
                      <>
                        <Copy className="size-3" />
                        <span>Copy All Commands</span>
                      </>
                    )}
                  </button>
                </div>

                {/* Command 1: Install CLI */}
                <div className="space-y-1">
                  <div className="flex items-center justify-between text-xs font-medium">
                    <span>1. Install the Bloom CLI</span>
                    <button
                      type="button"
                      onClick={() =>
                        handleCopy("dart pub global activate bloom", "cmd1")
                      }
                      className="text-muted-foreground hover:text-foreground flex cursor-pointer items-center gap-1 text-[11px] transition-colors"
                    >
                      {copiedSnippet === "cmd1" ? (
                        <>
                          <Check className="text-status-success size-3" />
                          <span className="text-status-success font-medium">
                            Copied
                          </span>
                        </>
                      ) : (
                        <>
                          <Copy className="size-3" />
                          <span>Copy</span>
                        </>
                      )}
                    </button>
                  </div>
                  <div className="border-border/80 rounded-md border bg-zinc-950 p-2 font-mono text-xs text-zinc-100 dark:bg-zinc-900">
                    <code>dart pub global activate bloom</code>
                  </div>
                </div>

                {/* Command 2: Authenticate */}
                <div className="space-y-1">
                  <div className="flex items-center justify-between text-xs font-medium">
                    <span>2. Authenticate your machine</span>
                    <button
                      type="button"
                      onClick={() => handleCopy("bloom login", "cmd2")}
                      className="text-muted-foreground hover:text-foreground flex cursor-pointer items-center gap-1 text-[11px] transition-colors"
                    >
                      {copiedSnippet === "cmd2" ? (
                        <>
                          <Check className="text-status-success size-3" />
                          <span className="text-status-success font-medium">
                            Copied
                          </span>
                        </>
                      ) : (
                        <>
                          <Copy className="size-3" />
                          <span>Copy</span>
                        </>
                      )}
                    </button>
                  </div>
                  <div className="border-border/80 rounded-md border bg-zinc-950 p-2 font-mono text-xs text-zinc-100 dark:bg-zinc-900">
                    <code>bloom login</code>
                  </div>
                </div>

                {/* Command 3: Init */}
                <div className="space-y-1">
                  <div className="flex items-center justify-between text-xs font-medium">
                    <span>3. Initialize or link your application</span>
                    <button
                      type="button"
                      onClick={() => handleCopy("bloom init", "cmd3")}
                      className="text-muted-foreground hover:text-foreground flex cursor-pointer items-center gap-1 text-[11px] transition-colors"
                    >
                      {copiedSnippet === "cmd3" ? (
                        <>
                          <Check className="text-status-success size-3" />
                          <span className="text-status-success font-medium">
                            Copied
                          </span>
                        </>
                      ) : (
                        <>
                          <Copy className="size-3" />
                          <span>Copy</span>
                        </>
                      )}
                    </button>
                  </div>
                  <div className="border-border/80 rounded-md border bg-zinc-950 p-2 font-mono text-xs text-zinc-100 dark:bg-zinc-900">
                    <code>bloom init</code>
                  </div>
                </div>

                {/* Live CLI Handshake State Box */}
                <div className="border-border/70 bg-muted/30 rounded-md border p-3 text-[11px]">
                  {isCliConnected ? (
                    <div className="flex items-center justify-between">
                      <div className="text-status-success flex items-center gap-2">
                        <CheckCircle
                          className="size-4 shrink-0"
                          weight="fill"
                        />
                        <div>
                          <span className="text-foreground font-semibold">
                            Machine Linked
                          </span>
                          <p className="text-muted-foreground text-[10px]">
                            MacBook Pro (darwin-arm64) · Bloom CLI v1.0.4
                          </p>
                        </div>
                      </div>
                      <Badge
                        variant="outline"
                        className="text-status-success border-status-success/30 text-[9px]"
                      >
                        Online
                      </Badge>
                    </div>
                  ) : (
                    <div className="flex items-center justify-between">
                      <div className="text-muted-foreground flex items-center gap-2">
                        <span className="relative flex size-2">
                          <span className="bg-status-success absolute inline-flex h-full w-full animate-ping rounded-full opacity-75" />
                          <span className="bg-status-success relative inline-flex size-2 rounded-full" />
                        </span>
                        <span>
                          Waiting for terminal connection via{" "}
                          <code>bloom login</code>...
                        </span>
                      </div>
                      <button
                        type="button"
                        onClick={() => setIsCliConnected(true)}
                        className="text-foreground hover:text-primary cursor-pointer text-[10px] font-medium underline transition-colors"
                      >
                        Simulate connection
                      </button>
                    </div>
                  )}
                </div>
              </CardContent>

              <CardFooter className="border-border/50 flex justify-between border-t pt-3 pb-3">
                <Button
                  type="button"
                  variant="ghost"
                  onClick={() => setCurrentStep(2)}
                  className="h-8 text-xs"
                >
                  <ArrowLeft className="mr-1 size-3.5" />
                  Back
                </Button>

                <Button
                  type="button"
                  onClick={handleFinishOnboarding}
                  className="h-8 cursor-pointer gap-1.5 text-xs font-medium"
                >
                  Enter Dashboard Overview
                  <ArrowRight className="size-3.5" />
                </Button>
              </CardFooter>
            </div>
          )}
        </Card>
      </div>
    </div>
  );
}
