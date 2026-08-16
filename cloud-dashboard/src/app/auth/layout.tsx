import * as React from "react";
import type { Metadata } from "next";
import { BloomLogo } from "@/components/auth/bloom-logo";
import { HeroCarousel } from "@/components/auth/hero-carousel";

export const metadata: Metadata = {
  title: "Bloom Cloud — Authenticate",
  description: "Sign in or register for the Bloom Cloud developer console.",
};

export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="bg-background flex min-h-screen w-full">
      {/* Left Pane: Brand & Form Shell */}
      <div className="flex min-h-screen w-full flex-1 flex-col justify-between p-6 sm:p-10 lg:w-1/2 lg:p-12">
        {/* Center: Auth Form Slot with Centered Stacked Logo above */}
        <main className="flex flex-1 flex-col items-center justify-center py-6">
          <div className="flex w-full max-w-md flex-col items-center gap-6">
            <BloomLogo layout="vertical" size={42} />
            <div className="w-full">{children}</div>
          </div>
        </main>

        {/* Bottom Footer Note */}
        <footer className="text-muted-foreground mx-auto flex w-full max-w-md items-center justify-between text-[11px]">
          <span>&copy; {new Date().getFullYear()} Bloom Cloud</span>
          <div className="flex items-center gap-4">
            <a
              href="mailto:support@bloom.dev"
              className="hover:text-foreground transition-colors"
            >
              Support
            </a>
            <span className="text-border">•</span>
            <span className="font-mono text-[10px]">v1.0</span>
          </div>
        </footer>
      </div>

      {/* Right Pane: Rotating Hero Imagery */}
      <div className="border-border relative hidden min-h-screen border-l lg:flex lg:w-1/2">
        <HeroCarousel />
      </div>
    </div>
  );
}
