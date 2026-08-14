// lib/src/primitives/questionnaire.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/controllable_value.dart';
import '../utils/extensions.dart';
import 'button.dart';
import 'input.dart';

class BloomQuestionnaire extends StatefulWidget {
  final List<Widget> items;
  final double? initialIndex;
  final double? currentIndex;
  final ValueChanged<int>? onIndexChanged;
  final bool showProgress;
  final Widget Function(BuildContext, int)? progressBuilder;
  final VoidCallback? onFinish;
  final Widget? previousLabel;
  final Widget? nextLabel;
  final Widget? skipLabel;
  final Widget? submitLabel;
  final bool showSkip;

  const BloomQuestionnaire({
    super.key,
    required this.items,
    this.initialIndex,
    this.currentIndex,
    this.onIndexChanged,
    this.showProgress = true,
    this.progressBuilder,
    this.onFinish,
    this.previousLabel,
    this.nextLabel,
    this.skipLabel,
    this.submitLabel,
    this.showSkip = false,
  });

  @override
  State<BloomQuestionnaire> createState() => _BloomQuestionnaireState();
}

class _BloomQuestionnaireState extends State<BloomQuestionnaire> {
  late BloomControllableValue<double> _index;

  @override
  void initState() {
    super.initState();
    _index = BloomControllableValue<double>(
      controlledValue: widget.currentIndex,
      defaultValue: widget.initialIndex ?? 0,
      onChanged: (v) => widget.onIndexChanged?.call(v.round()),
    );
  }

  @override
  void didUpdateWidget(covariant BloomQuestionnaire oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _index = BloomControllableValue<double>(
        controlledValue: widget.currentIndex,
        defaultValue: widget.initialIndex ?? 0,
        onChanged: (v) => widget.onIndexChanged?.call(v.round()),
      );
    }
  }

  int get _step => _index.value.round();
  bool get _isLast => _step >= widget.items.length - 1;

  void _previous() {
    if (_step > 0) {
      setState(() => _index.update((_step - 1).toDouble()));
    }
  }

  void _next() {
    if (_isLast) {
      widget.onFinish?.call();
    } else {
      setState(() => _index.update((_step + 1).toDouble()));
    }
  }

  void _skip() {
    if (_isLast) {
      widget.onFinish?.call();
    } else {
      setState(() => _index.update((_step + 1).toDouble()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showProgress)
            widget.progressBuilder?.call(context, _step) ??
                BloomQuestionnaireProgress(
                  current: _step,
                  total: widget.items.length,
                ),
          const SizedBox(height: 16),
          if (_step >= 0 && _step < widget.items.length)
            widget.items[_step],
          const SizedBox(height: 24),
          BloomQuestionnaireActions(
            onPrevious: _step > 0 ? _previous : null,
            onNext: _next,
            onSkip: widget.showSkip && !_isLast ? _skip : null,
            isLastStep: _isLast,
            previousLabel: widget.previousLabel,
            nextLabel: widget.nextLabel,
            skipLabel: widget.skipLabel,
            submitLabel: widget.submitLabel,
          ),
        ],
      ),
    );
  }
}

class BloomQuestionnaireProgress extends StatelessWidget {
  final int current;
  final int total;

  const BloomQuestionnaireProgress({
    super.key,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final typography = context.bloomTypography;

    return Text(
      'Step ${current + 1} of $total',
      style: TextStyle(
        color: colors.mutedForeground,
        fontSize: 13,
        fontFamily: typography.mono,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class BloomQuestionnaireItem extends StatelessWidget {
  final Widget child;

  const BloomQuestionnaireItem({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class BloomQuestionnaireTitle extends StatelessWidget {
  final Widget child;

  const BloomQuestionnaireTitle({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final typography = context.bloomTypography;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DefaultTextStyle(
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: typography.xl,
          fontWeight: FontWeight.w500,
          fontFamily: typography.sans,
        ),
        child: child,
      ),
    );
  }
}

class BloomQuestionnaireDescription extends StatelessWidget {
  final Widget child;

  const BloomQuestionnaireDescription({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final typography = context.bloomTypography;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DefaultTextStyle(
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: typography.sm,
          fontFamily: typography.sans,
        ),
        child: child,
      ),
    );
  }
}

class BloomQuestionnaireChoices extends StatelessWidget {
  final List<Widget> children;

  const BloomQuestionnaireChoices({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class BloomQuestionnaireChoice extends StatelessWidget {
  final Widget child;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;
  final Widget? indicator;

  const BloomQuestionnaireChoice({
    super.key,
    required this.child,
    this.selected = false,
    this.disabled = false,
    this.onTap,
    this.indicator,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final theme = context.bloomTheme;
    final isInteractive = !disabled && onTap != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        enabled: isInteractive,
        selected: selected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isInteractive ? onTap : null,
            borderRadius: BorderRadius.circular(theme.radius.md),
            child: AnimatedContainer(
              duration: BloomMotion.instant,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? colors.muted : Colors.transparent,
                borderRadius: BorderRadius.circular(theme.radius.md),
                border: Border.all(
                  color: selected ? colors.primary.withValues(alpha: 0.3) : colors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  if (indicator != null) ...[
                    indicator!,
                    const SizedBox(width: 10),
                  ],
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BloomQuestionnaireChoiceDescription extends StatelessWidget {
  final Widget child;

  const BloomQuestionnaireChoiceDescription({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final typography = context.bloomTypography;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: DefaultTextStyle(
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: typography.xs,
          fontFamily: typography.sans,
        ),
        child: child,
      ),
    );
  }
}

class BloomQuestionnaireInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String? hintText;
  final ValueChanged<String>? onChanged;

  const BloomQuestionnaireInput({
    super.key,
    this.controller,
    this.initialValue,
    this.hintText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: BloomInput(
        controller: controller,
        initialValue: initialValue,
        hintText: hintText,
        onChanged: onChanged,
      ),
    );
  }
}

class BloomQuestionnaireError extends StatelessWidget {
  final Widget child;

  const BloomQuestionnaireError({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final typography = context.bloomTypography;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DefaultTextStyle(
        style: TextStyle(
          color: colors.destructive,
          fontSize: typography.sm,
          fontFamily: typography.sans,
        ),
        child: child,
      ),
    );
  }
}

class BloomQuestionnaireActions extends StatelessWidget {
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;
  final bool isLastStep;
  final Widget? previousLabel;
  final Widget? nextLabel;
  final Widget? skipLabel;
  final Widget? submitLabel;

  const BloomQuestionnaireActions({
    super.key,
    this.onPrevious,
    this.onNext,
    this.onSkip,
    this.isLastStep = false,
    this.previousLabel,
    this.nextLabel,
    this.skipLabel,
    this.submitLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onPrevious != null)
          BloomQuestionnairePrevious(
            onPressed: onPrevious!,
            label: previousLabel,
          ),
        const Spacer(),
        if (onSkip != null) ...[
          BloomQuestionnaireSkip(
            onPressed: onSkip!,
            label: skipLabel,
          ),
          const SizedBox(width: 8),
        ],
        BloomQuestionnaireNext(
          onPressed: onNext!,
          isLastStep: isLastStep,
          label: isLastStep ? submitLabel : nextLabel,
        ),
      ],
    );
  }
}

class BloomQuestionnairePrevious extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget? label;

  const BloomQuestionnairePrevious({
    super.key,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return BloomButton(
      variant: BloomButtonVariant.outline,
      onPressed: onPressed,
      child: label ?? const Text('Previous'),
    );
  }
}

class BloomQuestionnaireNext extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLastStep;
  final Widget? label;

  const BloomQuestionnaireNext({
    super.key,
    required this.onPressed,
    this.isLastStep = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return BloomButton(
      variant: BloomButtonVariant.defaultVariant,
      onPressed: onPressed,
      child: label ?? Text(isLastStep ? 'Submit' : 'Next'),
    );
  }
}

class BloomQuestionnaireSkip extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget? label;

  const BloomQuestionnaireSkip({
    super.key,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return BloomButton(
      variant: BloomButtonVariant.ghost,
      onPressed: onPressed,
      child: label ?? const Text('Skip'),
    );
  }
}

class BloomQuestionnaireSubmit extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget? label;

  const BloomQuestionnaireSubmit({
    super.key,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return BloomButton(
      variant: BloomButtonVariant.defaultVariant,
      onPressed: onPressed,
      child: label ?? const Text('Submit'),
    );
  }
}
