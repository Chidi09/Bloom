// lib/src/utils/bloom_editable_field.dart
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'bloom_text_selection_controls.dart';
import 'extensions.dart';

/// A Material-free text editing field primitive styled with Bloom design tokens.
///
/// Built on Flutter's core [EditableText], providing complete styling control,
/// placeholder rendering, prefix/suffix widgets, and tokenized focus/border states
/// without any dependency on Material or Cupertino.
///
/// ## Usage
/// ```dart
/// BloomEditableField(
///   placeholder: 'Enter your email...',
///   keyboardType: TextInputType.emailAddress,
///   onChanged: (text) => print(text),
/// );
/// ```
class BloomEditableField extends StatefulWidget {
  /// Creates a [BloomEditableField].
  const BloomEditableField({
    super.key,
    this.controller,
    this.focusNode,
    this.initialValue,
    this.placeholder,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.obscuringCharacter = '•',
    this.autofocus = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.expands = false,
    this.keyboardType,
    this.textInputAction,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.style,
    this.placeholderStyle,
    this.cursorColor,
    this.cursorWidth = 2.0,
    this.cursorRadius = const Radius.circular(2.0),
    this.selectionColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
    this.decoration,
    this.focusedDecoration,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTap,
    this.autofillHints,
    this.restorationId,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.showCursor,
    this.textDirection,
  });

  /// Controls the text being edited.
  ///
  /// If null, this widget will create and manage its own [TextEditingController]
  /// initialized with [initialValue].
  final TextEditingController? controller;

  /// Defines the keyboard focus for this widget.
  ///
  /// If null, this widget will create and manage its own [FocusNode].
  final FocusNode? focusNode;

  /// The initial text value when [controller] is null.
  final String? initialValue;

  /// Text that appears when the text field is empty.
  final String? placeholder;

  /// Whether the text field is enabled and interactive.
  final bool enabled;

  /// Whether the text can be changed.
  ///
  /// When true, the text cannot be modified by user input, but selection is still possible.
  final bool readOnly;

  /// Whether to hide the text being edited (e.g. for passwords).
  final bool obscureText;

  /// Character used to replace obscured characters when [obscureText] is true.
  ///
  /// Defaults to `'•'`.
  final String obscuringCharacter;

  /// Whether this text field should focus itself on initial build.
  final bool autofocus;

  /// Whether to enable autocorrection.
  final bool autocorrect;

  /// Whether to show input suggestions as the user types.
  final bool enableSuggestions;

  /// The maximum number of lines to show at one time, wrapping if necessary.
  ///
  /// Defaults to `1`. Set to null for unlimited multiline input.
  final int? maxLines;

  /// The minimum number of lines to occupy when content is short.
  final int? minLines;

  /// The maximum number of characters allowed in the text field.
  final int? maxLength;

  /// Whether this widget expands to fill its parent.
  final bool expands;

  /// The type of keyboard to display for editing the text.
  final TextInputType? keyboardType;

  /// The type of action button to use for the keyboard.
  final TextInputAction? textInputAction;

  /// How the text should be aligned horizontally.
  final TextAlign textAlign;

  /// How the text should be aligned vertically.
  final TextAlignVertical? textAlignVertical;

  /// Configures how the platform keyboard will select an uppercase or lowercase keyboard.
  final TextCapitalization textCapitalization;

  /// Optional input formatters to enforce formatting rules on typed text.
  final List<TextInputFormatter>? inputFormatters;

  /// The style to use for the text being edited.
  final TextStyle? style;

  /// The style to use for the [placeholder] text.
  final TextStyle? placeholderStyle;

  /// The color of the cursor.
  final Color? cursorColor;

  /// How thick the cursor will be.
  ///
  /// Defaults to `2.0`.
  final double cursorWidth;

  /// How rounded the corners of the cursor should be.
  ///
  /// Defaults to `Radius.circular(2.0)`.
  final Radius cursorRadius;

  /// The color of the text selection highlight.
  final Color? selectionColor;

  /// The inner padding applied inside the decorated box around the editable area.
  ///
  /// Defaults to `EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0)`.
  final EdgeInsetsGeometry padding;

  /// Custom box decoration for the input container.
  ///
  /// When null, defaults to a standard rounded surface with border from Bloom tokens.
  final BoxDecoration? decoration;

  /// Box decoration applied while the field has keyboard focus.
  ///
  /// Falls back to [decoration] when null, which in turn falls back to the
  /// token-driven default. Supply this alongside [decoration] to keep a focus
  /// ring on a field whose resting appearance is customised.
  final BoxDecoration? focusedDecoration;

  /// Optional widget displayed before the editable text input.
  final Widget? prefix;

  /// Optional widget displayed after the editable text input.
  final Widget? suffix;

  /// Called when the user changes the text in the field.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits editing on this field (e.g. presses enter/done).
  final ValueChanged<String>? onSubmitted;

  /// Called when the user submits editing on this field.
  final VoidCallback? onEditingComplete;

  /// Called when the field is tapped.
  final VoidCallback? onTap;

  /// A list of strings that helps the autofill service categorize the input.
  final Iterable<String>? autofillHints;

  /// Restoration ID to save and restore the state of the text field.
  final String? restorationId;

  /// Configures padding to edges when scrolling the field into view.
  ///
  /// Defaults to `EdgeInsets.all(20.0)`.
  final EdgeInsets scrollPadding;

  /// Whether to show the cursor.
  final bool? showCursor;

  /// The directionality of the text.
  final TextDirection? textDirection;

  @override
  State<BloomEditableField> createState() => BloomEditableFieldState();
}

/// State for [BloomEditableField].
class BloomEditableFieldState extends State<BloomEditableField> {
  TextEditingController? _internalController;
  FocusNode? _internalFocusNode;

  /// The active [TextEditingController], whether passed by caller or created internally.
  TextEditingController get effectiveController => widget.controller ?? _internalController!;

  /// The active [FocusNode], whether passed by caller or created internally.
  FocusNode get effectiveFocusNode => widget.focusNode ?? _internalFocusNode!;

  /// The resolved text value, for callers that pass no [BloomEditableField.controller].
  String get value => effectiveController.text;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = TextEditingController(text: widget.initialValue);
    }
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
    effectiveController.addListener(_onTextChanged);
    effectiveFocusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant BloomEditableField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && oldWidget.controller != null) {
      _internalController = TextEditingController(text: oldWidget.controller!.text);
      _internalController!.addListener(_onTextChanged);
    } else if (widget.controller != null && oldWidget.controller == null) {
      _internalController?.removeListener(_onTextChanged);
      _internalController?.dispose();
      _internalController = null;
      widget.controller!.addListener(_onTextChanged);
    } else if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onTextChanged);
      widget.controller?.addListener(_onTextChanged);
    }

    if (widget.focusNode == null && oldWidget.focusNode != null) {
      _internalFocusNode = FocusNode();
      _internalFocusNode!.addListener(_onFocusChanged);
    } else if (widget.focusNode != null && oldWidget.focusNode == null) {
      _internalFocusNode?.removeListener(_onFocusChanged);
      _internalFocusNode?.dispose();
      _internalFocusNode = null;
      widget.focusNode!.addListener(_onFocusChanged);
    } else if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      widget.focusNode?.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    effectiveController.removeListener(_onTextChanged);
    effectiveFocusNode.removeListener(_onFocusChanged);
    _internalController?.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Alignment _resolveAlignment(TextAlign align, TextAlignVertical? vertical) {
    final double y = vertical?.y ?? 0.0;
    return switch (align) {
      TextAlign.left || TextAlign.start => Alignment(-1.0, y),
      TextAlign.right || TextAlign.end => Alignment(1.0, y),
      TextAlign.center => Alignment(0.0, y),
      TextAlign.justify => Alignment(-1.0, y),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final typography = context.bloomTypography;
    final radius = context.bloomRadius;

    final TextStyle resolvedStyle = widget.style ??
        TextStyle(
          color: colors.textPrimary,
          fontSize: typography.base,
          fontFamily: typography.sans,
        );

    final TextStyle resolvedPlaceholderStyle = widget.placeholderStyle ??
        resolvedStyle.copyWith(
          color: colors.textTertiary,
        );

    final Color resolvedCursorColor = widget.cursorColor ?? colors.primary;
    final Color resolvedSelectionColor =
        widget.selectionColor ?? colors.primary.withValues(alpha: 0.28);
    final Color backgroundCursorColor = colors.muted;

    final List<TextInputFormatter> formatters = [
      if (widget.inputFormatters != null) ...widget.inputFormatters!,
      if (widget.maxLength != null) LengthLimitingTextInputFormatter(widget.maxLength),
    ];

    final BoxDecoration defaultDecoration = BoxDecoration(
      color: colors.surface1,
      borderRadius: BorderRadius.circular(radius.md),
      border: Border.all(
        color: effectiveFocusNode.hasFocus ? colors.ring : colors.border,
      ),
    );

    final BoxDecoration effectiveDecoration = effectiveFocusNode.hasFocus
        ? (widget.focusedDecoration ?? widget.decoration ?? defaultDecoration)
        : (widget.decoration ?? defaultDecoration);

    final Widget editableTextWidget = EditableText(
      controller: effectiveController,
      focusNode: effectiveFocusNode,
      readOnly: widget.readOnly || !widget.enabled,
      obscureText: widget.obscureText,
      obscuringCharacter: widget.obscuringCharacter,
      autofocus: widget.autofocus,
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.enableSuggestions,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      expands: widget.expands,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textAlign: widget.textAlign,
      textCapitalization: widget.textCapitalization,
      inputFormatters: formatters.isNotEmpty ? formatters : null,
      style: resolvedStyle,
      cursorColor: resolvedCursorColor,
      backgroundCursorColor: backgroundCursorColor,
      cursorWidth: widget.cursorWidth,
      cursorRadius: widget.cursorRadius,
      selectionColor: resolvedSelectionColor,
      selectionControls: bloomTextSelectionControls,
      contextMenuBuilder: bloomContextMenuBuilder,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onEditingComplete: widget.onEditingComplete,
      autofillHints: widget.autofillHints ?? const <String>[],
      restorationId: widget.restorationId,
      scrollPadding: widget.scrollPadding,
      showCursor: widget.showCursor,
      textDirection: widget.textDirection,
      scrollPhysics: widget.maxLines != 1 ? const ClampingScrollPhysics() : null,
    );

    final alignment = _resolveAlignment(widget.textAlign, widget.textAlignVertical);

    return GestureDetector(
      onTap: () {
        if (widget.enabled && !widget.readOnly) {
          effectiveFocusNode.requestFocus();
        }
        widget.onTap?.call();
      },
      behavior: HitTestBehavior.translucent,
      child: DecoratedBox(
        decoration: effectiveDecoration,
        child: Padding(
          padding: widget.padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.prefix != null) widget.prefix!,
              Expanded(
                child: Stack(
                  alignment: alignment,
                  children: [
                    if (effectiveController.text.isEmpty && widget.placeholder != null)
                      IgnorePointer(
                        child: Align(
                          alignment: alignment,
                          child: Text(
                            widget.placeholder!,
                            style: resolvedPlaceholderStyle,
                            textAlign: widget.textAlign,
                            textDirection: widget.textDirection,
                          ),
                        ),
                      ),
                    editableTextWidget,
                  ],
                ),
              ),
              if (widget.suffix != null) widget.suffix!,
            ],
          ),
        ),
      ),
    );
  }
}
