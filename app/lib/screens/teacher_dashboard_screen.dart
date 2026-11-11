import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import 'teacher_child_detail_screen.dart';
import '../widgets/common_widgets.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final VoidCallback onLoggedOut;
  const TeacherDashboardScreen({super.key, required this.onLoggedOut});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  String? _classCode;
  List<RosterEntry> _roster = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final code = await FirebaseService.instance.fetchMyClassCode();
    final roster = code == null ? <RosterEntry>[] : await FirebaseService.instance.fetchClassRoster(code);

    if (!mounted) return;
    setState(() {
      _classCode = code;
      _roster = roster;
      _loading = false;
    });
  }

  void _showClassCode() {
    if (_classCode == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('우리 반 코드'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(color: AppColors.lightGreenBg, borderRadius: BorderRadius.circular(12)),
              child: Text(
                _classCode!,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 6, color: AppColors.darkGreen),
              ),
            ),
            const SizedBox(height: 10),
            const Text('학부모님께 이 코드를 공유해 아이를 반에 연결해주세요.', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkedInCount = _roster.where((r) => r.attendance.checkInTime != null).length;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.primaryGreen, borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('선생님 대시보드 🏫',
                                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                              IconButton(
                                onPressed: () async {
                                  await FirebaseService.instance.signOut();
                                  widget.onLoggedOut();
                                },
                                icon: const Icon(Icons.logout, color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(DateFormat('yyyy년 M월 d일 EEEE', 'ko_KR').format(DateTime.now()),
                              style: TextStyle(color: Colors.white.withOpacity(0.9))),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: _showClassCode,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.qr_code_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _classCode == null ? '반 코드 없음' : '반 코드: $_classCode',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(label: '전체 원아', value: '${_roster.length}명', color: AppColors.lightGreenBg),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(label: '오늘 등원', value: '$checkedInCount명', color: AppColors.cardWeightBg),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('원아 목록', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    if (_roster.isEmpty)
                      SectionCard(
                        child: Column(
                          children: [
                            const Icon(Icons.child_care_rounded, size: 40, color: AppColors.textSecondary),
                            const SizedBox(height: 8),
                            Text(
                              _classCode == null
                                  ? '반 코드를 아직 발급받지 못했어요.'
                                  : '아직 이 반에 연결된 원아가 없어요.\n학부모님께 반 코드($_classCode)를 공유해주세요.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (final entry in _roster)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _RosterCard(
                                entry: entry,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TeacherChildDetailScreen(
                                      uid: entry.uid,
                                      child: entry.child,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }
}

/// 원아 카드 — 이름 + 등원/하원/키/몸무게를 한 줄에 다 보여줌
class _RosterCard extends StatelessWidget {
  final RosterEntry entry;
  final VoidCallback onTap;

  const _RosterCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final checkedIn = entry.attendance.checkInTime != null;
    final checkedOut = entry.attendance.checkOutTime != null;
    final record = entry.latestRecord;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.lightGreenBg,
                  child: Text('🐣', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.child.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text('생후 ${entry.child.ageInMonths}개월 · ${entry.child.gender}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _StatChip(
                  label: '키',
                  value: record != null ? '${record.heightCm}cm' : '-',
                  bg: AppColors.sectionAltBg,
                  valueColor: AppColors.textPrimary,
                ),
                const SizedBox(width: 6),
                _StatChip(
                  label: '몸무게',
                  value: record != null ? '${record.weightKg}kg' : '-',
                  bg: AppColors.sectionAltBg,
                  valueColor: AppColors.textPrimary,
                ),
                const SizedBox(width: 6),
                _StatChip(
                  label: '등원',
                  value: checkedIn ? DateFormat('HH:mm').format(entry.attendance.checkInTime!) : '-',
                  bg: AppColors.sectionAltBg,
                  valueColor: AppColors.textPrimary,
                ),
                const SizedBox(width: 6),
                _StatChip(
                  label: '하원',
                  value: checkedOut ? DateFormat('HH:mm').format(entry.attendance.checkOutTime!) : '-',
                  bg: AppColors.sectionAltBg,
                  valueColor: AppColors.textPrimary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color bg;
  final Color valueColor;

  const _StatChip({required this.label, required this.value, required this.bg, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: valueColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
