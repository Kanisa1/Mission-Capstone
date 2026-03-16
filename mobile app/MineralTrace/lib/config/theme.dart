import 'package:flutter/material.dart';

class AppTheme {
  // Screenshot-inspired palette (clean slate, deep blue, soft mint)
  static const Color primaryColor = Color(0xFF0A3552);
  static const Color secondaryColor = Color(0xFF2C6E91);
  static const Color accentColor = Color(0xFFBFDCD0);

  // Background colors
  static const Color backgroundColor = Color(0xFFFAFBFC);
  static const Color cardBackground = Colors.white;
  static const Color darkBackground = Color(0xFF082A42);
  static const Color surfaceLight = Color(0xFFF8F9FA);
  static const Color surfaceLighter = Color(0xFFF1F3F5);

  // Text colors
  static const Color textPrimary = Color(0xFF0A3552);
  static const Color textSecondary = Color(0xFF5F7280);
  static const Color textLight = Color(0xFF99A8B3);
  static const Color textLighter = Color(0xFFC0CAD0);

  // Status colors
  static const Color successColor = Color(0xFF2E8B6E);
  static const Color errorColor = Color(0xFFDC2626);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color infoColor = Color(0xFF3B82F6);

  // Spacing constants
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // Card border radius
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 20.0;
  static const double radiusXL = 28.0;

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient mineralGradient = LinearGradient(
    colors: [Color(0xFF0A3552), Color(0xFF2C6E91), Color(0xFF8EB9A9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFBFDCD0), Color(0xFF8EB9A9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadows - Modern & Premium
  static List<BoxShadow> get elevationShadow => [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.10),
          blurRadius: 16,
          offset: const Offset(0, 6),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get softCardShadow => [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.08),
          blurRadius: 18,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get mediumCardShadow => [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 12),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.04),
          blurRadius: 44,
          offset: const Offset(0, 20),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get heavyCardShadow => [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.15),
          blurRadius: 32,
          offset: const Offset(0, 16),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.05),
          blurRadius: 56,
          offset: const Offset(0, 28),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get accentShadow => [
        BoxShadow(
          color: accentColor.withValues(alpha: 0.20),
          blurRadius: 24,
          offset: const Offset(0, 10),
          spreadRadius: 0,
        ),
      ];

  // Premium shadows for UI elements
  static List<BoxShadow> get premiumElevation => [
        BoxShadow(
          color: primaryColor.withValues(alpha: 0.09),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
      ];

  static TextTheme get _premiumTextTheme => const TextTheme(
        displayLarge: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0.15,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.5,
          color: textPrimary,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.6,
          color: textSecondary,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.5,
          color: textSecondary,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      );

  static final PageTransitionsTheme _pageTransitionsTheme =
      const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
    },
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      surface: cardBackground,
      error: errorColor,
    ),
    textTheme: _premiumTextTheme,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    pageTransitionsTheme: _pageTransitionsTheme,
    splashFactory: InkSparkle.splashFactory,
    scaffoldBackgroundColor: backgroundColor,
    dividerColor: const Color(0xFFE2E8F0),

    // AppBar theme
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: textPrimary,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),

    // Card theme
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
        side: BorderSide(color: primaryColor.withValues(alpha: 0.05)),
      ),
      color: cardBackground,
      shadowColor: primaryColor.withValues(alpha: 0.08),
      margin: EdgeInsets.zero,
    ),

    // Elevated button theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: secondaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: BorderSide(color: primaryColor.withValues(alpha: 0.20), width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Text button theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Input decoration theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLight,
      hintStyle: const TextStyle(color: textLight, fontSize: 14),
      labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
      floatingLabelStyle: const TextStyle(
        color: primaryColor,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),

    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide(color: primaryColor.withValues(alpha: 0.12)),
      backgroundColor: surfaceLight,
      selectedColor: primaryColor.withValues(alpha: 0.14),
      labelStyle: const TextStyle(
        color: textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: accentColor.withValues(alpha: 0.25),
      elevation: 0,
      shadowColor: primaryColor.withValues(alpha: 0.08),
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primaryColor, size: 26);
        }
        return const IconThemeData(color: textLight, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          );
        }
        return const TextStyle(
          color: textLight,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        );
      }),
    ),

    // Bottom navigation bar theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryColor,
      linearTrackColor: Color(0x1A0A3552),
      circularTrackColor: Color(0x1A0A3552),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: darkBackground,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusXL),
      ),
      titleTextStyle: const TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: const TextStyle(
        color: textSecondary,
        fontSize: 14,
        height: 1.6,
      ),
    ),

    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
      iconColor: primaryColor,
      textColor: textPrimary,
      titleTextStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      subtitleTextStyle: const TextStyle(
        fontSize: 12,
        color: textSecondary,
      ),
    ),
  );
}
