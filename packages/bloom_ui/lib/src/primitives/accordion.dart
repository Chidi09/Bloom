// lib/src/primitives/accordion.dart
import 'package:flutter/widgets.dart';
import '../icons/bloom_icon.dart';
import '../icons/bloom_icons.dart';
import '../theme/tokens.dart';
import '../utils/bloom_pressable.dart';
import '../utils/extensions.dart';

/// A single expandable item entry within a [BloomAccordion].
class BloomAccordionItem {
  /// The header text title displayed on the clickable accordion trigger.
  final String title;

  /// The widget content revealed when the accordion section expands.
  final Widget content;

  /// Whether the accordion item is initially expanded upon first render.
  ///
  /// Defaults to `false`.
  final bool isExpanded;

  /// Creates a [BloomAccordionItem].
  const BloomAccordionItem({
    required this.title,
    required this.content,
    this.isExpanded = false,
  });
}

/// An accordion primitive displaying vertically stacked, expandable content sections.
///
/// Features smooth animated chevron rotation, cross-fade content reveal, and support
/// for single-open or multi-open ([allowMultiple]) accordion modes.
///
/// ```dart
/// BloomAccordion(
///   allowMultiple: true,
///   items: const [
///     BloomAccordionItem(
///       title: 'Is it accessible?',
///       content: Text('Yes. It adheres to the WAI-ARIA design pattern.'),
///     ),
///     BloomAccordionItem(
///       title: 'Is it styled?',
///       content: Text('Yes. It comes with default styles matching Bloom tokens.'),
///     ),
///   ],
/// )
/// ```
class BloomAccordion extends StatefulWidget {
  /// The list of expandable sections displayed in the accordion.
  final List<BloomAccordionItem> items;

  /// Whether multiple sections can be expanded simultaneously.
  ///
  /// When `false`, expanding one section collapses all others. Defaults to `false`.
  final bool allowMultiple;

  /// Creates a [BloomAccordion].
  const BloomAccordion({
    super.key,
    required this.items,
    this.allowMultiple = false,
  });

  @override
  State<BloomAccordion> createState() => _BloomAccordionState();
}

class _BloomAccordionState extends State<BloomAccordion> {
  late List<bool> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.items.map((i) => i.isExpanded).toList();
  }

  void _toggle(int index) {
    setState(() {
      if (widget.allowMultiple) {
        _expanded[index] = !_expanded[index];
      } else {
        final current = _expanded[index];
        for (var i = 0; i < _expanded.length; i++) {
          _expanded[i] = false;
        }
        _expanded[index] = !current;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Column(
      children: List.generate(widget.items.length, (index) {
        final item = widget.items[index];
        final isOpen = _expanded[index];

        return Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BloomPressable(
                onTap: () => _toggle(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: context.bloomTypography.sans,
                        ),
                      ),
                      AnimatedRotation(
                        duration: BloomMotion.fast,
                        turns: isOpen ? 0.5 : 0.0,
                        child: BloomIcon(
                          BloomIcons.keyboardArrowDown,
                          color: colors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: BloomMotion.fast,
                crossFadeState: isOpen ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                firstChild: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: item.content,
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ],
          ),
        );
      }),
    );
  }
}
