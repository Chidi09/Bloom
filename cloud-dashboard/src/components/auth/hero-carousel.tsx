"use client";

import * as React from "react";
import Image from "next/image";
import { cn } from "@/lib/utils";

interface Slide {
  src: string;
  tag: string;
  headline: string;
  description: string;
}

const SLIDES: readonly Slide[] = [
  {
    src: "/auth/build.jpg",
    tag: "BUILD",
    headline: "Build",
    description:
      "Compile and test every platform target across iOS, Android, and Web.",
  },
  {
    src: "/auth/ship.jpg",
    tag: "SHIP",
    headline: "Ship",
    description:
      "Deploy to TestFlight, Google Play, and global hosting in one unified flow.",
  },
  {
    src: "/auth/bloom.jpg",
    tag: "BLOOM",
    headline: "Bloom",
    description:
      "Watch releases thrive with live crash-free rates and rollout health.",
  },
] as const;

export function HeroCarousel() {
  const [activeIndex, setActiveIndex] = React.useState(0);

  React.useEffect(() => {
    const timer = setInterval(() => {
      setActiveIndex((prev) => (prev + 1) % SLIDES.length);
    }, 2500);

    return () => clearInterval(timer);
  }, []);

  return (
    <div className="relative h-full w-full overflow-hidden bg-black select-none">
      {/* Background Slides with crossfade */}
      {SLIDES.map((slide, index) => {
        const isActive = index === activeIndex;
        return (
          <div
            key={slide.src}
            className={cn(
              "absolute inset-0 transition-opacity duration-700 ease-in-out",
              isActive
                ? "z-10 opacity-100"
                : "pointer-events-none z-0 opacity-0",
            )}
            aria-hidden={!isActive}
          >
            <Image
              src={slide.src}
              alt={slide.headline}
              fill
              priority
              sizes="(min-width: 1024px) 50vw, 100vw"
              className="scale-[1.02] object-cover object-center"
            />
          </div>
        );
      })}

      {/* Cinematic gradient overlay for maximum legibility */}
      <div className="pointer-events-none absolute inset-0 z-20 bg-gradient-to-t from-black/90 via-black/40 to-black/20" />

      {/* Slide Content & Pagination */}
      <div className="absolute inset-x-0 bottom-0 z-30 flex flex-col gap-6 p-8 sm:p-12 lg:p-16">
        <div className="flex max-w-lg flex-col gap-2">
          <div className="flex items-center gap-2">
            <span className="inline-flex items-center rounded-full border border-white/15 bg-white/10 px-2.5 py-0.5 font-mono text-[10px] font-semibold tracking-widest text-white uppercase backdrop-blur-md">
              {SLIDES[activeIndex].tag}
            </span>
          </div>
          <h2 className="font-heading text-2xl font-medium tracking-tight text-white sm:text-3xl">
            {SLIDES[activeIndex].headline}
          </h2>
          <p className="text-sm/relaxed text-zinc-300">
            {SLIDES[activeIndex].description}
          </p>
        </div>

        {/* Indicator dots */}
        <div
          className="flex items-center gap-2"
          role="tablist"
          aria-label="Hero carousel pagination"
        >
          {SLIDES.map((slide, index) => {
            const isActive = index === activeIndex;
            return (
              <button
                key={slide.src}
                type="button"
                role="tab"
                aria-selected={isActive}
                aria-label={`Go to slide ${index + 1}: ${slide.headline}`}
                onClick={() => setActiveIndex(index)}
                className={cn(
                  "h-1.5 rounded-full transition-all duration-300 focus-visible:ring-2 focus-visible:ring-white focus-visible:outline-none",
                  isActive
                    ? "w-8 bg-white"
                    : "w-2 bg-white/30 hover:bg-white/60",
                )}
              />
            );
          })}
        </div>
      </div>
    </div>
  );
}
