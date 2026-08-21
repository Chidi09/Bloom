import 'package:flutter/material.dart';

enum BloomFlexWrap { nowrap, wrap, wrapReverse }

class BloomComputedStyle {
  Color? backgroundColor;
  Color? textColor;
  Color? borderColor;
  double? borderWidth;
  BorderRadius? borderRadius;
  EdgeInsets padding = EdgeInsets.zero;
  EdgeInsets margin = EdgeInsets.zero;
  double gap = 0.0;
  bool isFlex = false;
  Axis flexDirection = Axis.horizontal;
  BloomFlexWrap flexWrap = BloomFlexWrap.nowrap;
  CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start;
  MainAxisAlignment mainAxisAlignment = MainAxisAlignment.start;
  bool flexExpand = false;
  int? flexGrow;
  int? flexShrink;
  double? width;
  double? height;
  double? percentWidth;
  double? percentHeight;
  double fontSize = 13.0;
  FontWeight fontWeight = FontWeight.normal;
  String? fontFamily;
  TextDecoration? textDecoration;
  bool isAbsolute = false;
  bool isFixed = false;
  double? top;
  double? bottom;
  double? left;
  double? right;
  int zIndex = 0;
}

class BloomStyleResolver {
  static BloomComputedStyle resolve(String? classNames, {String? inlineStyle}) {
    final s = BloomComputedStyle();
    if (classNames == null || classNames.trim().isEmpty) {
      _applyInline(s, inlineStyle);
      return s;
    }

    final tokens = classNames.split(RegExp(r'\s+'));
    for (final token in tokens) {
      _parseToken(token.trim(), s);
    }

    _applyInline(s, inlineStyle);
    return s;
  }

  static void _parseToken(String token, BloomComputedStyle s) {
    if (token.isEmpty) return;

    // Flexbox
    if (token == 'flex') {
      s.isFlex = true;
    } else if (token == 'flex-col') {
      s.isFlex = true;
      s.flexDirection = Axis.vertical;
    } else if (token == 'flex-row') {
      s.isFlex = true;
      s.flexDirection = Axis.horizontal;
    } else if (token == 'flex-wrap') {
      s.flexWrap = BloomFlexWrap.wrap;
    } else if (token == 'flex-nowrap') {
      s.flexWrap = BloomFlexWrap.nowrap;
    } else if (token == 'items-center') {
      s.crossAxisAlignment = CrossAxisAlignment.center;
    } else if (token == 'items-start') {
      s.crossAxisAlignment = CrossAxisAlignment.start;
    } else if (token == 'items-end') {
      s.crossAxisAlignment = CrossAxisAlignment.end;
    } else if (token == 'items-stretch') {
      s.crossAxisAlignment = CrossAxisAlignment.stretch;
    } else if (token == 'justify-between') {
      s.mainAxisAlignment = MainAxisAlignment.spaceBetween;
    } else if (token == 'justify-center') {
      s.mainAxisAlignment = MainAxisAlignment.center;
    } else if (token == 'justify-start') {
      s.mainAxisAlignment = MainAxisAlignment.start;
    } else if (token == 'justify-end') {
      s.mainAxisAlignment = MainAxisAlignment.end;
    } else if (token == 'justify-around') {
      s.mainAxisAlignment = MainAxisAlignment.spaceAround;
    } else if (token == 'justify-evenly') {
      s.mainAxisAlignment = MainAxisAlignment.spaceEvenly;
    } else if (token == 'flex-1') {
      s.flexExpand = true;
      s.flexGrow = 1;
    }

    // Positioning
    else if (token == 'absolute') {
      s.isAbsolute = true;
    } else if (token == 'fixed') {
      s.isFixed = true;
    } else if (token == 'top-0') {
      s.top = 0;
    } else if (token == 'bottom-0') {
      s.bottom = 0;
    } else if (token == 'left-0') {
      s.left = 0;
    } else if (token == 'right-0') {
      s.right = 0;
    } else if (token.startsWith('z-')) {
      s.zIndex = int.tryParse(token.substring(2)) ?? 0;
    }

    // Gap
    else if (token.startsWith('gap-')) {
      final v = double.tryParse(token.substring(4));
      if (v != null) s.gap = v * 4.0;
    }

    // Padding
    else if (token.startsWith('p-')) {
      final v = double.tryParse(token.substring(2));
      if (v != null) s.padding = EdgeInsets.all(v * 4.0);
    } else if (token.startsWith('px-')) {
      final v = double.tryParse(token.substring(3));
      if (v != null) {
        s.padding = s.padding.copyWith(left: v * 4.0, right: v * 4.0);
      }
    } else if (token.startsWith('py-')) {
      final v = double.tryParse(token.substring(3));
      if (v != null) {
        s.padding = s.padding.copyWith(top: v * 4.0, bottom: v * 4.0);
      }
    }

    // Margin
    else if (token.startsWith('m-')) {
      final v = double.tryParse(token.substring(2));
      if (v != null) s.margin = EdgeInsets.all(v * 4.0);
    } else if (token.startsWith('mx-')) {
      final v = double.tryParse(token.substring(3));
      if (v != null) {
        s.margin = s.margin.copyWith(left: v * 4.0, right: v * 4.0);
      }
    } else if (token.startsWith('my-')) {
      final v = double.tryParse(token.substring(3));
      if (v != null) {
        s.margin = s.margin.copyWith(top: v * 4.0, bottom: v * 4.0);
      }
    }

    // Radius
    else if (token == 'rounded') {
      s.borderRadius = BorderRadius.circular(4);
    } else if (token == 'rounded-md') {
      s.borderRadius = BorderRadius.circular(6);
    } else if (token == 'rounded-lg') {
      s.borderRadius = BorderRadius.circular(8);
    } else if (token == 'rounded-xl') {
      s.borderRadius = BorderRadius.circular(12);
    } else if (token == 'rounded-2xl') {
      s.borderRadius = BorderRadius.circular(16);
    } else if (token == 'rounded-full') {
      s.borderRadius = BorderRadius.circular(999);
    }

    // Border
    else if (token == 'border') {
      s.borderWidth = 1.0;
      s.borderColor ??= const Color(0xFF1E1E24);
    } else if (token.startsWith('border-[') && token.endsWith(']')) {
      final hex = token.substring(8, token.length - 1);
      s.borderColor = _parseHex(hex);
      s.borderWidth ??= 1.0;
    }

    // Background
    else if (token.startsWith('bg-[') && token.endsWith(']')) {
      final hex = token.substring(4, token.length - 1);
      s.backgroundColor = _parseHex(hex);
    } else if (token == 'bg-indigo-600') {
      s.backgroundColor = const Color(0xFF4F46E5);
    } else if (token == 'bg-indigo-500') {
      s.backgroundColor = const Color(0xFF6366F1);
    } else if (token == 'bg-emerald-500' || token == 'bg-emerald-600') {
      s.backgroundColor = const Color(0xFF10B981);
    } else if (token == 'bg-red-500' || token == 'bg-red-600') {
      s.backgroundColor = const Color(0xFFEF4444);
    } else if (token == 'bg-amber-500') {
      s.backgroundColor = const Color(0xFFF59E0B);
    } else if (token == 'bg-zinc-800') {
      s.backgroundColor = const Color(0xFF27272A);
    } else if (token == 'bg-zinc-900') {
      s.backgroundColor = const Color(0xFF18181B);
    }

    // Text
    else if (token == 'text-white') {
      s.textColor = Colors.white;
    } else if (token == 'text-zinc-100') {
      s.textColor = const Color(0xFFF4F4F5);
    } else if (token == 'text-zinc-200') {
      s.textColor = const Color(0xFFE4E4E7);
    } else if (token == 'text-zinc-300') {
      s.textColor = const Color(0xFFD4D4D8);
    } else if (token == 'text-zinc-400') {
      s.textColor = const Color(0xFFA1A1AA);
    } else if (token == 'text-zinc-500') {
      s.textColor = const Color(0xFF71717A);
    } else if (token == 'text-indigo-400') {
      s.textColor = const Color(0xFF818CF8);
    } else if (token == 'text-emerald-400') {
      s.textColor = const Color(0xFF34D399);
    } else if (token == 'text-red-400') {
      s.textColor = const Color(0xFFF87171);
    } else if (token == 'text-amber-400') {
      s.textColor = const Color(0xFFFBBF24);
    } else if (token == 'text-cyan-400') {
      s.textColor = const Color(0xFF22D3EE);
    }

    // Typography
    else if (token == 'text-xs' || token == 'text-[10px]' || token == 'text-[11px]') {
      s.fontSize = token == 'text-[10px]' ? 10.0 : (token == 'text-[11px]' ? 11.0 : 12.0);
    } else if (token == 'text-sm') {
      s.fontSize = 14.0;
    } else if (token == 'text-base') {
      s.fontSize = 16.0;
    } else if (token == 'text-lg') {
      s.fontSize = 18.0;
    } else if (token == 'text-xl') {
      s.fontSize = 20.0;
    } else if (token == 'text-2xl') {
      s.fontSize = 24.0;
    } else if (token == 'font-bold') {
      s.fontWeight = FontWeight.bold;
    } else if (token == 'font-semibold') {
      s.fontWeight = FontWeight.w600;
    } else if (token == 'font-medium') {
      s.fontWeight = FontWeight.w500;
    } else if (token == 'font-mono') {
      s.fontFamily = 'monospace';
    } else if (token == 'line-through') {
      s.textDecoration = TextDecoration.lineThrough;
    }

    // Sizing
    else if (token == 'w-full') {
      s.percentWidth = 1.0;
    } else if (token == 'w-1/2') {
      s.percentWidth = 0.5;
    } else if (token == 'w-1/3') {
      s.percentWidth = 0.3333;
    } else if (token == 'w-2/3') {
      s.percentWidth = 0.6666;
    } else if (token == 'h-full') {
      s.percentHeight = 1.0;
    } else if (token.startsWith('w-') && !token.contains('[')) {
      final v = double.tryParse(token.substring(2));
      if (v != null) s.width = v * 4.0;
    } else if (token.startsWith('h-') && !token.contains('[')) {
      final v = double.tryParse(token.substring(2));
      if (v != null) s.height = v * 4.0;
    }
  }

  static void _applyInline(BloomComputedStyle s, String? inline) {
    if (inline == null || inline.isEmpty) return;
    final parts = inline.split(';');
    for (final part in parts) {
      final kv = part.split(':');
      if (kv.length == 2) {
        final k = kv[0].trim().toLowerCase();
        final v = kv[1].trim();
        if (k == 'background-color' || k == 'background') {
          s.backgroundColor = _parseHex(v);
        } else if (k == 'color') {
          s.textColor = _parseHex(v);
        } else if (k == 'width' && v.endsWith('%')) {
          final pct = double.tryParse(v.replaceAll('%', ''));
          if (pct != null) s.percentWidth = pct / 100.0;
        }
      }
    }
  }

  static Color _parseHex(String hex) {
    var clean = hex.replaceAll('#', '').trim();
    if (clean.length == 3) {
      clean = '${clean[0]}${clean[0]}${clean[1]}${clean[1]}${clean[2]}${clean[2]}';
    }
    if (clean.length == 6) {
      clean = 'FF$clean';
    }
    final val = int.tryParse(clean, radix: 16);
    return val != null ? Color(val) : const Color(0xFF14141A);
  }
}
