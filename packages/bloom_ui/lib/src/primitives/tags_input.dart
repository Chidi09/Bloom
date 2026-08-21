// lib/src/primitives/tags_input.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'badge.dart';

/// An interactive tag/chip input field allowing users to add tags by typing and pressing Enter,
/// and remove tags by clicking close icons on badges.
///
/// Example:
/// ```dart
/// BloomTagsInput(
///   tags: currentTags,
///   onChanged: (newTags) => setState(() => currentTags = newTags),
/// )
/// ```
class BloomTagsInput extends StatefulWidget {
  /// The current list of tag strings.
  final List<String> tags;

  /// Callback fired when tags are added or removed.
  final ValueChanged<List<String>> onChanged;

  /// Placeholder text for the inner text field. Defaults to `'Add tag and press Enter...'`.
  final String placeholder;

  /// Creates a [BloomTagsInput].
  const BloomTagsInput({
    super.key,
    required this.tags,
    required this.onChanged,
    this.placeholder = 'Add tag and press Enter...',
  });

  @override
  State<BloomTagsInput> createState() => _BloomTagsInputState();
}

class _BloomTagsInputState extends State<BloomTagsInput> {
  final TextEditingController _controller = TextEditingController();

  void _addTag(String val) {
    final text = val.trim();
    if (text.isNotEmpty && !widget.tags.contains(text)) {
      widget.onChanged([...widget.tags, text]);
      _controller.clear();
    }
  }

  void _removeTag(String tag) {
    widget.onChanged(widget.tags.where((t) => t != tag).toList());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...widget.tags.map((tag) {
            return BloomBadge(
              variant: BloomBadgeVariant.secondary,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tag),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _removeTag(tag),
                    child: const Icon(Icons.close, size: 12),
                  ),
                ],
              ),
            );
          }),
          SizedBox(
            width: 160,
            child: TextField(
              controller: _controller,
              onSubmitted: _addTag,
              style: TextStyle(color: colors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: TextStyle(color: colors.textTertiary, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
