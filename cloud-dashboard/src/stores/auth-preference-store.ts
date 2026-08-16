import { create } from "zustand";
import { persist } from "zustand/middleware";

// Purely a UX hint (which sign-in method to surface as "Last used" / "Most used") —
// never used for authorization decisions, safe to persist to localStorage.
export type AuthMethod = "email" | "google" | "github";

type AuthPreferenceState = {
  lastUsedMethod: AuthMethod | null;
  usageCounts: Partial<Record<AuthMethod, number>>;
  recordAuthMethodUsage: (method: AuthMethod) => void;
};

export const useAuthPreferenceStore = create<AuthPreferenceState>()(
  persist(
    (set, get) => ({
      lastUsedMethod: null,
      usageCounts: {},
      recordAuthMethodUsage: (method) => {
        const counts = get().usageCounts;
        set({
          lastUsedMethod: method,
          usageCounts: { ...counts, [method]: (counts[method] ?? 0) + 1 },
        });
      },
    }),
    { name: "bloom-auth-preference" },
  ),
);

/** Highest-count method, excluding the current last-used method (that gets its own badge). */
export function getMostUsedMethod(
  state: Pick<AuthPreferenceState, "usageCounts" | "lastUsedMethod">,
): AuthMethod | null {
  let best: AuthMethod | null = null;
  let bestCount = 0;
  for (const [method, count] of Object.entries(state.usageCounts) as [
    AuthMethod,
    number,
  ][]) {
    if (method === state.lastUsedMethod) continue;
    if (count > bestCount) {
      best = method;
      bestCount = count;
    }
  }
  return bestCount > 0 ? best : null;
}
