import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;
    final Color primary =
        isLight ? AppColors.lightPrimary : AppColors.darkPrimary;
    final Color surface =
        isLight ? AppColors.lightSurface : AppColors.darkSurface;
    final Color background =
        isLight ? AppColors.lightBackground : AppColors.darkBackground;
    final Color text = isLight ? AppColors.lightText : AppColors.darkText;
    final Color textSecondary =
        isLight ? AppColors.lightTextSecondary : AppColors.darkTextSecondary;
    final Color border = isLight ? AppColors.lightBorder : AppColors.darkBorder;
    final Color primarySoft =
        isLight ? AppColors.lightPrimarySoft : AppColors.darkPrimarySoft;

    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: isLight ? AppColors.lightAccent : AppColors.darkAccent,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: textSecondary,
      outline: border,
      outlineVariant: border,
      error: AppColors.error,
    );

    final ThemeData baseTheme = ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      useMaterial3: true,
    );

    final TextTheme textTheme = baseTheme.textTheme.copyWith(
      headlineLarge: baseTheme.textTheme.headlineLarge?.copyWith(
        color: text,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: baseTheme.textTheme.headlineMedium?.copyWith(
        color: text,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
        color: text,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
        color: text,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(
        color: text,
        height: 1.35,
      ),
      bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
        color: text,
        height: 1.35,
      ),
      bodySmall: baseTheme.textTheme.bodySmall?.copyWith(
        color: textSecondary,
        height: 1.35,
      ),
      labelLarge: baseTheme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );

    OutlineInputBorder fieldBorder(Color color) => OutlineInputBorder(
          borderRadius: AppRadii.field,
          borderSide: BorderSide(color: color),
        );

    return baseTheme.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppColors.lightSurface : AppColors.darkSurfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: textSecondary,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: textSecondary,
        ),
        enabledBorder: fieldBorder(border),
        focusedBorder: fieldBorder(primary),
        errorBorder: fieldBorder(AppColors.error),
        focusedErrorBorder: fieldBorder(AppColors.error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.75),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.button,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 54),
          foregroundColor: primary,
          side: BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.button,
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: primarySoft,
        disabledColor: surface,
        side: BorderSide(color: border),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.pill,
        ),
        labelStyle: textTheme.bodySmall?.copyWith(
          color: text,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: textTheme.bodySmall?.copyWith(
          color:
              isLight ? AppColors.lightPrimaryDark : AppColors.darkPrimaryDark,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: surface,
        indicatorColor: primarySoft,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll<TextStyle?>(
          textTheme.labelSmall?.copyWith(
            color: text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: text),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: primarySoft,
      ),
    );
  }
}
