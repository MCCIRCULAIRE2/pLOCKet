import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0D0D0F);
  static const Color surface1 = Color(0xFF1C1C1E);
  static const Color surface2 = Color(0xFF262628);
  static const Color surface3 = Color(0xFF2C2C2E);
  static const Color surfaceGlass = Color(0x1AFFFFFF);
  static const Color surfaceGlassLight = Color(0x0DFFFFFF);

  static const Color border = Color(0x1AFFFFFF);
  static const Color borderLight = Color(0x0DFFFFFF);

  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFF636366);

  static const Color primaryBlue = Color(0xFF5B9CF6);
  static const Color primaryPurple = Color(0xFFA78BFA);
  static const Color accentGreen = Color(0xFF34D399);
  static const Color accentOrange = Color(0xFFFBBF24);
  static const Color accentRed = Color(0xFFF87171);
  static const Color accentTeal = Color(0xFF2DD4BF);

  static const Color documentColor = Color(0xFF5B9CF6);
  static const Color eventColor = Color(0xFFFBBF24);
  static const Color infoColor = Color(0xFF34D399);
  static const Color invoiceColor = Color(0xFFA78BFA);

  static Color confidenceColor(String confidence) {
    switch (confidence) {
      case 'Fort': return accentGreen;
      case 'Moyen': return accentOrange;
      default: return accentRed;
    }
  }
}
