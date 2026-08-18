import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function walkDir(dir: string, fileList: string[] = []): string[] {
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    if (stat.isDirectory()) {
      walkDir(filePath, fileList);
    } else if (/\.(astro|tsx|ts|jsx|js|css)$/.test(file)) {
      fileList.push(filePath);
    }
  }
  return fileList;
}

const replacements: [RegExp, string][] = [
  // Slate dark backgrounds -> Pure AMOLED black / zinc
  [/dark:bg-slate-950\/95/g, 'dark:bg-black/95'],
  [/dark:bg-slate-950\/90/g, 'dark:bg-black/90'],
  [/dark:bg-slate-950\/80/g, 'dark:bg-black/80'],
  [/dark:bg-slate-950\/60/g, 'dark:bg-black/60'],
  [/dark:bg-slate-950\/50/g, 'dark:bg-black/50'],
  [/dark:bg-slate-950\/40/g, 'dark:bg-black/40'],
  [/dark:bg-slate-950\/30/g, 'dark:bg-black/30'],
  [/dark:bg-slate-950/g, 'dark:bg-black'],

  [/dark:bg-slate-900\/95/g, 'dark:bg-zinc-950/95'],
  [/dark:bg-slate-900\/90/g, 'dark:bg-zinc-950/90'],
  [/dark:bg-slate-900\/80/g, 'dark:bg-zinc-950/80'],
  [/dark:bg-slate-900\/70/g, 'dark:bg-zinc-950/70'],
  [/dark:bg-slate-900\/60/g, 'dark:bg-zinc-950/60'],
  [/dark:bg-slate-900\/50/g, 'dark:bg-zinc-950/50'],
  [/dark:bg-slate-900\/40/g, 'dark:bg-zinc-950/40'],
  [/dark:bg-slate-900\/30/g, 'dark:bg-zinc-950/30'],
  [/dark:bg-slate-900\/20/g, 'dark:bg-zinc-950/20'],
  [/dark:bg-slate-900/g, 'dark:bg-zinc-950'],

  [/dark:bg-slate-800\/90/g, 'dark:bg-zinc-900/90'],
  [/dark:bg-slate-800\/80/g, 'dark:bg-zinc-900/80'],
  [/dark:bg-slate-800\/60/g, 'dark:bg-zinc-900/60'],
  [/dark:bg-slate-800\/50/g, 'dark:bg-zinc-900/50'],
  [/dark:bg-slate-800\/40/g, 'dark:bg-zinc-900/40'],
  [/dark:bg-slate-800\/30/g, 'dark:bg-zinc-900/30'],
  [/dark:bg-slate-800/g, 'dark:bg-zinc-900'],

  // Slate dark borders -> Zinc 800 AMOLED
  [/dark:border-slate-800\/90/g, 'dark:border-zinc-800'],
  [/dark:border-slate-800\/80/g, 'dark:border-zinc-800'],
  [/dark:border-slate-800\/60/g, 'dark:border-zinc-800'],
  [/dark:border-slate-800\/50/g, 'dark:border-zinc-800'],
  [/dark:border-slate-800\/40/g, 'dark:border-zinc-800'],
  [/dark:border-slate-800\/30/g, 'dark:border-zinc-800'],
  [/dark:border-slate-800/g, 'dark:border-zinc-800'],

  [/dark:border-slate-700\/80/g, 'dark:border-zinc-800'],
  [/dark:border-slate-700\/60/g, 'dark:border-zinc-800'],
  [/dark:border-slate-700/g, 'dark:border-zinc-800'],

  // Hover states
  [/dark:hover:bg-slate-900\/80/g, 'dark:hover:bg-zinc-900/80'],
  [/dark:hover:bg-slate-900\/50/g, 'dark:hover:bg-zinc-900/50'],
  [/dark:hover:bg-slate-900/g, 'dark:hover:bg-zinc-900'],
  [/dark:hover:bg-slate-800\/80/g, 'dark:hover:bg-zinc-800/80'],
  [/dark:hover:bg-slate-800/g, 'dark:hover:bg-zinc-800'],
  [/dark:hover:border-slate-700/g, 'dark:hover:border-zinc-700'],
  [/dark:hover:border-slate-600/g, 'dark:hover:border-zinc-700'],

  // Hex hardcoded dark blue surfaces
  [/dark:bg-\[#090C10\]/g, 'dark:bg-black'],
  [/dark:bg-\[#090C14\]/g, 'dark:bg-black'],
  [/dark:bg-\[#0D1117\]/g, 'dark:bg-black'],
  [/dark:bg-\[#0B0F19\]/g, 'dark:bg-black'],
  [/dark:bg-\[#070A10\]/g, 'dark:bg-black'],
  [/dark:bg-\[#0D121F\]/g, 'dark:bg-zinc-950'],
  [/dark:bg-\[#05080F\]/g, 'dark:bg-zinc-950'],
  [/dark:border-\[#30363D\]/g, 'dark:border-zinc-800'],
];

const srcDir = path.resolve(__dirname, '../src');
const files = walkDir(srcDir);

let totalChanged = 0;
for (const file of files) {
  let content = fs.readFileSync(file, 'utf-8');
  let original = content;

  for (const [regex, replacement] of replacements) {
    content = content.replace(regex, replacement);
  }

  if (content !== original) {
    fs.writeFileSync(file, content, 'utf-8');
    totalChanged++;
    console.log(`Updated AMOLED tokens in: ${path.relative(srcDir, file)}`);
  }
}

console.log(`\nSuccessfully normalized AMOLED tokens across ${totalChanged} files!`);
