import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../constants/colors.dart';

class AppTheme {
  // Shadcn-inspired modern theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: const Color(0xFF18181B), // zinc-900
    scaffoldBackgroundColor: const Color(0xFFFFFFFF),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF18181B),
      secondary: Color(0xFF71717A),
      surface: Color(0xFFFFFFFF),
      surfaceContainerHighest: Color(0xFFF4F4F5), // zinc-100
      error: Color(0xFFEF4444),
      outline: Color(0xFFE4E4E7), // zinc-200
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w600,
        color: Color(0xFF18181B),
        height: 1.2,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Color(0xFF18181B),
        letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFF18181B),
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Color(0xFF18181B),
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFF71717A),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFFFFFF),
      foregroundColor: Color(0xFF18181B),
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF18181B),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFFFFFFFF),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE4E4E7), width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF18181B),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: const Color(0xFFFAFAFA),
    scaffoldBackgroundColor: const Color(0xFF09090B), // zinc-950
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFFAFAFA),
      secondary: Color(0xFFA1A1AA),
      surface: Color(0xFF09090B),
      surfaceContainerHighest: Color(0xFF27272A), // zinc-800
      error: Color(0xFFEF4444),
      outline: Color(0xFF3F3F46), // zinc-700
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w600,
        color: Color(0xFFFAFAFA),
        height: 1.2,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Color(0xFFFAFAFA),
        letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFFFAFAFA),
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Color(0xFFFAFAFA),
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xFFA1A1AA),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF09090B),
      foregroundColor: Color(0xFFFAFAFA),
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFFAFAFA),
      foregroundColor: Color(0xFF09090B),
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF09090B),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF3F3F46), width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFAFAFA),
        foregroundColor: const Color(0xFF09090B),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );

  // Cupertino Theme for iOS-native feel
  static CupertinoThemeData cupertinoLightTheme = const CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.lightAccent,
    scaffoldBackgroundColor: AppColors.lightBackground,
    textTheme: CupertinoTextThemeData(
      primaryColor: AppColors.lightText,
    ),
  );

  static CupertinoThemeData cupertinoDarkTheme = const CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.darkAccent,
    scaffoldBackgroundColor: AppColors.darkBackground,
    textTheme: CupertinoTextThemeData(
      primaryColor: AppColors.darkText,
    ),
  );
}
