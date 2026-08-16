import { z } from "zod";

// Wire error envelope — cloud-dashboard-frontend.md §21.2.
// `details` is omitted (not null) when absent, so it must stay optional.
export const apiErrorSchema = z.object({
  error: z.object({
    status: z.number(),
    code: z.string(),
    message: z.string(),
    details: z.record(z.string(), z.array(z.string())).optional(),
  }),
});

export type ApiErrorBody = z.infer<typeof apiErrorSchema>;

export class ApiError extends Error {
  readonly status: number;
  readonly code: string;
  readonly details?: Record<string, string[]>;

  constructor(body: ApiErrorBody) {
    super(body.error.message);
    this.name = "ApiError";
    this.status = body.error.status;
    this.code = body.error.code;
    this.details = body.error.details;
  }
}
