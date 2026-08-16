import { useAuthStore } from "@/stores/auth-store";
import { useOrganizationStore } from "@/stores/organization-store";
import { ApiError, apiErrorSchema } from "@/lib/api/errors";

// Routed through the same-origin BFF proxy (§6.6), not the backend origin directly —
// see src/app/api/bff/[...path]/route.ts.
const API_BASE = "/api/bff";

let refreshPromise: Promise<void> | null = null;

async function refreshAccessToken(): Promise<void> {
  const refreshToken = useAuthStore.getState().refreshToken;
  if (!refreshToken) {
    useAuthStore
      .getState()
      .setTokens({ accessToken: null, refreshToken: null });
    throw new Error("session expired");
  }

  const res = await fetch(`${API_BASE}/auth/refresh`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refresh_token: refreshToken }),
  });
  if (!res.ok) {
    useAuthStore
      .getState()
      .setTokens({ accessToken: null, refreshToken: null });
    throw new Error("session expired");
  }
  const body = (await res.json()) as {
    access_token: string;
    refresh_token: string;
  };
  useAuthStore.getState().setTokens({
    accessToken: body.access_token,
    refreshToken: body.refresh_token,
  });
}

type ApiOptions = RequestInit & {
  params?: Record<string, string | number | boolean | undefined>;
  /** Skip the automatic X-Bloom-Organization-Id header (org-less endpoints, e.g. auth). */
  skipOrgHeader?: boolean;
};

function buildUrl(path: string, params?: ApiOptions["params"]) {
  // Kept relative (no URL object) so this also works during SSR/server actions, where
  // there is no window origin to resolve a relative URL against.
  const search = new URLSearchParams();
  if (params) {
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined) search.set(key, String(value));
    }
  }
  const query = search.toString();
  return `${API_BASE}${path}${query ? `?${query}` : ""}`;
}

async function request<T>(
  path: string,
  options: ApiOptions = {},
  isRetry = false,
): Promise<T> {
  const { params, skipOrgHeader, headers, ...rest } = options;
  const accessToken = useAuthStore.getState().accessToken;
  const orgId = useOrganizationStore.getState().currentOrganizationId;

  const res = await fetch(buildUrl(path, params), {
    ...rest,
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
      ...(!skipOrgHeader && orgId ? { "X-Bloom-Organization-Id": orgId } : {}),
      ...headers,
    },
  });

  if (res.status === 401 && !isRetry && !skipOrgHeader) {
    refreshPromise ??= refreshAccessToken().finally(() => {
      refreshPromise = null;
    });
    await refreshPromise;
    return request<T>(path, options, true);
  }

  if (!res.ok) {
    const raw: unknown = await res.json().catch(() => null);
    const parsed = apiErrorSchema.safeParse(raw);
    if (parsed.success) throw new ApiError(parsed.data);
    throw new Error(`Request to ${path} failed with status ${res.status}`);
  }

  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}

export const api = {
  get: <T>(path: string, options?: ApiOptions) =>
    request<T>(path, { ...options, method: "GET" }),
  post: <T>(path: string, body?: unknown, options?: ApiOptions) =>
    request<T>(path, {
      ...options,
      method: "POST",
      body: body !== undefined ? JSON.stringify(body) : undefined,
    }),
  patch: <T>(path: string, body?: unknown, options?: ApiOptions) =>
    request<T>(path, {
      ...options,
      method: "PATCH",
      body: body !== undefined ? JSON.stringify(body) : undefined,
    }),
  delete: <T>(path: string, options?: ApiOptions) =>
    request<T>(path, { ...options, method: "DELETE" }),
};
