import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0E1217);
  static const surface = Color(0xFF171C23);
  static const surfaceHigh = Color(0xFF202732);
  static const outline = Color(0xFF2B3440);
  static const primary = Color(0xFF4C8DFF);
  static const muted = Color(0xFF9AA6B5);
  static const danger = Color(0xFFEF5350);
  static const success = Color(0xFF3DDC97);
}

Color statusColor(String s) => switch (s) {
  'Pending' => const Color(0xFFFFB84D),
  'Confirmed' => AppColors.primary,
  'On the Way' => const Color(0xFF9B8CFF),
  'In Service' => const Color(0xFF2EC4D6),
  'Completed' => AppColors.success,
  'Cancelled' => AppColors.danger,
  _ => AppColors.muted,
};

OutlineInputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(14),
  borderSide: BorderSide(color: c, width: w),
);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    surface: AppColors.surface,
    error: AppColors.danger,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: _border(AppColors.outline),
      enabledBorder: _border(AppColors.outline),
      focusedBorder: _border(AppColors.primary, 1.6),
      errorBorder: _border(AppColors.danger),
      focusedErrorBorder: _border(AppColors.danger, 1.6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        side: const BorderSide(color: AppColors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primary.withValues(alpha: 0.2),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withValues(alpha: 0.2),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary.withValues(alpha: 0.25),
      side: const BorderSide(color: AppColors.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: const DividerThemeData(color: AppColors.outline, space: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.muted),
  );
}