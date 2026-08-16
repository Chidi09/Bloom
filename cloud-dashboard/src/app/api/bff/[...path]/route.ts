import { NextRequest, NextResponse } from "next/server";

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

import { mockStore } from "@/lib/mock-store";

async function handleMockFallback(req: NextRequest, path: string[]) {
  const p = path.join("/");

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

  // Organizations endpoints
  if (req.method === "GET" && p === "organizations") {
    return NextResponse.json({
      count: mockStore.organizations.length,
      page: 1,
      total_pages: 1,
      results: mockStore.organizations,
    });
  }

  if (req.method === "POST" && p === "organizations") {
    let body: { name?: string } = {};
    try {
      body = await req.json();
    } catch {
      // ignore
    }
    const org = mockStore.createOrganization(body.name || "My Organization");
    return NextResponse.json(org, { status: 201 });
  }

  // Projects endpoints
  if (req.method === "GET" && p === "projects") {
    return NextResponse.json({
      count: mockStore.projects.length,
      page: 1,
      total_pages: 1,
      results: mockStore.projects,
    });
  }

  if (req.method === "POST" && p === "projects") {
    let body: { name?: string; description?: string } = {};
    try {
      body = await req.json();
    } catch {
      // ignore
    }
    const orgId =
      req.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "default";
    const prj = mockStore.createProject(
      orgId,
      body.name || "Main",
      body.description,
    );
    return NextResponse.json(prj, { status: 201 });
  }

  // Apps endpoints
  if (req.method === "GET" && p === "apps") {
    return NextResponse.json({
      count: mockStore.apps.length,
      page: 1,
      total_pages: 1,
      results: mockStore.apps,
    });
  }

  if (req.method === "POST" && p === "apps") {
    let body: { project_id?: string; name?: string; repository_url?: string } =
      {};
    try {
      body = await req.json();
    } catch {
      // ignore
    }
    const orgId =
      req.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "default";
    const prjId = body.project_id || mockStore.projects[0]?.id || "default";
    const app = mockStore.createApp(
      prjId,
      orgId,
      body.name || "my_bloom_app",
      body.repository_url,
    );
    return NextResponse.json(app, { status: 201 });
  }

  // Builds endpoints
  if (req.method === "GET" && (p === "builds" || p.endsWith("/builds"))) {
    return NextResponse.json({
      count: mockStore.builds.length,
      page: 1,
      total_pages: 1,
      results: mockStore.builds,
    });
  }

  if (req.method === "POST" && p === "builds") {
    let body: { app_id?: string; environment_id?: string; platform?: string } =
      {};
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
    );
    return NextResponse.json(newBuild, { status: 201 });
  }

  // Environments endpoints
  if (req.method === "GET" && p === "environments") {
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

  if (req.method === "POST" && p === "environments") {
    let body: { app_id?: string; name?: string; slug?: string } = {};
    try {
      body = await req.json();
    } catch {
      // ignore
    }
    const orgId =
      req.headers.get("x-bloom-organization-id") ||
      mockStore.organizations[0]?.id ||
      "default";
    const env = mockStore.createEnvironment(
      body.app_id || mockStore.apps[0]?.id || "default",
      orgId,
      body.name || "Production",
      body.slug || "production",
    );
    return NextResponse.json(env, { status: 201 });
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
