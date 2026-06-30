import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color lightPrimary = Color(0xFF4E7A5D);
  static const Color lightPrimaryDark = Color(0xFF355C45);
  static const Color lightPrimarySoft = Color(0xFFDCE9DF);
  static const Color lightAccent = Color(0xFF6F9B7E);

  static const Color lightBackground = Color(0xFFF6F7F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEFF3EF);
  static const Color lightText = Color(0xFF1E2420);
  static const Color lightTextSecondary = Color(0xFF6C746D);
  static const Color lightBorder = Color(0xFFDFE4DE);

  static const Color darkPrimary = Color(0xFF83B391);
  static const Color darkPrimaryDark = Color(0xFFB4D4BD);
  static const Color darkPrimarySoft = Color(0xFF2D4033);
  static const Color darkAccent = Color(0xFF96C2A3);

  static const Color darkBackground = Color(0xFF141816);
  static const Color darkSurface = Color(0xFF1D2320);
  static const Color darkSurfaceAlt = Color(0xFF252C27);
  static const Color darkText = Color(0xFFF1F4F1);
  static const Color darkTextSecondary = Color(0xFFA8B1A9);
  static const Color darkBorder = Color(0xFF384038);

  static const Color error = Color(0xFFB74A4A);
  static const Color warning = Color(0xFFB88132);
  static const Color success = Color(0xFF3C7A50);

  static Color background(Brightness brightness) =>
      brightness == Brightness.light ? lightBackground : darkBackground;

  static Color surface(Brightness brightness) =>
      brightness == Brightness.light ? lightSurface : darkSurface;

  static Color surfaceAlt(Brightness brightness) =>
      brightness == Brightness.light ? lightSurfaceAlt : darkSurfaceAlt;

  static Color border(Brightness brightness) =>
      brightness == Brightness.light ? lightBorder : darkBorder;

  static Color textSecondary(Brightness brightness) =>
      brightness == Brightness.light ? lightTextSecondary : darkTextSecondary;
}
