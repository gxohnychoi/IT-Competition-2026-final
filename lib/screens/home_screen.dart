import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../core/growth_aggregator.dart';
import '../core/text_styles.dart';
import '../models/models.dart';
import '../services/attendance_watch_service.dart';
import '../services/firebase_service.dart';
import '../services/growth_sync_service.dart';
import '../services/realtime_measurement_service.dart';
import '../widgets/common_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ChildProfile? _child;
  List<GrowthRecord> _records = [];
  AttendanceRecord? _attendance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final children = await FirebaseService.instance.fetchChildren();
    final child = children.first;
    AttendanceWatchService.instance.start(child); // 등원/하원 실시간 감시 시작
    await GrowthSyncService.instance.syncFromHardware(child); // 하드웨어 실측값 → Firestore 반영
    final records = await FirebaseService.instance.fetchGrowthRecords(child.id);
    final attendance = await FirebaseService.instance.fetchTodayAttendance(child.id);
    if (!mounted) return;
    setState(() {
      _child = child;
      _records = records;
      _attendance = attendance;
      _loading = false;
    });
  }

  /// 홈 화면 미니 차트는 최근 3개월치 (월별 평균)
  List<GrowthRecord> get _monthlyRecords => GrowthAggregator.forRange(_records, '3M');

  /// "월별 성장 기록" 리스트용 — 최신순
  List<GrowthRecord> get _monthlyRecordsDesc => _monthlyRecords.reversed.toList();

  @override
  Widget build(BuildContext context) {
    if (_loading || _child == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final latest = _records.isNotEmpty ? _records.last : null;
    final prev = _records.length > 1 ? _records[_records.length - 2] : null;
    final heightDelta = (latest != null && prev != null) ? latest.heightCm - prev.heightCm : 0.0;
    final weightDelta = (latest != null && prev != null) ? latest.weightKg - prev.weightKg : 0.0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ChildHeaderCard(greeting: '오늘도 쑥쑥 크는 중!', child: _child!),
          const SizedBox(height: 16),
          Text(DateFormat('yyyy년 M월 d일 EEEE', 'ko_KR').format(DateTime.now()), style: dateTextStyle()),
          const SizedBox(height: 4),

          // ── 1. 오늘 요약 ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('오늘 요약 📋', style: Theme.of(context).textTheme.titleMedium),
              TextButton(
                onPressed: () => context.push('/growth'),
                child: const Text('성장분석 보기 ›'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/growth'),
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (latest != null) ...[
                    Text('최신 측정값 · ${DateFormat('yyyy.MM.dd').format(latest.date)}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _NumberMiniCard(
                          label: '키',
                          value: latest.heightCm.toStringAsFixed(1),
                          unit: 'cm',
                          delta: '${heightDelta >= 0 ? '+' : ''}${heightDelta.toStringAsFixed(1)}cm',
                          deltaValue: heightDelta,
                          bgColor: AppColors.cardHeightBg,
                        ),
                        const SizedBox(width: 10),
                        _NumberMiniCard(
                          label: '몸무게',
                          value: latest.weightKg.toStringAsFixed(1),
                          unit: 'kg',
                          delta: '${weightDelta >= 0 ? '+' : ''}${weightDelta.toStringAsFixed(1)}kg',
                          deltaValue: weightDelta,
                          bgColor: AppColors.cardWeightBg,
                        ),
                      ],
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          const Icon(Icons.straighten_rounded, size: 32, color: AppColors.textSecondary),
                          const SizedBox(height: 8),
                          Text('아직 측정 기록이 없어요', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('최근 ${_monthlyRecords.length}개월 키 추이', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 10),
                  GrowthLineChart(records: _monthlyRecords, showHeight: true),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── 2. 오늘 등원 현황 ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('오늘 등원 현황', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 6),
                  const Icon(Icons.home_rounded, size: 18, color: AppColors.textPrimary),
                ],
              ),
              TextButton(
                onPressed: () => context.push('/alerts'),
                child: const Text('알림 히스토리 ›'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AttendanceSection(child: _child!, fallback: _attendance),

          const SizedBox(height: 16),

          // ── 3. 월별 성장 기록 ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('월별 성장 기록', style: Theme.of(context).textTheme.titleMedium),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('매달 1일',
                    style: TextStyle(fontSize: 11, color: AppColors.darkGreen, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 키/몸무게 컬럼 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [
                    Text('키',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryGreen)),
                    SizedBox(width: 24),
                    Text('몸무게',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.alertOrange)),
                  ],
                ),
                const SizedBox(height: 10),
                for (int i = 0; i < _monthlyRecordsDesc.length; i++) ...[
                  if (i > 0) const Divider(height: 24, color: AppColors.sectionAltBg),
                  _MonthlyRecordRow(
                    record: _monthlyRecordsDesc[i],
                    isLatest: i == 0,
                    prevRecord: i < _monthlyRecordsDesc.length - 1 ? _monthlyRecordsDesc[i + 1] : null,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

/// 키/몸무게 요약 미니 카드 — 숫자-단위 간격 벌림
class _NumberMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String delta;
  final double? deltaValue;
  final Color bgColor;

  const _NumberMiniCard({
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
                Text(value, style: numberStyle(size: 20)),
                const SizedBox(width: 4), // 숫자-단위 간격
                Text(unit, style: Theme.of(context).textTheme.bodySmall),
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

/// 등원 현황 섹션 — RFID 카드 있으면 실시간 감시 서비스(AttendanceWatchService)의
/// 검증된 최신값을 그대로 사용, 없으면 폴백
class _AttendanceSection extends StatelessWidget {
  final ChildProfile child;
  final AttendanceRecord? fallback;
  const _AttendanceSection({required this.child, required this.fallback});

  @override
  Widget build(BuildContext context) {
    if (child.rfidCardId == null || child.rfidCardId!.isEmpty) {
      return _AttendanceCard(
        checkIn: fallback?.checkInTime,
        checkOut: fallback?.checkOutTime,
        stay: fallback?.stayDuration,
        rfidCardId: null,
      );
    }

    return ValueListenableBuilder<TodayAttendanceInfo?>(
      valueListenable: AttendanceWatchService.instance.currentInfo,
      builder: (context, info, _) {
        return _AttendanceCard(
          checkIn: info?.checkInTime,
          checkOut: info?.checkOutTime,
          stay: info?.stayDuration,
          rfidCardId: child.rfidCardId,
        );
      },
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final DateTime? checkIn;
  final DateTime? checkOut;
  final Duration? stay;
  final String? rfidCardId;
  const _AttendanceCard({required this.checkIn, required this.checkOut, required this.stay, required this.rfidCardId});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/alerts'),
      child: SectionCard(
        child: Row(
          children: [
            _AttendanceBox(
              label: '등원',
              value: checkIn != null ? DateFormat('HH:mm').format(checkIn!) : '-',
              bgColor: AppColors.cardHeightBg,
            ),
            const SizedBox(width: 8),
            _AttendanceBox(
              label: '하원',
              value: checkOut != null ? DateFormat('HH:mm').format(checkOut!) : '-',
              bgColor: AppColors.cardWeightBg,
            ),
            const SizedBox(width: 8),
            _AttendanceBox(
              label: '체류',
              value: stay != null ? '${stay!.inHours}h ${stay!.inMinutes % 60}m' : '-',
              bgColor: AppColors.sectionAltBg,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceBox extends StatelessWidget {
  final String label;
  final String value;
  final Color bgColor;
  const _AttendanceBox({required this.label, required this.value, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: numberStyle()),
          ],
        ),
      ),
    );
  }
}

/// 월별 성장 기록 한 줄 — 큰 카드 안에서 구분선으로만 나뉘는 행
class _MonthlyRecordRow extends StatelessWidget {
  final GrowthRecord record;
  final bool isLatest;
  final GrowthRecord? prevRecord;

  const _MonthlyRecordRow({required this.record, required this.isLatest, required this.prevRecord});

  @override
  Widget build(BuildContext context) {
    final heightDelta = prevRecord != null ? record.heightCm - prevRecord!.heightCm : null;
    final weightDelta = prevRecord != null ? record.weightKg - prevRecord!.weightKg : null;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isLatest ? AppColors.primaryGreen : AppColors.sectionAltBg,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${record.date.month}월',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isLatest ? Colors.white : const Color(0xFF8A9490),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(DateFormat('yyyy년 M월 d일').format(record.date), style: dateTextStyle()),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(record.heightCm.toStringAsFixed(1), style: numberStyle(size: 15)),
                const SizedBox(width: 2),
                const Text('cm', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                Text(record.weightKg.toStringAsFixed(1), style: numberStyle(size: 15)),
                const SizedBox(width: 2),
                const Text('kg', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 4),
            if (heightDelta != null && weightDelta != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DeltaBadge(value: heightDelta, unit: 'cm'),
                  const SizedBox(width: 4),
                  _DeltaBadge(value: weightDelta, unit: 'kg'),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// 증감 배지 — 늘었으면 초록 ↗, 줄었으면 빨강 ↘
class _DeltaBadge extends StatelessWidget {
  final double value;
  final String unit;
  const _DeltaBadge({required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    final isDown = value < 0;
    final arrow = isDown ? '↘' : '↗';
    final sign = value >= 0 ? '+' : '';
    final color = isDown ? AppColors.alertRed : AppColors.alertGreen;
    final bg = isDown ? const Color(0xFFFBE4E1) : AppColors.lightGreenBg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text('$arrow$sign${value.toStringAsFixed(1)}$unit', style: TextStyle(fontSize: 10, color: color)),
    );
  }
}
