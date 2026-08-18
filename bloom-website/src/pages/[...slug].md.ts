import type { APIRoute } from 'astro';
import { getAllStaticMarkdownPaths } from '../lib/llms-generator';

export function getStaticPaths() {
  return getAllStaticMarkdownPaths();
}

export const GET: APIRoute = async ({ props }) => {
  const content = (props as { content: string }).content;
  return new Response(content, {
    status: 200,
    headers: {
      'Content-Type': 'text/markdown; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
};
