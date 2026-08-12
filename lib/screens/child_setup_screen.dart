import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';

/// 로그인 다음, 홈 화면 진입 전에 뜨는 아이 프로필 입력 화면.
/// (로그인은 했는데 아직 등록된 아이가 없는 경우에만 뜸 — SplashScreen이 판단)
/// 이름 · 생년월일 · 성별 · 고유 RFID를 다 입력해야 다음으로 넘어감 (필수).
/// 여기서 입력한 값은 로그인된 계정의 Firestore에 실제로 저장됨.
class ChildSetupScreen extends StatefulWidget {
  final VoidCallback onDone;
  const ChildSetupScreen({super.key, required this.onDone});

  @override
  State<ChildSetupScreen> createState() => _ChildSetupScreenState();
}

class _ChildSetupScreenState extends State<ChildSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _rfidCtrl = TextEditingController();
  DateTime? _birthDate;
  String? _gender; // '남자아이' | '여자아이'
  String? _errorText;
  bool _saving = false;

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: '생년월일 선택',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _birthDate == null ||
        _gender == null ||
        _rfidCtrl.text.trim().isEmpty) {
      setState(() => _errorText = '이름, 생년월일, 성별, 고유 RFID를 모두 입력해주세요.');
      return;
    }

    setState(() => _saving = true);

    final child = ChildProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      birthDate: _birthDate!,
      gender: _gender!,
      rfidCardId: _rfidCtrl.text.trim(),
    );

    await FirebaseService.instance.addChild(child); // 로그인 계정의 Firestore에 실제 저장

    if (!mounted) return;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text('🌱', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 16),
              Text('아기 이름을 입력해주세요',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 22)),
              const SizedBox(height: 6),
              Text('아이의 성장 기록을 시작하기 위해 기본 정보가 필요해요.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 28),

              const Text('이름 *', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  hintText: '예: 김서준',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              const Text('생년월일 *', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickBirthDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  child: Text(
                    _birthDate == null
                        ? '날짜 선택'
                        : '${_birthDate!.year}년 ${_birthDate!.month}월 ${_birthDate!.day}일',
                    style: TextStyle(
                      color: _birthDate == null ? AppColors.textSecondary : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text('성별 *', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _GenderChip(
                      label: '남자아이',
                      selected: _gender == '남자아이',
                      onTap: () => setState(() => _gender = '남자아이'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GenderChip(
                      label: '여자아이',
                      selected: _gender == '여자아이',
                      onTap: () => setState(() => _gender = '여자아이'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text('고유 RFID *', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('쑥쑥이 기기에 등록된 RFID 카드 번호를 입력해주세요.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              TextField(
                controller: _rfidCtrl,
                decoration: InputDecoration(
                  hintText: '예: 37250202',
                  prefixIcon: const Icon(Icons.nfc_rounded, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(_errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('시작하기 🚀'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GenderChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primaryGreen : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
