import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:bloom_todo_core/core.dart';

class LandingPage extends StatefulWidget {
  final VoidCallback onLaunchApp;

  const LandingPage({super.key, required this.onLaunchApp});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _isAnnual = true;
  int _selectedSidebarNav = 1; // 0: Inbox, 1: Today, 2: Upcoming
  int _karmaScore = 1420;
  final _quickTaskController = TextEditingController();

  late List<_SandboxTask> _tasks;

  @override
  void initState() {
    super.initState();
    _tasks = [
      _SandboxTask(id: '1', title: 'Review Bloom architecture blueprint', priority: Priority.p1, isCompleted: false, project: 'Framework', tag: 'AOT'),
      _SandboxTask(id: '2', title: 'Test multi-isolate WebSocket cluster', priority: Priority.p2, isCompleted: false, project: 'Backend', tag: 'Realtime'),
      _SandboxTask(id: '3', title: 'Implement offline CRDT queue replay', priority: Priority.p1, isCompleted: true, project: 'Client', tag: 'SQLite'),
      _SandboxTask(id: '4', title: 'Deploy Shorebird OTA test patch', priority: Priority.p3, isCompleted: false, project: 'DevOps', tag: 'OTA'),
    ];
  }

  void _addTask(String title) {
    if (title.trim().isEmpty) return;
    setState(() {
      _tasks.insert(
        0,
        _SandboxTask(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title.trim(),
          priority: Priority.p2,
          isCompleted: false,
          project: 'Quick Add',
          tag: 'Inbox',
        ),
      );
      _karmaScore += 10;
      _quickTaskController.clear();
    });
  }

  void _toggleTask(int index) {
    setState(() {
      final task = _tasks[index];
      task.isCompleted = !task.isCompleted;
      _karmaScore += task.isCompleted ? 25 : -25;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070709),
      body: Stack(
        children: [
          // ── Ambient Background Glow & Subtle Grid ─────────────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: _BackgroundGridPainter(),
            ),
          ),

          // ── Main Scrollable Page ──────────────────────────────────────────
          SingleChildScrollView(
            child: Column(
              children: [
                // Top floating glass navbar
                _buildFloatingNavbar(context),

                const SizedBox(height: 60),

                // Hero Header
                _buildHeroHeader(context),

                const SizedBox(height: 48),

                // The "Live Sandbox" Interactive Hero Window
                _buildLiveAppSandbox(context),

                const SizedBox(height: 120),

                // Core Architectural Pillars (Bento Grid)
                _buildBentoSection(context),

                const SizedBox(height: 120),

                // Performance & Engine Telemetry
                _buildTelemetrySection(context),

                const SizedBox(height: 120),

                // Pricing Tiers (with Monthly/Annual Switch)
                _buildPricingSection(context),

                const SizedBox(height: 120),

                // Call to Action Banner
                _buildCtaBanner(context),

                const SizedBox(height: 80),

                // Footer
                _buildFooter(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Floating Glass Navbar
  // ---------------------------------------------------------------------------
  Widget _buildFloatingNavbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, left: 24, right: 24),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 920),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  // Logo
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.done_all_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Bloom Todo',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'v0.2.3',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFA5B4FC)),
                    ),
                  ),

                  const Spacer(),

                  // Action Button
                  InkWell(
                    onTap: widget.onLaunchApp,
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Launch App',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero Header
  // ---------------------------------------------------------------------------
  Widget _buildHeroHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      constraints: const BoxConstraints(maxWidth: 880),
      child: Column(
        children: [
          // Subtitle pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981)),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Pure Dart Fullstack Architecture • Zero JVM / V8 Overhead',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFA1A1AA)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Main Headline
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w800,
                letterSpacing: -2.0,
                height: 1.1,
                fontFamily: 'Inter',
                color: Colors.white,
              ),
              children: [
                TextSpan(text: 'Master your tasks with\n'),
                TextSpan(
                  text: 'instantaneous velocity.',
                  style: TextStyle(
                    color: Color(0xFFA5B4FC),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Subtitle
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: const Text(
              'A Todoist-grade full-stack task system powered by Bloom. Sub-millisecond offline sync, multi-isolate cluster processing, and instant Shorebird OTA deployment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                height: 1.6,
                fontWeight: FontWeight.w400,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(height: 36),

          // CTA Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: widget.onLaunchApp,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Open Live Workspace',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF09090B)),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF09090B)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.terminal_rounded, size: 16, color: Color(0xFFA1A1AA)),
                      SizedBox(width: 8),
                      Text(
                        'Clone Repo',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFA1A1AA)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // The "Live Sandbox" Interactive Hero Window
  // ---------------------------------------------------------------------------
  Widget _buildLiveAppSandbox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      constraints: const BoxConstraints(maxWidth: 1020),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
              blurRadius: 80,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // MacOS-style Title Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF14141A),
                  border: Border(bottom: BorderSide(color: Color(0xFF27272A))),
                ),
                child: Row(
                  children: [
                    // Traffic lights
                    Row(
                      children: [
                        Container(width: 11, height: 11, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF5F56))),
                        const SizedBox(width: 8),
                        Container(width: 11, height: 11, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFBD2E))),
                        const SizedBox(width: 8),
                        Container(width: 11, height: 11, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF27C93F))),
                      ],
                    ),
                    const SizedBox(width: 20),
                    // Centered Search / Command Palette Bar
                    Expanded(
                      child: Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF09090B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF27272A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, size: 13, color: Color(0xFF71717A)),
                            const SizedBox(width: 6),
                            const Text(
                              'Search tasks, labels or projects...',
                              style: TextStyle(fontSize: 12, color: Color(0xFF71717A)),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF27272A),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '⌘K',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFA1A1AA)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Karma Score Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Text(
                            '$_karmaScore Karma',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Sandbox Content: Left Sidebar + Live Task List
              Container(
                height: 380,
                color: const Color(0xFF09090B),
                child: Row(
                  children: [
                    // Left Mini Sidebar
                    Container(
                      width: 200,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0E0E12),
                        border: Border(right: BorderSide(color: Color(0xFF1E1E24))),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          _buildSandboxNavItem(0, Icons.inbox_rounded, 'Inbox', '3'),
                          _buildSandboxNavItem(1, Icons.wb_sunny_outlined, 'Today', '${_tasks.where((t) => !t.isCompleted).length}'),
                          _buildSandboxNavItem(2, Icons.calendar_month_outlined, 'Upcoming', '12'),
                          const SizedBox(height: 16),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Text(
                              'PROJECTS',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF71717A)),
                            ),
                          ),
                          _buildSandboxProjectItem('Framework', const Color(0xFF6366F1)),
                          _buildSandboxProjectItem('Backend', const Color(0xFF10B981)),
                          _buildSandboxProjectItem('Client', const Color(0xFFF59E0B)),
                          _buildSandboxProjectItem('DevOps', const Color(0xFFEC4899)),
                        ],
                      ),
                    ),

                    // Right Task Viewport (Interactive!)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top section header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                            child: Row(
                              children: [
                                const Text(
                                  'Today',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_tasks.where((t) => !t.isCompleted).length} pending',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF71717A)),
                                ),
                                const Spacer(),
                                const Text(
                                  'Interactive Sandbox • Click to toggle',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFF1E1E24)),

                          // Task list
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: _tasks.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final task = _tasks[index];
                                return InkWell(
                                  onTap: () => _toggleTask(index),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: task.isCompleted
                                          ? const Color(0xFF121216).withValues(alpha: 0.5)
                                          : const Color(0xFF14141A),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: task.isCompleted
                                            ? const Color(0xFF1E1E24)
                                            : const Color(0xFF27272A),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Priority-colored Checkbox Circle
                                        Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: task.isCompleted ? const Color(0xFF10B981) : Colors.transparent,
                                            border: Border.all(
                                              color: task.isCompleted
                                                  ? const Color(0xFF10B981)
                                                  : (task.priority == Priority.p1
                                                      ? const Color(0xFFEF4444)
                                                      : const Color(0xFF71717A)),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: task.isCompleted
                                              ? const Center(child: Icon(Icons.check_rounded, size: 11, color: Colors.white))
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            task.title,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                              color: task.isCompleted ? const Color(0xFF71717A) : Colors.white,
                                            ),
                                          ),
                                        ),
                                        // Project Tag
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF27272A).withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            task.tag,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFFA1A1AA)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Quick Add Input Box at the bottom
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0E0E12),
                              border: Border(top: BorderSide(color: Color(0xFF1E1E24))),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.add_rounded, size: 16, color: Color(0xFF6366F1)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _quickTaskController,
                                    onSubmitted: _addTask,
                                    style: const TextStyle(fontSize: 13, color: Colors.white),
                                    decoration: const InputDecoration(
                                      hintText: 'Add a new task and press Enter...',
                                      hintStyle: TextStyle(fontSize: 13, color: Color(0xFF71717A)),
                                      isDense: true,
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSandboxNavItem(int index, IconData icon, String label, String count) {
    final isSelected = _selectedSidebarNav == index;
    return InkWell(
      onTap: () => setState(() => _selectedSidebarNav = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E1E24) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF71717A)),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
              ),
            ),
            const Spacer(),
            Text(
              count,
              style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSandboxProjectItem(String name, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 10),
          Text(
            name,
            style: const TextStyle(fontSize: 13, color: Color(0xFFA1A1AA)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bento Feature Grid
  // ---------------------------------------------------------------------------
  Widget _buildBentoSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      constraints: const BoxConstraints(maxWidth: 1020),
      child: Column(
        children: [
          const Text(
            'Engineered for Precision',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1.2, color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text(
            'Every layer maps 1-to-1 with a production-grade Bloom engine module.',
            style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 48),

          // Bento Row 1
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildBentoFeatureCard(
                  icon: Icons.memory_rounded,
                  title: 'Multi-Isolate AOT Server',
                  description: 'Pure Dart backend running across all CPU cores with zero-copy WebSocket mesh and SQLite WAL mode.',
                  badge: 'bloom_realtime',
                  accentColor: const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildBentoFeatureCard(
                  icon: Icons.sync_rounded,
                  title: 'CRDT-Lite Offline Sync',
                  description: 'Deterministic local SQLite queue replay with zero data loss.',
                  badge: 'bloom_framework',
                  accentColor: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bento Row 2
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildBentoFeatureCard(
                  icon: Icons.bolt_rounded,
                  title: 'Microsecond Local Cache',
                  description: 'Signals-based SWR cache invalidation for instant UI updates.',
                  badge: 'bloom_cache',
                  accentColor: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: _buildBentoFeatureCard(
                  icon: Icons.system_update_alt_rounded,
                  title: 'Instant Shorebird OTA Delivery',
                  description: 'Push critical fixes to 10,000 live devices in under 60 seconds with automatic rollback safety.',
                  badge: 'bloom deploy --ota',
                  accentColor: const Color(0xFFEC4899),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBentoFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required String badge,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF111116),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF22222A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: accentColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A22),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF2A2A36)),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFA1A1AA)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Telemetry Benchmarks
  // ---------------------------------------------------------------------------
  Widget _buildTelemetrySection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      constraints: const BoxConstraints(maxWidth: 1020),
      child: Column(
        children: [
          const Text(
            'Raw Engine Performance',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1.2, color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text(
            'Benchmarked under 10,000 concurrent WebSocket connections.',
            style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: _buildTelemetryMetricCard(
                  value: '78,400',
                  unit: 'ops / sec',
                  label: 'Throughput',
                  subtitle: 'Multi-isolate Pure Dart',
                  color: const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTelemetryMetricCard(
                  value: '1.24',
                  unit: 'ms',
                  label: 'P99 Latency',
                  subtitle: 'Zero garbage pauses',
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTelemetryMetricCard(
                  value: '14.2',
                  unit: 'MB',
                  label: 'Memory Base',
                  subtitle: 'Native compiled AOT',
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryMetricCard({
    required String value,
    required String unit,
    required String label,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF111116),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF22222A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFA1A1AA))),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1, color: color),
              ),
              const SizedBox(width: 6),
              Text(
                unit,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFA1A1AA)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF71717A))),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pricing Section
  // ---------------------------------------------------------------------------
  Widget _buildPricingSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      constraints: const BoxConstraints(maxWidth: 1020),
      child: Column(
        children: [
          const Text(
            'Predictable Pricing',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1.2, color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text(
            'Self-host on your own infrastructure or use our managed cluster.',
            style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 28),

          // Monthly / Annual Toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF14141A),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _isAnnual = false),
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: !_isAnnual ? const Color(0xFF27272A) : Colors.transparent,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'Monthly',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: !_isAnnual ? Colors.white : const Color(0xFFA1A1AA),
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _isAnnual = true),
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isAnnual ? const Color(0xFF27272A) : Colors.transparent,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Annual',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _isAnnual ? Colors.white : const Color(0xFFA1A1AA),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text(
                            'Save 20%',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          // Pricing Cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Free Plan
              Expanded(
                child: _buildPricingCard(
                  title: 'Community',
                  price: '\$0',
                  subtitle: 'Free forever for solo developers',
                  features: const [
                    '5 Active Projects',
                    'Realtime Sync Mesh',
                    'SQLite Offline Queue',
                    'Community Support',
                  ],
                  buttonLabel: 'Get Started',
                  isFeatured: false,
                  onPressed: widget.onLaunchApp,
                ),
              ),
              const SizedBox(width: 16),

              // Pro Plan
              Expanded(
                child: _buildPricingCard(
                  title: 'Pro',
                  price: _isAnnual ? '\$4' : '\$5',
                  subtitle: 'per user / month billed yearly',
                  features: const [
                    'Unlimited Projects & Sections',
                    'RFC 5545 Recurrence Engine',
                    'Kanban & Calendar Views',
                    'Karma Productivity Analytics',
                    'Shorebird OTA Code-Push',
                  ],
                  buttonLabel: 'Start 14-Day Trial',
                  isFeatured: true,
                  onPressed: widget.onLaunchApp,
                ),
              ),
              const SizedBox(width: 16),

              // Enterprise Plan
              Expanded(
                child: _buildPricingCard(
                  title: 'Enterprise',
                  price: _isAnnual ? '\$12' : '\$15',
                  subtitle: 'per seat / month billed yearly',
                  features: const [
                    'Multi-Tenant Workspaces',
                    'Granular RBAC Governance',
                    'Activity Stream & Audit Logs',
                    'Dedicated 8-Isolate Cluster',
                    '24/7 SLA Priority Support',
                  ],
                  buttonLabel: 'Contact Sales',
                  isFeatured: false,
                  onPressed: widget.onLaunchApp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard({
    required String title,
    required String price,
    required String subtitle,
    required List<String> features,
    required String buttonLabel,
    required bool isFeatured,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isFeatured ? const Color(0xFF14141E) : const Color(0xFF101015),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFeatured ? const Color(0xFF6366F1) : const Color(0xFF22222A),
          width: isFeatured ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isFeatured ? const Color(0xFFA5B4FC) : Colors.white,
                ),
              ),
              if (isFeatured)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    'POPULAR',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF71717A))),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFF22222A)),
          const SizedBox(height: 24),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.check_rounded, size: 15, color: Color(0xFF10B981)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(fontSize: 13, color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isFeatured ? const Color(0xFF6366F1) : const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  buttonLabel,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CTA Banner
  // ---------------------------------------------------------------------------
  Widget _buildCtaBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      constraints: const BoxConstraints(maxWidth: 1020),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF4338CA).withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            const Text(
              'Experience instant task velocity today.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1.2, color: Colors.white),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: const Text(
                'Launch the full Web Workspace in your browser and test realtime sync with sub-millisecond local latency.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.5, color: Color(0xFFC7D2FE)),
              ),
            ),
            const SizedBox(height: 32),
            InkWell(
              onTap: widget.onLaunchApp,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Launch Live Workspace',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF09090B)),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF09090B)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Footer
  // ---------------------------------------------------------------------------
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF1E1E24))),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '© 2026 Bloom Todo • Pure Dart Fullstack Reference',
            style: TextStyle(fontSize: 13, color: Color(0xFF71717A)),
          ),
          Row(
            children: [
              Text('Pure Dart AOT', style: TextStyle(fontSize: 13, color: Color(0xFF71717A))),
              SizedBox(width: 24),
              Text('Flutter CanvasKit', style: TextStyle(fontSize: 13, color: Color(0xFF71717A))),
              SizedBox(width: 24),
              Text('Shorebird OTA', style: TextStyle(fontSize: 13, color: Color(0xFF71717A))),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Subtle Background Grid & Glow Painter
// -----------------------------------------------------------------------------
class _BackgroundGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle top glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.9),
        radius: 0.8,
        colors: [
          const Color(0xFF4F46E5).withValues(alpha: 0.15),
          const Color(0xFF070709).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.7));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.7), glowPaint);

    // Subtle 40px grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..strokeWidth = 1;

    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SandboxTask {
  final String id;
  final String title;
  final Priority priority;
  bool isCompleted;
  final String project;
  final String tag;

  _SandboxTask({
    required this.id,
    required this.title,
    required this.priority,
    required this.isCompleted,
    required this.project,
    required this.tag,
  });
}
