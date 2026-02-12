import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Material 3 Theme Configuration for Stock Profit Tracker
///
/// Features:
/// - Modern Material 3 design system
/// - Custom color scheme for financial data
/// - Google Fonts (Inter/Poppins) for typography
/// - Profit/Loss color coding: Green (profit), Red (loss)
/// - Rounded cards with soft shadows
/// - Adaptive colors for light/dark mode
class AppTheme {
  // Brand colors for stock tracking
  static const Color profitGreen = Color(0xFF00C853);
  static const Color lossRed = Color(0xFFD32F2F);
  static const Color neutralGray = Color(0xFF757575);
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color backgroundLight = Color(0xFFFAFBFE);
  static const Color backgroundDark = Color(0xFF121212);

  /// Light theme configuration
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
      surface: backgroundLight,
      onSurface: const Color(0xFF1C1B1F),
    ),

    // Typography using Google Fonts
    textTheme: GoogleFonts.interTextTheme().copyWith(
      // Headings
      headlineLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1C1B1F),
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1C1B1F),
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1C1B1F),
      ),

      // Body text
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: const Color(0xFF49454F),
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: const Color(0xFF49454F),
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: const Color(0xFF79747E),
      ),

      // Labels
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF1D1B20),
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF49454F),
      ),
    ),

    // Card theme for stock items
    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      surfaceTintColor: primaryBlue.withValues(alpha: 0.05),
    ),

    // App bar theme
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundLight,
      foregroundColor: const Color(0xFF1C1B1F),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1C1B1F),
      ),
    ),

    // Floating action button
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // Input decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF7F2FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: lossRed, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: GoogleFonts.inter(
        color: const Color(0xFF79747E),
        fontSize: 14,
      ),
    ),

    // Button themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
  );

  /// Dark theme configuration
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
      surface: backgroundDark,
      onSurface: const Color(0xFFE6E1E5),
    ),

    // Typography for dark mode
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      // Headings
      headlineLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFE6E1E5),
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFE6E1E5),
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFE6E1E5),
      ),

      // Body text
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: const Color(0xFFCAC4D0),
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: const Color(0xFFCAC4D0),
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: const Color(0xFF938F99),
      ),
    ),

    // Dark mode card theme
    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF1D1B1E),
      surfaceTintColor: primaryBlue.withValues(alpha: 0.1),
    ),

    // Dark mode app bar
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundDark,
      foregroundColor: const Color(0xFFE6E1E5),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFE6E1E5),
      ),
    ),

    // Dark mode input decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2B2930),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: lossRed, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: GoogleFonts.inter(
        color: const Color(0xFF938F99),
        fontSize: 14,
      ),
    ),
  );

  /// Get profit/loss color based on value
  static Color getProfitLossColor(double value) {
    if (value > 0) return profitGreen;
    if (value < 0) return lossRed;
    return neutralGray;
  }

  /// Get profit/loss text with proper formatting
  static String formatProfitLoss(double value) {
    final isProfit = value >= 0;
    final prefix = isProfit ? '+' : '';
    return '$prefix${value.toStringAsFixed(2)}';
  }

  /// Get percentage text with proper formatting
  static String formatPercentage(double percentage) {
    final isProfit = percentage >= 0;
    final prefix = isProfit ? '+' : '';
    return '$prefix${percentage.toStringAsFixed(2)}%';
  }

  /// Custom gradient for charts and graphics
  static LinearGradient profitGradient = const LinearGradient(
    colors: [profitGreen, Color(0xFF81C784)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient lossGradient = const LinearGradient(
    colors: [lossRed, Color(0xFFEF5350)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Extension methods for consistent styling
extension ThemeExtensions on BuildContext {
  /// Quick access to theme
  ThemeData get theme => Theme.of(this);

  /// Quick access to color scheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Quick access to text theme
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Get profit/loss styled text widget
  Widget profitLossText(
    double value, {
    double? fontSize,
    FontWeight? fontWeight,
  }) {
    return Text(
      AppTheme.formatProfitLoss(value),
      style: textTheme.bodyMedium?.copyWith(
        color: AppTheme.getProfitLossColor(value),
        fontSize: fontSize,
        fontWeight: fontWeight ?? FontWeight.w600,
      ),
    );
  }

  /// Get percentage styled text widget
  Widget percentageText(
    double percentage, {
    double? fontSize,
    FontWeight? fontWeight,
  }) {
    return Text(
      AppTheme.formatPercentage(percentage),
      style: textTheme.bodyMedium?.copyWith(
        color: AppTheme.getProfitLossColor(percentage),
        fontSize: fontSize,
        fontWeight: fontWeight ?? FontWeight.w600,
      ),
    );
  }
}
