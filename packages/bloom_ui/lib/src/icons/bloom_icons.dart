// lib/src/icons/bloom_icons.dart
import 'dart:math' as math;
import 'dart:ui';

import 'bloom_icon_data.dart';

/// The Bloom icon catalog — a Material-free replacement for `Icons`.
abstract final class BloomIcons {
  const BloomIcons._();

  static const double _pi = math.pi;

  /// Crossing lines close icon (`Icons.close`).
  static const BloomIconData close = BloomIconData([
    BloomIconLine(6, 6, 18, 18),
    BloomIconLine(18, 6, 6, 18),
  ]);

  /// Clear icon (`Icons.clear`), alias for [close].
  static const BloomIconData clear = close;

  /// Checkmark polyline icon (`Icons.check`).
  static const BloomIconData check = BloomIconData([
    BloomIconPolyline([4, 12.5, 9.5, 18, 20, 6.5]),
  ]);

  /// Right-pointing chevron angle polyline icon (`Icons.chevron_right`).
  static const BloomIconData chevronRight = BloomIconData([
    BloomIconPolyline([9, 5, 16, 12, 9, 19]),
  ]);

  /// Left-pointing chevron angle polyline icon (`Icons.chevron_left`).
  static const BloomIconData chevronLeft = BloomIconData([
    BloomIconPolyline([15, 5, 8, 12, 15, 19]),
  ]);

  /// Downward-pointing chevron angle polyline icon.
  static const BloomIconData chevronDown = BloomIconData([
    BloomIconPolyline([5, 9, 12, 16, 19, 9]),
  ]);

  /// Upward-pointing chevron angle polyline icon.
  static const BloomIconData chevronUp = BloomIconData([
    BloomIconPolyline([5, 15, 12, 8, 19, 15]),
  ]);

  /// Keyboard arrow down icon (`Icons.keyboard_arrow_down`), alias for [chevronDown].
  static const BloomIconData keyboardArrowDown = chevronDown;

  /// Filled downward triangle dropdown indicator icon (`Icons.arrow_drop_down`).
  static const BloomIconData arrowDropDown = BloomIconData([
    BloomIconPolyline([7, 10, 17, 10, 12, 16], close: true, filled: true),
  ]);

  /// Upward-pointing arrow icon (`Icons.arrow_upward`).
  static const BloomIconData arrowUpward = BloomIconData([
    BloomIconLine(12, 20, 12, 4),
    BloomIconPolyline([5, 11, 12, 4, 19, 11]),
  ]);

  /// Downward-pointing arrow icon (`Icons.arrow_downward`).
  static const BloomIconData arrowDownward = BloomIconData([
    BloomIconLine(12, 4, 12, 20),
    BloomIconPolyline([5, 13, 12, 20, 19, 13]),
  ]);

  /// Magnifying glass search icon (`Icons.search`).
  static const BloomIconData search = BloomIconData([
    BloomIconCircle(11, 11, 7),
    BloomIconLine(16, 16, 21, 21),
  ]);

  /// Informational outline badge (`Icons.info_outline`).
  static const BloomIconData infoOutline = BloomIconData([
    BloomIconCircle(12, 12, 9),
    BloomIconLine(12, 11, 12, 16),
    BloomIconCircle(12, 8, 0.9, filled: true),
  ]);

  /// Error outline badge (`Icons.error_outline`).
  static const BloomIconData errorOutline = BloomIconData([
    BloomIconCircle(12, 12, 9),
    BloomIconLine(12, 7, 12, 13),
    BloomIconCircle(12, 16.5, 0.9, filled: true),
  ]);

  /// Outlined circle containing a checkmark (`Icons.check_circle_outline`).
  static const BloomIconData checkCircleOutline = BloomIconData([
    BloomIconCircle(12, 12, 9),
    BloomIconPolyline([7.5, 12.5, 10.8, 15.8, 16.5, 8.5]),
  ]);

  /// Warning triangle with exclamation point (`Icons.warning_amber_rounded` / `Icons.warning_amber_outlined`).
  static const BloomIconData warning = BloomIconData([
    BloomIconPolyline([12, 3.5, 22, 20, 2, 20], close: true),
    BloomIconLine(12, 10, 12, 14.5),
    BloomIconCircle(12, 17.3, 0.9, filled: true),
  ]);

  /// Three horizontal dots for overflow actions (`Icons.more_horiz`).
  static const BloomIconData moreHorizontal = BloomIconData([
    BloomIconCircle(5.5, 12, 1.4, filled: true),
    BloomIconCircle(12, 12, 1.4, filled: true),
    BloomIconCircle(18.5, 12, 1.4, filled: true),
  ]);

  /// Filled solid circle icon (`Icons.circle`).
  static const BloomIconData circle = BloomIconData([
    BloomIconCircle(12, 12, 5, filled: true),
  ]);

  /// Outlined heart icon (`Icons.favorite_border`).
  static const BloomIconData favoriteBorder = BloomIconData([
    BloomIconArc(7.5, 8.5, 4.5, 2.423, 3.860),
    BloomIconArc(16.5, 8.5, 4.5, _pi, 3.860),
    BloomIconPolyline([4.11, 11.46, 12, 20.5, 19.89, 11.46]),
  ]);

  /// Outlined trash can delete icon (`Icons.delete_outline`).
  static const BloomIconData deleteOutline = BloomIconData([
    BloomIconLine(3.5, 6.5, 20.5, 6.5),
    BloomIconPolyline([9, 6.5, 9, 4, 15, 4, 15, 6.5]),
    BloomIconPolyline([5.5, 6.5, 6.7, 20.5, 17.3, 20.5, 18.5, 6.5]),
    BloomIconLine(10, 10.5, 10, 17),
    BloomIconLine(14, 10.5, 14, 17),
  ]);

  /// Outlined editing pencil icon (`Icons.edit_outlined`).
  static const BloomIconData edit = BloomIconData([
    BloomIconPolyline([4, 20, 4, 16, 16, 4, 20, 8, 8, 20, 4, 20], close: true),
    BloomIconLine(14, 6, 18, 10),
  ]);

  /// Overlapping sheets copy icon (`Icons.copy`).
  static const BloomIconData copy = BloomIconData([
    BloomIconRect(8, 8, 12, 12, radius: 2.5),
    BloomIconPolyline([16, 8, 16, 5.5, 4, 5.5, 4, 17.5, 6.5, 17.5]),
  ]);

  /// Cogwheel settings icon (`Icons.settings`).
  static const BloomIconData settings = BloomIconData([
    BloomIconCircle(12, 12, 3.0),
    BloomIconCircle(12, 12, 7.0),
    BloomIconLine(19.0, 12.0, 21.4, 12.0),
    BloomIconLine(16.95, 16.95, 18.65, 18.65),
    BloomIconLine(12.0, 19.0, 12.0, 21.4),
    BloomIconLine(7.05, 16.95, 5.35, 18.65),
    BloomIconLine(5.0, 12.0, 2.6, 12.0),
    BloomIconLine(7.05, 7.05, 5.35, 5.35),
    BloomIconLine(12.0, 5.0, 12.0, 2.6),
    BloomIconLine(16.95, 7.05, 18.65, 5.35),
  ]);

  /// User profile person icon (`Icons.person`).
  static const BloomIconData person = BloomIconData([
    BloomIconCircle(12, 8, 4),
    BloomIconArc(12, 21, 7.5, _pi, _pi),
  ]);

  /// Padlock lock icon with body and legged shackle (`Icons.lock`).
  static const BloomIconData lock = BloomIconData([
    BloomIconRect(3.5, 10.5, 17.0, 10.0, radius: 2.0),
    BloomIconLine(7.5, 10.5, 7.5, 8.0),
    BloomIconLine(16.5, 10.5, 16.5, 8.0),
    BloomIconArc(12.0, 8.0, 4.5, _pi, _pi),
  ]);

  /// Document tray inbox icon (`Icons.inbox_outlined`).
  static const BloomIconData inbox = BloomIconData([
    BloomIconRect(3, 4.5, 18, 15, radius: 2.5),
    BloomIconPolyline([3, 13.5, 8.5, 13.5, 10, 16, 14, 16, 15.5, 13.5, 21, 13.5]),
  ]);

  /// Calendar schedule icon (`Icons.calendar_today`).
  static const BloomIconData calendar = BloomIconData([
    BloomIconRect(3.5, 5, 17, 15.5, radius: 2.5),
    BloomIconLine(3.5, 10, 20.5, 10),
    BloomIconLine(8, 3, 8, 7),
    BloomIconLine(16, 3, 16, 7),
  ]);

  /// Bold text formatting glyph ('B') (`Icons.format_bold`).
  static const BloomIconData formatBold = BloomIconData([
    BloomIconGlyph('B', weight: FontWeight.w800),
  ]);

  /// Italic text formatting glyph ('I') (`Icons.format_italic`).
  static const BloomIconData formatItalic = BloomIconData([
    BloomIconGlyph('I', italic: true),
  ]);

  /// Underlined text formatting glyph ('U') (`Icons.format_underlined`).
  static const BloomIconData formatUnderlined = BloomIconData([
    BloomIconGlyph('U', underline: true),
  ]);

  /// Left-aligned paragraph text lines (`Icons.format_align_left`).
  static const BloomIconData formatAlignLeft = BloomIconData([
    BloomIconLine(4, 6, 20, 6),
    BloomIconLine(4, 10.5, 14, 10.5),
    BloomIconLine(4, 15, 20, 15),
    BloomIconLine(4, 19.5, 14, 19.5),
  ]);

  /// Center-aligned paragraph text lines (`Icons.format_align_center`).
  static const BloomIconData formatAlignCenter = BloomIconData([
    BloomIconLine(4, 6, 20, 6),
    BloomIconLine(7, 10.5, 17, 10.5),
    BloomIconLine(4, 15, 20, 15),
    BloomIconLine(7, 19.5, 17, 19.5),
  ]);

  /// Right-aligned paragraph text lines (`Icons.format_align_right`).
  static const BloomIconData formatAlignRight = BloomIconData([
    BloomIconLine(4, 6, 20, 6),
    BloomIconLine(10, 10.5, 20, 10.5),
    BloomIconLine(4, 15, 20, 15),
    BloomIconLine(10, 19.5, 20, 19.5),
  ]);

  /// Sun light mode icon (`Icons.light_mode`).
  static const BloomIconData lightMode = BloomIconData([
    BloomIconCircle(12, 12, 4.5),
    BloomIconLine(19.5, 12, 22, 12),
    BloomIconLine(17.3, 17.3, 19.07, 19.07),
    BloomIconLine(12, 19.5, 12, 22),
    BloomIconLine(6.7, 17.3, 4.93, 19.07),
    BloomIconLine(4.5, 12, 2, 12),
    BloomIconLine(6.7, 6.7, 4.93, 4.93),
    BloomIconLine(12, 4.5, 12, 2),
    BloomIconLine(17.3, 6.7, 19.07, 4.93),
  ]);

  /// Crescent moon dark mode icon (`Icons.dark_mode`).
  static const BloomIconData darkMode = BloomIconData([
    BloomIconArc(12, 12, 8.5, 0.386, 3.941),
    BloomIconArc(15.5, 8.5, 8.0, 0.992, 2.728),
  ]);

  /// Stacked sheets layers icon (`Icons.layers_outlined`).
  static const BloomIconData layers = BloomIconData([
    BloomIconPolyline([12, 2.5, 21, 7.5, 12, 12.5, 3, 7.5], close: true),
    BloomIconPolyline([3, 12, 12, 17, 21, 12]),
    BloomIconPolyline([3, 16.5, 12, 21.5, 21, 16.5]),
  ]);

  /// Stacked server racks storage icon (`Icons.storage_rounded`).
  static const BloomIconData storage = BloomIconData([
    BloomIconRect(3, 4.5, 18, 4.5, radius: 1.5),
    BloomIconCircle(6.5, 6.75, 0.9, filled: true),
    BloomIconRect(3, 10, 18, 4.5, radius: 1.5),
    BloomIconCircle(6.5, 12.25, 0.9, filled: true),
    BloomIconRect(3, 15.5, 18, 4.5, radius: 1.5),
    BloomIconCircle(6.5, 17.75, 0.9, filled: true),
  ]);

  /// Slider controls tune icon (`Icons.tune_rounded`).
  static const BloomIconData tune = BloomIconData([
    BloomIconLine(3, 7, 21, 7),
    BloomIconCircle(9, 7, 2.2),
    BloomIconLine(3, 12, 21, 12),
    BloomIconCircle(15, 12, 2.2),
    BloomIconLine(3, 17, 21, 17),
    BloomIconCircle(8, 17, 2.2),
  ]);

  /// Phone with down arrow system update icon (`Icons.system_update_rounded`).
  static const BloomIconData systemUpdate = BloomIconData([
    BloomIconRect(6, 2.5, 12, 19, radius: 2.5),
    BloomIconLine(12, 8, 12, 15),
    BloomIconPolyline([9, 12, 12, 15, 15, 12]),
  ]);

  /// Code brackets developer mode icon (`Icons.developer_mode`).
  static const BloomIconData developerMode = BloomIconData([
    BloomIconPolyline([8.5, 8, 4.5, 12, 8.5, 16]),
    BloomIconPolyline([15.5, 8, 19.5, 12, 15.5, 16]),
  ]);

  /// Map of all icon names to their respective [BloomIconData] descriptors.
  static const Map<String, BloomIconData> all = <String, BloomIconData>{
    'close': close,
    'clear': clear,
    'check': check,
    'chevronRight': chevronRight,
    'chevronLeft': chevronLeft,
    'chevronDown': chevronDown,
    'chevronUp': chevronUp,
    'keyboardArrowDown': keyboardArrowDown,
    'arrowDropDown': arrowDropDown,
    'arrowUpward': arrowUpward,
    'arrowDownward': arrowDownward,
    'search': search,
    'infoOutline': infoOutline,
    'errorOutline': errorOutline,
    'checkCircleOutline': checkCircleOutline,
    'warning': warning,
    'moreHorizontal': moreHorizontal,
    'circle': circle,
    'favoriteBorder': favoriteBorder,
    'deleteOutline': deleteOutline,
    'edit': edit,
    'copy': copy,
    'settings': settings,
    'person': person,
    'lock': lock,
    'inbox': inbox,
    'calendar': calendar,
    'formatBold': formatBold,
    'formatItalic': formatItalic,
    'formatUnderlined': formatUnderlined,
    'formatAlignLeft': formatAlignLeft,
    'formatAlignCenter': formatAlignCenter,
    'formatAlignRight': formatAlignRight,
    'lightMode': lightMode,
    'darkMode': darkMode,
    'layers': layers,
    'storage': storage,
    'tune': tune,
    'systemUpdate': systemUpdate,
    'developerMode': developerMode,
  };
}
