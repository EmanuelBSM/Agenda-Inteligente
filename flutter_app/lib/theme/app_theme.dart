import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const primary = Color(0xFF4B3CFF);
  static const primaryDark = Color(0xFF392CF3);
  static const violet = Color(0xFF7A2EF4);
  static const ink = Color(0xFF10172C);
  static const muted = Color(0xFF68758F);
  static const border = Color(0xFFDDE4F0);
  static const background = Color(0xFFFCFDFF);
  static const surface = Colors.white;
  static const softBlue = Color(0xFFF0F3FF);
  static const softPurple = Color(0xFFF4EEFF);
  static const softGreen = Color(0xFFECFAF1);
  static const success = Color(0xFF31BC67);
  static const warning = Color(0xFFF3A000);
  static const danger = Color(0xFFE85F63);

  static const primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF4B46FF), Color(0xFF5037FF), Color(0xFF6734F5)],
  );
}

ThemeData buildAgendaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.violet,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    outline: AppColors.border,
    error: AppColors.danger,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: scheme,
    dividerColor: AppColors.border,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.ink),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.ink),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
      bodyLarge: TextStyle(fontSize: 16, height: 1.25, color: AppColors.ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.25, color: AppColors.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: AppColors.muted),
      prefixIconColor: AppColors.muted,
      suffixIconColor: AppColors.muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}
