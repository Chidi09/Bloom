import fs from 'node:fs';
import path from 'node:path';
import { marked } from 'marked';

export interface DocPage {
  section: string;
  slug: string;
  title: string;
  description: string;
  rawMarkdown: string;
  htmlContent: string;
  toc: { id: string; title: string }[];
  category: string;
  filePath: string;
}

export interface DocSectionNav {
  title: string;
  section: string;
  items: { title: string; href: string; slug: string }[];
}

function getDocsBaseDir(): string {
  const candidates = [
    path.resolve(process.cwd(), 'src/docs-content'),
    path.resolve(process.cwd(), 'docs-content'),
    path.resolve(process.cwd(), '../docs'),
    path.resolve('/root/dev/Bloom/docs'),
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  return path.resolve(process.cwd(), 'src/docs-content');
}

const DOCS_BASE_DIR = getDocsBaseDir();

const SECTIONS_CONFIG: { dir: string; sectionName: string; categoryTitle: string }[] = [
  { dir: 'getting-started', sectionName: 'getting-started', categoryTitle: 'Getting Started' },
  { dir: 'runtime', sectionName: 'runtime', categoryTitle: 'Runtime & Architecture' },
  { dir: 'data', sectionName: 'data', categoryTitle: 'Data Layer & Caching' },
  { dir: 'native', sectionName: 'native', categoryTitle: 'Native Platform & Prebuild' },
  { dir: 'cli', sectionName: 'cli', categoryTitle: 'Bloom CLI Commands' },
  { dir: 'dev-experience', sectionName: 'dev-experience', categoryTitle: 'Developer Experience & DevTools' },
  { dir: 'adapters', sectionName: 'adapters', categoryTitle: 'Backend Adapters' },
  { dir: 'guides', sectionName: 'guides', categoryTitle: 'Architecture Guides & Recipes' },
];

function slugify(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\w\s-]/g, '')
    .replace(/\s+/g, '-');
}

export function getAllFrameworkDocs(): DocPage[] {
  const docs: DocPage[] = [];

  for (const { dir, sectionName, categoryTitle } of SECTIONS_CONFIG) {
    const fullDir = path.join(DOCS_BASE_DIR, dir);
    if (!fs.existsSync(fullDir)) continue;

    const files = fs.readdirSync(fullDir).filter((f) => f.endsWith('.md'));

    for (const file of files) {
      const filePath = path.join(fullDir, file);
      const content = fs.readFileSync(filePath, 'utf-8');

      // Extract slug from filename (e.g. 01_installation.md -> installation, boot_lifecycle.md -> boot-lifecycle)
      const rawSlug = file.replace(/\.md$/, '').replace(/^\d+[-_]/, '');
      const slug = rawSlug.replace(/_/g, '-');

      // Extract first H1 heading for title
      const h1Match = content.match(/^#\s+(.+)$/m);
      let title = h1Match ? h1Match[1].replace(/^\d+[\.\s]+/, '').trim() : slug;
      // Strip leading emojis or numbers for clean title
      title = title.replace(/^[^\w\s]+/, '').trim();

      // Extract lead paragraph as description
      const lines = content.split('\n');
      let description = 'Comprehensive guide and architecture reference for the Bloom Framework.';
      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed && !trimmed.startsWith('#') && !trimmed.startsWith('---') && !trimmed.startsWith('```')) {
          description = trimmed;
          break;
        }
      }

      // Extract H2 headings for Table of Contents
      const toc: { id: string; title: string }[] = [];
      const h2Matches = content.matchAll(/^##\s+(.+)$/gm);
      for (const match of h2Matches) {
        const rawHeading = match[1].trim();
        const cleanHeading = rawHeading.replace(/^[^\w\s]+/, '').trim();
        const id = slugify(cleanHeading);
        toc.push({ id, title: cleanHeading });
      }

      // Render Markdown to HTML with marked
      const htmlContent = marked.parse(content, { async: false }) as string;

      docs.push({
        section: sectionName,
        slug,
        title,
        description,
        rawMarkdown: content,
        htmlContent,
        toc,
        category: categoryTitle,
        filePath,
      });
    }
  }

  return docs;
}

export function getDocsNav(): DocSectionNav[] {
  const allDocs = getAllFrameworkDocs();
  return SECTIONS_CONFIG.map(({ sectionName, categoryTitle }) => {
    const items = allDocs
      .filter((d) => d.section === sectionName)
      .map((d) => ({
        title: d.title,
        href: `/docs/${d.section}/${d.slug}`,
        slug: `${d.section}-${d.slug}`,
      }));

    return {
      title: categoryTitle,
      section: sectionName,
      items,
    };
  }).filter((s) => s.items.length > 0);
}
