import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../state/task_store.dart';
import '../../widgets/sidebar.dart';
import '../../widgets/top_header.dart';
import '../../widgets/today_view.dart';
import '../../widgets/kanban_view.dart';
import '../../widgets/upcoming_view.dart';
import '../../widgets/inbox_view.dart';
import '../../widgets/activity_stream_view.dart';
import '../../widgets/telemetry_panel.dart';
import '../../widgets/command_palette.dart';
import '../../widgets/quick_add_dialog.dart';

/// Top-level Web App Layout coordinator.
/// Adheres to SOLID Single Responsibility Principle and Separation of Concerns.
class WebAppLayout extends StatefulWidget {
  const WebAppLayout({super.key});

  @override
  State<WebAppLayout> createState() => _WebAppLayoutState();
}

class _WebAppLayoutState extends State<WebAppLayout> {
  final TaskStore _store = TaskStore.instance;
  final FocusNode _keyboardFocusNode = FocusNode();

  int _activeNav = 0; // 0: Today, 1: Kanban Board, 2: Upcoming, 3: Inbox, 4: Live Activity
  String _selectedProjectId = 'prj_1';
  String _selectedFilter = 'all'; // all, p1, my_tasks

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreUpdate);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreUpdate);
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _onStoreUpdate() {
    if (mounted) setState(() {});
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // ⌘K or Ctrl+K -> Command Palette
      if ((HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed) &&
          event.logicalKey == LogicalKeyboardKey.keyK) {
        _openCommandPalette();
        return;
      }

      // Q -> Quick Add Dialog
      if (event.logicalKey == LogicalKeyboardKey.keyQ &&
          FocusManager.instance.primaryFocus?.children.isEmpty == true &&
          FocusManager.instance.primaryFocus is! EditableText) {
        QuickAddDialog.show(context, defaultProjectId: _selectedProjectId);
        return;
      }
    }
  }

  void _openCommandPalette() {
    CommandPalette.show(
      context,
      onSelectProject: (pId) {
        setState(() {
          _selectedProjectId = pId;
          _activeNav = 1;
        });
      },
      onNavigate: (navIndex) {
        setState(() => _activeNav = navIndex);
      },
      onOpenQuickAdd: () {
        QuickAddDialog.show(context, defaultProjectId: _selectedProjectId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF09090B),
        body: Row(
          children: [
            // 1. Sidebar Navigation (Left 260px)
            SidebarView(
              activeNav: _activeNav,
              selectedProjectId: _selectedProjectId,
              onNavChanged: (index) => setState(() => _activeNav = index),
              onProjectSelected: (id) => setState(() {
                _selectedProjectId = id;
                _activeNav = 1;
              }),
              onOpenCommandPalette: _openCommandPalette,
            ),

            // 2. Center Dynamic Viewport
            Expanded(
              child: Column(
                children: [
                  TopHeaderView(
                    activeNav: _activeNav,
                    selectedProjectId: _selectedProjectId,
                    selectedFilter: _selectedFilter,
                    onFilterChanged: (f) => setState(() => _selectedFilter = f),
                  ),
                  Expanded(
                    child: _buildActiveView(),
                  ),
                ],
              ),
            ),

            // 3. Right Telemetry & Productivity Panel (for Today View)
            if (_activeNav == 0) const TelemetryPanelView(),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveView() {
    return switch (_activeNav) {
      0 => TodayView(selectedFilter: _selectedFilter, selectedProjectId: _selectedProjectId),
      1 => KanbanBoardView(selectedProjectId: _selectedProjectId),
      2 => const UpcomingView(),
      3 => const InboxView(),
      4 => const ActivityStreamView(),
      _ => TodayView(selectedFilter: _selectedFilter, selectedProjectId: _selectedProjectId),
    };
  }
}
