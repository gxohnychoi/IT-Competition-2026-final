import '../models/models.dart';

class GrowthPrediction {
  final double predictedValue;
  final DateTime predictedDate;
  final double confidence; // 0~1, 데이터 점이 많고 추세가 일관될수록 높음
  GrowthPrediction({required this.predictedValue, required this.predictedDate, required this.confidence});
}

/// 최근 측정 기록으로 단순 선형회귀를 돌려서 "다음 달 예상치"를 계산.
/// 통계적으로 복잡한 모델(다항회귀, 성장 곡선 모델 등)까지는 안 가고,
/// 최근 추세가 유지된다는 가정 하의 근사치 — 그래서 "예측"이 아니라
/// 화면에는 "예상"이라는 단어를 씀 (과신 방지).
class GrowthPredictor {
  GrowthPredictor._();

  /// [useHeight]가 true면 키, false면 몸무게로 예측.
  static GrowthPrediction? predictNextMonth(List<GrowthRecord> records, {required bool useHeight}) {
    if (records.length < 2) return null;

    final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
    // 최근 4개(또는 있는 만큼)만 써서 최근 추세를 반영 — 오래된 데이터가
    // 성장기 특성(초반엔 빠르고 나중엔 완만해짐)을 왜곡하지 않도록.
    final recent = sorted.length > 4 ? sorted.sublist(sorted.length - 4) : sorted;

    final baseDate = recent.first.date;
    final xs = <double>[];
    final ys = <double>[];
    for (final r in recent) {
      xs.add(r.date.difference(baseDate).inDays.toDouble());
      ys.add(useHeight ? r.heightCm : r.weightKg);
    }

    final n = xs.length;
    final sumX = xs.reduce((a, b) => a + b);
    final sumY = ys.reduce((a, b) => a + b);
    final sumXY = List.generate(n, (i) => xs[i] * ys[i]).reduce((a, b) => a + b);
    final sumXX = List.generate(n, (i) => xs[i] * xs[i]).reduce((a, b) => a + b);

    final denominator = n * sumXX - sumX * sumX;
    if (denominator == 0) return null; // 같은 날짜만 있는 등 계산 불가 상황

    final slope = (n * sumXY - sumX * sumY) / denominator; // 일(day)당 변화량
    final intercept = (sumY - slope * sumX) / n;

    final lastDate = recent.last.date;
    final targetDate = DateTime(lastDate.year, lastDate.month + 1, lastDate.day);
    final targetX = targetDate.difference(baseDate).inDays.toDouble();
    final predicted = slope * targetX + intercept;

    // 데이터 점 개수와 잔차(실제값-회귀선 차이)로 신뢰도를 간단히 추정.
    double sumResidualSq = 0;
    for (int i = 0; i < n; i++) {
      final fitted = slope * xs[i] + intercept;
      sumResidualSq += (ys[i] - fitted) * (ys[i] - fitted);
    }
    final avgResidual = sumResidualSq / n;
    // 잔차가 작고 데이터가 많을수록 신뢰도 ↑ (경험적 근사, 통계적 엄밀함보단 UX용 지표)
    final dataConfidence = (n / 4.0).clamp(0.0, 1.0);
    final fitConfidence = (1 - (avgResidual / (useHeight ? 4.0 : 0.5))).clamp(0.0, 1.0);
    final confidence = (dataConfidence * 0.5 + fitConfidence * 0.5).clamp(0.3, 0.95);

    return GrowthPrediction(
      predictedValue: double.parse(predicted.toStringAsFixed(1)),
      predictedDate: targetDate,
      confidence: confidence,
    );
  }
}
