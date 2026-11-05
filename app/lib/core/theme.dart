import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Rang tizimi: indigo aksent, tekis tonal yuzalar. Gradient faqat bosh
/// sahifadagi "Bugungi savdo" kartasida ishlatiladi.
class AppColors {
  static const primary = Color(0xFF6366F1);
  static const primaryDeep = Color(0xFF4338CA);
  static const secondary = Color(0xFF06B6D4);

  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const success = Color(0xFF10B981);

  // Light mode
  static const lightBg = Color(0xFFF6F7FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFEEF0F6);
  static const lightText = Color(0xFF0F172A);
  static const lightTextMuted = Color(0xFF64748B);

  // Dark mode
  static const darkBg = Color(0xFF0B0D11);
  static const darkSurface = Color(0xFF14171C);
  static const darkSurfaceAlt = Color(0xFF1C2027);
  static const darkText = Color(0xFFF3F4F6);
  static const darkTextMuted = Color(0xFF9CA3AF);
}

/// Pul va miqdorlar uchun: raqamlar bir xil kenglikda (ustunlar tekis turadi).
const tabularFigures = [FontFeature.tabularFigures()];

const _rCard = 18.0;
const _rControl = 14.0;

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.lightSurface,
    error: AppColors.danger,
    onSurface: AppColors.lightText,
  );
  return _base(scheme, AppColors.lightBg, AppColors.lightSurface,
      AppColors.lightSurfaceAlt, AppColors.lightText, AppColors.lightTextMuted);
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.darkSurface,
    error: AppColors.danger,
    onSurface: AppColors.darkText,
  );
  return _base(scheme, AppColors.darkBg, AppColors.darkSurface,
      AppColors.darkSurfaceAlt, AppColors.darkText, AppColors.darkTextMuted);
}

ThemeData _base(
  ColorScheme scheme,
  Color bg,
  Color surface,
  Color surfaceAlt,
  Color text,
  Color textMuted,
) {
  final isDark = scheme.brightness == Brightness.dark;
  final hairline = isDark
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.black.withValues(alpha: 0.06);

  final baseText = ThemeData(brightness: scheme.brightness).textTheme;
  final textTheme = GoogleFonts.manropeTextTheme(baseText)
      .apply(bodyColor: text, displayColor: text)
      .copyWith(
        headlineMedium: GoogleFonts.manrope(
            fontSize: 28, fontWeight: FontWeight.w800, color: text),
        headlineSmall: GoogleFonts.manrope(
            fontSize: 24, fontWeight: FontWeight.w800, color: text),
        titleLarge: GoogleFonts.manrope(
            fontSize: 20, fontWeight: FontWeight.w800, color: text),
        titleMedium: GoogleFonts.manrope(
            fontSize: 16, fontWeight: FontWeight.w700, color: text),
        titleSmall: GoogleFonts.manrope(
            fontSize: 14, fontWeight: FontWeight.w700, color: text),
      );

  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(_rControl),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: text,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.manrope(
          fontSize: 22, fontWeight: FontWeight.w800, color: text),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_rCard),
        side: BorderSide(color: hairline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceAlt,
      border: inputBorder(Colors.transparent),
      enabledBorder: inputBorder(Colors.transparent),
      focusedBorder: inputBorder(scheme.primary, 1.6),
      errorBorder: inputBorder(AppColors.danger.withValues(alpha: 0.7)),
      focusedErrorBorder: inputBorder(AppColors.danger, 1.6),
      labelStyle: TextStyle(color: textMuted),
      hintStyle: TextStyle(color: textMuted),
      prefixIconColor: textMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(4),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rControl),
            side: BorderSide(color: hairline),
          ),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        textStyle:
            GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rControl)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        minimumSize: const Size(64, 48),
        textStyle:
            GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rControl)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        minimumSize: const Size(64, 48),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.45)),
        textStyle:
            GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rControl)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle:
            GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rControl)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 2,
      highlightElevation: 3,
      extendedTextStyle:
          GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        textStyle:
            GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700),
        side: BorderSide(color: hairline),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rControl)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: hairline),
      backgroundColor: surfaceAlt,
      selectedColor: scheme.primary.withValues(alpha: 0.18),
      showCheckmark: false,
      labelStyle: GoogleFonts.manrope(
          fontSize: 13, fontWeight: FontWeight.w700, color: textMuted),
      secondaryLabelStyle: GoogleFonts.manrope(
          fontSize: 13, fontWeight: FontWeight.w800, color: scheme.primary),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.15),
      selectedIconTheme: IconThemeData(color: scheme.primary),
      unselectedIconTheme: IconThemeData(color: textMuted),
      selectedLabelTextStyle: TextStyle(
        color: scheme.primary,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: TextStyle(color: textMuted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      indicatorShape: const StadiumBorder(),
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : textMuted,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? scheme.primary : textMuted,
        );
      }),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: textMuted,
      textColor: text,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      titleTextStyle: GoogleFonts.manrope(
          fontSize: 15, fontWeight: FontWeight.w700, color: text),
      subtitleTextStyle: GoogleFonts.manrope(
          fontSize: 13, fontWeight: FontWeight.w500, color: textMuted),
    ),
    dividerTheme: DividerThemeData(color: hairline, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? AppColors.darkSurfaceAlt : AppColors.lightText,
      contentTextStyle: GoogleFonts.manrope(
          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rControl)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.manrope(
          fontSize: 20, fontWeight: FontWeight.w800, color: text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle:
          GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w800),
      unselectedLabelStyle:
          GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
      dividerColor: hairline,
    ),
  );
}
