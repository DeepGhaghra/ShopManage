import 'package:flutter/material.dart';

/// Single source-of-truth for the app's brand colors.
/// Primary palette: Slate Charcoal — professional, bold, high-contrast.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary    = Color(0xFF263238); // Slate Charcoal
  static const Color primaryDim = Color(0xFF37474F); // Lighter Charcoal
  static const Color accent     = Color(0xFF546E7A); // Muted Blue-Grey accent

  // App chrome
  static const Color scaffoldBg   = Color(0xFFF5F7FA); // Soft off-white background
  static const Color cardBg       = Colors.white;
  static const Color appBarBg     = Colors.white;
  static const Color divider      = Color(0xFFECEFF1); // Very light divider

  // Text
  static const Color textPrimary   = Color(0xFF263238);
  static const Color textSecondary = Color(0xFF546E7A);
  static const Color textHint      = Color(0xFF90A4AE);

  // Status (keep vivid for strong visual cues)
  static const Color success  = Color(0xFF2E7D32);
  static const Color warning  = Color(0xFFF57F17);
  static const Color error    = Color(0xFFC62828);

  // Dashboard Quick-Ops card colors (untouched — module identity)
  static const Color cardStock    = Color(0xFFEF6C00); // Orange
  static const Color cardSales    = Color(0xFF0F4C81); // Blue
  static const Color cardPurchase = Color(0xFF2E7D32); // Green
  static const Color cardPrice    = Color(0xFFD32F2F); // Red
  static const Color cardParties  = Color(0xFF00838F); // Teal
  static const Color cardExport   = Color(0xFF6A1B9A); // Purple
}
