// lib/src/primitives/questionnaire.dart
import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import '../utils/bloom_pressable.dart';
import '../utils/controllable_value.dart';
import '../utils/extensions.dart';
import 'button.dart';
import 'input.dart';

/// A multi-step questionnaire or survey wizard component with navigation controls and progress indicators.
///
/// Example:
/// ```dart
/// BloomQuestionnaire(
///   items: [
///     BloomQuestionnaireItem(
///       child: Column(
///         children: [
///           BloomQuestionnaireTitle(Text('Step 1')),
///           BloomQuestionnaireDescription(Text('Select an option below:')),
///           BloomQuestionnaireChoices(children: [...]),
///         ],
///       ),
///     ),
///   ],
///   onFinish: () => print('Survey finished'),
/// )
/// ```
class BloomQuestionnaire extends StatefulWidget {
  /// The list of step widgets to display one at a time.
  final List<Widget> items;

  /// The initial step index when uncontrolled. Defaults to 0.
  final double? initialIndex;

  /// The current controlled step index.
  final double? currentIndex;

  /// Callback fired when the step index changes.
  final ValueChanged<int>? onIndexChanged;

  /// Whether to display the default progress indicator. Defaults to true.
  final bool showProgress;

  /// Optional custom builder for the progress indicator widget.
  final Widget Function(BuildContext, int)? progressBuilder;

  /// Callback fired when the user completes the final step.
  final VoidCallback? onFinish;

  /// Custom label widget for the Previous button.
  final Widget? previousLabel;

  /// Custom label widget for the Next button.
  final Widget? nextLabel;

  /// Custom label widget for the Skip button.
  final Widget? skipLabel;

  /// Custom label widget for the Submit/Finish button on the last step.
  final Widget? submitLabel;

  /// Whether to show the Skip button on non-final steps. Defaults to false.
  final bool showSkip;

  /// Creates a [BloomQuestionnaire].
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

/// Step progress indicator text displaying current step out of total.
class BloomQuestionnaireProgress extends StatelessWidget {
  /// The zero-based current step index.
  final int current;

  /// The total count of steps in the questionnaire.
  final int total;

  /// Creates a [BloomQuestionnaireProgress].
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

/// A wrapper item for a single step in a [BloomQuestionnaire].
class BloomQuestionnaireItem extends StatelessWidget {
  /// The content of this questionnaire step.
  final Widget child;

  /// Creates a [BloomQuestionnaireItem].
  const BloomQuestionnaireItem({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// A title widget for a questionnaire step.
class BloomQuestionnaireTitle extends StatelessWidget {
  /// The title text or widget.
  final Widget child;

  /// Creates a [BloomQuestionnaireTitle].
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

/// A description widget for a questionnaire step.
class BloomQuestionnaireDescription extends StatelessWidget {
  /// The description text or widget.
  final Widget child;

  /// Creates a [BloomQuestionnaireDescription].
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

/// A vertical list container for [BloomQuestionnaireChoice] items.
class BloomQuestionnaireChoices extends StatelessWidget {
  /// The choice option widgets.
  final List<Widget> children;

  /// Creates a [BloomQuestionnaireChoices].
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

/// A selectable option card in a questionnaire choice list.
class BloomQuestionnaireChoice extends StatelessWidget {
  /// The label or main widget for this choice.
  final Widget child;

  /// Whether this choice is currently selected. Defaults to false.
  final bool selected;

  /// Whether this choice is disabled. Defaults to false.
  final bool disabled;

  /// Callback when this choice is tapped.
  final VoidCallback? onTap;

  /// Optional leading indicator widget (e.g. radio icon or badge).
  final Widget? indicator;

  /// Creates a [BloomQuestionnaireChoice].
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
        child: BloomPressable(
          enabled: isInteractive,
          onTap: isInteractive ? onTap : null,
          borderRadius: BorderRadius.circular(theme.radius.md),
          child: AnimatedContainer(
            duration: BloomMotion.instant,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? colors.muted : BloomColors.transparent,
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
    );
  }
}

/// Subtitle or helper description text within a [BloomQuestionnaireChoice].
class BloomQuestionnaireChoiceDescription extends StatelessWidget {
  /// The description text or widget.
  final Widget child;

  /// Creates a [BloomQuestionnaireChoiceDescription].
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

/// A text input field tailored for questionnaire steps.
class BloomQuestionnaireInput extends StatelessWidget {
  /// Optional text editing controller.
  final TextEditingController? controller;

  /// Initial text value when uncontrolled.
  final String? initialValue;

  /// Hint text shown when input is empty.
  final String? hintText;

  /// Callback fired when text changes.
  final ValueChanged<String>? onChanged;

  /// Creates a [BloomQuestionnaireInput].
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

/// An error message text component for questionnaire validation.
class BloomQuestionnaireError extends StatelessWidget {
  /// The error text or widget.
  final Widget child;

  /// Creates a [BloomQuestionnaireError].
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

/// Action button bar rendered at the bottom of a [BloomQuestionnaire].
class BloomQuestionnaireActions extends StatelessWidget {
  /// Callback for the Previous button action, or null to disable/hide.
  final VoidCallback? onPrevious;

  /// Callback for the Next or Submit button action.
  final VoidCallback? onNext;

  /// Callback for the Skip button action, or null to hide.
  final VoidCallback? onSkip;

  /// Whether the questionnaire is currently at the final step.
  final bool isLastStep;

  /// Custom label widget for Previous button.
  final Widget? previousLabel;

  /// Custom label widget for Next button.
  final Widget? nextLabel;

  /// Custom label widget for Skip button.
  final Widget? skipLabel;

  /// Custom label widget for Submit button on last step.
  final Widget? submitLabel;

  /// Creates a [BloomQuestionnaireActions] bar.
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

/// Navigation button to return to the previous step in a questionnaire.
class BloomQuestionnairePrevious extends StatelessWidget {
  /// Callback fired on press.
  final VoidCallback onPressed;

  /// Custom label widget. Defaults to `Text('Previous')`.
  final Widget? label;

  /// Creates a [BloomQuestionnairePrevious] button.
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

/// Navigation button to proceed to the next step or submit in a questionnaire.
class BloomQuestionnaireNext extends StatelessWidget {
  /// Callback fired on press.
  final VoidCallback onPressed;

  /// Whether this button represents the final submission step. Defaults to false.
  final bool isLastStep;

  /// Custom label widget. Defaults to `Text('Next')` or `Text('Submit')`.
  final Widget? label;

  /// Creates a [BloomQuestionnaireNext] button.
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

/// Action button to skip the current optional step in a questionnaire.
class BloomQuestionnaireSkip extends StatelessWidget {
  /// Callback fired on press.
  final VoidCallback onPressed;

  /// Custom label widget. Defaults to `Text('Skip')`.
  final Widget? label;

  /// Creates a [BloomQuestionnaireSkip] button.
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

/// Action button to submit the completed questionnaire.
class BloomQuestionnaireSubmit extends StatelessWidget {
  /// Callback fired on press.
  final VoidCallback onPressed;

  /// Custom label widget. Defaults to `Text('Submit')`.
  final Widget? label;

  /// Creates a [BloomQuestionnaireSubmit] button.
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
