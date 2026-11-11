import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../constants/colors.dart';

/// One family throughout: Atkinson Hyperlegible Next, drawn by the Braille
/// Institute for legibility, which is the whole job of prompter text.
class AppTheme {
  static const fontFamily = 'Atkinson';

  static const _tabular = [FontFeature.tabularFigures()];

  /// Large figures in stats and timers; tabular so digits don't jitter.
  static const TextStyle figure = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.1,
    color: AppColors.paper,
    fontFeatures: _tabular,
  );

  static const TextStyle figureSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.paper,
    fontFeatures: _tabular,
  );

  static final ThemeData darkTheme = _build();

  static ThemeData _build() {
    const scheme = ColorScheme.dark(
      primary: AppColors.cue,
      onPrimary: AppColors.onCue,
      secondary: AppColors.paper,
      onSecondary: AppColors.ink,
      surface: AppColors.ink,
      onSurface: AppColors.paper,
      surfaceContainerHighest: AppColors.raised,
      surfaceContainerHigh: AppColors.raised,
      surfaceContainer: AppColors.raised,
      error: AppColors.tally,
      onError: Colors.white,
      outline: AppColors.line,
      outlineVariant: AppColors.line,
    );

    const text = TextTheme(
      displaySmall: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.6,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.55,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.muted,
      ),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.ink,
      canvasColor: AppColors.ink,
      splashFactory: InkSparkle.splashFactory,
      textTheme: text.apply(
        bodyColor: AppColors.paper,
        displayColor: AppColors.paper,
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColors.cue,
        scaffoldBackgroundColor: AppColors.ink,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            fontFamily: fontFamily,
            color: AppColors.paper,
            fontSize: 17,
          ),
          navLargeTitleTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: AppColors.paper,
          ),
        ),
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.paper,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.paper, size: 22),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.cue,
          foregroundColor: AppColors.onCue,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.paper,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColors.line, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.cue,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.raised,
        hintStyle: TextStyle(color: AppColors.muted),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.cue, width: 1.5),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.cue,
        selectionColor: AppColors.cue.withValues(alpha: 0.35),
        selectionHandleColor: AppColors.cue,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.raised,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.line,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.paper,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.ink,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        shape: StadiumBorder(),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.cue,
        foregroundColor: AppColors.onCue,
        elevation: 0,
        shape: StadiumBorder(),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.cue,
        thumbColor: AppColors.cue,
        inactiveTrackColor: AppColors.line,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.onCue
              : AppColors.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? AppColors.cue : AppColors.line,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.cue,
        linearTrackColor: AppColors.line,
      ),
    );
  }
}
