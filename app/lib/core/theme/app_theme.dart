import 'package:flutter/material.dart';

// ── Variant enum ──────────────────────────────────────────────────────────────

enum AppThemeVariant {
  light, dark, dracula, nord, catppuccin, tokyoNight, rosePine, monokai, solarized;

  String get label => switch (this) {
        AppThemeVariant.light      => 'Claro',
        AppThemeVariant.dark       => 'Escuro',
        AppThemeVariant.dracula    => 'Dracula',
        AppThemeVariant.nord       => 'Nord',
        AppThemeVariant.catppuccin => 'Catppuccin',
        AppThemeVariant.tokyoNight => 'Tokyo Night',
        AppThemeVariant.rosePine   => 'Rose Piné',
        AppThemeVariant.monokai    => 'Monokai',
        AppThemeVariant.solarized  => 'Solarized',
      };

  bool get isLight => this == AppThemeVariant.light;
}

// ── Theme extension (carries custom colors alongside Material ThemeData) ──────

class AppColorScheme extends ThemeExtension<AppColorScheme> {
  final Color bg;
  final Color surface;
  final Color border;

  const AppColorScheme({
    required this.bg,
    required this.surface,
    required this.border,
  });

  @override
  AppColorScheme copyWith({Color? bg, Color? surface, Color? border}) =>
      AppColorScheme(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        border: border ?? this.border,
      );

  @override
  AppColorScheme lerp(AppColorScheme? other, double t) {
    if (other == null) return this;
    return AppColorScheme(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

// ── Per-variant palette ────────────────────────────────────────────────────────

class AppThemePalette {
  final Color bg;
  final Color surface;
  final Color border;
  final Color primary;
  final bool isDark;

  const AppThemePalette({
    required this.bg,
    required this.surface,
    required this.border,
    required this.primary,
    required this.isDark,
  });
}

// ── App theme ─────────────────────────────────────────────────────────────────

class AppTheme {
  // Semantic / static colors (same across all themes)
  static const green         = Color(0xFF22C55E);
  static const red           = Color(0xFFEF4444);
  static const textMuted     = Color(0xFF6B7280);
  static const textSecondary = Color(0xFF9CA3AF);

  // Kept as fallback for _parseColor / _hexColor helper returns
  static const primaryColor = Color(0xFF6366F1);

  // ── Palettes ──────────────────────────────────────────────────────────────

  static const Map<AppThemeVariant, AppThemePalette> palettes = {
    AppThemeVariant.light: AppThemePalette(
      bg: Color(0xFFF9FAFB), surface: Color(0xFFFFFFFF), border: Color(0xFFE5E7EB),
      primary: Color(0xFF6366F1), isDark: false,
    ),
    AppThemeVariant.dark: AppThemePalette(
      bg: Color(0xFF111827), surface: Color(0xFF1F2937), border: Color(0xFF374151),
      primary: Color(0xFF6366F1), isDark: true,
    ),
    AppThemeVariant.dracula: AppThemePalette(
      bg: Color(0xFF282A36), surface: Color(0xFF44475A), border: Color(0xFF6272A4),
      primary: Color(0xFFBD93F9), isDark: true,
    ),
    AppThemeVariant.nord: AppThemePalette(
      bg: Color(0xFF2E3440), surface: Color(0xFF3B4252), border: Color(0xFF4C566A),
      primary: Color(0xFF88C0D0), isDark: true,
    ),
    AppThemeVariant.catppuccin: AppThemePalette(
      bg: Color(0xFF1E1E2E), surface: Color(0xFF313244), border: Color(0xFF45475A),
      primary: Color(0xFFCBA6F7), isDark: true,
    ),
    AppThemeVariant.tokyoNight: AppThemePalette(
      bg: Color(0xFF1A1B26), surface: Color(0xFF24283B), border: Color(0xFF414868),
      primary: Color(0xFF7AA2F7), isDark: true,
    ),
    AppThemeVariant.rosePine: AppThemePalette(
      bg: Color(0xFF191724), surface: Color(0xFF1F1D2E), border: Color(0xFF403D52),
      primary: Color(0xFFC4A7E7), isDark: true,
    ),
    AppThemeVariant.monokai: AppThemePalette(
      bg: Color(0xFF272822), surface: Color(0xFF3E3D32), border: Color(0xFF75715E),
      primary: Color(0xFFA6E22E), isDark: true,
    ),
    AppThemeVariant.solarized: AppThemePalette(
      bg: Color(0xFF002B36), surface: Color(0xFF073642), border: Color(0xFF586E75),
      primary: Color(0xFF268BD2), isDark: true,
    ),
  };

  // ── ThemeData factory ─────────────────────────────────────────────────────

  static ThemeData themeData(AppThemeVariant variant) {
    final p = palettes[variant]!;
    final brightness = p.isDark ? Brightness.dark : Brightness.light;
    final onBg = p.isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
    final inputFill = p.isDark ? p.surface : const Color(0xFFF3F4F6);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.primary,
        brightness: brightness,
      ).copyWith(
        primary: p.primary,
        onPrimary: Colors.white,
        surface: p.surface,
        onSurface: onBg,
        error: red,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: p.bg,
      cardColor: p.surface,
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: onBg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onBg,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: _onPrimary(p.primary),
          disabledBackgroundColor: p.primary.withValues(alpha: 0.4),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.primary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
                color: p.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: textMuted, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: p.primary);
          }
          return const IconThemeData(color: textMuted);
        }),
      ),
      textTheme: TextTheme(
        headlineLarge:
            TextStyle(color: onBg, fontWeight: FontWeight.w700),
        headlineMedium:
            TextStyle(color: onBg, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: onBg, fontWeight: FontWeight.w600),
        titleMedium:
            TextStyle(color: onBg, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: onBg),
        bodyMedium: const TextStyle(color: textSecondary),
        bodySmall: const TextStyle(color: textMuted),
      ),
      extensions: [
        AppColorScheme(bg: p.bg, surface: p.surface, border: p.border),
      ],
    );
  }

  // Returns white or dark text depending on primary luminance
  static Color _onPrimary(Color primary) {
    final luminance = primary.computeLuminance();
    return luminance > 0.4 ? const Color(0xFF1A1A1A) : Colors.white;
  }
}

// ── BuildContext extension ────────────────────────────────────────────────────

extension AppColors on BuildContext {
  AppColorScheme get _cs =>
      Theme.of(this).extension<AppColorScheme>() ??
      const AppColorScheme(
        bg: Color(0xFF111827),
        surface: Color(0xFF1F2937),
        border: Color(0xFF374151),
      );

  Color get appBg      => _cs.bg;
  Color get appSurface => _cs.surface;
  Color get appBorder  => _cs.border;
  Color get appPrimary => Theme.of(this).colorScheme.primary;
}
