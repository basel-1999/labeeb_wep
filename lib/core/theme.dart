import 'package:flutter/material.dart';

class LabeebTheme {
  // الألوان الأساسية
  static const Color oliveGreen = Color(0xFF4E6B45); // زيتي خفيف ومريح للعين
  static const Color oliveLight = Color(0xFF708E67); // زيتي أفتح للأزرار الثانوية
  static const Color beigeBackground = Color(0xFFF4EFE6); // بيج دافئ للخلفية
  static const Color beigeCard = Color(0xFFFAF7F2); // بيج فاتح جداً للكروت

  // النصوص
  static const Color textDark = Color(0xFF1E241B); // نص داكن مريح للقراءة
  static const Color textMuted = Color(0xFF6B7280); // نص ثانوي باهت

  // ألوان التأكيد
  static const Color accentGold = Color(0xFFC79A3B); // ذهبي للتأكيدات
  static const Color accentOrange = Color(0xFFD97706); // برتقالي للشخبطة والتنبيهات

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: oliveGreen,
      scaffoldBackgroundColor: beigeBackground,
      fontFamily: 'Cairo', // موحّد مع main.dart
      colorScheme: ColorScheme.fromSeed(
        seedColor: oliveGreen,
        primary: oliveGreen,
        secondary: oliveLight,
        surface: beigeCard,
        onPrimary: Colors.white,
        onSurface: textDark,
        brightness: Brightness.light,
      ),
      textTheme: const TextTheme(
        // عناوين
        headlineLarge: TextStyle(color: textDark, fontSize: 28, fontWeight: FontWeight.bold, height: 1.4),
        headlineMedium: TextStyle(color: textDark, fontSize: 22, fontWeight: FontWeight.bold, height: 1.4),
        titleLarge: TextStyle(color: textDark, fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
        // نصوص الجسم
        bodyLarge: TextStyle(color: textDark, fontSize: 16, height: 1.6),
        bodyMedium: TextStyle(color: textDark, fontSize: 14, height: 1.5),
        bodySmall: TextStyle(color: textMuted, fontSize: 12, height: 1.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: oliveGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      // Fix: استخدام CardThemeData بدلاً من CardTheme
      cardTheme: const CardThemeData(
        color: beigeCard,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}