import type { APIRoute } from 'astro';
import { generateLlmsFullTxt } from '../lib/llms-generator';

export const GET: APIRoute = async () => {
  const content = generateLlmsFullTxt();
  return new Response(content, {
    status: 200,
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
};
