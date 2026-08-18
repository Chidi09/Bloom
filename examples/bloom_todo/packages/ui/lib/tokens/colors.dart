import 'package:flutter/material.dart';

class TodoColors {
  // Brand & Accents
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color accent = Color(0xFFA855F7); // Purple

  // Priorities (Todoist standard)
  static const Color p1 = Color(0xFFDC2626); // Red - Urgent
  static const Color p2 = Color(0xFFEA580C); // Orange - High
  static const Color p3 = Color(0xFF2563EB); // Blue - Medium
  static const Color p4 = Color(0xFF94A3B8); // Slate - None

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Surface & Backgrounds (Dark Mode First)
  static const Color bgDark = Color(0xFF09090B); // Zinc 950
  static const Color surfaceDark = Color(0xFF18181B); // Zinc 900
  static const Color cardDark = Color(0xFF1E1E24);
  static const Color borderDark = Color(0xFF27272A); // Zinc 800

  // Surface & Backgrounds (Light Mode)
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);

  // 14 Predefined Project Colors
  static const List<Color> projectColors = [
    Color(0xFFEF4444), // Red
    Color(0xFFF97316), // Orange
    Color(0xFFFBBF24), // Amber
    Color(0xFF10B981), // Emerald
    Color(0xFF06B6D4), // Cyan
    Color(0xFF3B82F6), // Blue
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Violet
    Color(0xFFA855F7), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFFF43F5E), // Rose
    Color(0xFF14B8A6), // Teal
    Color(0xFF84CC16), // Lime
    Color(0xFF64748B), // Slate
  ];
}
