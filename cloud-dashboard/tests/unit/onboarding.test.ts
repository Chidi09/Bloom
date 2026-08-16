import { describe, expect, it } from "bun:test";
import { z } from "zod";

const orgSchema = z.object({
  name: z
    .string()
    .min(2, "Workspace name must be at least 2 characters")
    .max(50, "Workspace name is too long"),
});

const appSetupSchema = z.object({
  projectName: z
    .string()
    .min(2, "Project name must be at least 2 characters")
    .max(50, "Project name is too long"),
  appName: z
    .string()
    .min(2, "App name must be at least 2 characters")
    .max(50, "App name is too long")
    .regex(/^[a-z0-9_-]+$/i, "App name can only contain letters, numbers, hyphens, and underscores"),
  repositoryUrl: z
    .string()
    .url("Please enter a valid URL (e.g. https://github.com/org/repo)")
    .optional()
    .or(z.literal("")),
});

describe("Onboarding validation schemas", () => {
  it("validates organization name correctly", () => {
    expect(orgSchema.safeParse({ name: "Acme Labs" }).success).toBe(true);
    expect(orgSchema.safeParse({ name: "A" }).success).toBe(false);
  });

  it("validates project and app setup parameters", () => {
    const valid = appSetupSchema.safeParse({
      projectName: "Main",
      appName: "bloom_flutter_app",
      repositoryUrl: "https://github.com/acme/app",
    });
    expect(valid.success).toBe(true);

    const invalidSlug = appSetupSchema.safeParse({
      projectName: "Main",
      appName: "invalid slug with spaces",
      repositoryUrl: "",
    });
    expect(invalidSlug.success).toBe(false);
  });
});
