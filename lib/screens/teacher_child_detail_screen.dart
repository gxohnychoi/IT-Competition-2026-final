import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../core/growth_aggregator.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../services/growth_comment_service.dart';
import '../widgets/common_widgets.dart';

/// 선생님이 원아 카드를 눌렀을 때 뜨는 상세 화면.
/// 학부모용 홈/성장분석 화면과 비슷하게 — 오늘 요약, 성장 차트,
/// 백분위, 분석 코멘트를 한 화면에서 볼 수 있음.
class TeacherChildDetailScreen extends StatefulWidget {
  final String uid;
  final ChildProfile child;
  const TeacherChildDetailScreen({super.key, required this.uid, required this.child});

  @override
  State<TeacherChildDetailScreen> createState() => _TeacherChildDetailScreenState();
}

class _TeacherChildDetailScreenState extends State<TeacherChildDetailScreen> {
  List<GrowthRecord> _records = [];
  List<GrowthComment> _comments = [];
  bool _loading = true;

  bool get _isMale => widget.child.gender.contains('남');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records =
        await FirebaseService.instance.fetchGrowthRecordsForChild(widget.uid, widget.child.id);
    final comments = await GrowthCommentService.instance.generate(records, widget.child);
    if (!mounted) return;
    setState(() {
      _records = records;
      _comments = comments;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(title: Text('${widget.child.name} 성장 정보')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ChildHeaderCard(greeting: '${widget.child.name} 성장 기록', child: widget.child),
                  const SizedBox(height: 16),
                  _buildTodaySummary(context),
                  const SizedBox(height: 16),
                  if (_records.isNotEmpty) _buildChart(context),
                  const SizedBox(height: 16),
                  if (_comments.isNotEmpty) _buildComments(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildTodaySummary(BuildContext context) {
    final latest = _records.isNotEmpty ? _records.last : null;
    final prev = _records.length > 1 ? _records[_records.length - 2] : null;
    // 테스트 중 잘못 들어간 값(예: 몸무게 수백kg) 때문에 증감이 비정상적으로
    // 크게 나오는 걸 방지 — 하루 사이 변화가 이 범위를 넘으면 증감 자체를 숨김.
    final rawHeightDelta = (latest != null && prev != null) ? latest.heightCm - prev.heightCm : null;
    final rawWeightDelta = (latest != null && prev != null) ? latest.weightKg - prev.weightKg : null;
    final heightDelta = (rawHeightDelta != null && rawHeightDelta.abs() <= 15) ? rawHeightDelta : null;
    final weightDelta = (rawWeightDelta != null && rawWeightDelta.abs() <= 10) ? rawWeightDelta : null;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('최신 측정값', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (latest != null)
            Row(
              children: [
                MeasurementMiniCard(
                  label: '키',
                  value: latest.heightCm.toStringAsFixed(1),
                  unit: 'cm',
                  delta: heightDelta == null ? '' : '${heightDelta.toStringAsFixed(1)}cm',
                  deltaValue: heightDelta,
                  bgColor: AppColors.cardHeightBg,
                ),
                const SizedBox(width: 10),
                MeasurementMiniCard(
                  label: '몸무게',
                  value: latest.weightKg.toStringAsFixed(1),
                  unit: 'kg',
                  delta: weightDelta == null ? '' : '${weightDelta.toStringAsFixed(1)}kg',
                  deltaValue: weightDelta,
                  bgColor: AppColors.cardWeightBg,
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('아직 측정 기록이 없어요', style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final monthly = GrowthAggregator.forRange(_records, '6M');
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('최근 성장 추이', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          GrowthLineChart(records: monthly, showHeight: true),
        ],
      ),
    );
  }

  Widget _buildComments(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('성장 분석 코멘트', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (int i = 0; i < _comments.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _buildCommentRow(_comments[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentRow(GrowthComment comment) {
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
                Text(comment.body, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
