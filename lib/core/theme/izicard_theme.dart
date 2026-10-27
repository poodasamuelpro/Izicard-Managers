import 'package:flutter/material.dart';

import 'izicard_colors.dart';

class IzicardTheme {
  const IzicardTheme._();

  static ThemeData get light => _build(_lightScheme);
  static ThemeData get dark => _build(_darkScheme);

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: IzicardColors.cyan,
    brightness: Brightness.light,
  ).copyWith(
    primary: const Color(0xFF007F9E),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFD9F3F8),
    onPrimaryContainer: const Color(0xFF003642),
    secondary: const Color(0xFF006EAA),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFD4E9FF),
    onSecondaryContainer: const Color(0xFF001D35),
    error: const Color(0xFFB42318),
    onError: Colors.white,
    errorContainer: const Color(0xFFFEE4E2),
    onErrorContainer: const Color(0xFF7A271A),
    surface: const Color(0xFFF7FAFC),
    onSurface: const Color(0xFF172B3A),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF0F5F8),
    surfaceContainer: const Color(0xFFE8F0F4),
    surfaceContainerHigh: const Color(0xFFDFE9EE),
    surfaceContainerHighest: const Color(0xFFD6E2E8),
    onSurfaceVariant: const Color(0xFF526777),
    outline: const Color(0xFF718493),
    outlineVariant: const Color(0xFFD5E0E6),
    inverseSurface: const Color(0xFF253945),
    onInverseSurface: const Color(0xFFEAF2F6),
    inversePrimary: const Color(0xFF5AD5ED),
  );

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF5AD5ED),
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFF5AD5ED),
    onPrimary: const Color(0xFF003640),
    primaryContainer: const Color(0xFF064B5B),
    onPrimaryContainer: const Color(0xFFD0F6FC),
    secondary: const Color(0xFF78C8FF),
    onSecondary: const Color(0xFF00344F),
    secondaryContainer: const Color(0xFF064A6C),
    onSecondaryContainer: const Color(0xFFD2EFFF),
    error: const Color(0xFFFFB4AB),
    onError: const Color(0xFF690005),
    errorContainer: const Color(0xFF93000A),
    onErrorContainer: const Color(0xFFFFDAD6),
    surface: const Color(0xFF101820),
    onSurface: const Color(0xFFEAF2F6),
    surfaceContainerLowest: const Color(0xFF0B1117),
    surfaceContainerLow: const Color(0xFF17212A),
    surfaceContainer: const Color(0xFF1E2A34),
    surfaceContainerHigh: const Color(0xFF293741),
    surfaceContainerHighest: const Color(0xFF34434D),
    onSurfaceVariant: const Color(0xFFB7C7D1),
    outline: const Color(0xFF8799A5),
    outlineVariant: const Color(0xFF43535E),
    inverseSurface: const Color(0xFFDCE6EB),
    onInverseSurface: const Color(0xFF23313A),
    inversePrimary: const Color(0xFF00677F),
  );

  static ThemeData _build(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final radius = BorderRadius.circular(16);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: dark ? 1 : 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          foregroundColor: scheme.onPrimary,
          backgroundColor: scheme.primary,
          disabledForegroundColor: scheme.onSurfaceVariant,
          disabledBackgroundColor: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 50),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          foregroundColor: scheme.primary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? scheme.onPrimary
                  : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.surfaceContainerHigh,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        subtitleTextStyle: base.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          base.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLow,
        textStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withOpacity(0.28),
        selectionHandleColor: scheme.primary,
      ),
      visualDensity: VisualDensity.standard,
    );
  }
}
