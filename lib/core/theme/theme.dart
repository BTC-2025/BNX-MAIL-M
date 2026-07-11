import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';
import '../constants/constants.dart';

class BNXTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: BNXColors.lightPrimary,
      scaffoldBackgroundColor: BNXColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: BNXColors.lightPrimary,
        secondary: BNXColors.lightPrimary,
        surface: BNXColors.lightSurface,
        onPrimary: Colors.white,
        onSurface: BNXColors.lightTextPrimary,
        outline: BNXColors.lightBorder,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        titleLarge: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: BNXColors.lightTextPrimary,
        ),
        titleMedium: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: BNXColors.lightTextPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 14,
          color: BNXColors.lightTextPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          color: BNXColors.lightTextSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: BNXColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BNXConstants.borderRadiusL),
          side: const BorderSide(color: BNXColors.lightBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: BNXColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      hoverColor: BNXColors.lightSidebarHover,
      splashColor: BNXColors.lightSidebarSelected.withValues(alpha: 0.4),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: BNXColors.lightTextPrimary),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: BNXColors.darkPrimary,
      scaffoldBackgroundColor: BNXColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: BNXColors.darkPrimary,
        secondary: BNXColors.darkPrimary,
        surface: BNXColors.darkSurface,
        onPrimary: Colors.white,
        onSurface: BNXColors.darkTextPrimary,
        outline: BNXColors.darkBorder,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        titleLarge: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: BNXColors.darkTextPrimary,
        ),
        titleMedium: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: BNXColors.darkTextPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 14,
          color: BNXColors.darkTextPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          color: BNXColors.darkTextSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: BNXColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BNXConstants.borderRadiusL),
          side: const BorderSide(color: BNXColors.darkBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: BNXColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      hoverColor: BNXColors.darkSidebarHover,
      splashColor: BNXColors.darkSidebarSelected.withValues(alpha: 0.4),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: BNXColors.darkTextPrimary),
      ),
    );
  }
}
