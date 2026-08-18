import { join } from 'path';
import { existsSync, statSync } from 'fs';

const PORT = 4399;
const DIST_DIR = join(import.meta.dir, '../dist');

Bun.serve({
  port: PORT,
  async fetch(req) {
    const url = new URL(req.url);
    let pathname = decodeURIComponent(url.pathname);

    // Default to index.html for root or directories
    let filePath = join(DIST_DIR, pathname);
    if (existsSync(filePath) && statSync(filePath).isDirectory()) {
      filePath = join(filePath, 'index.html');
    } else if (!existsSync(filePath) && existsSync(`${filePath}.html`)) {
      filePath = `${filePath}.html`;
    } else if (!existsSync(filePath) && existsSync(join(filePath, 'index.html'))) {
      filePath = join(filePath, 'index.html');
    }

    const file = Bun.file(filePath);
    if (await file.exists()) {
      return new Response(file);
    }

    return new Response('Not Found', { status: 404 });
  },
});

console.log(`Server running at http://localhost:${PORT}`);
