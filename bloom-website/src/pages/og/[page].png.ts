import { ImageResponse } from '@vercel/og';

export const prerender = true;

export function getStaticPaths() {
  return [
    { params: { page: 'hub' } },
    { params: { page: 'build' } },
    { params: { page: 'ship' } },
    { params: { page: 'bloom' } },
  ];
}

let fontRegular: ArrayBuffer | null = null;
let fontBold: ArrayBuffer | null = null;

async function loadFonts() {
  if (!fontRegular || !fontBold) {
    const [reg, bold] = await Promise.all([
      fetch('https://cdn.jsdelivr.net/fontsource/fonts/plus-jakarta-sans@latest/latin-400-normal.ttf').then(res => res.arrayBuffer()),
      fetch('https://cdn.jsdelivr.net/fontsource/fonts/plus-jakarta-sans@latest/latin-800-normal.ttf').then(res => res.arrayBuffer())
    ]);
    fontRegular = reg;
    fontBold = bold;
  }
  return { fontRegular, fontBold };
}

export async function GET({ params }: { params: { page: string } }) {
  const page = params.page || 'hub';

  const pageConfig: Record<string, { title: string; subtitle: string; color: string; tag: string }> = {
    hub: {
      title: 'Build. Ship. Bloom.',
      subtitle: 'The opinionated application platform for Dart & Flutter.',
      color: '#8B5CF6',
      tag: 'PLATFORM HUB',
    },
    build: {
      title: 'BUILD — Framework & DX',
      subtitle: 'File-based routing, reactive signals, and automated CLI code generators.',
      color: '#8B5CF6',
      tag: 'CHAPTER 01',
    },
    ship: {
      title: 'SHIP — Cloud OTA Delivery',
      subtitle: 'Shorebird-powered instant over-the-air updates without App Store delays.',
      color: '#3B82F6',
      tag: 'CHAPTER 02',
    },
    bloom: {
      title: 'BLOOM — UI Studio',
      subtitle: 'shadcn/ui inspired mobile primitives with live interactive design token controls.',
      color: '#EC4899',
      tag: 'CHAPTER 03',
    },
  };

  const config = pageConfig[page] || pageConfig.hub;
  const { fontRegular: reg, fontBold: bold } = await loadFonts();

  return new ImageResponse(
    {
      type: 'div',
      props: {
        style: {
          width: '1200px',
          height: '630px',
          background: 'linear-gradient(135deg, #FAFAFA 0%, #FFFFFF 50%, #F1F5F9 100%)',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
          padding: '64px',
          fontFamily: '"Plus Jakarta Sans", system-ui, -apple-system, sans-serif',
          position: 'relative',
          overflow: 'hidden',
        },
        children: [
          // Background Glow Blobs (Softer for Light Mode)
          {
            type: 'div',
            props: {
              style: {
                position: 'absolute',
                top: '-100px',
                right: '-100px',
                width: '500px',
                height: '500px',
                borderRadius: '50%',
                background: `radial-gradient(circle, ${config.color}22 0%, transparent 70%)`,
              },
            },
          },
          {
            type: 'div',
            props: {
              style: {
                position: 'absolute',
                bottom: '-80px',
                left: '200px',
                width: '400px',
                height: '400px',
                borderRadius: '50%',
                background: 'radial-gradient(circle, #3B82F618 0%, transparent 70%)',
              },
            },
          },
          // Header Bar
          {
            type: 'div',
            props: {
              style: {
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
              },
              children: [
                {
                  type: 'div',
                  props: {
                    style: {
                      display: 'flex',
                      alignItems: 'center',
                      gap: '16px',
                    },
                    children: [
                      {
                        type: 'svg',
                        props: {
                          width: '52',
                          height: '52',
                          viewBox: '0 0 200 200',
                          fill: 'none',
                          children: [
                            { type: 'path', props: { d: 'M100 20 C130 20 145 60 125 90 C110 100 90 100 75 90 C55 60 70 20 100 20 Z', fill: 'url(#og_pink)', opacity: '0.95' } },
                            { type: 'path', props: { d: 'M180 80 C190 110 155 135 125 115 C115 100 105 85 115 70 C145 50 170 50 180 80 Z', fill: 'url(#og_orange)', opacity: '0.95' } },
                            { type: 'path', props: { d: 'M140 175 C115 185 85 155 100 125 C110 110 125 105 135 115 C165 135 165 165 140 175 Z', fill: 'url(#og_cyan)', opacity: '0.95' } },
                            { type: 'path', props: { d: 'M60 175 C35 165 35 135 65 115 C75 105 90 110 100 125 C115 155 85 185 60 175 Z', fill: 'url(#og_blue)', opacity: '0.95' } },
                            { type: 'path', props: { d: 'M20 80 C30 50 55 50 85 70 C95 85 85 100 75 115 C45 135 10 110 20 80 Z', fill: 'url(#og_purple)', opacity: '0.95' } },
                            { type: 'path', props: { d: 'M100 82 L104 96 L118 100 L104 104 L100 118 L96 104 L82 100 L96 96 Z', fill: '#FFFFFF' } },
                            {
                              type: 'defs',
                              props: {
                                children: [
                                  { type: 'linearGradient', props: { id: 'og_pink', x1: '100', y1: '20', x2: '100', y2: '100', children: [{ type: 'stop', props: { stopColor: '#FF4B8B' } }, { type: 'stop', props: { offset: '1', stopColor: '#FF8BA7' } }] } },
                                  { type: 'linearGradient', props: { id: 'og_orange', x1: '180', y1: '80', x2: '110', y2: '110', children: [{ type: 'stop', props: { stopColor: '#FF884D' } }, { type: 'stop', props: { offset: '1', stopColor: '#FFA066' } }] } },
                                  { type: 'linearGradient', props: { id: 'og_cyan', x1: '140', y1: '175', x2: '100', y2: '115', children: [{ type: 'stop', props: { stopColor: '#20C9B0' } }, { type: 'stop', props: { offset: '1', stopColor: '#48E5C8' } }] } },
                                  { type: 'linearGradient', props: { id: 'og_blue', x1: '60', y1: '175', x2: '100', y2: '115', children: [{ type: 'stop', props: { stopColor: '#2563EB' } }, { type: 'stop', props: { offset: '1', stopColor: '#60A5FA' } }] } },
                                  { type: 'linearGradient', props: { id: 'og_purple', x1: '20', y1: '80', x2: '90', y2: '110', children: [{ type: 'stop', props: { stopColor: '#8B5CF6' } }, { type: 'stop', props: { offset: '1', stopColor: '#A855F7' } }] } },
                                ],
                              },
                            },
                          ],
                        },
                      },
                      {
                        type: 'div',
                        props: {
                          style: {
                            fontSize: '32px',
                            fontWeight: '900',
                            color: '#0F172A',
                            letterSpacing: '-1px',
                          },
                          children: 'bloom',
                        },
                      },
                    ],
                  },
                },
                {
                  type: 'div',
                  props: {
                    style: {
                      padding: '10px 22px',
                      borderRadius: '100px',
                      border: `1px solid ${config.color}33`,
                      background: `${config.color}11`,
                      color: config.color,
                      fontSize: '14px',
                      fontWeight: '700',
                      letterSpacing: '2px',
                    },
                    children: config.tag,
                  },
                },
              ],
            },
          },
          // Body Text
          {
            type: 'div',
            props: {
              style: { display: 'flex', flexDirection: 'column', gap: '20px' },
              children: [
                {
                  type: 'div',
                  props: {
                    style: {
                      fontSize: '68px',
                      fontWeight: '900',
                      color: '#0F172A',
                      lineHeight: '1.05',
                      letterSpacing: '-2px',
                    },
                    children: config.title,
                  },
                },
                {
                  type: 'div',
                  props: {
                    style: {
                      fontSize: '24px',
                      color: '#475569',
                      fontWeight: '400',
                      lineHeight: '1.5',
                      maxWidth: '750px',
                    },
                    children: config.subtitle,
                  },
                },
              ],
            },
          },
          // Footer Bar
          {
            type: 'div',
            props: {
              style: {
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                borderTop: '1px solid #E2E8F0',
                paddingTop: '24px',
              },
              children: [
                {
                  type: 'div',
                  props: {
                    style: {
                      display: 'flex',
                      alignItems: 'center',
                      gap: '20px',
                      fontSize: '14px',
                      color: '#475569',
                      fontWeight: '700',
                      letterSpacing: '1px',
                    },
                    children: [
                      { type: 'span', props: { style: { color: '#8B5CF6' }, children: 'BUILD' } },
                      { type: 'span', props: { children: '•' } },
                      { type: 'span', props: { style: { color: '#3B82F6' }, children: 'SHIP' } },
                      { type: 'span', props: { children: '•' } },
                      { type: 'span', props: { style: { color: '#EC4899' }, children: 'BLOOM' } },
                    ],
                  },
                },
                {
                  type: 'div',
                  props: {
                    style: {
                      fontSize: '16px',
                      color: '#64748B',
                      fontWeight: '600',
                    },
                    children: 'bloom.dev',
                  },
                },
              ],
            },
          },
        ],
      },
    },
    {
      width: 1200,
      height: 630,
      fonts: [
        {
          name: 'Plus Jakarta Sans',
          data: reg!,
          weight: 400,
          style: 'normal',
        },
        {
          name: 'Plus Jakarta Sans',
          data: bold!,
          weight: 800,
          style: 'normal',
        },
      ],
    }
  );
}
