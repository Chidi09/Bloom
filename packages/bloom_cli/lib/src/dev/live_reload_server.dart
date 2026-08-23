import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'dev_proxy.dart';

/// Zero-configuration HTTP dev server with Server-Sent Events (SSE) live reload.
class BloomLiveReloadServer {
  final Directory webDir;
  final String host;
  final int port;
  final bool autoInjectScript;
  final List<BloomDevProxyRule> proxyRules;

  HttpServer? _server;
  final List<HttpResponse> _sseClients = [];
  final BloomDevProxy _proxy = BloomDevProxy();
  late final List<BloomDevProxyRule> _sortedProxyRules;

  static const String liveReloadScript = r'''
<script>
  (() => {
    if (window.__BLOOM_HR_ACTIVE__) return;
    window.__BLOOM_HR_ACTIVE__ = true;

    const NS = 'http://www.w3.org/2000/svg';
    const bloomMarkPaths = [
      ['M100 20 C130 20 145 60 125 90 C110 100 90 100 75 90 C55 60 70 20 100 20 Z', '#pf_pink'],
      ['M180 80 C190 110 155 135 125 115 C115 100 105 85 115 70 C145 50 170 50 180 80 Z', '#pf_orange'],
      ['M140 175 C115 185 85 155 100 125 C110 110 125 105 135 115 C165 135 165 165 140 175 Z', '#pf_cyan'],
      ['M60 175 C35 165 35 135 65 115 C75 105 90 110 100 125 C115 155 85 185 60 175 Z', '#pf_blue'],
      ['M20 80 C30 50 55 50 85 70 C95 85 85 100 75 115 C45 135 10 110 20 80 Z', '#pf_purple'],
    ];

    function svgEl(tag, attrs) {
      const el = document.createElementNS(NS, tag);
      for (const k in attrs) el.setAttribute(k, attrs[k]);
      return el;
    }

    function buildBloomMark(size) {
      const svg = svgEl('svg', { viewBox: '0 0 200 200', width: size, height: size, fill: 'none' });
      const defs = svgEl('defs', {});
      const grads = [
        ['pf_pink', '100', '20', '100', '100', '#FF4B8B', '#FF8BA7'],
        ['pf_orange', '180', '80', '110', '110', '#FF884D', '#FFA066'],
        ['pf_cyan', '140', '175', '100', '115', '#20C9B0', '#48E5C8'],
        ['pf_blue', '60', '175', '100', '115', '#2563EB', '#60A5FA'],
        ['pf_purple', '20', '80', '90', '110', '#8B5CF6', '#A855F7'],
      ];
      for (const [id, x1, y1, x2, y2, c1, c2] of grads) {
        const g = svgEl('linearGradient', { id, x1, y1, x2, y2 });
        const s1 = svgEl('stop', { 'stop-color': c1 });
        const s2 = svgEl('stop', { offset: '1', 'stop-color': c2 });
        g.appendChild(s1); g.appendChild(s2);
        defs.appendChild(g);
      }
      svg.appendChild(defs);
      for (const [d, fillRef] of bloomMarkPaths) {
        svg.appendChild(svgEl('path', { d, fill: 'url(' + fillRef + ')', opacity: '0.9' }));
      }
      svg.appendChild(svgEl('path', {
        d: 'M100 82 L104 96 L118 100 L104 104 L100 118 L96 104 L82 100 L96 96 Z',
        fill: '#FFFFFF',
      }));
      return svg;
    }

    function svgIcon(name, size) {
      size = size || 13;
      const icons = {
        overview: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"/>',
        errors: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>',
        history: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>',
        console: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>',
        reload: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>',
        copy: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/>',
        check: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>',
        close: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>',
      };
      const svg = svgEl('svg', {
        viewBox: '0 0 24 24',
        width: size,
        height: size,
        fill: 'none',
        stroke: 'currentColor',
      });
      svg.innerHTML = icons[name] || '';
      return svg;
    }

    function formatTimeAgo(timestamp) {
      if (!timestamp) return 'Never';
      const elapsed = Math.max(0, Math.floor((Date.now() - timestamp) / 1000));
      if (elapsed < 3) return 'Just now';
      if (elapsed < 60) return elapsed + 's ago';
      const mins = Math.floor(elapsed / 60);
      if (mins < 60) return mins + 'm ago';
      const hours = Math.floor(mins / 60);
      return hours + 'h ago';
    }

    function formatClock(timestamp) {
      const d = new Date(timestamp);
      const pad = (n) => (n < 10 ? '0' + n : n);
      return pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds());
    }

    const STYLES = `
      .bloom-root {
        position: fixed;
        left: 16px;
        bottom: 16px;
        z-index: 2147483647;
        font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
        font-size: 12px;
        line-height: 1.45;
        color: #f4f4f5;
        -webkit-font-smoothing: antialiased;
        box-sizing: border-box;
      }
      .bloom-root * {
        box-sizing: border-box;
        margin: 0;
        padding: 0;
      }
      .bloom-badge-wrap {
        position: relative;
        display: inline-block;
      }
      .bloom-badge {
        width: 36px;
        height: 36px;
        border-radius: 9999px;
        border: 1px solid rgba(255, 255, 255, 0.12);
        background: #09090b;
        box-shadow: 0 4px 20px -2px rgba(0, 0, 0, 0.6), 0 0 0 1px rgba(255, 255, 255, 0.05);
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
        padding: 0;
        transition: transform 160ms cubic-bezier(0.16, 1, 0.3, 1), box-shadow 160ms ease, border-color 160ms ease;
        outline: none;
        user-select: none;
      }
      .bloom-badge:hover {
        transform: scale(1.08);
        border-color: rgba(99, 102, 241, 0.45);
        box-shadow: 0 6px 24px -2px rgba(0, 0, 0, 0.7), 0 0 0 1px rgba(99, 102, 241, 0.3);
      }
      .bloom-badge:active {
        transform: scale(0.94);
      }
      .bloom-badge.bloom-open {
        border-color: rgba(99, 102, 241, 0.6);
        box-shadow: 0 0 0 2px rgba(99, 102, 241, 0.35), 0 4px 20px rgba(0, 0, 0, 0.6);
      }
      .bloom-badge.bloom-has-error {
        border-color: rgba(239, 68, 68, 0.7);
        box-shadow: 0 0 0 2px rgba(239, 68, 68, 0.4), 0 4px 20px rgba(239, 68, 68, 0.25);
      }
      .bloom-badge-mark {
        display: flex;
        align-items: center;
        justify-content: center;
        transition: transform 600ms cubic-bezier(0.34, 1.56, 0.64, 1);
      }
      .bloom-status-dot {
        position: absolute;
        top: -1px;
        right: -1px;
        width: 9px;
        height: 9px;
        border-radius: 9999px;
        background: #10b981;
        border: 2px solid #09090b;
        box-shadow: 0 0 8px rgba(16, 185, 129, 0.6);
        transition: background 200ms ease, box-shadow 200ms ease;
        pointer-events: none;
      }
      .bloom-status-dot.bloom-dot-disconnected {
        background: #f59e0b;
        box-shadow: 0 0 8px rgba(245, 158, 11, 0.6);
        animation: bloom-pulse 1.4s infinite;
      }
      .bloom-status-dot.bloom-dot-error {
        background: #ef4444;
        box-shadow: 0 0 8px rgba(239, 68, 68, 0.7);
      }
      /* Rebuild-in-progress state. A compile takes seconds, so the badge has to
         say something the instant a file is saved -- otherwise a save looks like
         it did nothing right up until the page abruptly reloads. */
      .bloom-badge.bloom-compiling {
        box-shadow: 0 0 0 3px rgba(245,158,11,0.45), 0 4px 18px rgba(0,0,0,0.5);
        animation: bloom-compiling-pulse 1s ease-in-out infinite;
      }
      @keyframes bloom-compiling-pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.55; }
      }
      .bloom-status-badge.bloom-badge-compiling {
        background: rgba(245,158,11,0.15);
        color: #f59e0b;
      }
      .bloom-status-badge.bloom-badge-compiling .bloom-status-badge-dot {
        background: #f59e0b;
      }
      @media (prefers-reduced-motion: reduce) {
        .bloom-badge.bloom-compiling { animation: none; }
      }

      .bloom-badge-pill {
        position: absolute;
        top: -4px;
        right: -4px;
        min-width: 16px;
        height: 16px;
        padding: 0 3px;
        border-radius: 9999px;
        background: #ef4444;
        color: #ffffff;
        font-size: 9.5px;
        font-weight: 700;
        display: none;
        align-items: center;
        justify-content: center;
        border: 2px solid #09090b;
        box-shadow: 0 2px 8px rgba(239, 68, 68, 0.4);
        pointer-events: none;
      }
      @keyframes bloom-pulse {
        0%, 100% { opacity: 1; transform: scale(1); }
        50% { opacity: 0.45; transform: scale(0.85); }
      }
      .bloom-panel {
        position: absolute;
        left: 0;
        bottom: 48px;
        width: 380px;
        max-width: calc(100vw - 32px);
        background: #09090b;
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 12px;
        box-shadow: 0 24px 48px -12px rgba(0, 0, 0, 0.8), 0 0 0 1px rgba(255, 255, 255, 0.08);
        overflow: hidden;
        opacity: 0;
        pointer-events: none;
        transform: translateY(8px) scale(0.97);
        transition: opacity 160ms cubic-bezier(0.16, 1, 0.3, 1), transform 160ms cubic-bezier(0.16, 1, 0.3, 1);
        display: flex;
        flex-direction: column;
      }
      .bloom-panel.bloom-open {
        opacity: 1;
        pointer-events: auto;
        transform: translateY(0) scale(1);
      }
      .bloom-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 10px 12px;
        background: #121215;
        border-bottom: 1px solid rgba(255, 255, 255, 0.08);
      }
      .bloom-title-wrap {
        display: flex;
        align-items: center;
        gap: 7px;
        font-weight: 700;
        font-size: 12px;
        color: #f4f4f5;
        letter-spacing: -0.01em;
      }
      .bloom-env-pill {
        font-size: 9px;
        font-weight: 700;
        padding: 1px 5px;
        border-radius: 4px;
        background: rgba(99, 102, 241, 0.12);
        color: #818cf8;
        border: 1px solid rgba(99, 102, 241, 0.25);
        letter-spacing: 0.04em;
      }
      .bloom-header-actions {
        display: flex;
        align-items: center;
        gap: 8px;
      }
      .bloom-status-badge {
        display: inline-flex;
        align-items: center;
        gap: 5px;
        font-size: 11px;
        font-weight: 500;
        padding: 2px 8px;
        border-radius: 9999px;
        background: rgba(16, 185, 129, 0.1);
        color: #34d399;
        border: 1px solid rgba(16, 185, 129, 0.2);
      }
      .bloom-status-badge.bloom-badge-reconnecting {
        background: rgba(245, 158, 11, 0.1);
        color: #fbbf24;
        border-color: rgba(245, 158, 11, 0.2);
      }
      .bloom-status-badge-dot {
        width: 6px;
        height: 6px;
        border-radius: 9999px;
        background: currentColor;
      }
      .bloom-close-btn {
        width: 22px;
        height: 22px;
        border-radius: 4px;
        border: none;
        background: transparent;
        color: #71717a;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: color 120ms, background 120ms;
      }
      .bloom-close-btn:hover {
        color: #f4f4f5;
        background: rgba(255, 255, 255, 0.08);
      }
      .bloom-tabs {
        display: flex;
        gap: 4px;
        padding: 6px 8px;
        background: #09090b;
        border-bottom: 1px solid rgba(255, 255, 255, 0.06);
      }
      .bloom-tab-btn {
        flex: 1;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 4px;
        padding: 5px 6px;
        border-radius: 6px;
        font-size: 11px;
        font-weight: 500;
        color: #a1a1aa;
        background: transparent;
        border: 1px solid transparent;
        cursor: pointer;
        transition: all 120ms ease;
        font-family: inherit;
        outline: none;
      }
      .bloom-tab-btn:hover:not(.bloom-tab-active) {
        background: rgba(255, 255, 255, 0.04);
        color: #e4e4e7;
      }
      .bloom-tab-btn.bloom-tab-active {
        background: #18181b;
        color: #ffffff;
        font-weight: 600;
        border-color: rgba(255, 255, 255, 0.08);
        box-shadow: 0 1px 3px rgba(0, 0, 0, 0.4);
      }
      .bloom-tab-count {
        font-size: 9px;
        font-weight: 700;
        padding: 1px 4px;
        border-radius: 9999px;
        background: #27272a;
        color: #a1a1aa;
        min-width: 14px;
        text-align: center;
      }
      .bloom-tab-count.bloom-count-error {
        background: #ef4444;
        color: #ffffff;
      }
      .bloom-body {
        max-height: 290px;
        overflow-y: auto;
        padding: 12px;
        display: flex;
        flex-direction: column;
        gap: 10px;
      }
      .bloom-body::-webkit-scrollbar {
        width: 4px;
      }
      .bloom-body::-webkit-scrollbar-thumb {
        background: rgba(255, 255, 255, 0.15);
        border-radius: 9999px;
      }
      .bloom-card {
        background: #121215;
        border: 1px solid rgba(255, 255, 255, 0.06);
        border-radius: 8px;
        overflow: hidden;
      }
      .bloom-row {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 7px 10px;
        font-size: 11px;
        border-bottom: 1px solid rgba(255, 255, 255, 0.04);
      }
      .bloom-row:last-child {
        border-bottom: none;
      }
      .bloom-label {
        color: #a1a1aa;
        font-weight: 400;
      }
      .bloom-value {
        color: #f4f4f5;
        font-weight: 600;
        text-align: right;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
        max-width: 210px;
      }
      .bloom-value-accent {
        color: #60a5fa;
      }
      .bloom-actions {
        display: flex;
        gap: 6px;
      }
      .bloom-btn-action {
        flex: 1;
        padding: 6px 10px;
        border-radius: 6px;
        font-size: 11px;
        font-weight: 600;
        font-family: inherit;
        cursor: pointer;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 5px;
        transition: all 120ms ease;
        outline: none;
      }
      .bloom-btn-primary {
        background: #6366f1;
        color: #ffffff;
        border: 1px solid rgba(255, 255, 255, 0.15);
      }
      .bloom-btn-primary:hover {
        background: #4f46e5;
      }
      .bloom-btn-secondary {
        background: #18181b;
        color: #e4e4e7;
        border: 1px solid rgba(255, 255, 255, 0.08);
      }
      .bloom-btn-secondary:hover {
        background: #27272a;
        color: #ffffff;
      }
      .bloom-empty-state {
        padding: 24px 12px;
        text-align: center;
        color: #71717a;
        font-size: 11px;
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 6px;
      }
      .bloom-error-card {
        background: #181012;
        border: 1px solid rgba(239, 68, 68, 0.3);
        border-radius: 8px;
        padding: 10px;
        display: flex;
        flex-direction: column;
        gap: 6px;
      }
      .bloom-error-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        font-size: 11px;
      }
      .bloom-error-tag {
        color: #f87171;
        font-weight: 700;
        display: flex;
        align-items: center;
        gap: 4px;
      }
      .bloom-error-time {
        color: #71717a;
        font-size: 10.5px;
      }
      .bloom-error-pre {
        font-family: inherit;
        font-size: 10.5px;
        line-height: 1.45;
        color: #fca5a5;
        background: #0c0607;
        padding: 8px 10px;
        border-radius: 6px;
        overflow-x: auto;
        max-height: 130px;
        white-space: pre-wrap;
        word-break: break-all;
        border: 1px solid rgba(239, 68, 68, 0.18);
      }
      .bloom-copy-btn {
        align-self: flex-end;
        padding: 3px 8px;
        font-size: 10.5px;
        font-family: inherit;
        border-radius: 4px;
        border: 1px solid rgba(255, 255, 255, 0.1);
        background: #27272a;
        color: #d4d4d8;
        cursor: pointer;
        display: inline-flex;
        align-items: center;
        gap: 4px;
        transition: background 120ms, color 120ms;
      }
      .bloom-copy-btn:hover {
        background: #3f3f46;
        color: #ffffff;
      }
      .bloom-item {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 8px 10px;
        border-radius: 6px;
        background: #121215;
        border: 1px solid rgba(255, 255, 255, 0.05);
        font-size: 11px;
      }
      .bloom-item-sub {
        color: #71717a;
        font-size: 10px;
      }
      .bloom-clear-header {
        display: flex;
        justify-content: flex-end;
        margin-bottom: -4px;
      }
      .bloom-clear-btn {
        background: transparent;
        border: none;
        color: #71717a;
        font-size: 10.5px;
        font-family: inherit;
        cursor: pointer;
        text-decoration: underline;
      }
      .bloom-clear-btn:hover {
        color: #a1a1aa;
      }
    `;

    function mountDevTools() {
      const root = document.createElement('div');
      root.setAttribute('data-bloom-devtools', 'true');
      root.className = 'bloom-root';

      const styleEl = document.createElement('style');
      styleEl.textContent = STYLES;
      root.appendChild(styleEl);

      // Badge Wrap
      const badgeWrap = document.createElement('div');
      badgeWrap.className = 'bloom-badge-wrap';

      const badge = document.createElement('button');
      badge.className = 'bloom-badge';
      badge.setAttribute('aria-label', 'Bloom Dev Tools');
      badge.setAttribute('title', 'Bloom DevTools (Click to toggle)');

      const markWrap = document.createElement('div');
      markWrap.className = 'bloom-badge-mark';
      const markSvg = buildBloomMark(18);
      markWrap.appendChild(markSvg);
      badge.appendChild(markWrap);

      const statusDot = document.createElement('span');
      statusDot.className = 'bloom-status-dot';

      const badgePill = document.createElement('span');
      badgePill.className = 'bloom-badge-pill';

      badgeWrap.appendChild(badge);
      badgeWrap.appendChild(statusDot);
      badgeWrap.appendChild(badgePill);

      // Panel
      const panel = document.createElement('div');
      panel.className = 'bloom-panel';

      // Panel Header
      const header = document.createElement('div');
      header.className = 'bloom-header';

      const titleWrap = document.createElement('div');
      titleWrap.className = 'bloom-title-wrap';
      titleWrap.appendChild(buildBloomMark(14));
      const titleText = document.createElement('span');
      titleText.textContent = 'Bloom DevTools';
      const envPill = document.createElement('span');
      envPill.className = 'bloom-env-pill';
      envPill.textContent = 'DEV';
      titleWrap.appendChild(titleText);
      titleWrap.appendChild(envPill);

      const headerActions = document.createElement('div');
      headerActions.className = 'bloom-header-actions';

      const statusBadge = document.createElement('span');
      statusBadge.className = 'bloom-status-badge';
      statusBadge.innerHTML = '<span class="bloom-status-badge-dot"></span><span class="bloom-status-text">Connected</span>';

      const closeBtn = document.createElement('button');
      closeBtn.className = 'bloom-close-btn';
      closeBtn.appendChild(svgIcon('close', 12));
      closeBtn.setAttribute('aria-label', 'Close panel');
      closeBtn.onclick = (e) => {
        e.stopPropagation();
        setOpen(false);
      };

      headerActions.appendChild(statusBadge);
      headerActions.appendChild(closeBtn);
      header.appendChild(titleWrap);
      header.appendChild(headerActions);
      panel.appendChild(header);

      // Tabs Bar
      const tabsBar = document.createElement('div');
      tabsBar.className = 'bloom-tabs';

      const tabsDef = [
        { id: 'overview', label: 'Overview', icon: 'overview' },
        { id: 'errors', label: 'Errors', icon: 'errors', countId: 'errors-count' },
        { id: 'history', label: 'History', icon: 'history', countId: 'history-count' },
        { id: 'console', label: 'Logs', icon: 'console', countId: 'logs-count' },
      ];

      const tabButtons = {};
      const tabCounts = {};

      tabsDef.forEach((t) => {
        const btn = document.createElement('button');
        btn.className = 'bloom-tab-btn' + (t.id === 'overview' ? ' bloom-tab-active' : '');
        btn.appendChild(svgIcon(t.icon, 12));
        const lbl = document.createElement('span');
        lbl.textContent = t.label;
        btn.appendChild(lbl);

        if (t.countId) {
          const countSpan = document.createElement('span');
          countSpan.className = 'bloom-tab-count';
          countSpan.style.display = 'none';
          btn.appendChild(countSpan);
          tabCounts[t.id] = countSpan;
        }

        btn.onclick = () => switchTab(t.id);
        tabsBar.appendChild(btn);
        tabButtons[t.id] = btn;
      });

      panel.appendChild(tabsBar);

      // Body container
      const body = document.createElement('div');
      body.className = 'bloom-body';
      panel.appendChild(body);

      root.appendChild(panel);
      root.appendChild(badgeWrap);
      document.body.appendChild(root);

      // State
      let open = false;
      let currentTab = 'overview';
      let isConnectedState = false;
      let reloadCountState = 0;
      let lastReloadTimestamp = null;
      const errorsList = [];
      const historyList = [];
      const logsList = [];

      function setOpen(val) {
        open = val;
        if (open) {
          panel.classList.add('bloom-open');
          badge.classList.add('bloom-open');
          renderBody();
        } else {
          panel.classList.remove('bloom-open');
          badge.classList.remove('bloom-open');
        }
      }

      badge.onclick = () => setOpen(!open);

      function switchTab(tabId) {
        currentTab = tabId;
        for (const id in tabButtons) {
          if (id === tabId) {
            tabButtons[id].classList.add('bloom-tab-active');
          } else {
            tabButtons[id].classList.remove('bloom-tab-active');
          }
        }
        renderBody();
      }

      function updateBadgeIndicators() {
        const errorCount = errorsList.length;
        if (errorCount > 0) {
          badge.classList.add('bloom-has-error');
          statusDot.className = 'bloom-status-dot bloom-dot-error';
          badgePill.style.display = 'flex';
          badgePill.textContent = errorCount > 99 ? '99+' : String(errorCount);
        } else {
          badge.classList.remove('bloom-has-error');
          badgePill.style.display = 'none';
          if (isConnectedState) {
            statusDot.className = 'bloom-status-dot';
          } else {
            statusDot.className = 'bloom-status-dot bloom-dot-disconnected';
          }
        }

        if (tabCounts.errors) {
          if (errorCount > 0) {
            tabCounts.errors.style.display = 'inline-block';
            tabCounts.errors.className = 'bloom-tab-count bloom-count-error';
            tabCounts.errors.textContent = String(errorCount);
          } else {
            tabCounts.errors.style.display = 'none';
          }
        }
        if (tabCounts.history) {
          if (historyList.length > 0) {
            tabCounts.history.style.display = 'inline-block';
            tabCounts.history.className = 'bloom-tab-count';
            tabCounts.history.textContent = String(historyList.length);
          } else {
            tabCounts.history.style.display = 'none';
          }
        }
        if (tabCounts.console) {
          if (logsList.length > 0) {
            tabCounts.console.style.display = 'inline-block';
            tabCounts.console.className = 'bloom-tab-count';
            tabCounts.console.textContent = String(logsList.length);
          } else {
            tabCounts.console.style.display = 'none';
          }
        }
      }

      function renderBody() {
        if (!open) return;
        body.innerHTML = '';

        if (currentTab === 'overview') {
          const card = document.createElement('div');
          card.className = 'bloom-card';

          const makeRow = (label, value, isAccent) => {
            const r = document.createElement('div');
            r.className = 'bloom-row';
            const l = document.createElement('span');
            l.className = 'bloom-label';
            l.textContent = label;
            const v = document.createElement('span');
            v.className = 'bloom-value' + (isAccent ? ' bloom-value-accent' : '');
            v.textContent = value;
            v.setAttribute('title', value);
            r.appendChild(l);
            r.appendChild(v);
            return r;
          };

          card.appendChild(makeRow('Route', window.location.pathname || '/', true));
          card.appendChild(makeRow('Page Title', document.title || '(untitled)'));
          card.appendChild(makeRow('Live reload', isConnectedState ? 'connected' : 'reconnecting…'));
          card.appendChild(makeRow('Reloads', String(reloadCountState)));
          card.appendChild(makeRow('Last reload', formatTimeAgo(lastReloadTimestamp)));
          card.appendChild(makeRow('SSE Channel', '/_bloom_hr'));

          body.appendChild(card);

          const actions = document.createElement('div');
          actions.className = 'bloom-actions';

          const reloadBtn = document.createElement('button');
          reloadBtn.className = 'bloom-btn-action bloom-btn-primary';
          reloadBtn.appendChild(svgIcon('reload', 12));
          const reloadText = document.createElement('span');
          reloadText.textContent = 'Reload Page';
          reloadBtn.appendChild(reloadText);
          reloadBtn.onclick = () => window.location.reload();

          const copyBtn = document.createElement('button');
          copyBtn.className = 'bloom-btn-action bloom-btn-secondary';
          copyBtn.appendChild(svgIcon('copy', 12));
          const copyText = document.createElement('span');
          copyText.textContent = 'Copy Info';
          copyBtn.appendChild(copyText);
          copyBtn.onclick = () => {
            const info = {
              route: window.location.pathname,
              title: document.title,
              connected: isConnectedState,
              reloads: reloadCountState,
              errors: errorsList.length,
              time: new Date().toISOString(),
            };
            navigator.clipboard.writeText(JSON.stringify(info, null, 2)).then(() => {
              copyText.textContent = 'Copied!';
              setTimeout(() => { copyText.textContent = 'Copy Info'; }, 1500);
            });
          };

          actions.appendChild(reloadBtn);
          actions.appendChild(copyBtn);
          body.appendChild(actions);
        } else if (currentTab === 'errors') {
          if (errorsList.length === 0) {
            const empty = document.createElement('div');
            empty.className = 'bloom-empty-state';
            empty.appendChild(svgIcon('check', 24));
            const emptyText = document.createElement('span');
            emptyText.textContent = 'No build or compile errors.';
            empty.appendChild(emptyText);
            body.appendChild(empty);
          } else {
            const clearWrap = document.createElement('div');
            clearWrap.className = 'bloom-clear-header';
            const clearBtn = document.createElement('button');
            clearBtn.className = 'bloom-clear-btn';
            clearBtn.textContent = 'Clear errors';
            clearBtn.onclick = () => {
              errorsList.length = 0;
              updateBadgeIndicators();
              renderBody();
            };
            clearWrap.appendChild(clearBtn);
            body.appendChild(clearWrap);

            errorsList.forEach((err) => {
              const errCard = document.createElement('div');
              errCard.className = 'bloom-error-card';

              const errHeader = document.createElement('div');
              errHeader.className = 'bloom-error-header';
              const errTag = document.createElement('span');
              errTag.className = 'bloom-error-tag';
              errTag.appendChild(svgIcon('errors', 12));
              const errTagText = document.createElement('span');
              errTagText.textContent = err.type || 'Dart Compile Error';
              errTag.appendChild(errTagText);

              const errTime = document.createElement('span');
              errTime.className = 'bloom-error-time';
              errTime.textContent = formatClock(err.timestamp);
              errHeader.appendChild(errTag);
              errHeader.appendChild(errTime);

              const pre = document.createElement('pre');
              pre.className = 'bloom-error-pre';
              pre.textContent = err.message;

              const copyErrBtn = document.createElement('button');
              copyErrBtn.className = 'bloom-copy-btn';
              copyErrBtn.appendChild(svgIcon('copy', 11));
              const copyErrText = document.createElement('span');
              copyErrText.textContent = 'Copy';
              copyErrBtn.appendChild(copyErrText);
              copyErrBtn.onclick = () => {
                navigator.clipboard.writeText(err.message).then(() => {
                  copyErrText.textContent = 'Copied!';
                  setTimeout(() => { copyErrText.textContent = 'Copy'; }, 1500);
                });
              };

              errCard.appendChild(errHeader);
              errCard.appendChild(pre);
              errCard.appendChild(copyErrBtn);
              body.appendChild(errCard);
            });
          }
        } else if (currentTab === 'history') {
          if (historyList.length === 0) {
            const empty = document.createElement('div');
            empty.className = 'bloom-empty-state';
            empty.appendChild(svgIcon('history', 24));
            const emptyText = document.createElement('span');
            emptyText.textContent = 'No reload events recorded yet.';
            empty.appendChild(emptyText);
            body.appendChild(empty);
          } else {
            historyList.forEach((item) => {
              const row = document.createElement('div');
              row.className = 'bloom-item';
              const left = document.createElement('div');
              left.style.cssText = 'display:flex;flex-direction:column;gap:2px;';
              const title = document.createElement('span');
              title.style.fontWeight = '600';
              title.textContent = item.reason ? 'Changed: ' + item.reason : 'Hot Reload Triggered';
              const sub = document.createElement('span');
              sub.className = 'bloom-item-sub';
              sub.textContent = formatTimeAgo(item.timestamp);
              left.appendChild(title);
              left.appendChild(sub);

              const clock = document.createElement('span');
              clock.style.color = '#71717a';
              clock.style.fontSize = '10.5px';
              clock.textContent = formatClock(item.timestamp);

              row.appendChild(left);
              row.appendChild(clock);
              body.appendChild(row);
            });
          }
        } else if (currentTab === 'console') {
          if (logsList.length === 0) {
            const empty = document.createElement('div');
            empty.className = 'bloom-empty-state';
            empty.appendChild(svgIcon('console', 24));
            const emptyText = document.createElement('span');
            emptyText.textContent = 'No runtime client exceptions.';
            empty.appendChild(emptyText);
            body.appendChild(empty);
          } else {
            const clearWrap = document.createElement('div');
            clearWrap.className = 'bloom-clear-header';
            const clearBtn = document.createElement('button');
            clearBtn.className = 'bloom-clear-btn';
            clearBtn.textContent = 'Clear logs';
            clearBtn.onclick = () => {
              logsList.length = 0;
              updateBadgeIndicators();
              renderBody();
            };
            clearWrap.appendChild(clearBtn);
            body.appendChild(clearWrap);

            logsList.forEach((log) => {
              const row = document.createElement('div');
              row.className = 'bloom-item';
              row.style.flexDirection = 'column';
              row.style.alignItems = 'flex-start';
              row.style.gap = '4px';

              const header = document.createElement('div');
              header.style.cssText = 'display:flex;justify-content:space-between;width:100%;font-size:10.5px;';
              const tag = document.createElement('span');
              tag.style.color = log.type === 'error' ? '#f87171' : '#fbbf24';
              tag.style.fontWeight = '600';
              tag.textContent = (log.type || 'error').toUpperCase();
              const time = document.createElement('span');
              time.style.color = '#71717a';
              time.textContent = formatClock(log.timestamp);
              header.appendChild(tag);
              header.appendChild(time);

              const msg = document.createElement('pre');
              msg.style.cssText = 'font-family:inherit;font-size:10px;color:#d4d4d8;white-space:pre-wrap;word-break:break-all;max-height:80px;overflow-y:auto;width:100%;';
              msg.textContent = log.message;

              row.appendChild(header);
              row.appendChild(msg);
              body.appendChild(row);
            });
          }
        }
      }

      // Refresh relative timers every 1s
      setInterval(() => {
        if (open && currentTab === 'overview') {
          renderBody();
        }
      }, 1000);

      return {
        showCompiling(reason) {
          badge.classList.add('bloom-compiling');
          const statusText = statusBadge.querySelector('.bloom-status-text');
          if (statusText) {
            statusBadge.className = 'bloom-status-badge bloom-badge-compiling';
            statusText.textContent = reason ? 'Compiling ' + reason + '…' : 'Compiling…';
          }
          if (open && currentTab === 'overview') renderBody();
        },
        clearCompiling() {
          badge.classList.remove('bloom-compiling');
          if (open && currentTab === 'overview') renderBody();
        },
        setStatus(connected) {
          badge.classList.remove('bloom-compiling');
          isConnectedState = connected;
          const statusText = statusBadge.querySelector('.bloom-status-text');
          if (connected) {
            statusBadge.className = 'bloom-status-badge';
            if (statusText) statusText.textContent = 'Connected';
          } else {
            statusBadge.className = 'bloom-status-badge bloom-badge-reconnecting';
            if (statusText) statusText.textContent = 'Reconnecting…';
          }
          updateBadgeIndicators();
          if (open && currentTab === 'overview') renderBody();
        },
        showRefreshing(reason) {
          reloadCountState += 1;
          lastReloadTimestamp = Date.now();
          historyList.unshift({
            timestamp: lastReloadTimestamp,
            reason: reason || null,
          });
          if (historyList.length > 20) historyList.pop();

          markWrap.style.transform = 'rotate(' + (reloadCountState * 360) + 'deg)';
          badge.style.boxShadow = '0 0 0 3px rgba(99,102,241,0.5), 0 4px 18px rgba(0,0,0,0.5)';
          setTimeout(() => {
            badge.style.boxShadow = '';
          }, 600);

          updateBadgeIndicators();
          if (open) renderBody();
        },
        addError(errorMessage) {
          errorsList.unshift({
            type: 'Dart Compile Error',
            message: errorMessage,
            timestamp: Date.now(),
          });
          if (errorsList.length > 20) errorsList.pop();
          updateBadgeIndicators();
          switchTab('errors');
          setOpen(true);
        },
        addLog(type, message) {
          logsList.unshift({
            type: type,
            message: message,
            timestamp: Date.now(),
          });
          if (logsList.length > 20) logsList.pop();
          updateBadgeIndicators();
          if (open && currentTab === 'console') renderBody();
        },
      };
    }

    const devtools = document.readyState === 'loading'
      ? null
      : mountDevTools();
    function ensureDevtools() {
      return devtools || mountDevTools();
    }
    let dt = devtools;
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => { dt = ensureDevtools(); flushPendingLogs(); });
    }

    // This script is injected into <head>, so readyState is 'loading' and the
    // panel does not exist until DOMContentLoaded. Anything reported before then
    // used to hit an `if (dt)` guard and be discarded -- which silently dropped
    // exactly the earliest errors, the ones most worth seeing. Buffer instead.
    const pendingLogs = [];
    function pushLog(type, message) {
      if (dt) { dt.addLog(type, message); return; }
      pendingLogs.push([type, message]);
      if (pendingLogs.length > 50) pendingLogs.shift();
    }
    function flushPendingLogs() {
      if (!dt) return;
      while (pendingLogs.length) {
        const entry = pendingLogs.shift();
        dt.addLog(entry[0], entry[1]);
      }
    }

    // Intercept uncaught runtime client errors.
    //
    // `capture: true` is required, not cosmetic: a failed resource load
    // (<img>, <video>, <script>, <link>) fires an `error` event on the element
    // itself and does NOT bubble, so a plain non-capturing window listener never
    // observes it. Those events also carry no `message`/`filename`, so they need
    // to be formatted from the element rather than from the event.
    window.addEventListener('error', (e) => {
      const el = e.target;
      if (el && el !== window && el.tagName) {
        pushLog('error', 'Failed to load ' + el.tagName.toLowerCase() + ': ' + (el.src || el.href || '(unknown source)'));
        return;
      }
      pushLog('error', e.message + (e.filename ? ' (' + e.filename + ':' + e.lineno + ')' : ''));
    }, true);
    window.addEventListener('unhandledrejection', (e) => {
      const reason = e.reason ? (e.reason.stack || e.reason.message || String(e.reason)) : 'Unhandled Promise Rejection';
      pushLog('error', reason);
    });

    // Mirror console.* into the Logs tab.
    //
    // Nothing else populates it: addLog was only ever reached from the two
    // listeners above and from SSE build errors, so anything the application or
    // a third-party library reported through console.error/warn was invisible in
    // devtools while being plainly visible in the browser's own console. The
    // original method is always called, so native console output is unchanged.
    ['error', 'warn', 'log', 'info'].forEach((level) => {
      const original = console[level];
      if (typeof original !== 'function') return;
      console[level] = function () {
        const args = Array.prototype.slice.call(arguments);
        try {
          pushLog(level === 'info' ? 'log' : level, args.map((a) => {
            if (typeof a === 'string') return a;
            if (a instanceof Error) return a.stack || a.message;
            try { return JSON.stringify(a); } catch (_) { return String(a); }
          }).join(' '));
        } catch (_) {
          // Never let devtools bookkeeping break a real console call.
        }
        return original.apply(console, args);
      };
    });

    // Network failures are the most common thing anyone opens a dev console to
    // look for, and every hook above misses them.
    //
    // A CORS rejection reaches page JS only as a bare "TypeError: Failed to
    // fetch" / "NetworkError when attempting to fetch resource" with no URL
    // attached. The browser's explanatory line -- "Cross-Origin Request Blocked
    // ... Access-Control-Allow-Origin missing" -- is printed by the browser
    // itself and is deliberately NOT exposed through any JS-observable channel,
    // so no amount of hooking can capture it. Wrapping fetch/XHR cannot recover
    // that reason, but it does recover the part that actually identifies the
    // problem: which request failed.
    const nativeFetch = window.fetch;
    if (typeof nativeFetch === 'function') {
      window.fetch = function (input) {
        const url = (typeof input === 'string')
          ? input
          : (input && input.url) || String(input);
        return nativeFetch.apply(window, arguments).then((res) => {
          if (!res.ok) pushLog('error', 'HTTP ' + res.status + ' — ' + url);
          return res;
        }).catch((err) => {
          pushLog('error', 'Network request failed: ' + url +
            ' (' + ((err && err.message) || err) + '). If the host is reachable, this is' +
            ' usually a CORS rejection; the browser console has the specific reason.');
          throw err;
        });
      };
    }
    const NativeXHR = window.XMLHttpRequest;
    if (typeof NativeXHR === 'function' && NativeXHR.prototype) {
      const nativeOpen = NativeXHR.prototype.open;
      const nativeSend = NativeXHR.prototype.send;
      NativeXHR.prototype.open = function (method, url) {
        this.__bloomUrl = url;
        return nativeOpen.apply(this, arguments);
      };
      NativeXHR.prototype.send = function () {
        const self = this;
        self.addEventListener('error', () => {
          pushLog('error', 'XHR failed: ' + (self.__bloomUrl || '(unknown URL)') +
            ' — often a CORS rejection; see the browser console for the reason.');
        });
        self.addEventListener('load', () => {
          if (self.status >= 400) {
            pushLog('error', 'HTTP ' + self.status + ' — ' + (self.__bloomUrl || '(unknown URL)'));
          }
        });
        return nativeSend.apply(self, arguments);
      };
    }

    const connect = () => {
      const es = new EventSource('/_bloom_hr');
      es.addEventListener('open', () => { if (dt) dt.setStatus(true); });
      es.addEventListener('compiling', (e) => {
        let reason = null;
        try {
          if (e.data) {
            const payload = JSON.parse(e.data);
            if (payload.reason) reason = payload.reason;
          }
        } catch (_) {}
        dt = dt || ensureDevtools();
        if (dt) dt.showCompiling(reason);
      });
      es.addEventListener('reload', (e) => {
        let reason = null;
        try {
          if (e.data) {
            const payload = JSON.parse(e.data);
            if (payload.reason) reason = payload.reason;
          }
        } catch (_) {}
        console.log('%c⚡ [Bloom Hot Reload]%c Refreshing application...', 'color:#6366F1;font-weight:bold', 'color:inherit');
        if (dt) dt.showRefreshing(reason);
        setTimeout(() => window.location.reload(), 280);
      });
      es.addEventListener('error', (e) => {
        let msg = e.data;
        try {
          if (msg) {
            const parsed = JSON.parse(msg);
            if (parsed.message) msg = parsed.message;
          }
        } catch (_) {}
        if (msg) {
          console.error('[Bloom Build Error]', msg);
          dt = dt || ensureDevtools();
          // A failed build never reaches the 'reload' event, so the compiling
          // state has to be cleared here or the badge pulses forever.
          if (dt) { dt.clearCompiling(); dt.addError(msg); }
        }
      });
      es.onerror = () => {
        if (dt) dt.setStatus(false);
        es.close();
        setTimeout(connect, 1000);
      };
    };
    connect();
  })();
</script>
''';

  BloomLiveReloadServer({
    required this.webDir,
    this.host = '0.0.0.0',
    this.port = 8080,
    this.autoInjectScript = true,
    this.proxyRules = const [],
  }) {
    _sortedProxyRules = List<BloomDevProxyRule>.from(proxyRules)
      ..sort((a, b) => b.pathPrefix.length.compareTo(a.pathPrefix.length));
  }

  HttpServer? get server => _server;
  int get activeClientCount => _sseClients.length;

  Future<void> start() async {
    _server = await HttpServer.bind(host, port);
    _server!.listen(_handleRequest);
  }

  void broadcastReload({String? reason}) {
    final payload = jsonEncode({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      if (reason != null) 'reason': reason,
    });

    final data = 'event: reload\ndata: $payload\n\n';
    _broadcast(data);
  }

  /// Notifies clients that a rebuild has *started*, before the compile runs.
  ///
  /// Without this the browser shows nothing at all for the several seconds a
  /// compile takes and then reloads abruptly, so a save appears to do nothing
  /// until it suddenly doesn't. Emitting this immediately on the file-change
  /// event lets the badge report progress the moment you hit save.
  void broadcastCompiling({String? reason}) {
    final payload = jsonEncode({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      if (reason != null) 'reason': reason,
    });

    final data = 'event: compiling\ndata: $payload\n\n';
    _broadcast(data);
  }

  void broadcastError(String errorMessage) {
    final payload = jsonEncode({'message': errorMessage});
    final data = 'event: error\ndata: $payload\n\n';
    _broadcast(data);
  }

  void _broadcast(String sseMessage) {
    final deadClients = <HttpResponse>[];
    for (final client in _sseClients) {
      try {
        client.write(sseMessage);
        unawaited(client.flush());
      } catch (_) {
        deadClients.add(client);
      }
    }
    _sseClients.removeWhere(deadClients.contains);
  }

  Future<void> stop() async {
    for (final client in _sseClients) {
      try {
        await client.close();
      } catch (_) {}
    }
    _sseClients.clear();
    await _proxy.close(force: true);
    await _server?.close(force: true);
    _server = null;
  }

  void _handleRequest(HttpRequest req) async {
    final path = req.uri.path;

    // 1. SSE Live Reload Stream
    if (path == '/_bloom_hr') {
      req.response.bufferOutput = false;
      req.response.headers
        ..set(HttpHeaders.contentTypeHeader, 'text/event-stream')
        ..set(HttpHeaders.cacheControlHeader, 'no-cache')
        ..set(HttpHeaders.connectionHeader, 'keep-alive')
        ..set('Access-Control-Allow-Origin', '*');

      // Send an initial SSE comment line immediately: without any bytes
      // written, dart:io never actually puts the response headers on the
      // wire, so the browser's EventSource never fires its `open` event
      // (and devtools UI bound to that event stays stuck showing
      // "reconnecting…") until the first real reload/error broadcast.
      req.response.write(': connected\n\n');
      unawaited(req.response.flush());

      _sseClients.add(req.response);
      return;
    }

    // 2. Dev Proxy Rules (Longest prefix matched first)
    for (final rule in _sortedProxyRules) {
      if (rule.matches(path)) {
        await _proxy.forward(req, rule);
        return;
      }
    }

    try {
      var reqPath = path.startsWith('/') ? path.substring(1) : path;
      if (reqPath.isEmpty) reqPath = 'index.html';

      var targetPath = p.canonicalize(p.join(webDir.path, reqPath));

      if (p.isWithin(webDir.path, targetPath) || targetPath == p.canonicalize(webDir.path)) {
        var targetFile = File(targetPath);
        if (targetFile.existsSync() && !FileSystemEntity.isDirectorySync(targetFile.path)) {
          final ext = p.extension(targetFile.path).replaceAll('.', '').toLowerCase();
          req.response.headers.set(HttpHeaders.contentTypeHeader, _getContentType(ext));
          req.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');

          if (ext == 'html' && autoInjectScript) {
            var html = targetFile.readAsStringSync();
            if (!html.contains('__BLOOM_HR_ACTIVE__')) {
              html = html.replaceFirst('</body>', '$liveReloadScript</body>');
            }
            req.response.write(html);
          } else {
            req.response.add(targetFile.readAsBytesSync());
          }
          await req.response.close();
          return;
        }

        // SPA Fallback to index.html
        final indexFile = File(p.join(webDir.path, 'index.html'));
        if (indexFile.existsSync()) {
          var html = indexFile.readAsStringSync();
          if (autoInjectScript && !html.contains('__BLOOM_HR_ACTIVE__')) {
            html = html.replaceFirst('</body>', '$liveReloadScript</body>');
          }
          req.response.headers.set(HttpHeaders.contentTypeHeader, 'text/html; charset=utf-8');
          req.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
          req.response.write(html);
          await req.response.close();
          return;
        }
      }

      req.response.statusCode = HttpStatus.notFound;
      req.response.write('404 Not Found');
      await req.response.close();
    } catch (_) {
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      } catch (_) {}
    }
  }

  String _getContentType(String ext) {
    return switch (ext) {
      'html' => 'text/html; charset=utf-8',
      'js' => 'application/javascript; charset=utf-8',
      'json' => 'application/json; charset=utf-8',
      'css' => 'text/css; charset=utf-8',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'svg' => 'image/svg+xml',
      'ico' => 'image/x-icon',
      'woff2' => 'font/woff2',
      'woff' => 'font/woff',
      _ => 'application/octet-stream',
    };
  }
}
