import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/models.dart';

/// 상단 인사말 + 자녀 정보 그린 헤더 카드
class ChildHeaderCard extends StatelessWidget {
  final String greeting;
  final ChildProfile child;
  final VoidCallback? onTap;

  const ChildHeaderCard({super.key, required this.greeting, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('안녕하세요 김민지 님 👋', style: TextStyle(color: Colors.white.withOpacity(0.9))),
          const SizedBox(height: 4),
          Text(greeting,
              style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: Text('🐣', style: TextStyle(fontSize: 24, height: 32 / 24)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(child.name,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w600)),
                        Text('생후 ${child.ageInMonths}개월 · ${child.gender}',
                            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 키 / 몸무게 요약 미니 카드
class MeasurementMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String delta;
  final Color bgColor;
  final double? deltaValue; // 부호로 화살표 방향/색 결정 (안 주면 항상 위쪽 초록으로 폴백)

  const MeasurementMiniCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.delta,
    required this.bgColor,
    this.deltaValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDown = (deltaValue ?? 0) < 0;
    final arrow = isDown ? '↘' : '↗';
    final color = isDown ? AppColors.alertRed : AppColors.alertGreen;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                Text(' $unit', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            if (delta.isNotEmpty) Text('$arrow $delta', style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// 성장 추이 라인 차트 (키 or 몸무게)
class GrowthLineChart extends StatelessWidget {
  final List<GrowthRecord> records;
  final bool showHeight; // true: 키, false: 몸무게
  final bool showPeerAverage; // 또래 평균 비교선 (홈 요약용, 단일 점선)
  final bool showPercentileLines; // 97th/50th/3rd 백분위선 (성장분석용)
  final List<double?>? p97; // records와 같은 길이의 실제 97th 값 (질병관리청 데이터 기반)
  final List<double?>? p50;
  final List<double?>? p3;

  const GrowthLineChart({
    super.key,
    required this.records,
    this.showHeight = true,
    this.showPeerAverage = false,
    this.showPercentileLines = false,
    this.p97,
    this.p50,
    this.p3,
  });

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (int i = 0; i < records.length; i++)
        FlSpot(i.toDouble(), showHeight ? records[i].heightCm : records[i].weightKg),
    ];

    List<FlSpot> _scaled(double factor) => [
          for (int i = 0; i < records.length; i++)
            FlSpot(i.toDouble(), (showHeight ? records[i].heightCm : records[i].weightKg) * factor),
        ];

    List<FlSpot> _fromValues(List<double?>? values) => [
          for (int i = 0; i < records.length; i++)
            if (values != null && i < values.length && values[i] != null) FlSpot(i.toDouble(), values[i]!),
        ];

    final p97Spots = _fromValues(p97);
    final p50Spots = _fromValues(p50);
    final p3Spots = _fromValues(p3);
    final hasRealPercentileData = p97Spots.isNotEmpty || p50Spots.isNotEmpty || p3Spots.isNotEmpty;

    // 모든 라인(본인 + 참조선)을 포함해서 y축 범위를 계산 — 그래야 값이 잘리거나
    // 축 간격이 이상하게 촘촘해지는 문제가 안 생김.
    final allValues = <double>[for (final s in spots) s.y];
    if (showPercentileLines && hasRealPercentileData) {
      allValues.addAll(p97Spots.map((s) => s.y));
      allValues.addAll(p3Spots.map((s) => s.y));
    } else if (showPercentileLines) {
      allValues.addAll(_scaled(1.08).map((s) => s.y));
      allValues.addAll(_scaled(0.82).map((s) => s.y));
    } else if (showPeerAverage) {
      allValues.addAll(_scaled(0.94).map((s) => s.y));
    }
    final rawMin = allValues.isEmpty ? 0.0 : allValues.reduce((a, b) => a < b ? a : b);
    final rawMax = allValues.isEmpty ? 1.0 : allValues.reduce((a, b) => a > b ? a : b);
    final range = (rawMax - rawMin).clamp(1.0, double.infinity);
    // 위아래 여유(padding)를 좀 주고, 그래프가 보기 좋게 5 단위로 정리
    final padding = range * 0.15;
    final minY = ((rawMin - padding) / 5).floor() * 5.0;
    final maxY = ((rawMax + padding) / 5).ceil() * 5.0;
    final yInterval = (((maxY - minY) / 4) / 5).ceil() * 5.0;
    final safeInterval = yInterval < 5 ? 5.0 : yInterval;
    final maxX = records.isEmpty ? 1.0 : (records.length - 1).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: safeInterval,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(0),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: records.length > 10 ? (records.length / 6).ceilToDouble() : 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if (i < 0 || i >= records.length || (value - i).abs() > 0.01) {
                        return const SizedBox.shrink();
                      }
                      final sameMonth = records.every(
                          (r) => r.date.year == records.first.date.year && r.date.month == records.first.date.month);
                      final label = sameMonth ? '${records[i].date.day}일' : '${records[i].date.month}월';
                      return Text(label, style: Theme.of(context).textTheme.bodySmall);
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => Colors.white,
                  tooltipBorder: BorderSide(
                    color: const Color(0xFF5BAD72).withOpacity(0.2),
                    width: 1.5,
                  ),
                  tooltipRoundedRadius: 12,
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final i = spot.x.toInt();
                      final label = (i >= 0 && i < records.length)
                          ? '${records[i].date.month}월'
                          : '${spot.x.toInt()}';
                      return LineTooltipItem(
                        '$label\n',
                        const TextStyle(
                          color: Color(0xFF2D3A2E),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                        children: [
                          TextSpan(
                            text: '${spot.y.toStringAsFixed(1)}${showHeight ? 'cm' : 'kg'}',
                            style: const TextStyle(
                              color: Color(0xFF5BAD72),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
                getTouchedSpotIndicator: (barData, spotIndexes) {
                  return spotIndexes.map((index) {
                    return TouchedSpotIndicatorData(
                      FlLine(color: const Color(0xFF5BAD72), strokeWidth: 1.5, dashArray: [4, 3]),
                      FlDotData(
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 6,
                          color: Colors.white,
                          strokeWidth: 2.5,
                          strokeColor: const Color(0xFF5BAD72),
                        ),
                      ),
                    );
                  }).toList();
                },
              ),
              lineBarsData: [
                if (showPercentileLines && hasRealPercentileData) ...[
                  LineChartBarData(
                    spots: p97Spots,
                    isCurved: true,
                    color: AppColors.alertRed.withOpacity(0.55),
                    barWidth: 1.5,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: p50Spots,
                    isCurved: true,
                    color: AppColors.alertGreen.withOpacity(0.45),
                    barWidth: 1.5,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: p3Spots,
                    isCurved: true,
                    color: AppColors.textSecondary.withOpacity(0.4),
                    barWidth: 1.5,
                    dotData: const FlDotData(show: false),
                  ),
                ] else if (showPercentileLines) ...[
                  LineChartBarData(
                    spots: _scaled(1.08),
                    isCurved: true,
                    color: AppColors.alertRed.withOpacity(0.55),
                    barWidth: 1.5,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: _scaled(0.98),
                    isCurved: true,
                    color: AppColors.alertGreen.withOpacity(0.45),
                    barWidth: 1.5,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: _scaled(0.82),
                    isCurved: true,
                    color: AppColors.textSecondary.withOpacity(0.4),
                    barWidth: 1.5,
                    dotData: const FlDotData(show: false),
                  ),
                ] else if (showPeerAverage)
                  LineChartBarData(
                    spots: _scaled(0.94),
                    isCurved: true,
                    color: AppColors.textSecondary.withOpacity(0.5),
                    barWidth: 2,
                    dashArray: [6, 4],
                    dotData: const FlDotData(show: false),
                  ),
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.primaryGreen,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                      radius: 4,
                      color: Colors.white,
                      strokeWidth: 2,
                      strokeColor: const Color(0xFF5BAD72),
                    ),
                  ),
                  belowBarData:
                      BarAreaData(show: true, color: AppColors.primaryGreen.withOpacity(0.1)),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
          ),
        ),
        const SizedBox(height: 10),
        if (showPercentileLines)
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _LegendItem(color: AppColors.primaryGreen, label: '서준이'),
              _LegendItem(color: AppColors.alertRed.withOpacity(0.6), label: '97th'),
              _LegendItem(color: AppColors.alertGreen.withOpacity(0.5), label: '50th'),
              _LegendItem(color: AppColors.textSecondary.withOpacity(0.5), label: '3rd'),
            ],
          )
        else if (showPeerAverage)
          Row(
            children: [
              _LegendItem(color: AppColors.primaryGreen, label: '서준이'),
              const SizedBox(width: 16),
              _LegendItem(color: AppColors.textSecondary.withOpacity(0.5), label: '또래 평균', dashed: true),
            ],
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const _LegendItem({required this.color, required this.label, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

/// 리스트 카드 컨테이너 (흰색 라운드 박스)
class SectionCard extends StatelessWidget {
  final Widget child;
  const SectionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}
