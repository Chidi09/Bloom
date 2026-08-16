import { create } from "zustand";

// Both tokens live in memory only — never persisted (cloud-dashboard-frontend.md §6.3, §5.1).
// The backend returns refresh_token as a plain JSON body field (no Set-Cookie), so it
// must be held here and sent explicitly to /auth/refresh — see src/lib/api/client.ts.
type AuthState = {
  accessToken: string | null;
  refreshToken: string | null;
  setTokens: (tokens: {
    accessToken: string | null;
    refreshToken: string | null;
  }) => void;
  setAccessToken: (token: string | null) => void;
};

export const useAuthStore = create<AuthState>((set) => ({
  accessToken: null,
  refreshToken: null,
  setTokens: ({ accessToken, refreshToken }) =>
    set({ accessToken, refreshToken }),
  setAccessToken: (accessToken) => set({ accessToken }),
}));
