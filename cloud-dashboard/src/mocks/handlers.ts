import { http, HttpResponse } from "msw";
import { mockStore } from "@/lib/mock-store";

// Example handlers demonstrating the pattern — cloud-dashboard-frontend.md §6.5.
// Intercepted at the BFF path (what the client actually requests, §6.6/lib/api/client.ts),
// not the backend origin — MSW never sees the proxy hop, it just short-circuits the fetch.
// Add one handler per endpoint as each screen is built; shape responses exactly per
// the route inventory (§21.1) and envelopes (§21.2) so mocked and real data are interchangeable.
const API = "/api/bff";

export const handlers = [
  // Auth
  http.get(`${API}/auth/me`, () => {
    return HttpResponse.json(mockStore.currentUser);
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
    const body = (await request.json()) as {
      email?: string;
      username?: string;
    };
    const user = mockStore.registerUser(
      body.email ?? "dev@bloom.dev",
      body.username ?? "dev",
    );
    return HttpResponse.json(user, { status: 201 });
  }),

  http.post(`${API}/auth/refresh`, () => {
    return HttpResponse.json({
      access_token: "mock-access-token",
      refresh_token: "mock-refresh-token",
      token_type: "Bearer",
      expires_in: 3600,
    });
  }),

  http.post(`${API}/auth/logout`, () => {
    return HttpResponse.json({ message: "Logged out successfully" });
  }),

  // Organizations
  http.get(`${API}/organizations`, () => {
    return HttpResponse.json({
      count: mockStore.organizations.length,
      page: 1,
      total_pages: 1,
      results: mockStore.organizations,
    });
  }),

  http.post(`${API}/organizations`, async ({ request }) => {
    const body = (await request.json()) as { name?: string };
    const org = mockStore.createOrganization(body.name || "My Organization");
    return HttpResponse.json(org, { status: 201 });
  }),

  http.get(`${API}/organizations/current`, ({ request }) => {
    const orgHeaderId = request.headers.get("x-bloom-organization-id");
    const org =
      mockStore.organizations.find((o) => o.id === orgHeaderId) ||
      mockStore.organizations[0];
    if (!org)
      return HttpResponse.json(
        { error: { status: 404, message: "Organization not found" } },
        { status: 404 },
      );
    return HttpResponse.json(org);
  }),

  http.get(`${API}/organizations/:id`, ({ params }) => {
    const id = params.id as string;
    const org = mockStore.getOrganization(id);
    if (!org)
      return HttpResponse.json(
        { error: { status: 404, message: "Organization not found" } },
        { status: 404 },
      );
    return HttpResponse.json(org);
  }),

  http.patch(`${API}/organizations/:id`, async ({ params, request }) => {
    const id = params.id as string;
    const body = (await request.json()) as {
      name?: string;
      billing_email?: string;
    };
    const updated = mockStore.updateOrganization(id, body);
    if (!updated)
      return HttpResponse.json(
        { error: { status: 404, message: "Organization not found" } },
        { status: 404 },
      );
    return HttpResponse.json(updated);
  }),

  http.delete(`${API}/organizations/:id`, ({ params }) => {
    const id = params.id as string;
    const success = mockStore.deleteOrganization(id);
    if (!success)
      return HttpResponse.json(
        { error: { status: 404, message: "Organization not found" } },
        { status: 404 },
      );
    return new HttpResponse(null, { status: 204 });
  }),

  http.get(`${API}/organizations/:id/members`, ({ params }) => {
    const orgId = params.id as string;
    const members = mockStore.getMembers(orgId);
    return HttpResponse.json({
      count: members.length,
      page: 1,
      total_pages: 1,
      results: members,
    });
  }),

  http.post(`${API}/organizations/:id/members`, async ({ params, request }) => {
    const orgId = params.id as string;
    const body = (await request.json()) as { email?: string; role?: string };
    const mem = mockStore.inviteMember(
      orgId,
      body.email || "dev@bloom.dev",
      body.role || "Developer",
    );
    return HttpResponse.json(mem, { status: 201 });
  }),

  http.patch(
    `${API}/organizations/:id/members/:memberId`,
    async ({ params, request }) => {
      const orgId = params.id as string;
      const memberId = params.memberId as string;
      const body = (await request.json()) as { role?: string };
      const updated = mockStore.changeMemberRole(
        orgId,
        memberId,
        body.role || "Developer",
      );
      if (!updated)
        return HttpResponse.json(
          { error: { status: 404, message: "Member not found" } },
          { status: 404 },
        );
      return HttpResponse.json(updated);
    },
  ),

  http.delete(`${API}/organizations/:id/members/:memberId`, ({ params }) => {
    const orgId = params.id as string;
    const memberId = params.memberId as string;
    const success = mockStore.removeMember(orgId, memberId);
    if (!success)
      return HttpResponse.json(
        { error: { status: 404, message: "Member not found" } },
        { status: 404 },
      );
    return new HttpResponse(null, { status: 204 });
  }),

  // Projects
  http.get(`${API}/projects`, () => {
    return HttpResponse.json({
      count: mockStore.projects.length,
      page: 1,
      total_pages: 1,
      results: mockStore.projects,
    });
  }),

  http.post(`${API}/projects`, async ({ request }) => {
    const body = (await request.json()) as {
      name?: string;
      description?: string;
    };
    const orgHeaderId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const prj = mockStore.createProject(
      orgHeaderId,
      body.name || "Main",
      body.description,
    );
    return HttpResponse.json(prj, { status: 201 });
  }),

  http.get(`${API}/projects/:id`, ({ params }) => {
    const id = params.id as string;
    const prj = mockStore.getProject(id);
    if (!prj)
      return HttpResponse.json(
        { error: { status: 404, message: "Project not found" } },
        { status: 404 },
      );
    return HttpResponse.json(prj);
  }),

  http.patch(`${API}/projects/:id`, async ({ params, request }) => {
    const id = params.id as string;
    const body = (await request.json()) as {
      name?: string;
      description?: string;
    };
    const updated = mockStore.updateProject(id, body);
    if (!updated)
      return HttpResponse.json(
        { error: { status: 404, message: "Project not found" } },
        { status: 404 },
      );
    return HttpResponse.json(updated);
  }),

  http.delete(`${API}/projects/:id`, ({ params }) => {
    const id = params.id as string;
    const success = mockStore.deleteProject(id);
    if (!success)
      return HttpResponse.json(
        { error: { status: 404, message: "Project not found" } },
        { status: 404 },
      );
    return new HttpResponse(null, { status: 204 });
  }),

  // Apps
  http.get(`${API}/apps`, ({ request }) => {
    const url = new URL(request.url);
    const projectId = url.searchParams.get("project_id");
    const results = projectId
      ? mockStore.apps.filter((a) => a.project_id === projectId)
      : mockStore.apps;
    return HttpResponse.json({
      count: results.length,
      page: 1,
      total_pages: 1,
      results,
    });
  }),

  http.post(`${API}/apps`, async ({ request }) => {
    const body = (await request.json()) as {
      project_id: string;
      name: string;
      repository_url?: string;
      default_branch?: string;
    };
    const orgHeaderId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const prjId = body.project_id || mockStore.projects[0]?.id || "default";
    const app = mockStore.createApp(
      prjId,
      orgHeaderId,
      body.name || "my_bloom_app",
      body.repository_url,
      body.default_branch || "main",
    );
    return HttpResponse.json(app, { status: 201 });
  }),

  http.post(`${API}/apps/link`, async ({ request }) => {
    const body = (await request.json()) as {
      project_slug?: string;
      app_slug?: string;
    };
    const linked = mockStore.linkApp(
      body.project_slug || "mobile-suite",
      body.app_slug || "linked-app",
    );
    return HttpResponse.json(linked, { status: 201 });
  }),

  http.get(`${API}/apps/:id`, ({ params }) => {
    const id = params.id as string;
    const app = mockStore.getApp(id);
    if (!app)
      return HttpResponse.json(
        { error: { status: 404, message: "App not found" } },
        { status: 404 },
      );
    return HttpResponse.json(app);
  }),

  http.patch(`${API}/apps/:id`, async ({ params, request }) => {
    const id = params.id as string;
    const body = (await request.json()) as {
      name?: string;
      repository_url?: string | null;
      default_branch?: string;
    };
    const updated = mockStore.updateApp(id, body);
    if (!updated)
      return HttpResponse.json(
        { error: { status: 404, message: "App not found" } },
        { status: 404 },
      );
    return HttpResponse.json(updated);
  }),

  http.delete(`${API}/apps/:id`, ({ params }) => {
    const id = params.id as string;
    const success = mockStore.deleteApp(id);
    if (!success)
      return HttpResponse.json(
        { error: { status: 404, message: "App not found" } },
        { status: 404 },
      );
    return new HttpResponse(null, { status: 204 });
  }),

  // Builds
  http.get(`${API}/builds`, ({ request }) => {
    const url = new URL(request.url);
    const appId = url.searchParams.get("app_id");
    const results = appId
      ? mockStore.builds.filter((b) => b.app_id === appId)
      : mockStore.builds;
    return HttpResponse.json({
      count: results.length,
      page: 1,
      total_pages: 1,
      results,
    });
  }),

  http.post(`${API}/builds`, async ({ request }) => {
    const body = (await request.json()) as {
      app_id?: string;
      environment_id?: string;
      platform?: string;
      git_branch?: string;
      git_commit?: string;
    };
    const appId = body.app_id || mockStore.apps[0]?.id || "app_1";
    const newBuild = mockStore.createBuild(
      appId,
      body.environment_id || "",
      body.platform || "all",
      body.git_branch,
      body.git_commit,
    );
    return HttpResponse.json(newBuild, { status: 201 });
  }),

  http.get(`${API}/builds/:id`, ({ params }) => {
    const id = params.id as string;
    const b = mockStore.getBuild(id);
    if (!b)
      return HttpResponse.json(
        { error: { status: 404, message: "Build not found" } },
        { status: 404 },
      );
    return HttpResponse.json(b);
  }),

  http.post(`${API}/builds/:id/cancel`, ({ params }) => {
    const id = params.id as string;
    const cancelled = mockStore.cancelBuild(id);
    if (!cancelled)
      return HttpResponse.json(
        { error: { status: 404, message: "Build not found" } },
        { status: 404 },
      );
    return HttpResponse.json(cancelled);
  }),

  http.get(`${API}/builds/:id/logs`, ({ params }) => {
    const id = params.id as string;
    return HttpResponse.json({
      url: `https://storage.bloom.dev/logs/builds/${id}.log`,
      expires_in_secs: 3600,
    });
  }),

  // Environments
  http.get(`${API}/environments`, ({ request }) => {
    const url = new URL(request.url);
    const appId = url.searchParams.get("app_id");
    const results = appId
      ? mockStore.environments.filter((e) => e.app_id === appId)
      : mockStore.environments;
    return HttpResponse.json({
      count: results.length,
      page: 1,
      total_pages: 1,
      results,
    });
  }),

  http.post(`${API}/environments`, async ({ request }) => {
    const body = (await request.json()) as {
      app_id?: string;
      name?: string;
      slug?: string;
      build_profile?: string;
    };
    const orgHeaderId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const env = mockStore.createEnvironment(
      body.app_id || mockStore.apps[0]?.id || "default",
      orgHeaderId,
      body.name || "Production",
      body.slug || "production",
      body.build_profile || "release",
    );
    return HttpResponse.json(env, { status: 201 });
  }),

  http.get(`${API}/environments/:id`, ({ params }) => {
    const id = params.id as string;
    const env = mockStore.environments.find((e) => e.id === id);
    if (!env)
      return HttpResponse.json(
        { error: { status: 404, message: "Environment not found" } },
        { status: 404 },
      );
    return HttpResponse.json(env);
  }),

  // Billing
  http.get(`${API}/billing/usage`, () => {
    return HttpResponse.json({
      organization_id: mockStore.usage.organization_id,
      plan_name: mockStore.usage.plan_name,
      current_period_start: mockStore.usage.current_period_start,
      current_period_end: mockStore.usage.current_period_end,
      build_minutes_used: mockStore.usage.build_minutes_used,
      build_minutes_limit: mockStore.usage.build_minutes_limit,
      artifact_storage_gb_used: mockStore.usage.artifact_storage_gb_used,
      artifact_storage_gb_limit: mockStore.usage.artifact_storage_gb_limit,
      web_bandwidth_gb_used: mockStore.usage.web_bandwidth_gb_used,
      web_bandwidth_gb_limit: mockStore.usage.web_bandwidth_gb_limit,
      deploy_count: mockStore.usage.deploy_count,
    });
  }),
];
