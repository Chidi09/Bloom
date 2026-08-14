import * as React from 'preact/compat';
import { useState } from 'preact/hooks';
import { Star, MessageSquare, Users, GitPullRequest, ArrowUpRight, CheckCircle2, Heart, Sparkles } from 'lucide-preact';

interface Testimonial {
  id: string;
  quote: string;
  author: string;
  handle: string;
  role: string;
  company: string;
  avatar: string;
  category: 'all' | 'leads' | 'architects' | 'contributors';
  stars: number;
  highlightText?: string;
}

const testimonials: Testimonial[] = [
  {
    id: '1',
    quote: 'Bloom replaced our fragmented state packages and custom router with pure file-system routing and signals. Our release velocity doubled in the first sprint.',
    author: 'Alex Rivers',
    handle: '@arivers_dev',
    role: 'Mobile Tech Lead',
    company: 'Vercel Mobile',
    avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=120&h=120&q=80&crop=faces',
    category: 'leads',
    stars: 5,
    highlightText: 'Release velocity doubled in 1 sprint',
  },
  {
    id: '2',
    quote: 'Shorebird-powered OTA through Bloom Cloud is magic. We patched a critical payment flow bug on 400,000 active iOS & Android devices in 1.4 seconds.',
    author: 'Elena Rostova',
    handle: '@erostova_flutter',
    role: 'Principal Engineer',
    company: 'Fintech Labs',
    avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=120&h=120&q=80&crop=faces',
    category: 'architects',
    stars: 5,
    highlightText: 'Patched 400k devices in 1.4s',
  },
  {
    id: '3',
    quote: 'The DI boot sequence and typed route generation in Bloom feel like Next.js for mobile. Finally a framework that respects Dart’s sound null safety.',
    author: 'Marcus Vance',
    handle: '@marcusvance',
    role: 'Core Contributor',
    company: 'Flutter Ecosystem',
    avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=120&h=120&q=80&crop=faces',
    category: 'contributors',
    stars: 5,
    highlightText: 'Next.js DX for Flutter',
  },
  {
    id: '4',
    quote: 'Bloom UI Studio’s shadcn primitives bring production-grade mobile tokens to Flutter. Customizing border-radius and color swatches live at 60fps is unreal.',
    author: 'Sofia Chen',
    handle: '@sofiachen_ui',
    role: 'Design Systems Lead',
    company: 'Bloom Studio',
    avatar: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=120&h=120&q=80&crop=faces',
    category: 'leads',
    stars: 5,
    highlightText: 'Production-grade mobile tokens',
  },
  {
    id: '5',
    quote: 'We migrated 6 production Flutter apps to Bloom in under two weeks. Zero boilerplate, instant hot reload state preservation, and crisp developer DX.',
    author: "David O'Connor",
    handle: '@doconnor_app',
    role: 'Founder & Architect',
    company: 'MobileStack',
    avatar: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=120&h=120&q=80&crop=faces',
    category: 'architects',
    stars: 5,
    highlightText: '6 production apps migrated',
  },
  {
    id: '6',
    quote: 'Bloom Query eliminated 90% of our manual API state code. Automatic caching, optimistic mutations, and signals reactivity work seamlessly out of the box.',
    author: 'Kaito Tanaka',
    handle: '@kaito_dart',
    role: 'Staff Software Engineer',
    company: 'Global Cloud',
    avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=120&h=120&q=80&crop=faces',
    category: 'contributors',
    stars: 5,
    highlightText: 'Eliminated 90% manual state code',
  },
];

export function CommunityShowcase() {
  const [filter, setFilter] = useState<'all' | 'leads' | 'architects' | 'contributors'>('all');
  const [starred, setStarred] = useState(false);
  const [starCount, setStarCount] = useState(18420);

  const filteredTestimonials = filter === 'all' 
    ? testimonials 
    : testimonials.filter((t) => t.category === filter);

  const handleStarClick = () => {
    if (starred) {
      setStarCount((prev) => prev - 1);
      setStarred(false);
    } else {
      setStarCount((prev) => prev + 1);
      setStarred(true);
    }
  };

  return (
    <div className="space-y-12 max-w-6xl mx-auto">
      {/* Category Filter Pills */}
      <div className="flex flex-wrap items-center justify-center gap-2">
        {[
          { id: 'all', label: `All Testimonials (${testimonials.length})` },
          { id: 'leads', label: 'Tech Leads' },
          { id: 'architects', label: 'Mobile Architects' },
          { id: 'contributors', label: 'Core Contributors' },
        ].map((f) => (
          <button
            key={f.id}
            onClick={() => setFilter(f.id as any)}
            className={`px-4 py-2 rounded-xl text-xs font-semibold tracking-tight transition-all border ${
              filter === f.id
                ? 'bg-white text-slate-950 border-white shadow-md font-black'
                : 'bg-black text-slate-400 hover:text-white border-zinc-800'
            }`}
          >
            {f.label}
          </button>
        ))}
      </div>

      {/* Dynamic Testimonials Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {filteredTestimonials.map((t) => (
          <div
            key={t.id}
            className="group relative p-6 rounded-2xl bg-slate-950/90 dark:bg-black/95 backdrop-blur border border-slate-800 dark:border-white/10 hover:border-slate-700 dark:hover:border-white/20 hover:shadow-xl transition-all duration-300 flex flex-col justify-between"
          >
            <div>
              {/* Highlight Tag & Star Rating */}
              <div className="flex items-center justify-between mb-4 pb-3 border-b border-slate-800 dark:border-zinc-800">
                {t.highlightText && (
                  <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-md bg-zinc-900 text-slate-200 text-[10px] font-mono font-bold border border-zinc-800">
                    <Sparkles className="w-3 h-3 text-purple-400" />
                    {t.highlightText}
                  </span>
                )}
                <div className="flex items-center gap-0.5 text-amber-400">
                  {Array.from({ length: t.stars }).map((_, i) => (
                    <Star key={i} className="w-3.5 h-3.5 fill-amber-400 text-amber-400" />
                  ))}
                </div>
              </div>

              {/* Quote Body */}
              <p className="text-xs sm:text-sm text-slate-300 leading-relaxed mb-6 font-normal italic">
                "{t.quote}"
              </p>
            </div>

            {/* Author Profile */}
            <div className="flex items-center gap-3.5 pt-4 border-t border-slate-800 dark:border-zinc-800">
              <img
                src={t.avatar}
                alt={t.author}
                loading="lazy"
                className="w-10 h-10 rounded-full object-cover border border-zinc-700 flex-shrink-0 group-hover:scale-105 transition-transform"
              />
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-1.5">
                  <span className="text-xs font-bold text-white truncate">
                    {t.author}
                  </span>
                  <CheckCircle2 className="w-3.5 h-3.5 text-teal-400 flex-shrink-0" />
                </div>
                <div className="text-[11px] font-mono text-slate-400 truncate">
                  {t.role} · <span className="text-slate-200 font-semibold">{t.company}</span>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Dynamic Community Ecosystem Banner */}
      <div className="p-8 sm:p-10 rounded-3xl bg-black text-white border border-zinc-800 relative overflow-hidden shadow-2xl">
        <div className="absolute top-0 right-0 w-96 h-96 bg-purple-500/5 rounded-full blur-3xl pointer-events-none"></div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center relative z-10">
          {/* Left Stacked Avatars & Contributor Stats */}
          <div className="lg:col-span-7 space-y-4">
            <div className="flex items-center gap-2">
              {/* Stacked Avatar Group */}
              <div className="flex -space-x-3 overflow-hidden">
                {testimonials.map((t, idx) => (
                  <img
                    key={idx}
                    src={t.avatar}
                    alt={t.author}
                    className="inline-block h-9 w-9 rounded-full ring-2 ring-black object-cover"
                  />
                ))}
              </div>
              <span className="text-xs font-mono font-bold text-slate-400 pl-2">
                +5,000 Contributors
              </span>
            </div>

            <h3 className="text-2xl sm:text-3xl font-black tracking-tight text-white">
              5,000+ contributors. Open to everyone.
            </h3>

            <p className="text-xs sm:text-sm text-slate-300 leading-relaxed font-normal">
              Bloom is built in the open by Flutter core contributors, mobile architects, and developers worldwide. Join our Discord or star us on GitHub to shape the future of Flutter.
            </p>
          </div>

          {/* Right Interactive CTA Buttons */}
          <div className="lg:col-span-5 flex flex-col sm:flex-row lg:flex-col gap-3">
            <a
              href="https://github.com"
              target="_blank"
              rel="noreferrer"
              onClick={handleStarClick}
              className={`w-full px-5 py-3 rounded-xl font-bold text-xs flex items-center justify-between transition-all ${
                starred
                  ? 'bg-amber-400 text-slate-950 font-black shadow-lg shadow-amber-400/20'
                  : 'bg-white text-slate-950 hover:bg-slate-200 shadow-md font-black'
              }`}
            >
              <div className="flex items-center gap-2">
                <Star className={`w-4 h-4 ${starred ? 'fill-slate-950' : 'fill-slate-950'}`} />
                <span>{starred ? 'Starred on GitHub!' : 'Star Bloom on GitHub'}</span>
              </div>
              <span className="font-mono text-[11px] opacity-80">{starCount.toLocaleString()} ★</span>
            </a>

            <a
              href="https://discord.gg"
              target="_blank"
              rel="noreferrer"
              className="w-full px-5 py-3 rounded-xl bg-zinc-900 hover:bg-zinc-800 text-white font-bold text-xs flex items-center justify-between border border-zinc-800 transition-all"
            >
              <div className="flex items-center gap-2">
                <MessageSquare className="w-4 h-4 text-purple-400" />
                <span>Join the Discord Community</span>
              </div>
              <ArrowUpRight className="w-4 h-4 text-slate-400" />
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}
