import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/growth_aggregator.dart';
import '../core/growth_percentile_calculator.dart';
import '../core/text_styles.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../services/growth_comment_service.dart';
import '../services/growth_recommendation_service.dart';
import '../services/growth_sync_service.dart';
import '../widgets/common_widgets.dart';

class GrowthScreen extends StatefulWidget {
  const GrowthScreen({super.key});

  @override
  State<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends State<GrowthScreen> {
  ChildProfile? _child;
  List<GrowthRecord> _records = [];
  List<GrowthComment> _comments = [];
  bool _showHeight = true;
  bool _showPercentile = true;
  String _rangeFilter = '전체'; // '1M' | '3M' | '6M' | '전체'
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final children = await FirebaseService.instance.fetchChildren();
    final child = children.first;
    await GrowthSyncService.instance.syncFromHardware(child); // 하드웨어 실측값 → Firestore 반영
    final records = await FirebaseService.instance.fetchGrowthRecords(child.id);
    final comments = await GrowthCommentService.instance.generate(records, child);
    if (!mounted) return;
    setState(() {
      _child = child;
      _records = records;
      _comments = comments;
      _loading = false;
    });
  }

  bool get _isMale => _child!.gender.contains('남');

  /// 1M = 이번 달 일별 그대로, 3M/6M/전체 = 월별 평균 (과거→현재 순)
  List<GrowthRecord> get _chartRecords => GrowthAggregator.forRange(_records, _rangeFilter);

  @override
  Widget build(BuildContext context) {
    if (_loading || _child == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final latest = _records.isNotEmpty ? _records.last : null;
    final latestPercentile = latest == null
        ? null
        : (_showHeight
            ? GrowthPercentileCalculator.heightPercentile(
                heightCm: latest.heightCm, ageInMonths: _child!.ageInMonthsAt(latest.date), isMale: _isMale)
            : GrowthPercentileCalculator.weightPercentile(
                weightKg: latest.weightKg, ageInMonths: _child!.ageInMonthsAt(latest.date), isMale: _isMale));
    final chartRecords = _chartRecords;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ChildHeaderCard(greeting: '${_child!.name} 성장 분석', child: _child!),
        const SizedBox(height: 16),
        Text('질병관리청 표준 성장도표 기준', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('성장 분석 📊', style: Theme.of(context).textTheme.titleMedium),
            Row(
              children: [
                Text('백분위 표시', style: Theme.of(context).textTheme.bodySmall),
                Switch(
                  value: _showPercentile,
                  activeColor: AppColors.primaryGreen,
                  onChanged: (v) => setState(() => _showPercentile = v),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (latest != null && _showPercentile)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PercentileCard(
                label: '키 백분위',
                percentile: GrowthPercentileCalculator.heightPercentile(
                    heightCm: latest.heightCm, ageInMonths: _child!.ageInMonthsAt(latest.date), isMale: _isMale),
                subLabel: '${latest.heightCm}cm',
                bgColor: AppColors.cardHeightBg,
                accentColor: AppColors.primaryGreen,
              ),
              const SizedBox(width: 12),
              _PercentileCard(
                label: '몸무게 백분위',
                percentile: GrowthPercentileCalculator.weightPercentile(
                    weightKg: latest.weightKg, ageInMonths: _child!.ageInMonthsAt(latest.date), isMale: _isMale),
                subLabel: '${latest.weightKg}kg',
                bgColor: AppColors.cardWeightBg,
                accentColor: AppColors.alertOrange,
              ),
            ],
          )
        else if (latest != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MeasurementMiniCard(
                label: '키',
                value: latest.heightCm.toStringAsFixed(1),
                unit: 'cm',
                delta: '',
                bgColor: AppColors.cardHeightBg,
              ),
              const SizedBox(width: 12),
              MeasurementMiniCard(
                label: '몸무게',
                value: latest.weightKg.toStringAsFixed(1),
                unit: 'kg',
                delta: '',
                bgColor: AppColors.cardWeightBg,
              ),
            ],
          ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _OutlinedToggleChip(
                    label: '키',
                    selected: _showHeight,
                    onTap: () => setState(() => _showHeight = true),
                  ),
                  const SizedBox(width: 8),
                  _OutlinedToggleChip(
                    label: '몸무게',
                    selected: !_showHeight,
                    onTap: () => setState(() => _showHeight = false),
                  ),
                  const Spacer(),
                  for (final r in ['1M', '3M', '6M', '전체'])
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _OutlinedToggleChip(
                        label: r,
                        selected: _rangeFilter == r,
                        compact: true,
                        onTap: () => setState(() => _rangeFilter = r),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (latest != null && latestPercentile != null && _showPercentile)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _showHeight ? '${latest.heightCm}cm' : '${latest.weightKg}kg',
                      style: numberStyle(size: 26),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: AppColors.lightGreenBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${latestPercentile.clamp(1, 99).round()}th 백분위',
                        style: const TextStyle(fontSize: 11, color: AppColors.darkGreen),
                      ),
                    ),
                  ],
                )
              else if (latest != null)
                Text(
                  _showHeight ? '${latest.heightCm}cm' : '${latest.weightKg}kg',
                  style: numberStyle(size: 26),
                ),
              const SizedBox(height: 8),
              GrowthLineChart(
                records: chartRecords,
                showHeight: _showHeight,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.insights_rounded, size: 16, color: AppColors.primaryGreen),
            const SizedBox(width: 6),
            Text('성장 분석 코멘트', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 10),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < _comments.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _CommentBox(comment: _comments[i]),
              ],
            ],
          ),
        ),
        Builder(builder: (context) {
          if (latest == null) return const SizedBox.shrink();
          final status = GrowthPercentileCalculator.weightStatusFromBmi(
            heightCm: latest.heightCm,
            weightKg: latest.weightKg,
            ageInMonths: _child!.ageInMonthsAt(latest.date),
            isMale: _isMale,
          );
          if (status == null) return const SizedBox.shrink();

          final recommendations = GrowthRecommendationService.generate(
            status: status,
            ageInMonths: _child!.ageInMonthsAt(latest.date),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, size: 16, color: AppColors.primaryGreen),
                  const SizedBox(width: 6),
                  Text('맞춤 추천', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 4),
              Text('신체활동 · 식습관 — 공식 지침 기반 추천이에요',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 10),
              for (int i = 0; i < recommendations.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RecommendationCard(rec: recommendations[i]),
                ),
            ],
          );
        }),
        const SizedBox(height: 80),
      ],
    );
  }
}

/// 백분위 카드 (75th · 69.8cm 형식 + 하단 증가 화살표)
class _PercentileCard extends StatelessWidget {
  final String label;
  final double? percentile;
  final String subLabel;
  final Color bgColor;
  final Color accentColor;

  const _PercentileCard({
    required this.label,
    required this.percentile,
    required this.subLabel,
    required this.bgColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    const labelColor = AppColors.textSecondary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
            const SizedBox(height: 4),
            if (percentile != null)
              Text(
                '${percentile!.clamp(1, 99).round()}th',
                style: numberStyle(size: 24, color: accentColor),
              )
            else
              Text(subLabel, style: numberStyle(size: 24)),
            if (percentile != null) ...[
              const SizedBox(height: 2),
              Text(subLabel, style: const TextStyle(fontSize: 12, color: labelColor)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 원본 디자인의 각진 아웃라인 토글 칩 (선택 시 진한 배경 + 체크 아이콘)
class _OutlinedToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _OutlinedToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 6 : 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primaryGreen : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: compact ? 12 : 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 11 : 13,
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final GrowthRecommendation rec;
  const _RecommendationCard({required this.rec});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rec.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rec.color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 16, backgroundColor: rec.color.withOpacity(0.15), child: Icon(rec.icon, size: 16, color: rec.color)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: rec.color, borderRadius: BorderRadius.circular(6)),
                      child: Text(rec.category, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(rec.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(rec.body, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentBox extends StatelessWidget {
  final GrowthComment comment;
  const _CommentBox({required this.comment});

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = switch (comment.level) {
      CommentLevel.good => (Icons.check_circle, AppColors.alertGreen, AppColors.lightGreenBg),
      CommentLevel.warning => (Icons.error, AppColors.alertOrange, AppColors.cardWeightBg),
      CommentLevel.info => (Icons.info_outline, AppColors.textSecondary, const Color(0xFFF3F3F3)),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(comment.body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
