import { http, HttpResponse } from "msw";

// Example handlers demonstrating the pattern — cloud-dashboard-frontend.md §6.5.
// Intercepted at the BFF path (what the client actually requests, §6.6/lib/api/client.ts),
// not the backend origin — MSW never sees the proxy hop, it just short-circuits the fetch.
// Add one handler per endpoint as each screen is built; shape responses exactly per
// the route inventory (§21.1) and envelopes (§21.2) so mocked and real data are interchangeable.
const API = "/api/bff";

export const handlers = [
  http.get(`${API}/auth/me`, () => {
    return HttpResponse.json({
      id: "00000000-0000-0000-0000-000000000001",
      email: "dev@bloom.dev",
      username: "dev",
      display_name: "Dev User",
      avatar_url: null,
      timezone: "UTC",
    });
  }),

  http.post(`${API}/auth/login`, () => {
    return HttpResponse.json({
      access_token: "mock-access-token",
      refresh_token: "mock-refresh-token",
      token_type: "Bearer",
      expires_in: 3600,
    });
  }),

  http.post(`${API}/auth/register`, async ({ request }) => {
    const body = (await request.json()) as { email?: string; username?: string };
    return HttpResponse.json(
      {
        id: "00000000-0000-0000-0000-000000000001",
        email: body.email ?? "dev@bloom.dev",
        username: body.username ?? "dev",
        display_name: null,
        avatar_url: null,
        timezone: "UTC",
      },
      { status: 201 },
    );
  }),

  http.post(`${API}/organizations`, async ({ request }) => {
    const body = (await request.json()) as { name?: string };
    const name = body.name || "My Organization";
    const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
    return HttpResponse.json(
      {
        id: "00000000-0000-0000-0000-000000000010",
        name,
        slug,
        plan: "free",
        role: "Owner",
        created_at: new Date().toISOString(),
      },
      { status: 201 },
    );
  }),

  http.post(`${API}/projects`, async ({ request }) => {
    const body = (await request.json()) as { name?: string; description?: string };
    const name = body.name || "Default Project";
    const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
    return HttpResponse.json(
      {
        id: "00000000-0000-0000-0000-000000000020",
        organization_id: "00000000-0000-0000-0000-000000000010",
        name,
        slug,
        description: body.description ?? null,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      },
      { status: 201 },
    );
  }),

  http.post(`${API}/apps`, async ({ request }) => {
    const body = (await request.json()) as {
      project_id: string;
      name: string;
      repository_url?: string;
      default_branch?: string;
    };
    const slug = (body.name || "my-app").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
    return HttpResponse.json(
      {
        id: "00000000-0000-0000-0000-000000000030",
        project_id: body.project_id,
        organization_id: "00000000-0000-0000-0000-000000000010",
        name: body.name,
        slug,
        repository_url: body.repository_url ?? null,
        default_branch: body.default_branch ?? "main",
        created_at: new Date().toISOString(),
      },
      { status: 201 },
    );
  }),
];
