#!/usr/bin/env python3
"""
Fetch ALL shadcn/ui documentation pages as markdown.
Saves to docs/shadcn/ directory.
"""
import re, json, os, sys, time, html
from urllib.request import urlopen, Request
from urllib.parse import urljoin, urlparse
from html.parser import HTMLParser

OUT_DIR = "docs/shadcn"
BASE = "https://ui.shadcn.com"
SEEN = set()
PAGES = []

class MDStripper(HTMLParser):
    """Minimal HTML-to-markdown converter for shadcn docs."""
    def __init__(self):
        super().__init__()
        self.lines = []
        self.in_code = False
        self.code_lang = ""
        self.code_buf = []
        self.in_pre = False
        self.in_ul = False
        self.in_ol = False
        self.list_idx = 0
        self.skip_tags = {"script", "style", "nav", "header", "footer"}
        self.skip_depth = 0
        self.in_h = False
        self.h_level = 0
        self.h_buf = []
        self.in_p = False
        self.p_buf = []
        self.in_strong = False
        self.in_em = False
        self.in_a = False
        self.a_href = ""
        self.a_buf = []
        self.in_li = False
        self.li_buf = []
        self.in_table = False
        self.in_tr = False
        self.in_th = False
        self.in_td = False
        self.table_cells = []
        self.table_row = []
        self.table_headers = []
        self.seen_links = set()

    def _flush_p(self):
        if self.p_buf:
            t = ''.join(self.p_buf).strip()
            if t:
                self.lines.append(('p', t))
            self.p_buf = []

    def _flush_h(self):
        if self.h_buf:
            t = ''.join(self.h_buf).strip()
            if t:
                self.lines.append(('h', self.h_level, t))
            self.h_buf = []

    def _flush_li(self):
        if self.li_buf:
            t = ''.join(self.li_buf).strip()
            if t:
                self.lines.append(('li', t))
            self.li_buf = []

    def handle_starttag(self, tag, attrs):
        attrs_d = dict(attrs)
        if tag in self.skip_tags:
            self.skip_depth += 1
            return
        if self.skip_depth: return

        if tag in ('h1','h2','h3','h4','h5','h6'):
            self._flush_p()
            self.in_h = True
            self.h_level = int(tag[1])
            self.h_buf = []
        elif tag == 'p':
            self.in_p = True
            self.p_buf = []
        elif tag == 'strong' or tag == 'b':
            self.in_strong = True
            if self.in_p: self.p_buf.append('**')
            elif self.in_h: self.h_buf.append('**')
            elif self.in_li: self.li_buf.append('**')
        elif tag in ('em', 'i'):
            self.in_em = True
            if self.in_p: self.p_buf.append('*')
            elif self.in_h: self.h_buf.append('*')
            elif self.in_li: self.li_buf.append('*')
        elif tag == 'a':
            self.in_a = True
            self.a_href = attrs_d.get('href', '')
            self.a_buf = []
        elif tag == 'code':
            if not self.in_pre:
                if self.in_p: self.p_buf.append('`')
                elif self.in_li: self.li_buf.append('`')
        elif tag == 'pre':
            self.in_pre = True
            self.code_buf = []
            # check for language class
            cls = attrs_d.get('class', '')
            m = re.search(r'language-(\w+)', cls)
            self.code_lang = m.group(1) if m else ''
        elif tag == 'ul':
            self.in_ul = True
            self._flush_p()
        elif tag == 'ol':
            self.in_ol = True
            self.list_idx = 0
            self._flush_p()
        elif tag == 'li':
            self._flush_li()
            self.in_li = True
            self.li_buf = []
            if self.in_ul:
                self.li_buf.append('- ')
            elif self.in_ol:
                self.list_idx += 1
                self.li_buf.append(f'{self.list_idx}. ')
        elif tag == 'br':
            if self.in_p: self.p_buf.append('\n')
        elif tag == 'hr':
            self._flush_p()
            self.lines.append(('hr',))
        elif tag == 'table':
            self.in_table = True
            self.table_headers = []
            self.table_cells = []
        elif tag == 'tr':
            self.table_row = []
        elif tag in ('th', 'td'):
            self.in_th = tag == 'th'
            self.in_td = tag == 'td'
            self.a_buf = []
        elif tag == 'div':
            cls = attrs_d.get('class', '')
            if 'copy-button' in cls or 'copy' in cls:
                pass  # skip copy buttons

    def handle_endtag(self, tag):
        if tag in self.skip_tags:
            self.skip_depth -= 1
            return
        if self.skip_depth: return

        if tag in ('h1','h2','h3','h4','h5','h6'):
            self._flush_h()
            self.in_h = False
        elif tag == 'p':
            self._flush_p()
            self.in_p = False
        elif tag in ('strong', 'b'):
            self.in_strong = False
            if self.in_p: self.p_buf.append('**')
            elif self.in_h: self.h_buf.append('**')
            elif self.in_li: self.li_buf.append('**')
        elif tag in ('em', 'i'):
            self.in_em = False
            if self.in_p: self.p_buf.append('*')
            elif self.in_h: self.h_buf.append('*')
            elif self.in_li: self.li_buf.append('*')
        elif tag == 'a':
            self.in_a = False
            txt = ''.join(self.a_buf).strip()
            href = self.a_href
            if txt and href and href not in ('#', txt) and not href.startswith('#'):
                md = f'[{txt}]({href})'
            else:
                md = txt
            if self.in_p: self.p_buf.append(md)
            elif self.in_li: self.li_buf.append(md)
            self.a_buf = []
        elif tag == 'code':
            if not self.in_pre:
                if self.in_p: self.p_buf.append('`')
                elif self.in_li: self.li_buf.append('`')
        elif tag == 'pre':
            self.in_pre = False
            code = ''.join(self.code_buf)
            lang = self.code_lang
            self.lines.append(('code', lang, code))
            self.code_buf = []
        elif tag == 'ul':
            self._flush_li()
            self.in_ul = False
        elif tag == 'ol':
            self._flush_li()
            self.in_ol = False
        elif tag == 'li':
            self._flush_li()
            self.in_li = False
        elif tag == 'table':
            self.in_table = False
        elif tag == 'tr':
            if self.in_table:
                if self.table_headers:
                    self.table_cells.append(list(self.table_headers))
                    self.table_headers = []
                self.table_cells.append(list(self.table_row))
                self.table_row = []
        elif tag in ('th',):
            self.in_th = False
            txt = ''.join(self.a_buf).strip()
            if txt:
                self.table_headers.append(txt)
                self.table_row.append(txt)
        elif tag == 'td':
            txt = ''.join(self.a_buf).strip()
            if txt:
                self.table_row.append(txt)

    def handle_data(self, data):
        if self.skip_depth: return
        if self.in_pre:
            self.code_buf.append(data)
            return
        if self.in_code:
            return
        if self.in_a:
            self.a_buf.append(data)
            return
        if self.in_h:
            self.h_buf.append(data)
        elif self.in_p:
            self.p_buf.append(data)
        elif self.in_li:
            self.li_buf.append(data)
        elif self.in_th or self.in_td:
            self.a_buf.append(data)

    def render(self):
        """Convert parsed lines to markdown string."""
        out = []
        for item in self.lines:
            kind = item[0]
            if kind == 'h':
                _, level, text = item
                out.append(f'{"#" * level} {text}\n')
            elif kind == 'p':
                _, text = item
                out.append(f'{text}\n\n')
            elif kind == 'li':
                _, text = item
                out.append(f'{text}\n')
            elif kind == 'hr':
                out.append('---\n')
            elif kind == 'code':
                _, lang, code = item
                out.append(f'```{lang}\n{code}```\n\n')
        return ''.join(out)


def fetch(url):
    """Fetch a URL and return text."""
    req = Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        resp = urlopen(req, timeout=30)
        return resp.read().decode('utf-8', errors='replace')
    except Exception as e:
        print(f"  ERROR: {e}")
        return None


def extract_links(html_text, base_url):
    """Extract all internal doc links from an HTML page."""
    links = set()
    for m in re.finditer(r'href="([^"]*)"', html_text):
        href = m.group(1)
        # Only internal docs links
        if href.startswith('/docs/') or href.startswith('/docs/components/') or href.startswith('/docs/registry/') or href.startswith('/docs/helpers/') or href.startswith('/docs/forms/') or href.startswith('/docs/utils/') or href.startswith('/docs/react/'):
            links.add(urljoin(base_url, href))
    return links


def page_to_markdown(url):
    """Fetch a page and convert its main content to markdown."""
    html_text = fetch(url)
    if not html_text:
        return None, set()

    # Extract title
    title_m = re.search(r'<title>(.*?)</title>', html_text, re.DOTALL)
    title = title_m.group(1).strip() if title_m else url

    # Find main content area
    main_m = re.search(r'<main[^>]*>(.*?)</main>', html_text, re.DOTALL)
    if not main_m:
        # Fallback: try article or div[role=main]
        main_m = re.search(r'<article[^>]*>(.*?)</article>', html_text, re.DOTALL)
    if not main_m:
        main_m = re.search(r'<div[^>]*role="main"[^>]*>(.*?)</div>', html_text, re.DOTALL)

    content_html = main_m.group(1) if main_m else html_text

    # Extract links before stripping
    links = extract_links(html_text, url)

    # Parse content
    parser = MDStripper()
    parser.feed(content_html)
    markdown = parser.render()

    # Clean up excessive whitespace
    markdown = re.sub(r'\n{3,}', '\n\n', markdown)

    full = f"# {title}\n\n> Source: {url}\n\n{markdown}"
    return full, links


def slugify(url):
    """Convert a URL to a filename."""
    path = urlparse(url).path.strip('/')
    if not path:
        return 'index'
    return path.replace('/', '_').replace('-', '_')


def crawl(start_urls, max_pages=250):
    """Crawl all doc pages from starting URLs."""
    global SEEN, PAGES
    queue = list(start_urls)

    while queue and len(SEEN) < max_pages:
        url = queue.pop(0)
        if url in SEEN:
            continue
        SEEN.add(url)

        print(f"[{len(SEEN):3d}] {url}")
        markdown, links = page_to_markdown(url)

        if markdown:
            fname = slugify(url)
            fpath = os.path.join(OUT_DIR, f"{fname}.md")
            with open(fpath, 'w') as f:
                f.write(markdown)
            print(f"       -> saved {fpath} ({len(markdown)} chars)")
            PAGES.append({'url': url, 'file': fpath, 'title': '', 'chars': len(markdown)})

        # Add new links
        for link in links:
            if link not in SEEN and link not in queue:
                queue.append(link)

        time.sleep(0.3)  # rate limiting


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    start_urls = [
        f"{BASE}/docs/installation",
        f"{BASE}/docs/components",
        f"{BASE}/docs/theming",
        f"{BASE}/docs/typeset",
        f"{BASE}/docs/cli",
        f"{BASE}/docs/dark-mode",
        f"{BASE}/docs/components-json",
        f"{BASE}/docs/package-imports",
        f"{BASE}/docs/monorepo",
        f"{BASE}/docs/skills",
        f"{BASE}/docs/registry",
        f"{BASE}/docs/registry/registry-json",
        f"{BASE}/docs/registry/registry-item-json",
        f"{BASE}/docs/helpers/ai-sdk",
        f"{BASE}/docs/forms/react-hook-form",
        f"{BASE}/docs/utils/scroll-fade",
        f"{BASE}/docs/javascript",
        f"{BASE}/docs/figma",
        f"{BASE}/blocks",
        f"{BASE}/charts",
    ]

    crawl(start_urls)

    # Write index
    idx_path = os.path.join(OUT_DIR, "index.json")
    with open(idx_path, 'w') as f:
        json.dump(PAGES, f, indent=2)
    print(f"\nDone. Fetched {len(SEEN)} pages, saved {len(PAGES)} markdown files.")
    print(f"Index written to {idx_path}")


if __name__ == '__main__':
    main()
