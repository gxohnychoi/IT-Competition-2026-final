import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_theme.dart';
import '../core/web_notification.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onLoggedOut;
  const SettingsScreen({super.key, required this.onLoggedOut});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<ChildProfile> _children = [];
  bool _checkInAlert = true;
  bool _checkOutAlert = true;
  bool _loading = true;
  String _role = 'parent';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final children = await FirebaseService.instance.fetchChildren();
    final role = await FirebaseService.instance.fetchUserRole();
    final prefs = await FirebaseService.instance.fetchNotificationPreferences();
    if (!mounted) return;
    setState(() {
      _children = children;
      _role = role;
      _checkInAlert = prefs.checkIn;
      _checkOutAlert = prefs.checkOut;
      _loading = false;
    });
  }

  Future<void> _saveNotificationPrefs() async {
    await FirebaseService.instance.saveNotificationPreferences(
      checkIn: _checkInAlert,
      checkOut: _checkOutAlert,
    );
  }

  Future<void> _openAddChildDialog() async {
    final nameCtrl = TextEditingController();
    DateTime? birthDate;
    String? gender;
    String? errorText;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('자녀 추가하기'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '이름 *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().subtract(const Duration(days: 365)),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialogState(() => birthDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: '생년월일 *', border: OutlineInputBorder()),
                    child: Text(
                      birthDate == null ? '날짜 선택' : '${birthDate!.year}.${birthDate!.month}.${birthDate!.day}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('성별 *', style: TextStyle(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('남자아이'),
                        value: '남자아이',
                        groupValue: gender,
                        onChanged: (v) => setDialogState(() => gender = v),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('여자아이'),
                        value: '여자아이',
                        groupValue: gender,
                        onChanged: (v) => setDialogState(() => gender = v),
                      ),
                    ),
                  ],
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 4),
                  Text(errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || birthDate == null || gender == null) {
                  setDialogState(() => errorText = '이름, 생년월일, 성별은 필수 입력이에요.');
                  return;
                }
                final newChild = ChildProfile(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text.trim(),
                  birthDate: birthDate!,
                  gender: gender!,
                );
                await FirebaseService.instance.addChild(newChild);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await _load();
              },
              child: const Text('추가하기'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openJoinClassDialog() async {
    if (_children.isEmpty) return;
    final codeCtrl = TextEditingController();
    String? resultMessage;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('반 코드 연결'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('선생님께 받은 6자리 반 코드를 입력해주세요.'),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: '반 코드', border: OutlineInputBorder()),
              ),
              if (resultMessage != null) ...[
                const SizedBox(height: 4),
                Text(resultMessage!, style: const TextStyle(color: AppColors.primaryGreen)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('닫기')),
            ElevatedButton(
              onPressed: () async {
                final ok = await FirebaseService.instance
                    .joinClassAsChild(codeCtrl.text.trim(), _children.first.id);
                setDialogState(() => resultMessage = ok ? '연결됐어요! 🎉' : '유효하지 않은 코드예요.');
              },
              child: const Text('연결하기'),
            ),
          ],
        ),
      ),
    );
  }

  /// 로그아웃 — 이제 실제 Firebase Auth 로그아웃.
  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('로그아웃 할까요?'),
        content: const Text('다시 로그인하면 등록된 아이 정보 그대로 이용할 수 있어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('로그아웃', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseService.instance.signOut();
      widget.onLoggedOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final child = _children.isNotEmpty ? _children.first : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('설정 ⚙️', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Text('자녀 프로필', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SectionCard(
          child: Column(
            children: [
              for (final c in _children)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppColors.lightGreenBg,
                        child: Text('🐣', style: TextStyle(fontSize: 24, height: 32 / 24)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('생후 ${c.ageInMonths}개월 · ${c.gender}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              TextButton.icon(
                onPressed: _openAddChildDialog,
                icon: const Icon(Icons.add),
                label: const Text('자녀 추가하기'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('반(어린이집/유치원) 연결', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SectionCard(
          child: _SettingsRow(
            icon: Icons.school_rounded,
            iconBg: AppColors.lightGreenBg,
            iconColor: AppColors.primaryGreen,
            title: '반 코드 연결',
            subtitle: '선생님께 받은 코드로 아이를 반에 연결해요',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            onTap: _openJoinClassDialog,
          ),
        ),
        const SizedBox(height: 16),

        // ── 알림 권한 (특히 iOS에서 처음에 놓쳤을 때 다시 요청용) ──
        SectionCard(
          child: _SettingsRow(
            icon: Icons.notifications_active_rounded,
            iconBg: AppColors.lightGreenBg,
            iconColor: AppColors.primaryGreen,
            title: '알림 켜기',
            subtitle: '등원/하원 알림이 안 뜨면 여기를 눌러 권한을 다시 허용해주세요',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            onTap: () async {
              final granted = await requestNotificationPermission();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(granted ? '알림이 켜졌어요 🔔' : '알림 권한이 허용되지 않았어요')),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // ── RFID 카드 ──
        Text('RFID 카드', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SectionCard(
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.credit_card_rounded,
                iconBg: const Color(0xFFE3ECF9),
                iconColor: const Color(0xFF4A7FD6),
                title: '등록된 카드',
                trailing: Text('카드 #${child?.rfidCardId ?? '-'}',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              const Divider(height: 20),
              _SettingsRow(
                icon: Icons.sync_rounded,
                iconBg: const Color(0xFFE3ECF9),
                iconColor: const Color(0xFF4A7FD6),
                title: '카드 재등록 / 교체',
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () => context.push('/device-live'), // 기기 실시간 상태 확인 화면으로 연결
              ),
              const Divider(height: 20),
              _SettingsRow(
                icon: Icons.location_on_rounded,
                iconBg: const Color(0xFFFCE4EC),
                iconColor: const Color(0xFFD6558B),
                title: '연동된 기관',
                trailing: const Text('해피맘 어린이집', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 알림 설정 (학부모 계정만 표시) ──
        if (_role == 'parent') ...[
          Text('알림 설정', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SectionCard(
            child: Column(
              children: [
                _SettingsToggleRow(
                  icon: Icons.login_rounded,
                  iconBg: AppColors.lightGreenBg,
                  iconColor: AppColors.primaryGreen,
                  title: '등원 알림',
                  value: _checkInAlert,
                  onChanged: (v) {
                    setState(() => _checkInAlert = v);
                    _saveNotificationPrefs();
                  },
                ),
                const Divider(height: 20),
                _SettingsToggleRow(
                  icon: Icons.logout_rounded,
                  iconBg: const Color(0xFFE3ECF9),
                  iconColor: const Color(0xFF4A7FD6),
                  title: '하원 알림',
                  value: _checkOutAlert,
                  onChanged: (v) {
                    setState(() => _checkOutAlert = v);
                    _saveNotificationPrefs();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── 계정 ──
        Text('계정', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SectionCard(
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.person_rounded,
                iconBg: AppColors.sectionAltBg,
                iconColor: AppColors.textPrimary,
                title: '계정 정보',
                trailing: Text(FirebaseService.instance.currentUser?.email ?? '-',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              const Divider(height: 20),
              _SettingsRow(
                icon: Icons.logout_rounded,
                iconBg: const Color(0xFFFBE4E1),
                iconColor: AppColors.danger,
                title: '로그아웃',
                titleColor: AppColors.danger,
                onTap: _confirmLogout,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text('쑥쑥이 v1.0.0 · 문의: help@ssugssugi.kr',
              style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

/// 캡처 디자인 기준 — 원형 컬러 배경 아이콘 + 제목 + 우측 값/화살표
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            CircleAvatar(radius: 18, backgroundColor: iconBg, child: Icon(icon, size: 18, color: iconColor)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: titleColor)),
                  if (subtitle != null)
                    Text(subtitle!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 18, backgroundColor: iconBg, child: Icon(icon, size: 18, color: iconColor)),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
        Switch(value: value, activeColor: AppColors.primaryGreen, onChanged: onChanged),
      ],
    );
  }
}
