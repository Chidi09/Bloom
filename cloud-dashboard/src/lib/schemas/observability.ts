import { z } from "zod";

export const platformHealthSchema = z.object({
  platform: z.string(),
  target: z.string(),
  crash_free_rate: z.number().nullable().optional(),
  sessions: z.number().nullable().optional(),
  crashes: z.number().nullable().optional(),
  status: z.enum(["healthy", "warning", "degraded", "unknown"]),
});
export type PlatformHealth = z.infer<typeof platformHealthSchema>;

export const releaseHealthResponseSchema = z.object({
  release_id: z.string(),
  overall_crash_free_rate: z.number().nullable().optional(),
  platforms: z.array(platformHealthSchema),
});
export type ReleaseHealthResponse = z.infer<typeof releaseHealthResponseSchema>;

export const environmentStatusSchema = z.object({
  environment: z.string(),
  platform: z.string(),
  release_id: z.string().nullable().optional(),
  version: z.string().nullable().optional(),
  build_number: z.number().nullable().optional(),
  status: z.string(),
  crash_free_rate: z.number().nullable().optional(),
});
export type EnvironmentStatus = z.infer<typeof environmentStatusSchema>;

export const appStatusResponseSchema = z.object({
  app_id: z.string(),
  environments: z.array(environmentStatusSchema),
});
export type AppStatusResponse = z.infer<typeof appStatusResponseSchema>;
