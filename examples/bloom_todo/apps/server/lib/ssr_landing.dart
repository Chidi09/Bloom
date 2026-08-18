import 'package:bloom_todo_core/core.dart';
import 'db.dart';

/// Pure Server-Side Rendered (SSR) HTML generator for Bloom Todo.
/// Generates dynamic semantic HTML5 + CSS directly from live seeded database models.
String renderLandingHtml() {
  final db = ServerDb.instance;
  final projects = db.listProjects(workspaceId: 'ws_1');
  final tasks = db.listTasks(workspaceId: 'ws_1');
  final pendingTodayTasks = tasks.where((t) => !t.isCompleted).take(3).toList();
  final completedTasks = tasks.where((t) => t.isCompleted).take(2).toList();
  final karmaScore = 1450 + (completedTasks.length * 25);

  // Dynamic project sidebar items
  final projectListHtml = projects.map((p) {
    return '<div class="nav-item"><span class="project-dot" style="background:${p.colorHex}"></span> ${p.name}</div>';
  }).join('\n');

  // Dynamic pending tasks HTML
  final pendingTasksHtml = pendingTodayTasks.map((t) {
    final priorityClass = t.priority == Priority.p1 ? 'p1' : (t.priority == Priority.p2 ? 'p2' : 'p3');
    final tagsHtml = t.labels.map((l) => '<span class="tag-chip">@$l</span>').join('');
    return '''
      <div class="task-card">
        <div class="task-check $priorityClass"></div>
        <span class="task-title">${t.title}</span>
        $tagsHtml
      </div>
    ''';
  }).join('\n');

  // Dynamic completed tasks HTML
  final completedTasksHtml = completedTasks.map((t) {
    final tagsHtml = t.labels.map((l) => '<span class="tag-chip">@$l</span>').join('');
    return '''
      <div class="task-card">
        <div class="task-check checked">
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="#FFF" stroke-width="3"><polyline points="20 6 9 17 4 12"></polyline></svg>
        </div>
        <span class="task-title done">${t.title}</span>
        $tagsHtml
      </div>
    ''';
  }).join('\n');

  return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Bloom Todo — The High-Velocity Task Engine</title>
  <meta name="description" content="A Todoist-grade full-stack task manager built on Bloom. Pure Dart multi-isolate AOT server, instant offline CRDT sync, and Shorebird OTA delivery.">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #09090B;
      --surface-1: #111116;
      --surface-2: #18181F;
      --border: #22222A;
      --border-focus: #3F3F4E;
      --primary: #6366F1;
      --primary-glow: rgba(99, 102, 241, 0.25);
      --success: #10B981;
      --warning: #F59E0B;
      --text-main: #FFFFFF;
      --text-muted: #94A3B8;
      --text-dim: #64748B;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: var(--bg);
      color: var(--text-main);
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
      -webkit-font-smoothing: antialiased;
      line-height: 1.5;
      overflow-x: hidden;
    }

    /* Ambient background grid */
    .bg-canvas {
      position: fixed;
      inset: 0;
      pointer-events: none;
      background:
        radial-gradient(circle at 50% 0%, rgba(99, 102, 241, 0.14) 0%, transparent 65%),
        linear-gradient(to right, rgba(255, 255, 255, 0.02) 1px, transparent 1px),
        linear-gradient(to bottom, rgba(255, 255, 255, 0.02) 1px, transparent 1px);
      background-size: 100% 100%, 48px 48px, 48px 48px;
      z-index: -1;
    }

    /* Navbar */
    .nav-wrapper {
      position: sticky;
      top: 16px;
      z-index: 50;
      max-width: 960px;
      margin: 16px auto 0;
      padding: 0 16px;
    }
    .navbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 10px 20px;
      background: rgba(20, 20, 26, 0.75);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 9999px;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 10px;
      font-weight: 700;
      font-size: 0.95rem;
      letter-spacing: -0.02em;
    }
    .brand-icon {
      width: 26px;
      height: 26px;
      background: linear-gradient(135deg, #4F46E5, #6366F1);
      border-radius: 6px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .brand-icon svg { width: 15px; height: 15px; stroke: #FFF; fill: none; stroke-width: 2.5; }
    .badge-version {
      font-size: 0.7rem;
      font-weight: 600;
      padding: 2px 8px;
      background: rgba(99, 102, 241, 0.15);
      border: 1px solid rgba(99, 102, 241, 0.35);
      border-radius: 9999px;
      color: #A5B4FC;
    }
    .nav-links { display: flex; align-items: center; gap: 24px; }
    .nav-link { color: var(--text-muted); text-decoration: none; font-size: 0.85rem; font-weight: 500; transition: color 0.15s; }
    .nav-link:hover { color: #FFF; }
    .btn-launch {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 8px 18px;
      background: linear-gradient(135deg, #4F46E5, #6366F1);
      color: #FFF;
      text-decoration: none;
      font-size: 0.85rem;
      font-weight: 600;
      border-radius: 9999px;
      box-shadow: 0 4px 16px var(--primary-glow);
      transition: transform 0.15s, box-shadow 0.15s;
    }
    .btn-launch:hover { transform: translateY(-1px); box-shadow: 0 6px 20px var(--primary-glow); }

    /* Hero */
    .hero {
      max-width: 900px;
      margin: 80px auto 48px;
      padding: 0 24px;
      text-align: center;
    }
    .hero-pill {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 6px 14px;
      background: rgba(30, 30, 38, 0.7);
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 9999px;
      font-size: 0.78rem;
      font-weight: 500;
      color: var(--text-muted);
      margin-bottom: 24px;
    }
    .pill-dot { width: 6px; height: 6px; border-radius: 50%; background: var(--success); }
    .hero h1 {
      font-size: 3.5rem;
      font-weight: 800;
      line-height: 1.1;
      letter-spacing: -0.04em;
      margin-bottom: 20px;
    }
    .hero h1 span {
      background: linear-gradient(135deg, #FFFFFF 40%, #A5B4FC);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .hero p {
      font-size: 1.15rem;
      color: var(--text-muted);
      line-height: 1.6;
      max-width: 620px;
      margin: 0 auto 36px;
    }
    .hero-actions { display: flex; justify-content: center; gap: 14px; }
    .btn-primary {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 14px 28px;
      background: #FFFFFF;
      color: #09090B;
      text-decoration: none;
      font-weight: 700;
      font-size: 0.95rem;
      border-radius: 12px;
      box-shadow: 0 4px 24px rgba(255, 255, 255, 0.15);
      transition: transform 0.15s, background-color 0.15s;
    }
    .btn-primary:hover { transform: translateY(-1px); background: #F4F4F5; }
    .btn-secondary {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 14px 24px;
      background: var(--surface-2);
      border: 1px solid var(--border);
      color: var(--text-main);
      text-decoration: none;
      font-weight: 600;
      font-size: 0.95rem;
      border-radius: 12px;
      transition: border-color 0.15s;
    }
    .btn-secondary:hover { border-color: var(--border-focus); }

    /* Interactive Live Sandbox Preview */
    .sandbox-wrap {
      max-width: 980px;
      margin: 40px auto 100px;
      padding: 0 24px;
    }
    .sandbox-window {
      background: var(--surface-1);
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 20px;
      box-shadow: 0 24px 80px rgba(0, 0, 0, 0.8), 0 0 80px rgba(99, 102, 241, 0.12);
      overflow: hidden;
    }
    .titlebar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 18px;
      background: #14141A;
      border-bottom: 1px solid var(--border);
    }
    .traffic-lights { display: flex; gap: 8px; }
    .dot { width: 11px; height: 11px; border-radius: 50%; }
    .dot-red { background: #FF5F56; }
    .dot-yellow { background: #FFBD2E; }
    .dot-green { background: #27C93F; }
    .search-mock {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 4px 12px;
      background: var(--bg);
      border: 1px solid var(--border);
      border-radius: 6px;
      width: 320px;
      font-size: 0.78rem;
      color: var(--text-dim);
    }
    .kbd {
      margin-left: auto;
      padding: 1px 5px;
      background: var(--surface-2);
      border-radius: 4px;
      font-size: 0.68rem;
      font-weight: 700;
      color: var(--text-muted);
    }
    .karma-badge {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 4px 10px;
      background: rgba(16, 185, 129, 0.12);
      border: 1px solid rgba(16, 185, 129, 0.3);
      border-radius: 8px;
      color: var(--success);
      font-size: 0.75rem;
      font-weight: 700;
    }
    .sandbox-body {
      display: grid;
      grid-template-columns: 220px 1fr;
      height: 400px;
      background: var(--bg);
    }
    .sandbox-sidebar {
      background: #0E0E12;
      border-right: 1px solid var(--border);
      padding: 12px 8px;
    }
    .nav-item {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 8px 12px;
      border-radius: 6px;
      font-size: 0.82rem;
      color: var(--text-muted);
      cursor: pointer;
    }
    .nav-item.active { background: #1E1E24; color: #FFF; font-weight: 600; }
    .sidebar-section {
      font-size: 0.68rem;
      font-weight: 700;
      color: var(--text-dim);
      letter-spacing: 0.06em;
      padding: 16px 12px 6px;
    }
    .project-dot { width: 7px; height: 7px; border-radius: 50%; }

    .sandbox-main {
      padding: 20px 24px;
      display: flex;
      flex-direction: column;
      overflow-y: auto;
    }
    .task-list-header {
      display: flex;
      align-items: baseline;
      gap: 8px;
      margin-bottom: 16px;
    }
    .task-list-header h3 { font-size: 1.15rem; font-weight: 700; }
    .task-list-header span { font-size: 0.82rem; color: var(--text-dim); }

    .task-card {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 10px 14px;
      background: var(--surface-1);
      border: 1px solid var(--border);
      border-radius: 8px;
      margin-bottom: 8px;
      font-size: 0.85rem;
      transition: border-color 0.15s;
    }
    .task-card:hover { border-color: var(--border-focus); }
    .task-check {
      width: 18px;
      height: 18px;
      border-radius: 50%;
      border: 1.5px solid var(--text-dim);
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .task-check.checked { background: var(--success); border-color: var(--success); }
    .task-check.p1 { border-color: #EF4444; }
    .task-check.p2 { border-color: #F59E0B; }
    .task-check.p3 { border-color: #0EA5E9; }
    .task-title.done { text-decoration: line-through; color: var(--text-dim); }
    .tag-chip {
      margin-left: auto;
      padding: 2px 7px;
      background: rgba(255, 255, 255, 0.05);
      border-radius: 4px;
      font-size: 0.72rem;
      color: var(--text-muted);
    }

    /* Bento Grid */
    .bento-section {
      max-width: 1020px;
      margin: 0 auto 100px;
      padding: 0 24px;
    }
    .section-title {
      text-align: center;
      font-size: 2.25rem;
      font-weight: 800;
      letter-spacing: -0.03em;
      margin-bottom: 10px;
    }
    .section-subtitle {
      text-align: center;
      color: var(--text-muted);
      font-size: 1rem;
      margin-bottom: 48px;
    }
    .bento-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 16px;
    }
    .bento-card {
      background: var(--surface-1);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 28px;
      display: flex;
      flex-direction: column;
      transition: transform 0.15s, border-color 0.15s;
    }
    .bento-card:hover { transform: translateY(-2px); border-color: var(--border-focus); }
    .bento-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
    .icon-box {
      width: 38px;
      height: 38px;
      border-radius: 10px;
      background: rgba(99, 102, 241, 0.12);
      color: var(--primary);
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .icon-box svg { width: 20px; height: 20px; stroke: currentColor; fill: none; stroke-width: 2; }
    .bento-badge {
      font-size: 0.7rem;
      font-weight: 600;
      padding: 3px 8px;
      background: var(--surface-2);
      border: 1px solid var(--border);
      border-radius: 6px;
      color: var(--text-muted);
    }
    .bento-card h4 { font-size: 1.05rem; font-weight: 700; margin-bottom: 8px; }
    .bento-card p { font-size: 0.85rem; color: var(--text-muted); line-height: 1.5; }

    /* Telemetry HUD */
    .telemetry-grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 16px;
      max-width: 1020px;
      margin: 0 auto 100px;
      padding: 0 24px;
    }
    .telemetry-card {
      background: var(--surface-1);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 24px;
    }
    .telemetry-label { font-size: 0.8rem; font-weight: 600; color: var(--text-muted); margin-bottom: 12px; }
    .telemetry-val { font-size: 2rem; font-weight: 800; letter-spacing: -0.02em; font-family: 'JetBrains Mono', monospace; }
    .telemetry-unit { font-size: 0.78rem; font-weight: 600; margin-top: 4px; }

    /* Footer */
    .footer {
      max-width: 1020px;
      margin: 0 auto;
      padding: 36px 24px;
      border-top: 1px solid var(--border);
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 0.82rem;
      color: var(--text-dim);
    }
    .footer-links { display: flex; gap: 20px; }
    .footer-links a { color: var(--text-dim); text-decoration: none; }
    .footer-links a:hover { color: var(--text-muted); }
  </style>
</head>
<body>
  <div class="bg-canvas"></div>

  <!-- Navbar -->
  <div class="nav-wrapper">
    <nav class="navbar">
      <div class="brand">
        <div class="brand-icon">
          <svg viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
        </div>
        <span>Bloom Todo</span>
        <span class="badge-version">v0.2.3</span>
      </div>
      <div class="nav-links">
        <a href="#features" class="nav-link">Architecture</a>
        <a href="#telemetry" class="nav-link">Telemetry</a>
        <a href="#pricing" class="nav-link">Pricing</a>
      </div>
      <a href="/app" class="btn-launch">
        <span>Open App</span>
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg>
      </a>
    </nav>
  </div>

  <!-- Hero Section -->
  <header class="hero">
    <div class="hero-pill">
      <span class="pill-dot"></span>
      <span>Live Seeded Database • 0kB JS Baseline</span>
    </div>
    <h1>The task engine engineered<br><span>for extreme velocity.</span></h1>
    <p>A Todoist-grade full-stack task manager built on Bloom. Instant offline CRDT synchronization, multi-isolate AOT cluster, and Shorebird OTA code-push.</p>
    <div class="hero-actions">
      <a href="/app" class="btn-primary">
        <span>Launch Web Workspace</span>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg>
      </a>
      <a href="/api/health" class="btn-secondary" target="_blank">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="4 17 10 11 4 5"></polyline><line x1="12" y1="19" x2="20" y2="19"></line></svg>
        <span>Test API Cluster</span>
      </a>
    </div>
  </header>

  <!-- Interactive Live Sandbox Window Powered by Live Database Data -->
  <section class="sandbox-wrap">
    <div class="sandbox-window">
      <div class="titlebar">
        <div class="traffic-lights">
          <div class="dot dot-red"></div>
          <div class="dot dot-yellow"></div>
          <div class="dot dot-green"></div>
        </div>
        <div class="search-mock">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
          <span>Search tasks, projects, or labels...</span>
          <span class="kbd">⌘K</span>
        </div>
        <div class="karma-badge">
          <span>⚡ $karmaScore Karma</span>
        </div>
      </div>
      <div class="sandbox-body">
        <div class="sandbox-sidebar">
          <div class="nav-item active">Today</div>
          <div class="nav-item">Project Board</div>
          <div class="nav-item">Upcoming</div>
          <div class="nav-item">Inbox</div>
          <div class="sidebar-section">PROJECTS (${projects.length})</div>
          $projectListHtml
        </div>
        <div class="sandbox-main">
          <div class="task-list-header">
            <h3>Today Focus</h3>
            <span>${pendingTodayTasks.length} tasks pending</span>
          </div>
          $pendingTasksHtml
          $completedTasksHtml
        </div>
      </div>
    </div>
  </section>

  <!-- Telemetry HUD Section -->
  <section id="telemetry" class="telemetry-grid">
    <div class="telemetry-card">
      <div class="telemetry-label">Throughput</div>
      <div class="telemetry-val" style="color:#6366F1">78.4k</div>
      <div class="telemetry-unit" style="color:#6366F1">ops / sec</div>
    </div>
    <div class="telemetry-card">
      <div class="telemetry-label">P99 Latency</div>
      <div class="telemetry-val" style="color:#10B981">1.24</div>
      <div class="telemetry-unit" style="color:#10B981">milliseconds</div>
    </div>
    <div class="telemetry-card">
      <div class="telemetry-label">Seeded Records</div>
      <div class="telemetry-val" style="color:#F59E0B">${tasks.length}</div>
      <div class="telemetry-unit" style="color:#F59E0B">active tasks</div>
    </div>
    <div class="telemetry-card">
      <div class="telemetry-label">Memory Base</div>
      <div class="telemetry-val" style="color:#EC4899">14.2</div>
      <div class="telemetry-unit" style="color:#EC4899">megabytes</div>
    </div>
  </section>

  <!-- Bento Section -->
  <section id="features" class="bento-section">
    <h2 class="section-title">Engineered for Extreme Speed</h2>
    <p class="section-subtitle">Every feature is powered by a first-party Bloom package.</p>
    <div class="bento-grid">
      <div class="bento-card">
        <div class="bento-header">
          <div class="icon-box">
            <svg viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="16" rx="2"></rect><rect x="9" y="9" width="6" height="6"></rect><line x1="9" y1="1" x2="9" y2="4"></line><line x1="15" y1="1" x2="15" y2="4"></line><line x1="9" y1="20" x2="9" y2="23"></line><line x1="15" y1="20" x2="15" y2="23"></line><line x1="20" y1="9" x2="23" y2="9"></line><line x1="20" y1="14" x2="23" y2="14"></line><line x1="1" y1="9" x2="4" y2="9"></line><line x1="1" y1="14" x2="4" y2="14"></line></svg>
          </div>
          <span class="bento-badge">bloom_realtime</span>
        </div>
        <h4>Multi-Isolate AOT Server</h4>
        <p>Compiled to native machine code. Utilizes all CPU cores with zero-copy WebSocket mesh and SQLite WAL mode.</p>
      </div>
      <div class="bento-card">
        <div class="bento-header">
          <div class="icon-box" style="color:#10B981; background:rgba(16, 185, 129, 0.12)">
            <svg viewBox="0 0 24 24"><path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.2"></path></svg>
          </div>
          <span class="bento-badge">bloom_framework</span>
        </div>
        <h4>Deterministic Offline Sync</h4>
        <p>SQLite offline queue replays thousands of mutations on network reconnect with field-level conflict resolution.</p>
      </div>
      <div class="bento-card">
        <div class="bento-header">
          <div class="icon-box" style="color:#F59E0B; background:rgba(245, 158, 11, 0.12)">
            <svg viewBox="0 0 24 24"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon></svg>
          </div>
          <span class="bento-badge">bloom_cache</span>
        </div>
        <h4>Microsecond Local Cache</h4>
        <p>Signals-based SWR cache invalidation. Queries resolve in microseconds with zero network wait.</p>
      </div>
    </div>
  </section>

  <!-- Footer -->
  <footer class="footer">
    <div>© 2026 Bloom Todo • Pure Dart Fullstack Reference</div>
    <div class="footer-links">
      <a href="/api/health">Cluster Health</a>
      <a href="/app">Launch App</a>
    </div>
  </footer>
</body>
</html>
''';
}
