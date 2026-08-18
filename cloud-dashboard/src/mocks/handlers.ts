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
    const results = mockStore.listBuilds(appId ?? undefined);
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
      flutter_version?: string | null;
      dart_version?: string | null;
      bloom_version?: string | null;
      flavor?: string | null;
      api_config?: {
        env_vars?: { key: string; value: string }[];
        feature_flags?: { key: string; enabled: boolean }[];
      };
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
      body.api_config,
      {
        flutter_version: body.flutter_version,
        dart_version: body.dart_version,
        bloom_version: body.bloom_version,
        flavor: body.flavor,
      },
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

  http.patch(`${API}/environments/:id`, async ({ params, request }) => {
    const id = params.id as string;
    const body = await request.json();
    const updated = mockStore.updateEnvironment(
      id,
      body as Record<string, unknown>,
    );
    if (!updated)
      return HttpResponse.json(
        { error: { status: 404, message: "Environment not found" } },
        { status: 404 },
      );
    return HttpResponse.json(updated);
  }),

  http.delete(`${API}/environments/:id`, ({ params }) => {
    const id = params.id as string;
    const success = mockStore.deleteEnvironment(id);
    if (!success)
      return HttpResponse.json(
        { error: { status: 404, message: "Environment not found" } },
        { status: 404 },
      );
    return new HttpResponse(null, { status: 204 });
  }),

  // Secrets
  http.get(`${API}/secrets`, ({ request }) => {
    const url = new URL(request.url);
    const envId = url.searchParams.get("environment_id");
    const results = envId ? mockStore.getSecrets(envId) : mockStore.secrets;
    // Metadata only representation per contracts
    const safeResults = results.map((s) => ({
      id: s.id,
      environment_id: s.environment_id,
      organization_id: s.organization_id,
      key: s.key,
      is_json: s.is_json,
      version: s.version,
      updated_at: s.updated_at,
    }));
    return HttpResponse.json({
      count: safeResults.length,
      page: 1,
      total_pages: 1,
      results: safeResults,
    });
  }),

  http.post(`${API}/secrets`, async ({ request }) => {
    const body = (await request.json()) as {
      environment_id: string;
      key: string;
      value: string;
      is_json?: boolean;
    };
    const orgHeaderId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const sec = mockStore.createOrUpdateSecret(
      body.environment_id,
      orgHeaderId,
      body.key,
      body.value,
      body.is_json || false,
    );
    return HttpResponse.json(
      {
        id: sec.id,
        environment_id: sec.environment_id,
        organization_id: sec.organization_id,
        key: sec.key,
        is_json: sec.is_json,
        version: sec.version,
        updated_at: sec.updated_at,
      },
      { status: 201 },
    );
  }),

  http.get(`${API}/secrets/:id`, ({ params }) => {
    const id = params.id as string;
    const sec = mockStore.secrets.find((s) => s.id === id);
    if (!sec)
      return HttpResponse.json(
        { error: { status: 404, message: "Secret not found" } },
        { status: 404 },
      );
    return HttpResponse.json({
      id: sec.id,
      environment_id: sec.environment_id,
      organization_id: sec.organization_id,
      key: sec.key,
      is_json: sec.is_json,
      version: sec.version,
      updated_at: sec.updated_at,
    });
  }),

  http.patch(`${API}/secrets/:id`, async ({ params, request }) => {
    const id = params.id as string;
    const body = (await request.json()) as {
      value?: string;
      is_json?: boolean;
    };
    const sec = mockStore.updateSecret(id, body.value, body.is_json);
    if (!sec)
      return HttpResponse.json(
        { error: { status: 404, message: "Secret not found" } },
        { status: 404 },
      );
    return HttpResponse.json({
      id: sec.id,
      environment_id: sec.environment_id,
      organization_id: sec.organization_id,
      key: sec.key,
      is_json: sec.is_json,
      version: sec.version,
      updated_at: sec.updated_at,
    });
  }),

  http.post(`${API}/secrets/:id/rollback`, async ({ params, request }) => {
    const id = params.id as string;
    const body = (await request.json()) as { version: number };
    const sec = mockStore.rollbackSecret(id, body.version);
    if (!sec)
      return HttpResponse.json(
        { error: { status: 404, message: "Secret not found" } },
        { status: 404 },
      );
    return HttpResponse.json({
      id: sec.id,
      environment_id: sec.environment_id,
      organization_id: sec.organization_id,
      key: sec.key,
      is_json: sec.is_json,
      version: sec.version,
      updated_at: sec.updated_at,
    });
  }),

  http.delete(`${API}/secrets/:id`, ({ params }) => {
    const id = params.id as string;
    const success = mockStore.deleteSecret(id);
    if (!success)
      return HttpResponse.json(
        { error: { status: 404, message: "Secret not found" } },
        { status: 404 },
      );
    return new HttpResponse(null, { status: 204 });
  }),

  // Signing
  http.get(`${API}/signing`, ({ request }) => {
    const orgHeaderId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const results = mockStore.getSigningIdentities(orgHeaderId);
    return HttpResponse.json({
      count: results.length,
      page: 1,
      total_pages: 1,
      results,
    });
  }),

  http.post(`${API}/signing`, async ({ request }) => {
    const body = (await request.json()) as {
      platform: "android" | "ios";
      name: string;
      kind: "keystore" | "certificate" | "provisioning_profile" | "api_key";
      material: string;
      metadata: Record<string, unknown>;
      expires_at?: string | null;
    };
    const orgHeaderId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const identity = mockStore.createSigningIdentity(
      orgHeaderId,
      body.platform,
      body.name,
      body.kind,
      body.material,
      body.metadata,
      body.expires_at,
    );
    return HttpResponse.json(identity, { status: 201 });
  }),

  http.get(`${API}/signing/:id`, ({ params }) => {
    const id = params.id as string;
    const identity = mockStore.getSigningIdentity(id);
    if (!identity)
      return HttpResponse.json(
        { error: { status: 404, message: "Signing identity not found" } },
        { status: 404 },
      );
    return HttpResponse.json(identity);
  }),

  http.delete(`${API}/signing/:id`, ({ params }) => {
    const id = params.id as string;
    const success = mockStore.deleteSigningIdentity(id);
    if (!success)
      return HttpResponse.json(
        { error: { status: 404, message: "Signing identity not found" } },
        { status: 404 },
      );
    return new HttpResponse(null, { status: 204 });
  }),

  // Releases
  http.get(`${API}/releases`, ({ request }) => {
    const url = new URL(request.url);
    const appId = url.searchParams.get("app_id");
    const results = appId ? mockStore.getReleases(appId) : mockStore.releases;
    return HttpResponse.json({
      count: results.length,
      page: 1,
      total_pages: 1,
      results,
    });
  }),

  http.post(`${API}/releases`, async ({ request }) => {
    const body = (await request.json()) as {
      app_id: string;
      version: string;
      build_number: number;
      commit: string;
      changelog?: string;
      environment_id?: string | null;
      platforms?: string[];
      artifact_ids?: string[];
    };
    const orgHeaderId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const rel = mockStore.createRelease(
      body.app_id,
      orgHeaderId,
      body.version,
      body.build_number,
      body.commit,
      body.changelog || "",
      body.environment_id,
      body.platforms || ["ios", "android", "web"],
      body.artifact_ids || [],
    );
    return HttpResponse.json(rel, { status: 201 });
  }),

  http.get(`${API}/releases/:id`, ({ params }) => {
    const id = params.id as string;
    const rel = mockStore.getRelease(id);
    if (!rel)
      return HttpResponse.json(
        { error: { status: 404, message: "Release not found" } },
        { status: 404 },
      );
    return HttpResponse.json(rel);
  }),

  http.patch(`${API}/releases/:id`, async ({ params, request }) => {
    const id = params.id as string;
    const body = (await request.json()) as {
      changelog?: string;
      rollout_status?: Record<string, unknown>;
      status?: string;
    };
    const updated = mockStore.updateRelease(id, body);
    if (!updated)
      return HttpResponse.json(
        { error: { status: 404, message: "Release not found" } },
        { status: 404 },
      );
    return HttpResponse.json(updated);
  }),

  http.post(`${API}/releases/:id/approve`, async ({ params, request }) => {
    const id = params.id as string;
    const body = (await request.json()) as {
      approved: boolean;
      reason?: string;
    };
    const updated = mockStore.approveRelease(id, body.approved, body.reason);
    if (!updated)
      return HttpResponse.json(
        { error: { status: 404, message: "Release not found" } },
        { status: 404 },
      );
    return HttpResponse.json(updated);
  }),

  http.post(`${API}/releases/:id/rollback`, async ({ params, request }) => {
    const id = params.id as string;
    let reason: string | undefined;
    try {
      const body = (await request.json()) as { reason?: string };
      reason = body.reason;
    } catch {
      // optional body
    }
    const updated = mockStore.rollbackRelease(id, reason);
    if (!updated)
      return HttpResponse.json(
        { error: { status: 404, message: "Release not found" } },
        { status: 404 },
      );
    return HttpResponse.json(updated);
  }),

  // Deployments
  http.get(`${API}/deployments`, ({ request }) => {
    const url = new URL(request.url);
    const appId = url.searchParams.get("app_id") ?? undefined;
    const envId = url.searchParams.get("environment_id") ?? undefined;
    const relId = url.searchParams.get("release_id") ?? undefined;
    const results = mockStore.getDeployments(appId, envId, relId);
    return HttpResponse.json({
      count: results.length,
      page: 1,
      total_pages: 1,
      results,
    });
  }),

  http.post(`${API}/deployments`, async ({ request }) => {
    const body = (await request.json()) as {
      environment_id: string;
      platform: "ios" | "android" | "web";
      target: string;
      release_id?: string | null;
      artifact_id?: string | null;
    };
    const orgHeaderId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const dep = mockStore.createDeployment(
      orgHeaderId,
      body.environment_id,
      body.platform,
      body.target,
      body.release_id,
      body.artifact_id,
    );
    return HttpResponse.json(dep, { status: 201 });
  }),

  http.get(`${API}/deployments/:id`, ({ params }) => {
    const id = params.id as string;
    const dep = mockStore.getDeployment(id);
    if (!dep)
      return HttpResponse.json(
        { error: { status: 404, message: "Deployment not found" } },
        { status: 404 },
      );
    return HttpResponse.json(dep);
  }),

  http.post(`${API}/deployments/:id/rollback`, ({ params }) => {
    const id = params.id as string;
    const rolled = mockStore.rollbackDeployment(id);
    if (!rolled)
      return HttpResponse.json(
        { error: { status: 404, message: "Deployment not found" } },
        { status: 404 },
      );
    return HttpResponse.json(rolled);
  }),

  // Account & API Tokens
  http.patch(`${API}/auth/me`, async ({ request }) => {
    const body = (await request.json()) as {
      display_name?: string;
      avatar_url?: string | null;
      timezone?: string;
    };
    const user = mockStore.updateUserProfile(body);
    return HttpResponse.json(user);
  }),

  http.get(`${API}/auth/tokens`, () => {
    const tokens = mockStore.getApiTokens();
    return HttpResponse.json({
      count: tokens.length,
      page: 1,
      total_pages: 1,
      results: tokens,
    });
  }),

  http.post(`${API}/auth/token`, async ({ request }) => {
    const body = (await request.json()) as {
      name?: string;
      scopes?: string[];
      expires_in_days?: number | null;
      organization_id?: string | null;
    };
    const { tokenRecord, rawToken } = mockStore.createApiToken(
      body.name || "API Token",
      body.scopes,
      body.expires_in_days,
      body.organization_id,
    );
    return HttpResponse.json(
      {
        id: tokenRecord.id,
        name: tokenRecord.name,
        token: rawToken,
        scopes: tokenRecord.scopes || ["*"],
        expires_at: tokenRecord.expires_at || null,
        organization_id: tokenRecord.organization_id || null,
        created_at: tokenRecord.created_at,
        last_used_at: null,
      },
      { status: 201 },
    );
  }),

  http.delete(`${API}/auth/token/:id`, ({ params }) => {
    const id = params.id as string;
    const success = mockStore.revokeApiToken(id);
    if (!success)
      return HttpResponse.json(
        { error: { status: 404, message: "Token not found" } },
        { status: 404 },
      );
    return new HttpResponse(null, { status: 204 });
  }),

  http.post(`${API}/auth/change-password`, async () => {
    return HttpResponse.json({ message: "Password updated successfully" });
  }),

  // Web Hosting
  http.get(`${API}/webhosting/deployments`, ({ request }) => {
    const url = new URL(request.url);
    const appId = url.searchParams.get("app_id") ?? undefined;
    const list = mockStore.getWebDeployments(appId);
    return HttpResponse.json({
      count: list.length,
      page: 1,
      total_pages: 1,
      results: list,
    });
  }),

  http.post(`${API}/webhosting/deployments`, async ({ request }) => {
    const body = (await request.json()) as {
      app_id: string;
      environment_id: string;
      artifact_id: string;
      target?: "preview" | "production";
      release_id?: string | null;
      git_branch?: string;
    };
    const dep = mockStore.createWebDeployment(
      body.app_id,
      body.environment_id,
      body.artifact_id || "art_web_001",
      body.target || "preview",
      body.release_id,
      body.git_branch,
    );
    return HttpResponse.json(dep, { status: 201 });
  }),

  http.get(`${API}/webhosting/deployments/:id`, ({ params }) => {
    const id = params.id as string;
    const dep = mockStore.getWebDeployment(id);
    if (!dep)
      return HttpResponse.json(
        { error: { status: 404, message: "Web deployment not found" } },
        { status: 404 },
      );
    return HttpResponse.json(dep);
  }),

  http.post(`${API}/webhosting/deployments/:id/rollback`, ({ params }) => {
    const id = params.id as string;
    const dep = mockStore.rollbackWebDeployment(id);
    if (!dep)
      return HttpResponse.json(
        { error: { status: 404, message: "Web deployment not found" } },
        { status: 404 },
      );
    return HttpResponse.json(dep);
  }),

  http.get(`${API}/webhosting/domains`, ({ request }) => {
    const url = new URL(request.url);
    const appId = url.searchParams.get("app_id") ?? undefined;
    const domains = mockStore.getCustomDomains(appId);
    return HttpResponse.json({
      count: domains.length,
      page: 1,
      total_pages: 1,
      results: domains,
    });
  }),

  http.post(`${API}/webhosting/domains`, async ({ request }) => {
    const body = (await request.json()) as { app_id: string; domain: string };
    const created = mockStore.createCustomDomain(body.app_id, body.domain);
    return HttpResponse.json(created, { status: 201 });
  }),

  http.get(`${API}/webhosting/domains/:id`, ({ params }) => {
    const id = params.id as string;
    const domain = mockStore.getCustomDomain(id);
    if (!domain)
      return HttpResponse.json(
        { error: { status: 404, message: "Domain not found" } },
        { status: 404 },
      );
    return HttpResponse.json(domain);
  }),

  http.post(`${API}/webhosting/domains/:id/verify`, ({ params }) => {
    const id = params.id as string;
    const verified = mockStore.verifyCustomDomain(id);
    if (!verified)
      return HttpResponse.json(
        { error: { status: 404, message: "Domain not found" } },
        { status: 404 },
      );
    return HttpResponse.json(verified);
  }),

  http.delete(`${API}/webhosting/domains/:id`, ({ params }) => {
    const id = params.id as string;
    const success = mockStore.deleteCustomDomain(id);
    if (!success)
      return HttpResponse.json(
        { error: { status: 404, message: "Domain not found" } },
        { status: 404 },
      );
    return new HttpResponse(null, { status: 204 });
  }),

  // Observability
  http.get(`${API}/observability/apps/:id/status`, ({ params }) => {
    const id = params.id as string;
    const status = mockStore.getAppStatus(id);
    return HttpResponse.json(status);
  }),

  http.get(`${API}/observability/apps/:id/health`, ({ params }) => {
    const id = params.id as string;
    const health = mockStore.getAppHealth(id);
    return HttpResponse.json(health);
  }),

  http.get(`${API}/observability/releases/:id/health`, ({ params }) => {
    const id = params.id as string;
    const health = mockStore.getReleaseHealth(id);
    return HttpResponse.json(health);
  }),

  // Credentials
  http.get(`${API}/credentials`, ({ request }) => {
    const orgHeaderId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const creds = mockStore.getCredentials(orgHeaderId);
    return HttpResponse.json({
      count: creds.length,
      page: 1,
      total_pages: 1,
      results: creds,
    });
  }),

  http.post(`${API}/credentials`, async ({ request }) => {
    const body = (await request.json()) as {
      provider:
        | "apple"
        | "google_play"
        | "shorebird"
        | "github"
        | "gitlab"
        | "bitbucket";
      name: string;
      metadata: Record<string, unknown>;
      expires_at?: string | null;
    };
    const orgHeaderId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const cred = mockStore.createCredential(orgHeaderId, body);
    return HttpResponse.json(cred, { status: 201 });
  }),

  http.get(`${API}/credentials/:id`, ({ params }) => {
    const id = params.id as string;
    const cred = mockStore.getCredential(id);
    if (!cred)
      return HttpResponse.json(
        { error: { status: 404, message: "Credential not found" } },
        { status: 404 },
      );
    return HttpResponse.json(cred);
  }),

  http.post(`${API}/credentials/:id/test`, ({ params }) => {
    const id = params.id as string;
    const res = mockStore.testCredential(id);
    return HttpResponse.json({
      id,
      provider: res.provider,
      success: res.success,
      message: res.message,
    });
  }),

  http.delete(`${API}/credentials/:id`, ({ params }) => {
    const id = params.id as string;
    const success = mockStore.deleteCredential(id);
    if (!success)
      return HttpResponse.json(
        { error: { status: 404, message: "Credential not found" } },
        { status: 404 },
      );
    return new HttpResponse(null, { status: 204 });
  }),

  // Git Connections
  http.get(`${API}/git-connections`, ({ request }) => {
    const orgHeaderId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const connections = mockStore.getGitConnections(orgHeaderId);
    return HttpResponse.json({
      count: connections.length,
      page: 1,
      total_pages: 1,
      results: connections,
    });
  }),

  http.post(`${API}/git-connections`, async ({ request }) => {
    const body = (await request.json()) as {
      provider: "github" | "gitlab" | "bitbucket";
      installation_id: string;
      metadata?: Record<string, unknown>;
    };
    const orgHeaderId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const conn = mockStore.createGitConnection(orgHeaderId, body);
    return HttpResponse.json(conn, { status: 201 });
  }),

  http.get(`${API}/git-connections/:id`, ({ params }) => {
    const id = params.id as string;
    const conn = mockStore.getGitConnection(id);
    if (!conn)
      return HttpResponse.json(
        { error: { status: 404, message: "Git connection not found" } },
        { status: 404 },
      );
    return HttpResponse.json(conn);
  }),

  http.get(`${API}/git-connections/:id/repositories`, ({ params }) => {
    const id = params.id as string;
    const repos = mockStore.getGitRepositories(id);
    return HttpResponse.json({
      count: repos.length,
      page: 1,
      total_pages: 1,
      results: repos,
    });
  }),

  http.delete(`${API}/git-connections/:id`, ({ params, request }) => {
    const path = new URL(request.url).pathname.split("/").filter(Boolean);
    if (request.method === "DELETE" && path.length >= 2) {
      const success = mockStore.deleteGitConnection(params.id as string);
      if (!success) {
        return HttpResponse.json(
          { error: { status: 404, message: "Git connection not found" } },
          { status: 404 },
        );
      }
      return new HttpResponse(null, { status: 204 });
    }
  }),

  // Workflows
  http.get(`${API}/workflows`, ({ request }) => {
    const url = new URL(request.url);
    const appId = url.searchParams.get("app_id") || undefined;
    const orgId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const list = mockStore.getWorkflows(appId, orgId);
    return HttpResponse.json({
      count: list.length,
      page: 1,
      total_pages: 1,
      results: list,
    });
  }),

  http.post(`${API}/workflows`, async ({ request }) => {
    const body = (await request.json()) as {
      app_id?: string;
      name?: string;
      slug?: string;
      description?: string;
      definition?: string;
      is_active?: boolean;
    };
    const orgId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const wf = mockStore.createWorkflow(
      body.app_id || mockStore.apps[0]?.id || "app_001",
      orgId,
      {
        name: body.name || "New Workflow",
        slug: body.slug || "new-workflow",
        description: body.description,
        definition: body.definition || "name: Workflow\njobs: {}",
        is_active: body.is_active ?? true,
      },
    );
    return HttpResponse.json(wf, { status: 201 });
  }),

  http.get(`${API}/workflows/runs/:id`, ({ params }) => {
    const id = params.id as string;
    const run = mockStore.getWorkflowRun(id);
    if (!run) {
      return HttpResponse.json(
        { error: { status: 404, message: "Workflow run not found" } },
        { status: 404 },
      );
    }
    return HttpResponse.json(run);
  }),

  http.post(
    `${API}/workflows/runs/:id/approve`,
    async ({ params, request }) => {
      const id = params.id as string;
      let body: { approved?: boolean; reason?: string } = { approved: true };
      try {
        body = (await request.json()) as typeof body;
      } catch {
        // ignore
      }
      const run = mockStore.approveWorkflowRun(
        id,
        body.approved ?? true,
        body.reason,
      );
      if (!run) {
        return HttpResponse.json(
          { error: { status: 404, message: "Workflow run not found" } },
          { status: 404 },
        );
      }
      return HttpResponse.json(run);
    },
  ),

  http.get(`${API}/workflows/:id/runs`, ({ params }) => {
    const id = params.id as string;
    const runs = mockStore.getWorkflowRuns(id);
    return HttpResponse.json({
      count: runs.length,
      page: 1,
      total_pages: 1,
      results: runs,
    });
  }),

  http.post(`${API}/workflows/:id/runs`, async ({ params, request }) => {
    const id = params.id as string;
    let body: {
      git_commit?: string;
      git_branch?: string;
      git_ref?: string;
      trigger_event?: string;
    } = {};
    try {
      body = (await request.json()) as typeof body;
    } catch {
      // ignore
    }
    const run = mockStore.createWorkflowRun(id, body);
    return HttpResponse.json(run, { status: 201 });
  }),

  http.get(`${API}/workflows/:id`, ({ params }) => {
    const id = params.id as string;
    const wf = mockStore.getWorkflow(id);
    if (!wf) {
      return HttpResponse.json(
        { error: { status: 404, message: "Workflow not found" } },
        { status: 404 },
      );
    }
    return HttpResponse.json(wf);
  }),

  http.patch(`${API}/workflows/:id`, async ({ params, request }) => {
    const id = params.id as string;
    let body: Record<string, unknown> = {};
    try {
      body = (await request.json()) as typeof body;
    } catch {
      // ignore
    }
    const updated = mockStore.updateWorkflow(id, body);
    if (!updated) {
      return HttpResponse.json(
        { error: { status: 404, message: "Workflow not found" } },
        { status: 404 },
      );
    }
    return HttpResponse.json(updated);
  }),

  // Audit Log
  http.get(`${API}/audit-log`, ({ request }) => {
    const url = new URL(request.url);
    const orgId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const action = url.searchParams.get("action") || undefined;
    const actor = url.searchParams.get("actor") || undefined;
    const from = url.searchParams.get("from") || undefined;
    const to = url.searchParams.get("to") || undefined;
    const list = mockStore.getAuditLogs(orgId, { action, actor, from, to });
    return HttpResponse.json({
      count: list.length,
      page: 1,
      total_pages: 1,
      results: list,
    });
  }),

  // Billing
  http.get(`${API}/billing/plans`, () => {
    return HttpResponse.json(mockStore.getBillingPlans());
  }),

  http.get(`${API}/billing/subscription`, ({ request }) => {
    const orgId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    return HttpResponse.json(mockStore.getSubscription(orgId));
  }),

  http.post(`${API}/billing/subscribe`, async ({ request }) => {
    const orgId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    let body: { plan_id?: string; provider?: string; callback_url?: string } =
      {};
    try {
      body = (await request.json()) as typeof body;
    } catch {
      // ignore
    }
    const res = mockStore.subscribe(
      orgId,
      body.plan_id || "pro",
      body.provider,
      body.callback_url,
    );
    return HttpResponse.json(res);
  }),

  http.post(`${API}/billing/cancel`, async ({ request }) => {
    const orgId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    let body: { reason?: string; immediately?: boolean } = {};
    try {
      body = (await request.json()) as typeof body;
    } catch {
      // ignore
    }
    const res = mockStore.cancelSubscription(
      orgId,
      body.reason,
      body.immediately,
    );
    return HttpResponse.json(res);
  }),

  http.get(`${API}/billing/invoices`, ({ request }) => {
    const orgId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    return HttpResponse.json(mockStore.getInvoices(orgId));
  }),

  http.get(`${API}/billing/usage`, ({ request }) => {
    const orgId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    return HttpResponse.json(mockStore.getUsageSummary(orgId));
  }),

  // Marketplace
  http.get(`${API}/marketplace/templates`, ({ request }) => {
    const url = new URL(request.url);
    const q =
      url.searchParams.get("q") || url.searchParams.get("search") || undefined;
    const category = url.searchParams.get("category") || undefined;
    return HttpResponse.json(mockStore.getMarketplaceTemplates(q, category));
  }),

  http.get(`${API}/marketplace/templates/:id`, ({ params }) => {
    const id = params.id as string;
    const tmpl = mockStore.getMarketplaceTemplate(id);
    if (!tmpl) {
      return HttpResponse.json(
        { error: { status: 404, message: "Template not found" } },
        { status: 404 },
      );
    }
    return HttpResponse.json(tmpl);
  }),

  http.get(
    `${API}/marketplace/templates/:id/versions/:versionId`,
    ({ params }) => {
      const id = params.id as string;
      const versionId = params.versionId as string;
      const ver = mockStore.getMarketplaceTemplateVersion(id, versionId);
      if (!ver) {
        return HttpResponse.json(
          { error: { status: 404, message: "Version not found" } },
          { status: 404 },
        );
      }
      return HttpResponse.json(ver);
    },
  ),

  http.post(
    `${API}/marketplace/templates/:id/purchase`,
    async ({ params, request }) => {
      const id = params.id as string;
      const orgId =
        request.headers.get("x-bloom-organization-id") ||
        mockStore.organizations[0]?.id ||
        "";
      let body: { template_version_id?: string; idempotency_key?: string } = {};
      try {
        body = (await request.json()) as typeof body;
      } catch {
        // ignore
      }
      const purch = mockStore.purchaseTemplate(
        orgId,
        id,
        body.template_version_id,
        body.idempotency_key,
      );
      return HttpResponse.json(purch, { status: 201 });
    },
  ),

  http.get(`${API}/marketplace/templates/:id/reviews`, ({ params }) => {
    const id = params.id as string;
    const reviews = mockStore.getTemplateReviews(id);
    return HttpResponse.json({
      count: reviews.length,
      page: 1,
      total_pages: 1,
      results: reviews,
    });
  }),

  http.post(
    `${API}/marketplace/templates/:id/reviews`,
    async ({ params, request }) => {
      const id = params.id as string;
      const orgId =
        request.headers.get("x-bloom-organization-id") ||
        mockStore.organizations[0]?.id ||
        "";
      let body: { rating: number; title?: string; comment?: string } = {
        rating: 5,
      };
      try {
        body = (await request.json()) as typeof body;
      } catch {
        // ignore
      }
      const rev = mockStore.createTemplateReview(id, orgId, body);
      return HttpResponse.json(rev, { status: 201 });
    },
  ),

  http.post(
    `${API}/marketplace/reviews/:id/reply`,
    async ({ params, request }) => {
      const id = params.id as string;
      let body: { response: string } = { response: "" };
      try {
        body = (await request.json()) as typeof body;
      } catch {
        // ignore
      }
      const rev = mockStore.replyTemplateReview(id, body.response);
      if (!rev) {
        return HttpResponse.json(
          { error: { status: 404, message: "Review not found" } },
          { status: 404 },
        );
      }
      return HttpResponse.json(rev);
    },
  ),

  http.post(
    `${API}/marketplace/reviews/:id/report`,
    async ({ params, request }) => {
      const id = params.id as string;
      const orgId =
        request.headers.get("x-bloom-organization-id") ||
        mockStore.organizations[0]?.id ||
        "";
      let body: { reason: string; details?: string } = { reason: "spam" };
      try {
        body = (await request.json()) as typeof body;
      } catch {
        // ignore
      }
      const rep = mockStore.reportTemplateReview(
        id,
        orgId,
        body.reason,
        body.details,
      );
      return HttpResponse.json(rep, { status: 201 });
    },
  ),

  http.get(`${API}/marketplace/purchases`, ({ request }) => {
    const orgId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const url = new URL(request.url);
    const cursor = url.searchParams.get("cursor") || undefined;
    return HttpResponse.json(mockStore.getPurchases(orgId, cursor));
  }),

  http.post(
    `${API}/marketplace/purchases/:id/refund`,
    async ({ params, request }) => {
      const id = params.id as string;
      let body: { reason?: string } = {};
      try {
        body = (await request.json()) as typeof body;
      } catch {
        // ignore
      }
      return HttpResponse.json(mockStore.refundPurchase(id, body.reason));
    },
  ),

  http.get(`${API}/marketplace/seller/account`, ({ request }) => {
    const orgId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const acct = mockStore.getSellerAccount(orgId);
    if (!acct) {
      return HttpResponse.json(
        { error: { status: 404, message: "No seller account found" } },
        { status: 404 },
      );
    }
    return HttpResponse.json(acct);
  }),

  http.post(`${API}/marketplace/seller/onboarding`, async ({ request }) => {
    const orgId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    let body: { refresh_url?: string; return_url?: string } = {};
    try {
      body = (await request.json()) as typeof body;
    } catch {
      // ignore
    }
    const link = mockStore.createSellerOnboarding(
      orgId,
      body.refresh_url || "",
      body.return_url || "",
    );
    return HttpResponse.json(link);
  }),

  http.post(`${API}/marketplace/seller/refresh`, ({ request }) => {
    const orgId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const acct = mockStore.refreshSellerStatus(orgId);
    if (!acct) {
      return HttpResponse.json(
        { error: { status: 404, message: "No seller account found" } },
        { status: 404 },
      );
    }
    return HttpResponse.json(acct);
  }),

  // Templates (Org-scoped)
  http.get(`${API}/templates`, ({ request }) => {
    const orgId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    const results = mockStore.getOrgTemplates(orgId);
    return HttpResponse.json({
      count: results.length,
      page: 1,
      total_pages: 1,
      results,
    });
  }),

  http.post(`${API}/templates`, async ({ request }) => {
    const orgId =
      request.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "";
    let body: Record<string, unknown> = {};
    try {
      body = (await request.json()) as typeof body;
    } catch {
      // ignore
    }
    const created = mockStore.createOrgTemplate(orgId, body);
    return HttpResponse.json(created, { status: 201 });
  }),

  http.get(`${API}/templates/:id`, ({ params }) => {
    const id = params.id as string;
    const tmpl = mockStore.getMarketplaceTemplate(id);
    if (!tmpl) {
      return HttpResponse.json(
        { error: { status: 404, message: "Template not found" } },
        { status: 404 },
      );
    }
    return HttpResponse.json(tmpl);
  }),

  http.patch(`${API}/templates/:id`, async ({ params, request }) => {
    const id = params.id as string;
    let body: Record<string, unknown> = {};
    try {
      body = (await request.json()) as typeof body;
    } catch {
      // ignore
    }
    const updated = mockStore.updateOrgTemplate(id, body);
    if (!updated) {
      return HttpResponse.json(
        { error: { status: 404, message: "Template not found" } },
        { status: 404 },
      );
    }
    return HttpResponse.json(updated);
  }),

  http.post(`${API}/templates/:id/publish`, ({ params }) => {
    const id = params.id as string;
    const published = mockStore.publishOrgTemplate(id);
    if (!published) {
      return HttpResponse.json(
        { error: { status: 404, message: "Template not found" } },
        { status: 404 },
      );
    }
    return HttpResponse.json(published);
  }),

  http.post(`${API}/templates/:id/archive`, ({ params }) => {
    const id = params.id as string;
    const archived = mockStore.archiveOrgTemplate(id);
    if (!archived) {
      return HttpResponse.json(
        { error: { status: 404, message: "Template not found" } },
        { status: 404 },
      );
    }
    return HttpResponse.json(archived);
  }),

  http.get(`${API}/templates/:id/versions`, ({ params }) => {
    const id = params.id as string;
    const versions = mockStore.getTemplateVersions(id);
    return HttpResponse.json({
      count: versions.length,
      page: 1,
      total_pages: 1,
      results: versions,
    });
  }),

  http.post(`${API}/templates/:id/versions`, async ({ params, request }) => {
    const id = params.id as string;
    let body: {
      version: string;
      changelog?: string;
      manifest?: Record<string, unknown>;
      readme?: string;
    } = { version: "1.0.0" };
    try {
      body = (await request.json()) as typeof body;
    } catch {
      // ignore
    }
    const ver = mockStore.createTemplateVersion(id, body);
    return HttpResponse.json(ver, { status: 201 });
  }),
];
