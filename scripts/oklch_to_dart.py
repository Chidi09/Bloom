#!/usr/bin/env python3
"""
Convert shadcn/ui CSS variable tokens (oklch + hex) to exact Dart Color hex.
Reads a CSS file, extracts a set of --token values, converts oklch to sRGB hex.
"""
import re, sys, math

def oklch_to_srgb(L, C, H):
    # OKLab -> sRGB (CSS Color 4)
    h_rad = math.radians(H)
    a = C * math.cos(h_rad)
    b = C * math.sin(h_rad)

    # OKLab -> LMS
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b

    l = l_ ** 3
    m = m_ ** 3
    s = s_ ** 3

    # LMS -> linear sRGB
    r_lin = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g_lin = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    b_lin = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    def to_srgb(c):
        c = max(0.0, min(1.0, c))
        if c < 0.0031308:
            return 12.92 * c
        return 1.055 * (c ** (1 / 2.4)) - 0.055
    return round(to_srgb(r_lin) * 255), round(to_srgb(g_lin) * 255), round(to_srgb(b_lin) * 255)

def parse_hex(h):
    h = h.lstrip('#')
    if len(h) == 3:
        h = ''.join(c * 2 for c in h)
    if len(h) == 4:
        h = ''.join(c * 2 for c in list(h)[:3]) + h[3]  # ignore alpha-ish
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)

def resolve_token_value(decl_value, vars_map):
    """Resolve a value that may reference other vars and blend factors."""
    # handle 'oklch(1 0 0 / 10%)'
    m = re.match(r'oklch\(\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*(?:/\s*([\d.]+)%?)?\s*\)', decl_value)
    if m:
        L, C, H = float(m.group(1)), float(m.group(2)), float(m.group(3))
        rgb = oklch_to_srgb(L, C, H)
        alpha = int(float(m.group(4))) if m.group(4) else 255
        if alpha < 255:
            frac = alpha / 255
            bg = (255, 255, 255)  # composite over white
            rgb = tuple(round(r * frac + bg[i] * (1 - frac)) for i, r in enumerate(rgb))
        return '#%02X%02X%02X' % rgb
    m = re.match(r'#([0-9a-fA-F]{3,8})', decl_value)
    if m:
        return '#' + m.group(1)
    # var reference
    m = re.match(r'var\(--([a-z0-9-]+)\)', decl_value)
    if m:
        return vars_map.get(m.group(1))
    return decl_value

def main():
    css_path = sys.argv[1]
    text = open(css_path).read()

    # collect :root and .dark blocks
    blocks = {'light': {}, 'dark': {}}
    # split by section
    for section_name, pattern in [('light', r':root\s*\{(.*?)\}'), ('dark', r'\.dark\s*\{(.*?)\}')]:
        m = re.search(pattern, text, re.DOTALL)
        if not m:
            continue
        for decl in re.finditer(r'--([a-z0-9-]+)\s*:\s*([^;]+);', m.group(1)):
            key, val = decl.group(1), decl.group(2).strip()
            blocks[section_name][key] = val

    # resolve light (background usually white)
    resolved = {}
    for _ in range(5):  # few passes for var refs
        for k, v in list(blocks['light'].items()):
            rv = resolve_token_value(v, blocks['light'])
            if rv.startswith('#'):
                blocks['light'][k] = rv

    print("=== LIGHT ===")
    for k, v in blocks['light'].items():
        r = resolve_token_value(v, blocks['light'])
        if r.startswith('#'):
            r, g, b = parse_hex(r)
            print(f"{k:28s} {v:38s} -> 0xFF{r:02X}{g:02X}{b:02X}  (#{r:02X}{g:02X}{b:02X})")

    print("\n=== DARK ===")
    for k, v in blocks['dark'].items():
        r = resolve_token_value(v, blocks['dark'])
        if r.startswith('#'):
            r, g, b = parse_hex(r)
            print(f"{k:28s} {v:38s} -> 0xFF{r:02X}{g:02X}{b:02X}  (#{r:02X}{g:02X}{b:02X})")

    # Print derived radius scale for reference
    rm = re.search(r'--radius\s*:\s*([\d.]+rem)', text)
    if rm:
        base = float(rm.group(1).replace('rem', ''))
        print(f"\n=== RADIUS (base {base}rem = {base*16:.0f}px) ===")
        for name, mult in [('sm', 0.6), ('md', 0.8), ('lg', 1.0), ('xl', 1.4), ('2xl', 1.8), ('3xl', 2.2), ('4xl', 2.6)]:
            print(f"radius-{name}: {base*16*mult:.0f}px")

if __name__ == '__main__':
    main()
