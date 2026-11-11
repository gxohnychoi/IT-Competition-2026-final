import '../models/models.dart';

/// 성장 기록을 기간 필터에 맞게 집계하는 유틸.
///
/// - '1M'  : 이번 달 안의 기록을 일별로 그대로 보여줌 (집계 없음)
/// - '3M'  : 이번 달 포함 최근 3개월, 월별 평균 1개 포인트씩
/// - '6M'  : 이번 달 포함 최근 6개월, 월별 평균
/// - '전체' : 전체 기간, 월별 평균
class GrowthAggregator {
  GrowthAggregator._();

  static List<GrowthRecord> forRange(List<GrowthRecord> records, String rangeFilter) {
    if (records.isEmpty) return records;
    final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));

    if (rangeFilter == '1M') {
      final now = DateTime.now();
      final thisMonth =
          sorted.where((r) => r.date.year == now.year && r.date.month == now.month).toList();
      // 이번 달 기록이 없으면(더미데이터 등) 최신 달 하루치라도 보여줌
      if (thisMonth.isEmpty) {
        final lastMonth = sorted.last;
        return sorted
            .where((r) => r.date.year == lastMonth.date.year && r.date.month == lastMonth.date.month)
            .toList();
      }
      return thisMonth;
    }

    final monthly = _monthlyAverage(sorted);

    if (rangeFilter == '전체') return monthly;

    final months = rangeFilter == '3M' ? 3 : 6;
    if (monthly.length <= months) return monthly;
    return monthly.sublist(monthly.length - months);
  }

  /// 같은 연-월에 여러 기록이 있으면 평균 내서 월 1개 포인트로 합침.
  static List<GrowthRecord> _monthlyAverage(List<GrowthRecord> sorted) {
    final Map<String, List<GrowthRecord>> byMonth = {};
    for (final r in sorted) {
      final key = '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => []).add(r);
    }

    final result = <GrowthRecord>[];
    final keys = byMonth.keys.toList()..sort();
    for (final key in keys) {
      final group = byMonth[key]!;
      final avgHeight = group.map((r) => r.heightCm).reduce((a, b) => a + b) / group.length;
      final avgWeight = group.map((r) => r.weightKg).reduce((a, b) => a + b) / group.length;
      final percentiles = group.where((r) => r.heightPercentile != null);
      final avgHeightPct = percentiles.isEmpty
          ? null
          : percentiles.map((r) => r.heightPercentile!).reduce((a, b) => a + b) / percentiles.length;
      final weightPct = group.where((r) => r.weightPercentile != null);
      final avgWeightPct = weightPct.isEmpty
          ? null
          : weightPct.map((r) => r.weightPercentile!).reduce((a, b) => a + b) / weightPct.length;

      result.add(GrowthRecord(
        id: key,
        date: group.last.date, // 그 달의 마지막 기록 날짜를 라벨로 사용
        heightCm: double.parse(avgHeight.toStringAsFixed(1)),
        weightKg: double.parse(avgWeight.toStringAsFixed(1)),
        heightPercentile: avgHeightPct,
        weightPercentile: avgWeightPct,
      ));
    }
    return result;
  }
}
