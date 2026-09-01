// lib/src/primitives/collapsible.dart
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';

class BloomCollapsible extends StatelessWidget {
  final bool open;
  final Widget trigger;
  final Widget content;

  const BloomCollapsible({
    super.key,
    required this.open,
    required this.trigger,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        trigger,
        AnimatedCrossFade(
          duration: BloomMotion.fast,
          crossFadeState: open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: content,
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }
}
