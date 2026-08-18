import { NextRequest, NextResponse } from "next/server";

// BFF proxy — cloud-dashboard-frontend.md §6.6.
// The backend issues bearer tokens in the JSON body (no Set-Cookie), so this proxy's
// value here is same-origin request routing: it keeps the backend origin out of
// client-side network calls/CSP and avoids CORS entirely, not cookie handling.
//
// Mock data is NOT hardcoded here. When NEXT_PUBLIC_API_MOCKING=enabled, MSW's
// browser service worker (see src/mocks/) intercepts these same-origin fetch()
// calls before they ever reach this route handler — src/mocks/handlers.ts is the
// single source of truth for mock responses. This route only ever proxies to a
// real backend; it has no mock fallback of its own.
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

  // Forward Set-Cookie as-is — the browser sees it as first-party since this response
  // comes from the dashboard's own origin, not the backend's.
  const responseHeaders = new Headers(backendRes.headers);
  return new NextResponse(backendRes.body, {
    status: backendRes.status,
    headers: responseHeaders,
  });
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
