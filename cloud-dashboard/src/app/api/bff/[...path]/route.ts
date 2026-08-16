import { NextRequest, NextResponse } from "next/server";
import { mockStore } from "@/lib/mock-store";

// BFF proxy — cloud-dashboard-frontend.md §6.6.
// The backend issues bearer tokens in the JSON body (no Set-Cookie), so this proxy's
// value here is same-origin request routing: it keeps the backend origin out of
// client-side network calls/CSP and avoids CORS entirely, not cookie handling.
const BACKEND_ORIGIN = process.env.NEXT_PUBLIC_API_URL;

async function proxy(req: NextRequest, path: string[]) {
  if (!BACKEND_ORIGIN) {
    return NextResponse.json(
      {
        error: {
          status: 500,
          code: "misconfigured",
          message: "NEXT_PUBLIC_API_URL is not set",
        },
      },
      { status: 500 },
    );
  }

  const target = new URL(`${BACKEND_ORIGIN}/api/v1/${path.join("/")}`);
  target.search = req.nextUrl.search;

  const headers = new Headers(req.headers);
  headers.delete("host");
  headers.delete("connection");
  headers.delete("content-length");

  const hasBody = !["GET", "HEAD"].includes(req.method);

  let backendRes: Response;
  try {
    backendRes = await fetch(target, {
      method: req.method,
      headers,
      body: hasBody ? await req.text() : undefined,
      redirect: "manual",
    });
  } catch (_err: unknown) {
    // In production, never return mock data — return real upstream gateway error
    if (process.env.NODE_ENV === "production") {
      return NextResponse.json(
        {
          error: {
            status: 502,
            code: "bad_gateway",
            message: "Backend service unreachable",
          },
        },
        { status: 502 },
      );
    }
    return handleMockFallback(req, path);
  }

  // Forward Set-Cookie as-is — the browser sees it as first-party since this response
  // comes from the dashboard's own origin, not the backend's.
  const responseHeaders = new Headers(backendRes.headers);
  return new NextResponse(backendRes.body, {
    status: backendRes.status,
    headers: responseHeaders,
  });
}

async function handleMockFallback(req: NextRequest, path: string[]) {
  const p = path.join("/");
  const orgHeaderId =
    req.headers.get("x-bloom-organization-id") ||
    mockStore.organizations[0]?.id ||
    "";

  // Auth endpoints
  if (req.method === "POST" && p === "auth/register") {
    let body: { email?: string; username?: string } = {};
    try {
      body = await req.json();
    } catch {
      // ignore
    }
    const email = body.email || "dev@bloom.dev";
    const username = body.username || email.split("@")[0] || "dev";
    const user = mockStore.registerUser(email, username);
    return NextResponse.json(user, { status: 201 });
  }

  if (req.method === "POST" && p === "auth/login") {
    return NextResponse.json({
      access_token: "mock-access-token",
      refresh_token: "mock-refresh-token",
      token_type: "Bearer",
      expires_in: 3600,
    });
  }

  if (req.method === "GET" && p === "auth/me") {
    return NextResponse.json(mockStore.currentUser);
  }

  if (req.method === "POST" && p === "auth/logout") {
    return NextResponse.json({ message: "Logged out successfully" });
  }

  if (req.method === "POST" && p === "auth/refresh") {
    return NextResponse.json({
      access_token: "mock-access-token",
      refresh_token: "mock-refresh-token",
      token_type: "Bearer",
      expires_in: 3600,
    });
  }

  // Organizations endpoints
  if (path[0] === "organizations") {
    // GET /organizations
    if (req.method === "GET" && path.length === 1) {
      return NextResponse.json({
        count: mockStore.organizations.length,
        page: 1,
        total_pages: 1,
        results: mockStore.organizations,
      });
    }

    // POST /organizations
    if (req.method === "POST" && path.length === 1) {
      let body: { name?: string } = {};
      try {
        body = await req.json();
      } catch {
        // ignore
      }
      const org = mockStore.createOrganization(body.name || "My Organization");
      return NextResponse.json(org, { status: 201 });
    }

    // GET /organizations/current
    if (req.method === "GET" && path[1] === "current") {
      const org =
        mockStore.organizations.find((o) => o.id === orgHeaderId) ||
        mockStore.organizations[0];
      if (!org)
        return NextResponse.json(
          { error: { status: 404, message: "Organization not found" } },
          { status: 404 },
        );
      return NextResponse.json(org);
    }

    // Members endpoints: /organizations/{id}/members[/{memberId}]
    if (path.length >= 3 && path[2] === "members") {
      const orgId = path[1];
      if (req.method === "GET" && path.length === 3) {
        const members = mockStore.getMembers(orgId);
        return NextResponse.json({
          count: members.length,
          page: 1,
          total_pages: 1,
          results: members,
        });
      }
      if (req.method === "POST" && path.length === 3) {
        let body: { email?: string; role?: string } = {};
        try {
          body = await req.json();
        } catch {
          // ignore
        }
        const mem = mockStore.inviteMember(
          orgId,
          body.email || "new@bloom.dev",
          body.role || "Developer",
        );
        return NextResponse.json(mem, { status: 201 });
      }
      if (req.method === "PATCH" && path.length === 4) {
        const memberId = path[3];
        let body: { role?: string } = {};
        try {
          body = await req.json();
        } catch {
          // ignore
        }
        const updated = mockStore.changeMemberRole(
          orgId,
          memberId,
          body.role || "Developer",
        );
        if (!updated)
          return NextResponse.json(
            { error: { status: 404, message: "Member not found" } },
            { status: 404 },
          );
        return NextResponse.json(updated);
      }
      if (req.method === "DELETE" && path.length === 4) {
        const memberId = path[3];
        const success = mockStore.removeMember(orgId, memberId);
        if (!success)
          return NextResponse.json(
            { error: { status: 404, message: "Member not found" } },
            { status: 404 },
          );
        return new NextResponse(null, { status: 204 });
      }
    }

    // Detail endpoints: /organizations/{id}
    if (path.length === 2) {
      const orgId = path[1];
      if (req.method === "GET") {
        const org = mockStore.getOrganization(orgId);
        if (!org)
          return NextResponse.json(
            { error: { status: 404, message: "Organization not found" } },
            { status: 404 },
          );
        return NextResponse.json(org);
      }
      if (req.method === "PATCH") {
        let body: { name?: string; billing_email?: string } = {};
        try {
          body = await req.json();
        } catch {
          // ignore
        }
        const updated = mockStore.updateOrganization(orgId, body);
        if (!updated)
          return NextResponse.json(
            { error: { status: 404, message: "Organization not found" } },
            { status: 404 },
          );
        return NextResponse.json(updated);
      }
      if (req.method === "DELETE") {
        const success = mockStore.deleteOrganization(orgId);
        if (!success)
          return NextResponse.json(
            { error: { status: 404, message: "Organization not found" } },
            { status: 404 },
          );
        return new NextResponse(null, { status: 204 });
      }
    }
  }

  // Projects endpoints
  if (path[0] === "projects") {
    if (req.method === "GET" && path.length === 1) {
      return NextResponse.json({
        count: mockStore.projects.length,
        page: 1,
        total_pages: 1,
        results: mockStore.projects,
      });
    }

    if (req.method === "POST" && path.length === 1) {
      let body: { name?: string; description?: string } = {};
      try {
        body = await req.json();
      } catch {
        // ignore
      }
      const prj = mockStore.createProject(
        orgHeaderId,
        body.name || "Main",
        body.description,
      );
      return NextResponse.json(prj, { status: 201 });
    }

    if (path.length === 2) {
      const prjId = path[1];
      if (req.method === "GET") {
        const prj = mockStore.getProject(prjId);
        if (!prj)
          return NextResponse.json(
            { error: { status: 404, message: "Project not found" } },
            { status: 404 },
          );
        return NextResponse.json(prj);
      }
      if (req.method === "PATCH") {
        let body: { name?: string; description?: string } = {};
        try {
          body = await req.json();
        } catch {
          // ignore
        }
        const updated = mockStore.updateProject(prjId, body);
        if (!updated)
          return NextResponse.json(
            { error: { status: 404, message: "Project not found" } },
            { status: 404 },
          );
        return NextResponse.json(updated);
      }
      if (req.method === "DELETE") {
        const success = mockStore.deleteProject(prjId);
        if (!success)
          return NextResponse.json(
            { error: { status: 404, message: "Project not found" } },
            { status: 404 },
          );
        return new NextResponse(null, { status: 204 });
      }
    }
  }

  // Apps endpoints
  if (path[0] === "apps") {
    if (req.method === "GET" && path.length === 1) {
      const projectId = req.nextUrl.searchParams.get("project_id");
      const results = projectId
        ? mockStore.apps.filter((a) => a.project_id === projectId)
        : mockStore.apps;
      return NextResponse.json({
        count: results.length,
        page: 1,
        total_pages: 1,
        results,
      });
    }

    if (req.method === "POST" && path.length === 1) {
      let body: {
        project_id?: string;
        name?: string;
        repository_url?: string;
        default_branch?: string;
      } = {};
      try {
        body = await req.json();
      } catch {
        // ignore
      }
      const prjId = body.project_id || mockStore.projects[0]?.id || "default";
      const app = mockStore.createApp(
        prjId,
        orgHeaderId,
        body.name || "my_bloom_app",
        body.repository_url,
        body.default_branch || "main",
      );
      return NextResponse.json(app, { status: 201 });
    }

    if (req.method === "POST" && path[1] === "link") {
      let body: { project_slug?: string; app_slug?: string } = {};
      try {
        body = await req.json();
      } catch {
        // ignore
      }
      const linked = mockStore.linkApp(
        body.project_slug || "mobile-suite",
        body.app_slug || "linked-app",
      );
      return NextResponse.json(linked, { status: 201 });
    }

    if (path.length === 2) {
      const appId = path[1];
      if (req.method === "GET") {
        const app = mockStore.getApp(appId);
        if (!app)
          return NextResponse.json(
            { error: { status: 404, message: "App not found" } },
            { status: 404 },
          );
        return NextResponse.json(app);
      }
      if (req.method === "PATCH") {
        let body: {
          name?: string;
          repository_url?: string | null;
          default_branch?: string;
        } = {};
        try {
          body = await req.json();
        } catch {
          // ignore
        }
        const updated = mockStore.updateApp(appId, body);
        if (!updated)
          return NextResponse.json(
            { error: { status: 404, message: "App not found" } },
            { status: 404 },
          );
        return NextResponse.json(updated);
      }
      if (req.method === "DELETE") {
        const success = mockStore.deleteApp(appId);
        if (!success)
          return NextResponse.json(
            { error: { status: 404, message: "App not found" } },
            { status: 404 },
          );
        return new NextResponse(null, { status: 204 });
      }
    }
  }

  // Builds endpoints
  if (path[0] === "builds" || (path.length >= 3 && path[2] === "builds")) {
    if (req.method === "GET" && (path.length === 1 || path.length === 3)) {
      const appId =
        req.nextUrl.searchParams.get("app_id") ||
        (path.length === 3 ? path[1] : undefined);
      const results = appId
        ? mockStore.builds.filter((b) => b.app_id === appId)
        : mockStore.builds;
      return NextResponse.json({
        count: results.length,
        page: 1,
        total_pages: 1,
        results,
      });
    }

    if (req.method === "POST" && path.length === 1) {
      let body: {
        app_id?: string;
        environment_id?: string;
        platform?: string;
        git_branch?: string;
        git_commit?: string;
      } = {};
      try {
        body = await req.json();
      } catch {
        // ignore
      }
      const appId = body.app_id || mockStore.apps[0]?.id || "app_1";
      const newBuild = mockStore.createBuild(
        appId,
        body.environment_id || "",
        body.platform || "all",
        body.git_branch,
        body.git_commit,
      );
      return NextResponse.json(newBuild, { status: 201 });
    }

    if (path.length >= 2) {
      const buildId = path[1];
      if (req.method === "GET" && path.length === 2) {
        const b = mockStore.getBuild(buildId);
        if (!b)
          return NextResponse.json(
            { error: { status: 404, message: "Build not found" } },
            { status: 404 },
          );
        return NextResponse.json(b);
      }
      if (req.method === "POST" && path[2] === "cancel") {
        const cancelled = mockStore.cancelBuild(buildId);
        if (!cancelled)
          return NextResponse.json(
            { error: { status: 404, message: "Build not found" } },
            { status: 404 },
          );
        return NextResponse.json(cancelled);
      }
      if (req.method === "GET" && path[2] === "logs") {
        return NextResponse.json({
          url: `https://storage.bloom.dev/logs/builds/${buildId}.log`,
          expires_in_secs: 3600,
        });
      }
    }
  }

  // Environments endpoints
  if (path[0] === "environments") {
    if (req.method === "GET" && path.length === 1) {
      const appId = req.nextUrl.searchParams.get("app_id");
      const results = appId
        ? mockStore.environments.filter((e) => e.app_id === appId)
        : mockStore.environments;
      return NextResponse.json({
        count: results.length,
        page: 1,
        total_pages: 1,
        results,
      });
    }

    if (req.method === "POST" && path.length === 1) {
      let body: {
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
      } = {};
      try {
        body = await req.json();
      } catch {
        // ignore
      }
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
      return NextResponse.json(env, { status: 201 });
    }

    if (path.length === 2) {
      const envId = path[1];
      if (req.method === "GET") {
        const env = mockStore.environments.find((e) => e.id === envId);
        if (!env)
          return NextResponse.json(
            { error: { status: 404, message: "Environment not found" } },
            { status: 404 },
          );
        return NextResponse.json(env);
      }
      if (req.method === "PATCH") {
        let body: Record<string, unknown> = {};
        try {
          body = await req.json();
        } catch {
          // ignore
        }
        const updated = mockStore.updateEnvironment(envId, body);
        if (!updated)
          return NextResponse.json(
            { error: { status: 404, message: "Environment not found" } },
            { status: 404 },
          );
        return NextResponse.json(updated);
      }
      if (req.method === "DELETE") {
        const success = mockStore.deleteEnvironment(envId);
        if (!success)
          return NextResponse.json(
            { error: { status: 404, message: "Environment not found" } },
            { status: 404 },
          );
        return new NextResponse(null, { status: 204 });
      }
    }
  }

  // Secrets endpoints
  if (path[0] === "secrets") {
    if (req.method === "GET" && path.length === 1) {
      const envId = req.nextUrl.searchParams.get("environment_id");
      const results = envId ? mockStore.getSecrets(envId) : mockStore.secrets;
      const safeResults = results.map((s) => ({
        id: s.id,
        environment_id: s.environment_id,
        organization_id: s.organization_id,
        key: s.key,
        is_json: s.is_json,
        version: s.version,
        updated_at: s.updated_at,
      }));
      return NextResponse.json({
        count: safeResults.length,
        page: 1,
        total_pages: 1,
        results: safeResults,
      });
    }

    if (req.method === "POST" && path.length === 1) {
      let body: {
        environment_id: string;
        key: string;
        value: string;
        is_json?: boolean;
      } = { environment_id: "", key: "", value: "" };
      try {
        body = await req.json();
      } catch {
        // ignore
      }
      const sec = mockStore.createOrUpdateSecret(
        body.environment_id,
        orgHeaderId,
        body.key,
        body.value,
        body.is_json || false,
      );
      return NextResponse.json(
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
    }

    if (path.length >= 2) {
      const secId = path[1];
      if (req.method === "GET" && path.length === 2) {
        const sec = mockStore.secrets.find((s) => s.id === secId);
        if (!sec)
          return NextResponse.json(
            { error: { status: 404, message: "Secret not found" } },
            { status: 404 },
          );
        return NextResponse.json({
          id: sec.id,
          environment_id: sec.environment_id,
          organization_id: sec.organization_id,
          key: sec.key,
          is_json: sec.is_json,
          version: sec.version,
          updated_at: sec.updated_at,
        });
      }
      if (req.method === "PATCH" && path.length === 2) {
        let body: { value?: string; is_json?: boolean } = {};
        try {
          body = await req.json();
        } catch {
          // ignore
        }
        const sec = mockStore.updateSecret(secId, body.value, body.is_json);
        if (!sec)
          return NextResponse.json(
            { error: { status: 404, message: "Secret not found" } },
            { status: 404 },
          );
        return NextResponse.json({
          id: sec.id,
          environment_id: sec.environment_id,
          organization_id: sec.organization_id,
          key: sec.key,
          is_json: sec.is_json,
          version: sec.version,
          updated_at: sec.updated_at,
        });
      }
      if (req.method === "POST" && path[2] === "rollback") {
        let body: { version: number } = { version: 1 };
        try {
          body = await req.json();
        } catch {
          // ignore
        }
        const sec = mockStore.rollbackSecret(secId, body.version);
        if (!sec)
          return NextResponse.json(
            { error: { status: 404, message: "Secret not found" } },
            { status: 404 },
          );
        return NextResponse.json({
          id: sec.id,
          environment_id: sec.environment_id,
          organization_id: sec.organization_id,
          key: sec.key,
          is_json: sec.is_json,
          version: sec.version,
          updated_at: sec.updated_at,
        });
      }
      if (req.method === "DELETE" && path.length === 2) {
        const success = mockStore.deleteSecret(secId);
        if (!success)
          return NextResponse.json(
            { error: { status: 404, message: "Secret not found" } },
            { status: 404 },
          );
        return new NextResponse(null, { status: 204 });
      }
    }
  }

  // Signing endpoints
  if (path[0] === "signing") {
    if (req.method === "GET" && path.length === 1) {
      const results = mockStore.getSigningIdentities(orgHeaderId);
      return NextResponse.json({
        count: results.length,
        page: 1,
        total_pages: 1,
        results,
      });
    }

    if (req.method === "POST" && path.length === 1) {
      let body: {
        platform: "android" | "ios";
        name: string;
        kind: "keystore" | "certificate" | "provisioning_profile" | "api_key";
        material: string;
        metadata: Record<string, unknown>;
        expires_at?: string | null;
      } = {
        platform: "android",
        name: "",
        kind: "keystore",
        material: "",
        metadata: {},
      };
      try {
        body = await req.json();
      } catch {
        // ignore
      }
      const identity = mockStore.createSigningIdentity(
        orgHeaderId,
        body.platform,
        body.name,
        body.kind,
        body.material,
        body.metadata,
        body.expires_at,
      );
      return NextResponse.json(identity, { status: 201 });
    }

    if (path.length === 2) {
      const id = path[1];
      if (req.method === "GET") {
        const identity = mockStore.getSigningIdentity(id);
        if (!identity)
          return NextResponse.json(
            { error: { status: 404, message: "Signing identity not found" } },
            { status: 404 },
          );
        return NextResponse.json(identity);
      }
      if (req.method === "DELETE") {
        const success = mockStore.deleteSigningIdentity(id);
        if (!success)
          return NextResponse.json(
            { error: { status: 404, message: "Signing identity not found" } },
            { status: 404 },
          );
        return new NextResponse(null, { status: 204 });
      }
    }
  }

  // Releases endpoints
  if (path[0] === "releases") {
    if (req.method === "GET" && path.length === 1) {
      const appId = req.nextUrl.searchParams.get("app_id");
      const results = appId ? mockStore.getReleases(appId) : mockStore.releases;
      return NextResponse.json({
        count: results.length,
        page: 1,
        total_pages: 1,
        results,
      });
    }

    if (req.method === "POST" && path.length === 1) {
      let body: {
        app_id: string;
        version: string;
        build_number: number;
        commit: string;
        changelog?: string;
        environment_id?: string | null;
        platforms?: string[];
        artifact_ids?: string[];
      } = { app_id: "", version: "", build_number: 1, commit: "" };
      try {
        body = await req.json();
      } catch {
        // ignore
      }
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
      return NextResponse.json(rel, { status: 201 });
    }

    if (path.length >= 2) {
      const relId = path[1];
      if (req.method === "GET" && path.length === 2) {
        const rel = mockStore.getRelease(relId);
        if (!rel)
          return NextResponse.json(
            { error: { status: 404, message: "Release not found" } },
            { status: 404 },
          );
        return NextResponse.json(rel);
      }
      if (req.method === "PATCH" && path.length === 2) {
        let body: {
          changelog?: string;
          rollout_status?: Record<string, unknown>;
          status?: string;
        } = {};
        try {
          body = await req.json();
        } catch {
          // ignore
        }
        const updated = mockStore.updateRelease(relId, body);
        if (!updated)
          return NextResponse.json(
            { error: { status: 404, message: "Release not found" } },
            { status: 404 },
          );
        return NextResponse.json(updated);
      }
      if (req.method === "POST" && path[2] === "approve") {
        let body: { approved: boolean; reason?: string } = { approved: true };
        try {
          body = await req.json();
        } catch {
          // ignore
        }
        const updated = mockStore.approveRelease(
          relId,
          body.approved,
          body.reason,
        );
        if (!updated)
          return NextResponse.json(
            { error: { status: 404, message: "Release not found" } },
            { status: 404 },
          );
        return NextResponse.json(updated);
      }
      if (req.method === "POST" && path[2] === "rollback") {
        let reason: string | undefined;
        try {
          const body = (await req.json()) as { reason?: string };
          reason = body.reason;
        } catch {
          // optional body
        }
        const updated = mockStore.rollbackRelease(relId, reason);
        if (!updated)
          return NextResponse.json(
            { error: { status: 404, message: "Release not found" } },
            { status: 404 },
          );
        return NextResponse.json(updated);
      }
    }
  }

  // Deployments endpoints
  if (path[0] === "deployments") {
    if (req.method === "GET" && path.length === 1) {
      const appId = req.nextUrl.searchParams.get("app_id") ?? undefined;
      const envId = req.nextUrl.searchParams.get("environment_id") ?? undefined;
      const relId = req.nextUrl.searchParams.get("release_id") ?? undefined;
      const results = mockStore.getDeployments(appId, envId, relId);
      return NextResponse.json({
        count: results.length,
        page: 1,
        total_pages: 1,
        results,
      });
    }

    if (req.method === "POST" && path.length === 1) {
      let body: {
        environment_id: string;
        platform: "ios" | "android" | "web";
        target: string;
        release_id?: string | null;
        artifact_id?: string | null;
      } = { environment_id: "", platform: "ios", target: "testflight" };
      try {
        body = await req.json();
      } catch {
        // ignore
      }
      const dep = mockStore.createDeployment(
        orgHeaderId,
        body.environment_id,
        body.platform,
        body.target,
        body.release_id,
        body.artifact_id,
      );
      return NextResponse.json(dep, { status: 201 });
    }

    if (path.length >= 2) {
      const depId = path[1];
      if (req.method === "GET" && path.length === 2) {
        const dep = mockStore.getDeployment(depId);
        if (!dep)
          return NextResponse.json(
            { error: { status: 404, message: "Deployment not found" } },
            { status: 404 },
          );
        return NextResponse.json(dep);
      }
      if (req.method === "POST" && path[2] === "rollback") {
        const rolled = mockStore.rollbackDeployment(depId);
        if (!rolled)
          return NextResponse.json(
            { error: { status: 404, message: "Deployment not found" } },
            { status: 404 },
          );
        return NextResponse.json(rolled);
      }
    }
  }

  // Billing & Usage endpoints
  if (req.method === "GET" && p === "billing/usage") {
    return NextResponse.json({
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
  }

  // Account Profile & API Tokens
  if (req.method === "PATCH" && p === "auth/me") {
    let body: { display_name?: string; avatar_url?: string | null; timezone?: string } = {};
    try {
      body = await req.json();
    } catch {
      // ignore
    }
    const user = mockStore.updateUserProfile(body);
    return NextResponse.json(user);
  }

  if (req.method === "GET" && p === "auth/tokens") {
    const tokens = mockStore.getApiTokens();
    return NextResponse.json({
      count: tokens.length,
      page: 1,
      total_pages: 1,
      results: tokens,
    });
  }

  if (req.method === "POST" && p === "auth/token") {
    let body: { name?: string } = {};
    try {
      body = await req.json();
    } catch {
      // ignore
    }
    const { tokenRecord, rawToken } = mockStore.createApiToken(body.name || "API Token");
    return NextResponse.json(
      {
        id: tokenRecord.id,
        name: tokenRecord.name,
        token: rawToken,
        created_at: tokenRecord.created_at,
        last_used_at: null,
      },
      { status: 201 },
    );
  }

  if (req.method === "DELETE" && path[0] === "auth" && path[1] === "token" && path[2]) {
    const success = mockStore.revokeApiToken(path[2]);
    if (!success) {
      return NextResponse.json(
        { error: { status: 404, message: "Token not found" } },
        { status: 404 },
      );
    }
    return new NextResponse(null, { status: 204 });
  }

  if (req.method === "POST" && p === "auth/change-password") {
    return NextResponse.json({ message: "Password updated successfully" });
  }

  // Web Hosting endpoints
  if (path[0] === "webhosting") {
    if (path[1] === "deployments") {
      if (req.method === "GET" && path.length === 2) {
        const appId = req.nextUrl.searchParams.get("app_id") ?? undefined;
        const list = mockStore.getWebDeployments(appId);
        return NextResponse.json({
          count: list.length,
          page: 1,
          total_pages: 1,
          results: list,
        });
      }
      if (req.method === "POST" && path.length === 2) {
        let body: {
          app_id: string;
          environment_id: string;
          artifact_id: string;
          target?: "preview" | "production";
          release_id?: string | null;
          git_branch?: string;
        } = {
          app_id: "",
          environment_id: "",
          artifact_id: "",
        };
        try {
          body = await req.json();
        } catch {
          // ignore
        }
        const dep = mockStore.createWebDeployment(
          body.app_id,
          body.environment_id,
          body.artifact_id || "art_web_001",
          body.target || "preview",
          body.release_id,
          body.git_branch,
        );
        return NextResponse.json(dep, { status: 201 });
      }
      if (req.method === "GET" && path.length === 3) {
        const dep = mockStore.getWebDeployment(path[2]);
        if (!dep) {
          return NextResponse.json(
            { error: { status: 404, message: "Web deployment not found" } },
            { status: 404 },
          );
        }
        return NextResponse.json(dep);
      }
      if (req.method === "POST" && path.length === 4 && path[3] === "rollback") {
        const dep = mockStore.rollbackWebDeployment(path[2]);
        if (!dep) {
          return NextResponse.json(
            { error: { status: 404, message: "Web deployment not found" } },
            { status: 404 },
          );
        }
        return NextResponse.json(dep);
      }
    }

    if (path[1] === "domains") {
      if (req.method === "GET" && path.length === 2) {
        const appId = req.nextUrl.searchParams.get("app_id") ?? undefined;
        const domains = mockStore.getCustomDomains(appId);
        return NextResponse.json({
          count: domains.length,
          page: 1,
          total_pages: 1,
          results: domains,
        });
      }
      if (req.method === "POST" && path.length === 2) {
        let body: { app_id: string; domain: string } = { app_id: "", domain: "" };
        try {
          body = await req.json();
        } catch {
          // ignore
        }
        const created = mockStore.createCustomDomain(body.app_id, body.domain);
        return NextResponse.json(created, { status: 201 });
      }
      if (req.method === "GET" && path.length === 3) {
        const domain = mockStore.getCustomDomain(path[2]);
        if (!domain) {
          return NextResponse.json(
            { error: { status: 404, message: "Domain not found" } },
            { status: 404 },
          );
        }
        return NextResponse.json(domain);
      }
      if (req.method === "POST" && path.length === 4 && path[3] === "verify") {
        const verified = mockStore.verifyCustomDomain(path[2]);
        if (!verified) {
          return NextResponse.json(
            { error: { status: 404, message: "Domain not found" } },
            { status: 404 },
          );
        }
        return NextResponse.json(verified);
      }
      if (req.method === "DELETE" && path.length === 3) {
        const success = mockStore.deleteCustomDomain(path[2]);
        if (!success) {
          return NextResponse.json(
            { error: { status: 404, message: "Domain not found" } },
            { status: 404 },
          );
        }
        return new NextResponse(null, { status: 204 });
      }
    }
  }

  // Observability endpoints
  if (path[0] === "observability") {
    if (path[1] === "apps" && path.length === 4 && path[3] === "status") {
      const status = mockStore.getAppStatus(path[2]);
      return NextResponse.json(status);
    }
    if (path[1] === "apps" && path.length === 4 && path[3] === "health") {
      const health = mockStore.getAppHealth(path[2]);
      return NextResponse.json(health);
    }
    if (path[1] === "releases" && path.length === 4 && path[3] === "health") {
      const health = mockStore.getReleaseHealth(path[2]);
      return NextResponse.json(health);
    }
  }

  // Credentials endpoints
  if (path[0] === "credentials") {
    if (req.method === "GET" && path.length === 1) {
      const creds = mockStore.getCredentials(orgHeaderId);
      return NextResponse.json({
        count: creds.length,
        page: 1,
        total_pages: 1,
        results: creds,
      });
    }
    if (req.method === "POST" && path.length === 1) {
      let body: {
        provider: "apple" | "google_play" | "shorebird" | "github" | "gitlab" | "bitbucket";
        name: string;
        metadata: Record<string, unknown>;
        expires_at?: string | null;
      } = {
        provider: "apple",
        name: "",
        metadata: {},
      };
      try {
        body = await req.json();
      } catch {
        // ignore
      }
      const cred = mockStore.createCredential(orgHeaderId, body);
      return NextResponse.json(cred, { status: 201 });
    }
    if (req.method === "GET" && path.length === 2) {
      const cred = mockStore.getCredential(path[1]);
      if (!cred) {
        return NextResponse.json(
          { error: { status: 404, message: "Credential not found" } },
          { status: 404 },
        );
      }
      return NextResponse.json(cred);
    }
    if (req.method === "POST" && path.length === 3 && path[2] === "test") {
      const res = mockStore.testCredential(path[1]);
      return NextResponse.json({
        id: path[1],
        provider: res.provider,
        success: res.success,
        message: res.message,
      });
    }
    if (req.method === "DELETE" && path.length === 2) {
      const success = mockStore.deleteCredential(path[1]);
      if (!success) {
        return NextResponse.json(
          { error: { status: 404, message: "Credential not found" } },
          { status: 404 },
        );
      }
      return new NextResponse(null, { status: 204 });
    }
  }

  // Git Connections endpoints
  if (path[0] === "git-connections") {
    if (req.method === "GET" && path.length === 1) {
      const connections = mockStore.getGitConnections(orgHeaderId);
      return NextResponse.json({
        count: connections.length,
        page: 1,
        total_pages: 1,
        results: connections,
      });
    }
    if (req.method === "POST" && path.length === 1) {
      let body: {
        provider: "github" | "gitlab" | "bitbucket";
        installation_id: string;
        metadata?: Record<string, unknown>;
      } = {
        provider: "github",
        installation_id: "",
      };
      try {
        body = await req.json();
      } catch {
        // ignore
      }
      const conn = mockStore.createGitConnection(orgHeaderId, body);
      return NextResponse.json(conn, { status: 201 });
    }
    if (req.method === "GET" && path.length === 2) {
      const conn = mockStore.getGitConnection(path[1]);
      if (!conn) {
        return NextResponse.json(
          { error: { status: 404, message: "Git connection not found" } },
          { status: 404 },
        );
      }
      return NextResponse.json(conn);
    }
    if (req.method === "GET" && path.length === 3 && path[2] === "repositories") {
      const repos = mockStore.getGitRepositories(path[1]);
      return NextResponse.json({
        count: repos.length,
        page: 1,
        total_pages: 1,
        results: repos,
      });
    }
    if (req.method === "DELETE" && path.length === 2) {
      const success = mockStore.deleteGitConnection(path[1]);
      if (!success) {
        return NextResponse.json(
          { error: { status: 404, message: "Git connection not found" } },
          { status: 404 },
        );
      }
      return new NextResponse(null, { status: 204 });
    }
  }

  return NextResponse.json(
    {
      error: {
        status: 502,
        message: "Backend unreachable and no mock handler for " + p,
      },
    },
    { status: 502 },
  );
}

type RouteParams = { params: Promise<{ path: string[] }> };

export async function GET(req: NextRequest, { params }: RouteParams) {
  return proxy(req, (await params).path);
}
export async function POST(req: NextRequest, { params }: RouteParams) {
  return proxy(req, (await params).path);
}
export async function PATCH(req: NextRequest, { params }: RouteParams) {
  return proxy(req, (await params).path);
}
export async function PUT(req: NextRequest, { params }: RouteParams) {
  return proxy(req, (await params).path);
}
export async function DELETE(req: NextRequest, { params }: RouteParams) {
  return proxy(req, (await params).path);
}
