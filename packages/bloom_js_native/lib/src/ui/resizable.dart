import '../events.dart';
import '../framework.dart';
import '../signals.dart';
import '_resizable_dom_web.dart'
    if (dart.library.io) '_resizable_dom_stub.dart';
import 'cn.dart';
import 'icons.dart';

int _resizableInstanceCounter = 0;

/// Resizable split-pane layout component.
///
/// Supports horizontal and vertical split orientations with interactive drag resizing.
///
/// Drag tracking resolves the container's own bounding rect via a conditionally
/// imported browser-only helper (`_resizable_dom_web.dart`, falling back to a
/// no-op stub off the browser so this file — part of the pure-Dart core library
/// re-exported from `bloom_js_native.dart` — stays VM-testable and does not pull
/// `package:web` into server-rendering builds). `BloomEvent` only carries
/// pointer-relative coordinates (`clientX`/`clientY`), not the container's size,
/// so the container needs a stable id to resolve a drag position into a ratio.
BloomNode resizablePanels({
  required BloomNode first,
  required BloomNode second,
  bool vertical = false,
  double initialSplit = 0.5,
  double minSplit = 0.1,
  double maxSplit = 0.9,
  bool withHandle = true,
  String extraClassName = '',
}) {
  final split = signal<double>(initialSplit.clamp(minSplit, maxSplit));
  final isDragging = signal<bool>(false);
  final containerId = 'bloom-resizable-${_resizableInstanceCounter++}';

  void updateFromPointer(BloomEvent e) {
    if (!isDragging.value) return;
    final clientX = e.clientX;
    final clientY = e.clientY;
    if (clientX == null || clientY == null) return;
    final ratio = resolveContainerRatio(
      containerId: containerId,
      clientX: clientX,
      clientY: clientY,
      vertical: vertical,
    );
    if (ratio == null) return;
    split.value = ratio.clamp(minSplit, maxSplit);
  }

  return Live(() {
    final currentSplit = split.value;
    final firstPct = (currentSplit * 100).toStringAsFixed(2);

    return Div(
      attrs: {
        'id': containerId,
        'data-slot': 'resizable-panel-group',
        'aria-orientation': vertical ? 'vertical' : 'horizontal',
      },
      className: cn([
        'relative flex w-full h-full overflow-hidden select-none',
        vertical ? 'flex-col' : 'flex-row',
        extraClassName,
      ]),
      on: {
        'pointermove': updateFromPointer,
        'pointerup': (_) => isDragging.value = false,
        'pointerleave': (_) => isDragging.value = false,
      },
      children: [
        // First Panel
        Div(
          attrs: const {'data-slot': 'resizable-panel'},
          style: 'flex: 0 0 $firstPct%; overflow: auto;',
          className: 'min-w-0 min-h-0',
          children: [first],
        ),
        // Draggable Separator Handle
        El(
          'div',
          attrs: {
            'role': 'separator',
            'tabindex': '0',
            'aria-orientation': vertical ? 'horizontal' : 'vertical',
            'aria-valuenow': firstPct,
            'data-slot': 'resizable-handle',
          },
          className: cn([
            'relative flex items-center justify-center bg-[var(--border)] transition-colors hover:bg-[var(--primary)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--ring)]',
            vertical
                ? 'h-1.5 w-full cursor-row-resize'
                : 'w-1.5 h-full cursor-col-resize',
          ]),
          on: {
            'pointerdown': (BloomEvent e) {
              e.stopPropagation();
              isDragging.value = true;
            },
          },
          children: [
            if (withHandle)
              Div(
                className: cn([
                  'z-10 flex items-center justify-center rounded-sm bg-[var(--card)] border border-[var(--border)] text-[var(--text-muted)] shadow-xs',
                  vertical ? 'h-3 w-6' : 'h-6 w-3',
                ]),
                children: [
                  uiIcon(
                    vertical ? 'grip-horizontal' : 'grip-vertical',
                    className: 'w-2.5 h-2.5',
                  ),
                ],
              ),
          ],
        ),
        // Second Panel
        Div(
          attrs: const {'data-slot': 'resizable-panel'},
          style: 'flex: 1 1 0%; overflow: auto;',
          className: 'min-w-0 min-h-0',
          children: [second],
        ),
      ],
    );
  });
}
