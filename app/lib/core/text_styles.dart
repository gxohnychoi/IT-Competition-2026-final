import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 숫자 전용 폰트 스타일 (Nunito, weight 900) — 키/몸무게/시간 등
/// 굵게 강조해야 하는 숫자에 공통으로 씀.
TextStyle numberStyle({double size = 18, Color color = const Color(0xFF2D3A2E)}) => GoogleFonts.nunito(
      fontWeight: FontWeight.w900,
      fontSize: size,
      height: 28 / 18,
      color: color,
    );

/// 날짜/보조 텍스트 전용 스타일 (Noto Sans KR, 600, 12px, #8A9490)
TextStyle dateTextStyle() => GoogleFonts.notoSansKr(
      fontWeight: FontWeight.w600,
      fontSize: 12,
      height: 16 / 12,
      color: const Color(0xFF8A9490),
    );
