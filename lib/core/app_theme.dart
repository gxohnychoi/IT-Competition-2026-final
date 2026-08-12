import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 쑥쑥이 앱 컬러 팔레트 (피그마 "Selection colors" 캡처 기준으로 교체)
class AppColors {
  AppColors._();

  static const Color primaryGreen = Color(0xFF5BAD72); // 메인 그린
  static const Color darkGreen = Color(0xFF2D3A2E); // 진한 텍스트/포인트용 그린-블랙
  static const Color lightGreenBg = Color(0xFFE8F5EB); // 연한 그린 배경

  static const Color accentIndigo = Color(0xFF8A94D0); // 보조 포인트 컬러

  static const Color cardHeightBg = Color(0xFFE8F5EB); // 키 카드 배경 (연그린)
  static const Color cardWeightBg = Color(0xFFFFF0E8); // 몸무게 카드 배경 (연피치)

  static const Color scaffoldBg = Color(0xFFF5F2EE); // 전체 배경
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color sectionAltBg = Color(0xFFF0EDE8); // 보조 섹션/구분 배경

  static const Color textPrimary = Color(0xFF2D3A2E);
  static const Color textSecondary = Color(0xFF8A8A8A); // 가독성 위해 회색 유지
  static const Color borderGray = Color(0xFFC5CEC6); // 보더/구분선 전용

  static const Color alertGreen = Color(0xFF5BAD72);
  static const Color alertOrange = Color(0xFFE8A33D);
  static const Color alertRed = Color(0xFFE0604B);

  static const Color danger = Color(0xFFC94D3F);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.scaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryGreen,
        primary: AppColors.primaryGreen,
        surface: AppColors.scaffoldBg,
      ),
      fontFamily: GoogleFonts.notoSansKr().fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.scaffoldBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        titleMedium: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: Color(0xFF8A8A8A)),
      ),
    );
  }
}
