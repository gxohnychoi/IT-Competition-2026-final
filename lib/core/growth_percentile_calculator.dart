import 'dart:math';
import 'growth_reference_data.dart';

/// 질병관리청 2017 소아청소년 성장도표(LMS 파라미터) 기반 백분위 계산기.
///
/// LMS 방법: 측정값(신장/체중)을 나이·성별에 맞는 L, M, S 값으로
/// z-score로 변환한 뒤, 표준정규분포 누적확률로 백분위를 구함.
///   Z = ((value/M)^L - 1) / (L*S)   (L ≠ 0인 경우)
///   Z = ln(value/M) / S             (L = 0인 경우)
class GrowthPercentileCalculator {
  GrowthPercentileCalculator._();

  /// 신장 백분위 계산 (0~100 사이 값, 범위 밖이면 null)
  static double? heightPercentile({
    required double heightCm,
    required int ageInMonths,
    required bool isMale,
  }) {
    final table = isMale ? GrowthReferenceData.heightMale : GrowthReferenceData.heightFemale;
    return _percentileFromTable(table, heightCm, ageInMonths);
  }

  /// 체중 백분위 계산
  static double? weightPercentile({
    required double weightKg,
    required int ageInMonths,
    required bool isMale,
  }) {
    final table = isMale ? GrowthReferenceData.weightMale : GrowthReferenceData.weightFemale;
    return _percentileFromTable(table, weightKg, ageInMonths);
  }

  static double? _percentileFromTable(List<List<double>> table, double value, int ageInMonths) {
    if (ageInMonths < 0 || ageInMonths >= table.length) return null; // 데이터 범위(0~227개월) 밖
    if (value <= 0) return null;

    final lms = table[ageInMonths];
    final l = lms[0], m = lms[1], s = lms[2];

    final z = l == 0 ? log(value / m) / s : ((pow(value / m, l) - 1) / (l * s));

    final percentile = _standardNormalCdf(z.toDouble()) * 100;
    return percentile.clamp(0.1, 99.9);
  }

  /// 표준정규분포 누적분포함수 (근사식 — Abramowitz & Stegun 방법)
  static double _standardNormalCdf(double z) {
    const b1 = 0.319381530;
    const b2 = -0.356563782;
    const b3 = 1.781477937;
    const b4 = -1.821255978;
    const b5 = 1.330274429;
    const p = 0.2316419;
    const c = 0.39894228; // 1/sqrt(2*pi)

    if (z >= 0) {
      final t = 1.0 / (1.0 + p * z);
      final poly = t * (b1 + t * (b2 + t * (b3 + t * (b4 + t * b5))));
      return 1.0 - c * exp(-z * z / 2.0) * poly;
    } else {
      return 1.0 - _standardNormalCdf(-z);
    }
  }

  /// 반대로, 특정 백분위(예: 97)에 해당하는 실제 측정값을 구함.
  /// 차트에 97th/50th/3rd 기준선을 실제 데이터로 그릴 때 사용.
  static double? valueAtPercentile({
    required int ageInMonths,
    required double percentile,
    required bool isMale,
    required bool isHeight,
  }) {
    final table = isHeight
        ? (isMale ? GrowthReferenceData.heightMale : GrowthReferenceData.heightFemale)
        : (isMale ? GrowthReferenceData.weightMale : GrowthReferenceData.weightFemale);
    if (ageInMonths < 0 || ageInMonths >= table.length) return null;

    final lms = table[ageInMonths];
    final l = lms[0], m = lms[1], s = lms[2];
    final z = _inverseStandardNormalCdf(percentile / 100);

    if (l == 0) return m * exp(s * z);
    return m * pow(1 + l * s * z, 1 / l);
  }

  /// 표준정규분포 역함수(probit) — Peter Acklam의 근사 알고리즘
  static double _inverseStandardNormalCdf(double p) {
    if (p <= 0) return -8;
    if (p >= 1) return 8;

    const a = [
      -3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
      1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00,
    ];
    const b = [
      -5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
      6.680131188771972e+01, -1.328068155288572e+01,
    ];
    const c = [
      -7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
      -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00,
    ];
    const d = [
      7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
      3.754408661907416e+00,
    ];

    const pLow = 0.02425;
    final pHigh = 1 - pLow;

    if (p < pLow) {
      final q = sqrt(-2 * log(p));
      return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
          ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
    } else if (p <= pHigh) {
      final q = p - 0.5;
      final r = q * q;
      return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) *
          q /
          (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
    } else {
      final q = sqrt(-2 * log(1 - p));
      return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
          ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
    }
  }

  /// BMI(체질량지수) 백분위 계산. 데이터가 24개월부터 시작하므로 그 이전
  /// 나이는 null 반환 (그 나이대는 키/몸무게 개별 백분위로 판단하는 게 맞음).
  static double? bmiPercentile({
    required double heightCm,
    required double weightKg,
    required int ageInMonths,
    required bool isMale,
  }) {
    if (ageInMonths < 24) return null;
    final table = isMale ? GrowthReferenceData.bmiMale : GrowthReferenceData.bmiFemale;
    final index = ageInMonths - 24;
    if (index < 0 || index >= table.length) return null;

    final heightM = heightCm / 100;
    final bmi = weightKg / (heightM * heightM);

    final lms = table[index];
    final l = lms[0], m = lms[1], s = lms[2];
    final z = l == 0 ? log(bmi / m) / s : ((pow(bmi / m, l) - 1) / (l * s));
    return (_standardNormalCdf(z.toDouble()) * 100).clamp(0.1, 99.9);
  }

  /// 질병관리청 기준 체중 상태 분류: <5th 저체중 / 5~84th 정상 / 85~94th 과체중 / 95th+ 비만
  static WeightStatus? weightStatusFromBmi({
    required double heightCm,
    required double weightKg,
    required int ageInMonths,
    required bool isMale,
  }) {
    final pct = bmiPercentile(heightCm: heightCm, weightKg: weightKg, ageInMonths: ageInMonths, isMale: isMale);
    if (pct == null) return null;
    if (pct < 5) return WeightStatus.underweight;
    if (pct < 85) return WeightStatus.normal;
    if (pct < 95) return WeightStatus.overweight;
    return WeightStatus.obese;
  }

  /// 백분위(0~100)를 "또래 중 상위/하위 N%" 표시용으로 안전하게 변환.
  /// - 50 이상이면 "상위" (100-percentile), 미만이면 "하위" (percentile 그대로)
  /// - 극단값(0.2%, 99.9% 등)이 반올림돼서 "0%"로 보이는 걸 막기 위해
  ///   최소 1%는 보이게 clamp함 (실제 0%는 없다는 뜻이 아니라 "1% 미만"이라는 뜻)
  static ({bool isTop, int displayPercent}) topBottomLabel(double percentile) {
    if (percentile >= 50) {
      return (isTop: true, displayPercent: (100 - percentile).clamp(1, 99).round());
    }
    return (isTop: false, displayPercent: percentile.clamp(1, 99).round());
  }
}

enum WeightStatus { underweight, normal, overweight, obese }
