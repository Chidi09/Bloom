import { z } from "zod";

// cloud-dashboard-frontend.md §21.2 — the two list envelopes every endpoint uses.

export function pageEnvelope<T extends z.ZodTypeAny>(item: T) {
  return z.object({
    count: z.number(),
    page: z.number(),
    total_pages: z.number(),
    results: z.array(item),
  });
}

export function cursorEnvelope<T extends z.ZodTypeAny>(item: T) {
  return z.object({
    count: z.null(),
    results: z.array(item),
    next_cursor: z.string().nullable(),
    previous_cursor: z.string().nullable(),
  });
}

export type PageEnvelope<T> = {
  count: number;
  page: number;
  total_pages: number;
  results: T[];
};

export type CursorEnvelope<T> = {
  count: null;
  results: T[];
  next_cursor: string | null;
  previous_cursor: string | null;
};
