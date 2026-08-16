import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  allowedDevOrigins: [
    "*.trycloudflare.com",
    "sponsor-cells-borders-airfare.trycloudflare.com",
    "localhost:3000",
    "78.47.216.151:3000",
  ],
};

export default nextConfig;
