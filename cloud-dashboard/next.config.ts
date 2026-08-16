import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  allowedDevOrigins: [
    "*.trycloudflare.com",
    "sponsor-cells-borders-airfare.trycloudflare.com",
    "localhost:3000",
    "78.47.216.151:3000",
  ],
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "www.google.com",
        pathname: "/s2/favicons/**",
      },
      {
        protocol: "https",
        hostname: "*.gstatic.com",
        pathname: "/**",
      },
      {
        protocol: "https",
        hostname: "gstatic.com",
        pathname: "/**",
      },
    ],
  },
};

export default nextConfig;
