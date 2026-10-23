import 'package:flutter/material.dart';

/// The colours of the launcher icon (tool/app_icon/), so the app looks like
/// the thing the user tapped.
const Color kBrandViolet = Color(0xFF7C3AED);
const Color kBrandDeepViolet = Color(0xFF4C1D95);
const Color kBrandAmber = Color(0xFFFBBF24);

/// The icon's background, for the few surfaces that carry the brand.
const LinearGradient kBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[kBrandViolet, kBrandDeepViolet],
);

const String _fontFamily = 'Poppins';

/// The notes interface's theme. The onboarding interface builds its own in
/// `BrandShell` from the backend's colour and does not inherit any of this.
ThemeData buildNotesTheme(Brightness brightness) {
  final ColorScheme colors = ColorScheme.fromSeed(
    seedColor: kBrandViolet,
    brightness: brightness,
    // The default variant mutes the seed to a grey lavender; this one keeps
    // buttons the violet of the icon.
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  final ThemeData base = ThemeData(
    colorScheme: colors,
    fontFamily: _fontFamily,
  );
  final TextTheme text = base.textTheme;

  final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );
  const TextStyle buttonText = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  return base.copyWith(
    scaffoldBackgroundColor: colors.surface,
    // Poppins is wide and tall; one step lighter and tighter than Roboto's
    // defaults keeps headings from shouting.
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w600),
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 15, height: 1.6),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 13.5, height: 1.5),
      labelSmall: text.labelSmall?.copyWith(letterSpacing: 0.2),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      // No titleTextStyle: it would also shrink the large collapsing title on
      // the notes list, which takes its size from the text theme instead.
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.primary,
      foregroundColor: colors.onPrimary,
      elevation: 3,
      highlightElevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: buttonText,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: buttonShape,
        minimumSize: const Size(64, 52),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: buttonShape,
        minimumSize: const Size(64, 52),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: buttonText),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: colors.onSurface,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: text.bodyMedium?.copyWith(
        color: colors.onInverseSurface,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant.withValues(alpha: 0.6),
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 20),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),
  );
}
