import 'package:flutter/material.dart';

const _primary = Color(0xFF6366F1);
const _primaryDark = Color(0xFF4F46E5);

class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primary,
          brightness: Brightness.dark,
          primary: _primary,
          onPrimary: Colors.white,
          surface: const Color(0xFF1F2937),
          onSurface: const Color(0xFFF9FAFB),
        ),
        scaffoldBackgroundColor: const Color(0xFF111827),
        cardColor: const Color(0xFF1F2937),
        cardTheme: CardThemeData(
          color: const Color(0xFF1F2937),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF374151), width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111827),
          foregroundColor: Color(0xFFF9FAFB),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFFF9FAFB),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF374151),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4B5563)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
          hintStyle: const TextStyle(color: Color(0xFF6B7280)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _primary.withAlpha(100),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            elevation: 0,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1F2937),
          indicatorColor: _primary.withAlpha(50),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: _primary, fontSize: 12, fontWeight: FontWeight.w600);
            }
            return const TextStyle(color: Color(0xFF6B7280), fontSize: 12);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: _primary);
            }
            return const IconThemeData(color: Color(0xFF6B7280));
          }),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: Color(0xFFF9FAFB), fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: Color(0xFFF9FAFB), fontWeight: FontWeight.w700),
          titleLarge: TextStyle(color: Color(0xFFF9FAFB), fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: Color(0xFFF9FAFB), fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: Color(0xFFD1D5DB)),
          bodyMedium: TextStyle(color: Color(0xFF9CA3AF)),
          bodySmall: TextStyle(color: Color(0xFF6B7280)),
        ),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primary,
          brightness: Brightness.light,
          primary: _primary,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: const Color(0xFF111827),
        ),
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        cardColor: Colors.white,
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF9FAFB),
          foregroundColor: Color(0xFF111827),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF6B7280)),
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _primary.withAlpha(100),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            elevation: 0,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: _primary.withAlpha(50),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: _primary, fontSize: 12, fontWeight: FontWeight.w600);
            }
            return const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: _primary);
            }
            return const IconThemeData(color: Color(0xFF9CA3AF));
          }),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700),
          titleLarge: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: Color(0xFF374151)),
          bodyMedium: TextStyle(color: Color(0xFF6B7280)),
          bodySmall: TextStyle(color: Color(0xFF9CA3AF)),
        ),
      );

  static const primaryColor = _primary;
  static const primaryDarkColor = _primaryDark;
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
  // Static fallbacks kept for semantic colors; prefer context.appXxx for bg/surface/border
  static const cardBorder = Color(0xFF374151);
  static const surfaceColor = Color(0xFF1F2937);
  static const bgColor = Color(0xFF111827);
  static const textMuted = Color(0xFF6B7280);
  static const textSecondary = Color(0xFF9CA3AF);
}

extension AppColors on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;
  Color get appBg => _isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB);
  Color get appSurface => _isDark ? const Color(0xFF1F2937) : Colors.white;
  Color get appBorder => _isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
}
