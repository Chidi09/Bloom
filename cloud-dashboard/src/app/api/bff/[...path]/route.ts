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
      );
      return NextResponse.json(env, { status: 201 });
    }

    if (path.length === 2) {
      const envId = path[1];
      const env = mockStore.environments.find((e) => e.id === envId);
      if (!env)
        return NextResponse.json(
          { error: { status: 404, message: "Environment not found" } },
          { status: 404 },
        );
      return NextResponse.json(env);
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
