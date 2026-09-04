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
  final bool isDdcMode;
  final Directory? ddcCacheDir;

  HttpServer? _server;
  final List<HttpResponse> _sseClients = [];
  final BloomDevProxy _proxy = BloomDevProxy();
  late final List<BloomDevProxyRule> _sortedProxyRules;

  static const String ddcBootstrapScript = r'''
<script type="module">
  // Bloom DDC Dev Bootstrap (safe against AMD/UMD NPM interop pollution)
  (() => {
    window.__BLOOM_DDC_HOT_REMOUNT__ = true;

    function executeMain() {
      // Clear any active error overlays before mounting
      document.querySelectorAll('[data-bloom-dev-error-overlay]').forEach((el) => el.remove());

      require.config({
        baseUrl: '/',
        paths: {
          dart_sdk: 'dart_sdk',
          main: 'main'
        },
        urlArgs: 'v=' + Date.now()
      });

      require(['dart_sdk', 'main'], (dart_sdk, app) => {
        if (app) {
          for (const k of Object.keys(app)) {
            if (app[k] && typeof app[k].main === 'function') {
              try {
                app[k].main();
              } catch (err) {
                console.error('[Bloom DDC Main Error]', err);
                if (typeof window.__bloomReportUnhandledError === 'function') {
                  window.__bloomReportUnhandledError(err && (err.message || String(err)), err && err.stack);
                } else {
                  const host = document.createElement('div');
                  host.setAttribute('data-bloom-dev-error-overlay', 'true');
                  host.setAttribute('style', 'position:fixed;inset:0;z-index:2147483647;background:rgba(24,8,8,0.96);color:#f5e6e6;font-family:ui-monospace,monospace;padding:32px;overflow:auto;');
                  host.innerHTML = '<div style="max-width:900px;margin:0 auto;"><div style="font-size:12px;color:#ff8a8a;margin-bottom:8px;">Unhandled Error</div><div style="font-size:20px;font-weight:600;margin-bottom:4px;white-space:pre-wrap;">' + String(err) + '</div><pre style="background:rgba(0,0,0,0.35);padding:16px;border-radius:8px;font-size:12px;white-space:pre-wrap;">' + (err && err.stack ? String(err.stack) : '') + '</pre></div>';
                  (document.body || document.documentElement).appendChild(host);
                }
              }
              break;
            }
          }
        }
      }, (err) => {
        console.error('[Bloom DDC Error] Failed to load application modules:', err);
      });
    }

    window.__bloomDdcRemount = () => {
      // 1. Dispose previous active mount
      if (typeof window.__bloomDisposeActiveMount === 'function') {
        try {
          window.__bloomDisposeActiveMount();
        } catch (e) {
          console.warn('[Bloom Hot Remount] Error during mount disposal:', e);
        }
      }
      // 2. Evict cached main module from RequireJS
      if (typeof require !== 'undefined' && typeof require.undef === 'function') {
        require.undef('main');
      }
      // 3. Re-require and re-execute main
      executeMain();
    };

    const reqScript = document.createElement('script');
    reqScript.src = '/require.js';
    reqScript.onload = () => {
      executeMain();
    };
    document.body.appendChild(reqScript);
  })();
</script>
''';

  static const String liveReloadScript = r'''
<script>
  (() => {
    if (window.__BLOOM_HR_ACTIVE__) return;
    window.__BLOOM_HR_ACTIVE__ = true;

    // Current Next DevTools uses one isolated surface for status, diagnostics,
    // and error detail. Keep this client dependency-free, but use the same
    // interaction model: an unobtrusive indicator, a compact menu/panel, then
    // an accessible diagnostic dialog. The legacy drawer remains below only so
    // older cached pages can finish parsing this injected script; it is not run.
    bloomNextStyleDevtools();
    return;

    function bloomNextStyleDevtools() {
      const MAX_ISSUES = 50;
      const MAX_LOGS = 200;
      const storageKey = 'bloom.devtools.position.v1';
      const host = document.createElement('div');
      host.setAttribute('data-bloom-devtools-host', 'true');
      const shadow = host.attachShadow({ mode: 'open' });
      (document.body || document.documentElement).appendChild(host);

      shadow.innerHTML = `
        <style>
          :host { color-scheme: light dark; }
          *,*::before,*::after { box-sizing:border-box; }
          button { font:inherit; }
          #bloom-devtools { --bg:#fff;--surface:#fff;--surface-2:#f6f6f6;--text:#171717;--muted:#666;--line:#e5e5e5;--blue:#0070f3;--red:#d00;--amber:#a15c00; position:fixed;inset:0;z-index:2147483647;pointer-events:none;font-family:ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:var(--text);font-size:14px;line-height:1.4; }
          @media(prefers-color-scheme:dark) { #bloom-devtools { --bg:#111;--surface:#171717;--surface-2:#242424;--text:#ededed;--muted:#a1a1a1;--line:#333;--blue:#3291ff;--red:#ff5b5b;--amber:#f5b942; } }
          .indicator { position:fixed;bottom:20px;left:20px;width:40px;height:40px;border:1px solid var(--line);border-radius:999px;background:var(--surface);box-shadow:0 4px 14px #0002;display:grid;place-items:center;cursor:grab;pointer-events:auto;padding:0;color:var(--text);transition:transform .16s ease,box-shadow .16s ease; }
          .indicator:hover,.indicator:focus-visible { transform:scale(1.06);box-shadow:0 7px 20px #0003;outline:2px solid var(--blue);outline-offset:2px; }
          .indicator[data-status="compiling"] { animation:pulse 1s ease-in-out infinite; } .indicator[data-status="error"] { border-color:var(--red); }
          .mark { width:19px;height:19px;border-radius:6px;background:conic-gradient(from 210deg,#7928ca,#ff0080,#ff4d4d,#0070f3,#7928ca);position:relative; } .mark::after { content:"";position:absolute;inset:6px;border-radius:3px;background:var(--surface); }
          .count { position:absolute;right:-5px;top:-5px;min-width:18px;height:18px;border-radius:99px;background:var(--red);color:#fff;border:2px solid var(--surface);font:600 10px/14px ui-monospace,monospace;text-align:center;padding:0 3px;display:none; }
          .status { position:absolute;right:1px;bottom:1px;width:8px;height:8px;border-radius:50%;background:#20a35b;border:1px solid var(--surface); } .status[data-disconnected="true"]{background:var(--amber)}
          .popover,.panel { pointer-events:auto;background:var(--surface);border:1px solid var(--line);box-shadow:0 16px 48px #0003;border-radius:12px; } .popover { position:fixed;bottom:70px;left:20px;width:272px;padding:6px;display:none; } .popover[data-open="true"]{display:block;animation:enter .14s ease-out;}
          .menu-title { padding:9px 10px 6px;color:var(--muted);font-size:12px;display:flex;justify-content:space-between; } .menu-item { border:0;background:transparent;color:var(--text);display:flex;align-items:center;gap:9px;width:100%;border-radius:7px;padding:9px 10px;text-align:left;cursor:pointer; } .menu-item:hover,.menu-item:focus-visible { background:var(--surface-2);outline:0; } .menu-item b { margin-left:auto;font-size:12px;color:var(--muted);font-weight:500; } .menu-sep { height:1px;background:var(--line);margin:6px 0; }
          .panel { position:fixed;bottom:20px;left:72px;width:min(520px,calc(100vw - 92px));height:min(560px,calc(100vh - 40px));display:none;overflow:hidden;resize:both;min-width:330px;min-height:280px; } .panel[data-open="true"]{display:flex;flex-direction:column;animation:enter .16s ease-out;}
          .panel-header { min-height:48px;border-bottom:1px solid var(--line);display:flex;align-items:center;padding:0 10px 0 16px;gap:8px; } .panel-header strong{font-size:14px}.panel-header span{color:var(--muted);font-size:12px}.spacer{flex:1}.icon-btn { border:0;background:transparent;color:var(--muted);border-radius:6px;padding:7px 9px;cursor:pointer;}.icon-btn:hover,.icon-btn:focus-visible{background:var(--surface-2);color:var(--text);outline:0}
          .tabs{display:flex;border-bottom:1px solid var(--line);padding:0 8px;gap:2px}.tab{border:0;border-bottom:2px solid transparent;background:none;color:var(--muted);padding:11px 9px 9px;cursor:pointer}.tab[data-active="true"]{color:var(--text);border-color:var(--text)}.tab:focus-visible{outline:2px solid var(--blue);outline-offset:-2px}
          .body{overflow:auto;flex:1;padding:12px}.overview{display:grid;gap:8px}.card{border:1px solid var(--line);border-radius:8px;padding:12px}.row{display:flex;gap:12px;justify-content:space-between;padding:4px 0}.row label{color:var(--muted)}.mono{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.issue{width:100%;background:none;border:1px solid var(--line);border-radius:8px;padding:11px;text-align:left;color:var(--text);cursor:pointer;margin-bottom:8px}.issue:hover,.issue:focus-visible{border-color:var(--blue);outline:0}.issue-head{display:flex;gap:8px;align-items:center;font-size:12px;color:var(--muted);margin-bottom:6px}.dot{width:8px;height:8px;border-radius:50%;background:var(--red)}.dot.warn{background:var(--amber)}.issue-msg{font:500 13px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre-wrap;overflow:hidden;display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical}.empty{height:100%;display:grid;place-content:center;text-align:center;color:var(--muted);gap:8px}.log{padding:7px 0;border-bottom:1px solid var(--line);font:12px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre-wrap;word-break:break-word}.log[data-level="error"]{color:var(--red)}.log[data-level="warn"]{color:var(--amber)}
          .backdrop{position:fixed;inset:0;background:#0008;display:none;pointer-events:auto;padding:24px;place-items:center}.backdrop[data-open="true"]{display:grid}.dialog{width:min(900px,100%);max-height:min(720px,100%);background:var(--surface);border:1px solid var(--line);border-radius:12px;box-shadow:0 24px 80px #0008;display:flex;flex-direction:column;overflow:hidden}.dialog-head{padding:16px;border-bottom:1px solid var(--line);display:flex;gap:12px;align-items:flex-start}.dialog-head h2{font-size:15px;margin:0}.dialog-head p{margin:3px 0 0;color:var(--muted);font-size:12px}.dialog-body{padding:16px;overflow:auto}.message{font:600 15px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre-wrap;word-break:break-word}.frame{margin-top:16px;border:1px solid var(--line);background:var(--surface-2);border-radius:8px;padding:12px;font:12px/1.55 ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre-wrap;overflow:auto}.frame .hint{color:var(--blue);font-weight:600}.dialog-foot{border-top:1px solid var(--line);padding:10px 16px;display:flex;align-items:center;gap:8px}.button{border:1px solid var(--line);background:var(--surface);color:var(--text);border-radius:7px;padding:7px 10px;cursor:pointer}.button:hover,.button:focus-visible{background:var(--surface-2);outline:2px solid var(--blue);outline-offset:1px}.primary{background:var(--text);color:var(--surface);border-color:var(--text)}.primary:hover{opacity:.88;background:var(--text)}@keyframes enter{from{opacity:0;transform:translateY(5px) scale(.98)}to{opacity:1;transform:none}}@keyframes pulse{50%{box-shadow:0 0 0 5px #f5a62333}}
        </style>
        <div id="bloom-devtools"><button class="indicator" type="button" aria-label="Open Bloom DevTools" aria-expanded="false" data-status="ready"><span class="mark"></span><span class="count"></span><span class="status"></span></button><div class="popover" role="menu"><div class="menu-title"><span>Bloom DevTools</span><span class="connection">Connected</span></div><button class="menu-item" data-open-tab="overview">Overview <b>⌘I</b></button><button class="menu-item" data-open-tab="issues">Issues <b class="menu-issues">0</b></button><button class="menu-item" data-open-tab="console">Console <b class="menu-logs">0</b></button><button class="menu-item" data-open-tab="history">Reload history</button><div class="menu-sep"></div><button class="menu-item" data-action="reload">Reload page <b>⌘R</b></button></div><section class="panel" aria-label="Bloom DevTools"><header class="panel-header"><strong>Bloom DevTools</strong><span class="panel-state">Ready</span><i class="spacer"></i><button class="icon-btn" data-action="clear" title="Clear diagnostics">Clear</button><button class="icon-btn" data-action="close" aria-label="Close DevTools">×</button></header><nav class="tabs" aria-label="DevTools sections"><button class="tab" data-tab="overview">Overview</button><button class="tab" data-tab="issues">Issues</button><button class="tab" data-tab="console">Console</button><button class="tab" data-tab="history">History</button></nav><main class="body"></main></section><div class="backdrop" role="presentation"><section class="dialog" role="dialog" aria-modal="true" aria-labelledby="bloom-error-title"><header class="dialog-head"><span class="dot"></span><div><h2 id="bloom-error-title">Runtime Error</h2><p class="dialog-meta"></p></div><i class="spacer"></i><button class="icon-btn" data-action="dismiss" aria-label="Dismiss error">×</button></header><div class="dialog-body"><div class="message"></div><pre class="frame"></pre></div><footer class="dialog-foot"><span class="dialog-count"></span><i class="spacer"></i><button class="button" data-action="copy">Copy details</button><button class="button primary" data-action="dismiss">Dismiss</button></footer></section></div></div>`;

      const $ = (selector) => shadow.querySelector(selector);
      const $$ = (selector) => Array.from(shadow.querySelectorAll(selector));
      const indicator = $('.indicator'), popover = $('.popover'), panel = $('.panel'), body = $('.body'), backdrop = $('.backdrop');
      const state = { issues: [], logs: [], history: [], connected: false, compiling: false, tab: 'overview', selected: null };
      const safe = (value) => value == null ? '' : String(value);
      const short = (value, length = 170) => { value = safe(value); return value.length > length ? value.slice(0, length - 1) + '…' : value; };
      function locationHint(message) { const match = safe(message).match(/([\w./-]+\.dart):(\d+)(?::(\d+))?/); return match ? match[1] + ':' + match[2] + (match[3] ? ':' + match[3] : '') : ''; }
      function setText(selector, value) { const node = $(selector); if (node) node.textContent = safe(value); }
      function addIssue(type, message, stack, hint) { const fingerprint = type + '|' + safe(message) + '|' + safe(stack); if (state.issues.some((issue) => issue.fingerprint === fingerprint)) return false; state.issues.unshift({ type, message: safe(message), stack: safe(stack), hint: hint || locationHint(message), timestamp: Date.now(), fingerprint }); state.issues.splice(MAX_ISSUES); render(); return true; }
      function addLog(level, message) { state.logs.unshift({ level, message: safe(message), timestamp: Date.now() }); state.logs.splice(MAX_LOGS); render(); }
      function addHistory(kind, reason) { state.history.unshift({ kind, reason: safe(reason || ''), timestamp: Date.now() }); state.history.splice(MAX_LOGS); render(); }
      function setConnection(value) { state.connected = value; $('.status').dataset.disconnected = String(!value); setText('.connection', value ? 'Connected' : 'Reconnecting…'); renderHeader(); }
      function renderHeader() { const issueCount = state.issues.length; $('.count').style.display = issueCount ? 'block' : 'none'; $('.count').textContent = issueCount > 99 ? '99+' : String(issueCount); $('.menu-issues').textContent = String(issueCount); $('.menu-logs').textContent = String(state.logs.length); indicator.dataset.status = issueCount ? 'error' : state.compiling ? 'compiling' : 'ready'; setText('.panel-state', state.compiling ? 'Compiling…' : state.connected ? 'Ready' : 'Reconnecting…'); }
      function appendRow(container, label, value, mono) { const row = document.createElement('div'); row.className = 'row'; const l = document.createElement('label'); l.textContent = label; const v = document.createElement('span'); v.textContent = value; if (mono) v.className = 'mono'; row.append(l, v); container.append(row); }
      function empty(message) { const node = document.createElement('div'); node.className = 'empty'; node.textContent = message; return node; }
      function render() { renderHeader(); if (!panel.dataset.open) return; body.replaceChildren(); $$('.tab').forEach((tab) => tab.dataset.active = String(tab.dataset.tab === state.tab)); if (state.tab === 'overview') { const wrap = document.createElement('div'); wrap.className = 'overview'; const card = document.createElement('section'); card.className = 'card'; appendRow(card, 'Route', location.pathname || '/', true); appendRow(card, 'Connection', state.connected ? 'Connected' : 'Reconnecting…'); appendRow(card, 'Build status', state.compiling ? 'Compiling…' : 'Idle'); appendRow(card, 'Issues', String(state.issues.length)); appendRow(card, 'Live reload', 'SSE /_bloom_hr', true); wrap.append(card); const action = document.createElement('button'); action.className = 'button'; action.textContent = 'Reload page'; action.onclick = () => location.reload(); wrap.append(action); body.append(wrap); return; } const list = state.tab === 'issues' ? state.issues : state.tab === 'console' ? state.logs : state.history; if (!list.length) { body.append(empty(state.tab === 'issues' ? 'No build, runtime, or console issues.' : state.tab === 'console' ? 'No captured console output.' : 'No reloads yet.')); return; } list.forEach((item, index) => { if (state.tab === 'issues') { const button = document.createElement('button'); button.className = 'issue'; const head = document.createElement('div'); head.className = 'issue-head'; const dot = document.createElement('span'); dot.className = 'dot' + (item.type === 'Console warning' ? ' warn' : ''); const type = document.createElement('span'); type.textContent = item.type; const time = document.createElement('span'); time.style.marginLeft = 'auto'; time.textContent = new Date(item.timestamp).toLocaleTimeString(); head.append(dot, type, time); const message = document.createElement('div'); message.className = 'issue-msg'; message.textContent = item.message; button.append(head, message); button.onclick = () => openIssue(index); body.append(button); } else { const entry = document.createElement('div'); entry.className = 'log'; entry.dataset.level = item.level || ''; entry.textContent = (item.kind ? '[' + item.kind + '] ' : '') + (item.message || item.reason || ''); body.append(entry); } }); }
      function openIssue(index) { state.selected = index; const issue = state.issues[index]; if (!issue) return; setText('#bloom-error-title', issue.type); setText('.dialog-meta', issue.hint || new Date(issue.timestamp).toLocaleTimeString()); setText('.message', issue.message); const frame = $('.frame'); frame.replaceChildren(); if (issue.hint) { const hint = document.createElement('span'); hint.className = 'hint'; hint.textContent = '› ' + issue.hint + '\n\n'; frame.append(hint); } frame.append(document.createTextNode(issue.stack || 'No stack trace was supplied.')); setText('.dialog-count', (index + 1) + ' of ' + state.issues.length + ' issue' + (state.issues.length === 1 ? '' : 's')); backdrop.dataset.open = 'true'; $('.dialog [data-action="dismiss"]').focus(); }
      function dismiss() { backdrop.dataset.open = 'false'; state.selected = null; indicator.focus(); }
      function openPanel(tab) { state.tab = tab || state.tab; popover.dataset.open = 'false'; panel.dataset.open = 'true'; indicator.setAttribute('aria-expanded', 'true'); render(); }
      function closePanel() { panel.dataset.open = 'false'; popover.dataset.open = 'false'; indicator.setAttribute('aria-expanded', 'false'); indicator.focus(); }
      indicator.onclick = () => { if (panel.dataset.open === 'true') closePanel(); else { popover.dataset.open = popover.dataset.open === 'true' ? 'false' : 'true'; indicator.setAttribute('aria-expanded', popover.dataset.open); } };
      $$('[data-open-tab]').forEach((button) => button.onclick = () => openPanel(button.dataset.openTab)); $$('[data-tab]').forEach((button) => button.onclick = () => openPanel(button.dataset.tab)); $$('[data-action="close"]').forEach((button) => button.onclick = closePanel); $$('[data-action="dismiss"]').forEach((button) => button.onclick = dismiss); $$('[data-action="reload"]').forEach((button) => button.onclick = () => location.reload()); $$('[data-action="clear"]').forEach((button) => button.onclick = () => { state.issues.length = 0; state.logs.length = 0; render(); }); $('[data-action="copy"]').onclick = async () => { const issue = state.issues[state.selected]; if (!issue) return; const text = issue.type + '\n' + issue.message + '\n' + issue.hint + '\n\n' + issue.stack; try { await navigator.clipboard.writeText(text); setText('[data-action="copy"]', 'Copied'); setTimeout(() => setText('[data-action="copy"]', 'Copy details'), 1200); } catch (_) {} };
      backdrop.onclick = (event) => { if (event.target === backdrop) dismiss(); }; document.addEventListener('keydown', (event) => { if (event.key === 'Escape') { if (backdrop.dataset.open === 'true') dismiss(); else if (panel.dataset.open === 'true' || popover.dataset.open === 'true') closePanel(); } });
      let drag = null; const saved = (() => { try { return JSON.parse(localStorage.getItem(storageKey) || 'null'); } catch (_) { return null; } })(); if (saved && Number.isFinite(saved.x) && Number.isFinite(saved.y)) { indicator.style.left = saved.x + 'px'; indicator.style.top = saved.y + 'px'; indicator.style.bottom = 'auto'; }
      indicator.addEventListener('pointerdown', (event) => { drag = { x: event.clientX, y: event.clientY, left: indicator.offsetLeft, top: indicator.offsetTop, moved: false }; indicator.setPointerCapture(event.pointerId); }); indicator.addEventListener('pointermove', (event) => { if (!drag) return; const x = Math.max(12, Math.min(innerWidth - 52, drag.left + event.clientX - drag.x)); const y = Math.max(12, Math.min(innerHeight - 52, drag.top + event.clientY - drag.y)); drag.moved ||= Math.abs(event.clientX - drag.x) > 4 || Math.abs(event.clientY - drag.y) > 4; indicator.style.left = x + 'px'; indicator.style.top = y + 'px'; indicator.style.bottom = 'auto'; }); indicator.addEventListener('pointerup', () => { if (!drag) return; try { localStorage.setItem(storageKey, JSON.stringify({ x: indicator.offsetLeft, y: indicator.offsetTop })); } catch (_) {} drag = null; });
      window.addEventListener('error', (event) => { if (addIssue('Runtime Error', event.message || 'Uncaught error', event.error && event.error.stack || '', locationHint(event.message))) openIssue(0); }); window.addEventListener('unhandledrejection', (event) => { const reason = event.reason; if (addIssue('Unhandled Promise Rejection', reason && (reason.message || String(reason)), reason && reason.stack || '')) openIssue(0); }); window.addEventListener('bloom-runtime-error', (event) => { const detail = event.detail || {}; if (addIssue('Runtime Error', detail.message || detail.error || 'Bloom runtime error', detail.stack || detail.stackTrace || '', detail.sourceHint)) openIssue(0); });
      const nativeConsole = { error: console.error, warn: console.warn }; ['error', 'warn'].forEach((level) => { console[level] = function(...args) { try { const message = args.map((arg) => arg instanceof Error ? (arg.stack || arg.message) : typeof arg === 'string' ? arg : JSON.stringify(arg)).join(' '); addLog(level, message); if (!message.startsWith('[Bloom Build Error]')) addIssue(level === 'error' ? 'Console Error' : 'Console warning', message, ''); } catch (_) {} return nativeConsole[level].apply(console, args); }; });
      const observer = new MutationObserver(() => { document.querySelectorAll('[data-bloom-dev-error-overlay]').forEach((overlay) => { const message = overlay.textContent || 'Bloom runtime error'; if (addIssue('Runtime Error', message, '')) openIssue(0); // Keep the marker for existing integrations and tests, but prevent the legacy red screen from covering the unified dialog.
        overlay.style.display = 'none'; }); }); observer.observe(document.documentElement, { childList:true, subtree:true });
      function parse(event) { try { return event.data ? JSON.parse(event.data) : {}; } catch (_) { return {}; } } function connect() { const es = new EventSource('/_bloom_hr'); es.addEventListener('open', () => setConnection(true)); es.addEventListener('compiling', (event) => { const data = parse(event); state.compiling = true; addHistory('Compiling', data.reason); render(); }); es.addEventListener('reload', (event) => { const data = parse(event); addHistory('Reload', data.reason); location.reload(); }); es.addEventListener('hot-remount', (event) => { const data = parse(event); addHistory('Hot remount', data.reason); state.compiling = false; if (typeof window.__bloomDdcRemount === 'function') window.__bloomDdcRemount(); else location.reload(); render(); }); es.addEventListener('css-patch', (event) => { const data = parse(event); const matches = Array.from(document.querySelectorAll('style')).filter((style) => style.textContent === data.oldCss); if (matches.length === 1) { matches[0].textContent = data.newCss; state.compiling = false; addHistory('CSS patch', 'Patched stylesheet'); render(); } else location.reload(); }); es.addEventListener('error', (event) => { const data = parse(event); if (data.message) { state.compiling = false; if (addIssue('Build Error', data.message, '', locationHint(data.message))) openIssue(0); } render(); }); es.onerror = () => { setConnection(false); es.close(); setTimeout(connect, 1000); }; } connect(); setConnection(true); renderHeader();
    }

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
        editor: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"/>',
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
      .bloom-error-footer {
        display: flex;
        align-items: center;
        justify-content: flex-end;
        gap: 6px;
        margin-top: 2px;
      }
      .bloom-open-btn {
        padding: 3px 8px;
        font-size: 10.5px;
        font-family: inherit;
        border-radius: 4px;
        border: 1px solid rgba(99, 102, 241, 0.35);
        background: rgba(99, 102, 241, 0.15);
        color: #a5b4fc;
        cursor: pointer;
        display: inline-flex;
        align-items: center;
        gap: 4px;
        transition: background 120ms, color 120ms, border-color 120ms;
      }
      .bloom-open-btn:hover {
        background: rgba(99, 102, 241, 0.28);
        border-color: rgba(99, 102, 241, 0.6);
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

              const errFooter = document.createElement('div');
              errFooter.className = 'bloom-error-footer';

              const locMatch = (err.message || '').match(/([\w./-]+\.dart):(\d+)(?::\d+)?/);
              if (locMatch) {
                const capturedFile = locMatch[1];
                const capturedLine = parseInt(locMatch[2], 10);
                const shortFileName = capturedFile.split('/').pop() || capturedFile;

                const openBtn = document.createElement('button');
                openBtn.className = 'bloom-open-btn';
                openBtn.appendChild(svgIcon('editor', 11));
                const openText = document.createElement('span');
                openText.textContent = 'Open ' + shortFileName + ':' + capturedLine;
                openBtn.appendChild(openText);

                openBtn.onclick = () => {
                  fetch('/__open-in-editor', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ file: capturedFile, line: capturedLine }),
                  }).catch(() => {});
                };
                errFooter.appendChild(openBtn);
              }

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
              errFooter.appendChild(copyErrBtn);

              errCard.appendChild(errHeader);
              errCard.appendChild(pre);
              errCard.appendChild(errFooter);
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
      es.addEventListener('hot-remount', (e) => {
        let reason = null;
        try {
          if (e.data) {
            const payload = JSON.parse(e.data);
            if (payload.reason) reason = payload.reason;
          }
        } catch (_) {}
        console.log('%c⚡ [Bloom Hot Remount]%c Fast remounting application...', 'color:#6366F1;font-weight:bold', 'color:inherit');
        if (dt) dt.showRefreshing(reason);
        if (typeof window.__bloomDdcRemount === 'function') {
          window.__bloomDdcRemount();
        } else {
          setTimeout(() => window.location.reload(), 280);
        }
      });
      es.addEventListener('css-patch', (e) => {
        let payload = null;
        try {
          if (e.data) {
            payload = JSON.parse(e.data);
          }
        } catch (_) {}
        if (!payload || typeof payload.oldCss !== 'string' || typeof payload.newCss !== 'string') {
          console.warn('[Bloom CSS Hot Swap] Invalid css-patch payload; falling back to full reload.');
          console.log('%c⚡ [Bloom Hot Reload]%c Refreshing application...', 'color:#6366F1;font-weight:bold', 'color:inherit');
          if (dt) dt.showRefreshing();
          setTimeout(() => window.location.reload(), 280);
          return;
        }
        const styles = document.querySelectorAll('style');
        const matches = Array.from(styles).filter((s) => s.textContent === payload.oldCss);
        if (matches.length === 1) {
          matches[0].textContent = payload.newCss;
          console.log('%c⚡ [Bloom CSS Hot Swap]%c Patched stylesheet in place.', 'color:#6366F1;font-weight:bold', 'color:inherit');
        } else {
          console.warn('[Bloom CSS Hot Swap] Found ' + matches.length + ' matching <style> elements (expected 1); falling back to full reload.');
          console.log('%c⚡ [Bloom Hot Reload]%c Refreshing application...', 'color:#6366F1;font-weight:bold', 'color:inherit');
          if (dt) dt.showRefreshing();
          setTimeout(() => window.location.reload(), 280);
        }
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
    this.isDdcMode = false,
    this.ddcCacheDir,
  }) {
    _sortedProxyRules = List<BloomDevProxyRule>.from(proxyRules)
      ..sort((a, b) => b.pathPrefix.length.compareTo(a.pathPrefix.length));
  }

  String _prepareHtml(String html) {
    if (isDdcMode) {
      final mainScriptRegex = RegExp(
        r'<script\b[^>]*\bsrc\s*=\s*[\x22\x27](?:\./|/)?main\.js(?:[?#][^\x22\x27]*)?[\x22\x27][^>]*>\s*<\/script\s*>',
        caseSensitive: false,
      );
      html = html.replaceAll(mainScriptRegex, '');
    }

    if (autoInjectScript && !html.contains('__BLOOM_HR_ACTIVE__')) {
      final injection = isDdcMode
          ? '$ddcBootstrapScript\n$liveReloadScript</body>'
          : '$liveReloadScript</body>';
      html = html.replaceFirst('</body>', injection);
    } else if (isDdcMode && !html.contains('Bloom DDC Dev Bootstrap')) {
      html = html.replaceFirst('</body>', '$ddcBootstrapScript\n</body>');
    }
    return html;
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

  void broadcastHotRemount({String? reason}) {
    final payload = jsonEncode({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      if (reason != null) 'reason': reason,
    });

    final data = 'event: hot-remount\ndata: $payload\n\n';
    _broadcast(data);
  }

  void broadcastCssPatch({required String oldCss, required String newCss}) {
    final payload = jsonEncode({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'oldCss': oldCss,
      'newCss': newCss,
    });
    final data = 'event: css-patch\ndata: $payload\n\n';
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

  /// Broadcasts a structured development error to connected browser clients.
  ///
  /// [message] remains the required fallback for compilers that only provide
  /// stderr. Callers can provide a source location and stack when available;
  /// the browser overlay can then display those fields without parsing raw
  /// compiler output.
  void broadcastError(
    String errorMessage, {
    String kind = 'build',
    String? file,
    int? line,
    int? column,
    String? stack,
    String? codeFrame,
  }) {
    final payload = jsonEncode({
      'message': errorMessage,
      'kind': kind,
      if (file != null) 'file': file,
      if (line != null) 'line': line,
      if (column != null) 'column': column,
      if (stack != null) 'stack': stack,
      if (codeFrame != null) 'codeFrame': codeFrame,
    });
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

    // 2. Open in Editor Endpoint
    if (path == '/__open-in-editor') {
      req.response.headers.add('Access-Control-Allow-Origin', '*');
      req.response.headers.add('Access-Control-Allow-Methods', 'POST, OPTIONS');
      req.response.headers
          .add('Access-Control-Allow-Headers', 'Content-Type, Authorization');

      if (req.method == 'OPTIONS') {
        req.response.statusCode = HttpStatus.ok;
        await req.response.close();
        return;
      }

      if (req.method != 'POST') {
        req.response.statusCode = HttpStatus.methodNotAllowed;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({'error': 'Method not allowed'}));
        await req.response.close();
        return;
      }

      await _handleOpenInEditor(req);
      return;
    }

    // 3. Dev Proxy Rules (Longest prefix matched first)
    for (final rule in _sortedProxyRules) {
      if (rule.matches(path)) {
        await _proxy.forward(req, rule);
        return;
      }
    }

    // 4. DDC Runtime Assets (/require.js, /dart_sdk.js, /dart_sdk.js.map)
    if (isDdcMode && ddcCacheDir != null) {
      if (path == '/require.js' ||
          path == '/dart_sdk.js' ||
          path == '/dart_sdk.js.map') {
        final fileName = path.substring(1);
        final file = File(p.join(ddcCacheDir!.path, fileName));
        if (file.existsSync()) {
          final ext = p.extension(file.path).replaceAll('.', '').toLowerCase();
          req.response.headers
              .set(HttpHeaders.contentTypeHeader, _getContentType(ext));
          req.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
          req.response.add(file.readAsBytesSync());
          await req.response.close();
          return;
        }
      }
    }

    try {
      var reqPath = path.startsWith('/') ? path.substring(1) : path;
      if (reqPath.isEmpty) reqPath = 'index.html';

      var targetPath = p.canonicalize(p.join(webDir.path, reqPath));

      if (p.isWithin(webDir.path, targetPath) ||
          targetPath == p.canonicalize(webDir.path)) {
        var targetFile = File(targetPath);
        if (targetFile.existsSync() &&
            !FileSystemEntity.isDirectorySync(targetFile.path)) {
          final ext =
              p.extension(targetFile.path).replaceAll('.', '').toLowerCase();
          req.response.headers
              .set(HttpHeaders.contentTypeHeader, _getContentType(ext));
          req.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');

          if (ext == 'html') {
            var html = targetFile.readAsStringSync();
            html = _prepareHtml(html);
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
          html = _prepareHtml(html);
          req.response.headers
              .set(HttpHeaders.contentTypeHeader, 'text/html; charset=utf-8');
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
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'svg' => 'image/svg+xml',
      'ico' => 'image/x-icon',
      'mp4' => 'video/mp4',
      'webm' => 'video/webm',
      'woff2' => 'font/woff2',
      'woff' => 'font/woff',
      _ => 'application/octet-stream',
    };
  }

  Future<void> _handleOpenInEditor(HttpRequest req) async {
    try {
      final bodyStr = await utf8.decodeStream(req);
      final dynamic decoded;
      try {
        decoded = jsonDecode(bodyStr);
      } catch (e) {
        req.response.statusCode = HttpStatus.badRequest;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({'error': 'Malformed JSON body: $e'}));
        await req.response.close();
        return;
      }

      if (decoded is! Map<String, dynamic>) {
        req.response.statusCode = HttpStatus.badRequest;
        req.response.headers.contentType = ContentType.json;
        req.response.write(
            jsonEncode({'error': 'Invalid JSON body: expected an object'}));
        await req.response.close();
        return;
      }

      final rawFile = decoded['file'];
      final rawLine = decoded['line'];

      if (rawFile is! String || rawFile.trim().isEmpty) {
        req.response.statusCode = HttpStatus.badRequest;
        req.response.headers.contentType = ContentType.json;
        req.response.write(
            jsonEncode({'error': 'Missing or invalid "file" parameter'}));
        await req.response.close();
        return;
      }

      final int line;
      if (rawLine is int) {
        line = rawLine;
      } else if (rawLine is String) {
        final parsed = int.tryParse(rawLine);
        if (parsed == null) {
          req.response.statusCode = HttpStatus.badRequest;
          req.response.headers.contentType = ContentType.json;
          req.response.write(jsonEncode(
              {'error': 'Invalid "line" parameter: integer expected'}));
          await req.response.close();
          return;
        }
        line = parsed;
      } else {
        line = 1;
      }

      final canonicalWebDir = p.canonicalize(webDir.path);
      final targetPath = p.isAbsolute(rawFile)
          ? p.canonicalize(rawFile)
          : p.canonicalize(p.join(canonicalWebDir, rawFile));

      // Security boundary 1: Project path containment
      final isInside = targetPath == canonicalWebDir ||
          p.isWithin(canonicalWebDir, targetPath);
      if (!isInside) {
        req.response.statusCode = HttpStatus.badRequest;
        req.response.headers.contentType = ContentType.json;
        req.response.write(
            jsonEncode({'error': 'Path escapes project directory: $rawFile'}));
        await req.response.close();
        return;
      }

      final fileEntity = File(targetPath);
      if (!fileEntity.existsSync() ||
          FileSystemEntity.isDirectorySync(targetPath)) {
        req.response.statusCode = HttpStatus.badRequest;
        req.response.headers.contentType = ContentType.json;
        req.response
            .write(jsonEncode({'error': 'File does not exist: $rawFile'}));
        await req.response.close();
        return;
      }

      // Security boundary 2: Separate process arguments (no shell injection)
      final result = await _launchEditor(targetPath, line);
      req.response.statusCode = HttpStatus.ok;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(result));
      await req.response.close();
    } catch (e) {
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({'error': e.toString()}));
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> _launchEditor(
      String absoluteFilePath, int line) async {
    final envEditor =
        Platform.environment['VISUAL'] ?? Platform.environment['EDITOR'];

    String editorBin;
    List<String> args;

    if (envEditor != null && envEditor.trim().isNotEmpty) {
      final parts = envEditor.trim().split(RegExp(r'\s+'));
      editorBin = parts.first;
      final binName = p.basename(editorBin).toLowerCase();

      if (binName.contains('code') || binName.contains('cursor')) {
        args = ['--goto', '$absoluteFilePath:$line'];
      } else if (binName.contains('subl')) {
        args = ['$absoluteFilePath:$line'];
      } else if (binName.contains('vim') || binName.contains('nvim')) {
        args = ['+$line', absoluteFilePath];
      } else {
        args = ['$absoluteFilePath:$line'];
      }
    } else {
      editorBin = 'code';
      args = ['--goto', '$absoluteFilePath:$line'];
    }

    try {
      final processResult = await Process.run(editorBin, args);
      if (processResult.exitCode == 0) {
        return {'opened': true};
      } else {
        final stderrStr = processResult.stderr.toString().trim();
        final errReason = stderrStr.isNotEmpty
            ? stderrStr
            : 'Editor process exited with code ${processResult.exitCode}';
        return {'opened': false, 'error': errReason};
      }
    } catch (e) {
      if (envEditor == null || envEditor.trim().isEmpty) {
        return {
          'opened': false,
          'error':
              'No known editor found. Set \$EDITOR or \$VISUAL, or install VS Code (`code` command).',
        };
      }
      return {
        'opened': false,
        'error': 'Failed to launch editor "$editorBin": $e',
      };
    }
  }
}
