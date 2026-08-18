import 'package:flutter/material.dart';
import 'colors.dart';

class TodoTheme {
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: TodoColors.bgDark,
      primaryColor: TodoColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: TodoColors.primary,
        secondary: TodoColors.accent,
        surface: TodoColors.surfaceDark,
        error: TodoColors.danger,
        onPrimary: Colors.white,
        onSurface: Color(0xFFF4F4F5),
      ),
      cardTheme: const CardThemeData(
        color: TodoColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: TodoColors.borderDark),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TodoColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: TodoColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: TodoColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: TodoColors.primary, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: TodoColors.borderDark,
        thickness: 1,
      ),
    );
  }

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: TodoColors.bgLight,
      primaryColor: TodoColors.primary,
      colorScheme: const ColorScheme.light(
        primary: TodoColors.primary,
        secondary: TodoColors.accent,
        surface: TodoColors.surfaceLight,
        error: TodoColors.danger,
        onPrimary: Colors.white,
        onSurface: Color(0xFF0F172A),
      ),
      cardTheme: const CardThemeData(
        color: TodoColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: TodoColors.borderLight),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TodoColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: TodoColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: TodoColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: TodoColors.primary, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: TodoColors.borderLight,
        thickness: 1,
      ),
    );
  }
}
