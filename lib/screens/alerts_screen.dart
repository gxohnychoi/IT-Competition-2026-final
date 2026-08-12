import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../services/attendance_watch_service.dart';
import '../services/firebase_service.dart';
import '../widgets/common_widgets.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  ChildProfile? _child;
  AttendanceRecord? _fallbackAttendance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // 이 화면이 열려있는 동안 새 등원/하원 감지되면 리스트 실시간 갱신
    AttendanceWatchService.instance.events.listen((_) {
      if (mounted) setState(() {});
    });
    // 요약 박스(등원/하원/체류)도 같은 서비스의 최신값을 계속 반영
    AttendanceWatchService.instance.currentInfo.addListener(_onInfoChanged);
  }

  @override
  void dispose() {
    AttendanceWatchService.instance.currentInfo.removeListener(_onInfoChanged);
    super.dispose();
  }

  void _onInfoChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final children = await FirebaseService.instance.fetchChildren();
    final child = children.first;
    // RFID 없는 경우에만 쓰이는 폴백값 (있으면 AttendanceWatchService가 우선)
    final attendance = await FirebaseService.instance.fetchTodayAttendance(child.id);
    if (!mounted) return;
    setState(() {
      _child = child;
      _fallbackAttendance = attendance;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _child == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final history = AttendanceWatchService.instance.history;
    final hasRfid = _child!.rfidCardId != null && _child!.rfidCardId!.isNotEmpty;
    final liveInfo = AttendanceWatchService.instance.currentInfo.value;
    final checkInTime = hasRfid ? liveInfo?.checkInTime : _fallbackAttendance?.checkInTime;
    final checkOutTime = hasRfid ? liveInfo?.checkOutTime : _fallbackAttendance?.checkOutTime;
    final stayDuration = (checkInTime != null && checkOutTime != null)
        ? checkOutTime.difference(checkInTime)
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ChildHeaderCard(greeting: '알림 & 등하원', child: _child!),
        const SizedBox(height: 16),
        Text('RFID 기반 자동 기록', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text('알림 & 등하원 🔔', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SectionCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AttendanceStat(
                icon: Icons.login_rounded,
                iconColor: AppColors.alertGreen,
                label: '등원',
                value: checkInTime != null ? DateFormat('HH:mm').format(checkInTime) : '-',
              ),
              _AttendanceStat(
                icon: Icons.logout_rounded,
                iconColor: AppColors.alertOrange,
                label: '하원',
                value: checkOutTime != null ? DateFormat('HH:mm').format(checkOutTime) : '-',
              ),
              _AttendanceStat(
                icon: Icons.timer_outlined,
                iconColor: AppColors.textSecondary,
                label: '체류',
                value: stayDuration != null ? '${stayDuration.inHours}h ${stayDuration.inMinutes % 60}m' : '-',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('알림 히스토리', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('앱을 켜둔 동안 실시간으로 감지된 등원/하원 알림이에요',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        if (history.isEmpty)
          SectionCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('아직 감지된 알림이 없어요', style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          )
        else
          SectionCard(
            child: Column(
              children: [
                for (final event in history)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: event.type == 'checkin'
                              ? AppColors.lightGreenBg
                              : const Color(0xFFE3ECF9),
                          child: Icon(
                            event.type == 'checkin' ? Icons.login_rounded : Icons.logout_rounded,
                            size: 16,
                            color: event.type == 'checkin' ? AppColors.alertGreen : const Color(0xFF4A7FD6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DateFormat('오늘 HH:mm').format(event.time),
                                  style: Theme.of(context).textTheme.bodySmall),
                              Text(event.message),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Text('날짜별 기록', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final day in const [
          (2025, 7, 10, '목', '09:05 → 16:30', '7h 25m', true),
          (2025, 7, 9, '수', '09:12 → 16:25', '7h 13m', false),
          (2025, 7, 8, '화', '08:58 → 16:40', '7h 42m', false),
          (2025, 6, 8, '일', '09:20 → 16:15', '6h 55m', true),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DayRecordCard(
              year: day.$1,
              month: day.$2,
              day: day.$3,
              weekday: day.$4,
              timeRange: day.$5,
              duration: day.$6,
              measured: day.$7,
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _AttendanceStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _AttendanceStat({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 3),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ],
    );
  }
}

/// 날짜별 기록 카드 - 왼쪽 미니 달력 아이콘(요일 + 일) + 우측 상단 측정완료 뱃지
class _DayRecordCard extends StatelessWidget {
  final int year;
  final int month;
  final int day;
  final String weekday;
  final String timeRange;
  final String duration;
  final bool measured;

  const _DayRecordCard({
    required this.year,
    required this.month,
    required this.day,
    required this.weekday,
    required this.timeRange,
    required this.duration,
    required this.measured,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SectionCard(
          child: Row(
            children: [
              // 미니 달력 아이콘: 상단 빨간 띠 + 요일, 아래 큰 날짜 숫자
              Container(
                width: 40,
                height: 40,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      color: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(weekday,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: Center(
                        child: Text('$day',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$year년 $month월 $day일 ($weekday)',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('$timeRange   $duration', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
        if (measured)
          Positioned(
            top: 10,
            right: 36,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.lightGreenBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('측정 완료',
                  style: TextStyle(fontSize: 10, color: AppColors.darkGreen, fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }
}
