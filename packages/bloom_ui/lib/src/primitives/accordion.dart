// lib/src/primitives/accordion.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

class BloomAccordionItem {
  final String title;
  final Widget content;
  final bool isExpanded;

  const BloomAccordionItem({
    required this.title,
    required this.content,
    this.isExpanded = false,
  });
}

class BloomAccordion extends StatefulWidget {
  final List<BloomAccordionItem> items;
  final bool allowMultiple;

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
              InkWell(
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
                        child: Icon(
                          Icons.keyboard_arrow_down,
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
