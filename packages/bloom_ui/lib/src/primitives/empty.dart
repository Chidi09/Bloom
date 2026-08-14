// lib/src/primitives/empty.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomEmpty extends StatelessWidget {
  final Widget? media;
  final Widget? title;
  final Widget? description;
  final List<Widget> children;

  const BloomEmpty({
    super.key,
    this.media,
    this.title,
    this.description,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final theme = context.bloomTheme;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(theme.radius.lg),
          border: Border.all(
            color: colors.border,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (media != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: media!,
              ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: theme.typography.sans,
                  ),
                  child: title!,
                ),
              ),
            if (description != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                    fontFamily: theme.typography.sans,
                  ),
                  child: description!,
                ),
              ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class BloomEmptyHeader extends StatelessWidget {
  final Widget child;

  const BloomEmptyHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: child,
    );
  }
}

class BloomEmptyMedia extends StatelessWidget {
  final Widget child;

  const BloomEmptyMedia({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: child,
    );
  }
}

class BloomEmptyTitle extends StatelessWidget {
  final String text;

  const BloomEmptyTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: context.bloomColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: context.bloomTypography.sans,
      ),
    );
  }
}

class BloomEmptyDescription extends StatelessWidget {
  final String text;

  const BloomEmptyDescription(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: context.bloomColors.textSecondary,
          fontSize: 14,
          fontFamily: context.bloomTypography.sans,
        ),
      ),
    );
  }
}

class BloomEmptyContent extends StatelessWidget {
  final List<Widget> children;

  const BloomEmptyContent({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
