// lib/src/primitives/carousel.dart
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

class BloomCarousel extends StatefulWidget {
  final List<Widget> items;
  final double height;
  final bool showIndicators;

  const BloomCarousel({
    super.key,
    required this.items,
    this.height = 200,
    this.showIndicators = true,
  });

  @override
  State<BloomCarousel> createState() => _BloomCarouselState();
}

class _BloomCarouselState extends State<BloomCarousel> {
  late PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: PageView(
            controller: _controller,
            onPageChanged: (idx) => setState(() => _currentIndex = idx),
            children: widget.items,
          ),
        ),
        if (widget.showIndicators && widget.items.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.items.length, (index) {
              final isSelected = index == _currentIndex;
              return AnimatedContainer(
                duration: BloomMotion.fast,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isSelected ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary : colors.secondary,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
