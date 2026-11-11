import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/child_profile_storage.dart';
import '../services/local_child_store.dart';

/// 스플래시 다음에 뜨는 선택 화면.
///  - "처음이에요" → 이름/생년월일/성별/RFID 입력 화면으로
///  - "이미 등록했어요" → 이 기기에 저장된 정보를 불러와서 바로 홈으로
///    (저장된 게 없으면 안내 후 그대로 대기)
class WelcomeChoiceScreen extends StatefulWidget {
  final VoidCallback onFirstTime;
  final VoidCallback onReturningUser;
  const WelcomeChoiceScreen({super.key, required this.onFirstTime, required this.onReturningUser});

  @override
  State<WelcomeChoiceScreen> createState() => _WelcomeChoiceScreenState();
}

class _WelcomeChoiceScreenState extends State<WelcomeChoiceScreen> {
  bool _checking = false;

  Future<void> _handleReturningUser() async {
    setState(() => _checking = true);
    final saved = await ChildProfileStorage.load();
    if (!mounted) return;
    setState(() => _checking = false);

    if (saved != null) {
      LocalChildStore.instance.child = saved;
      widget.onReturningUser();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 기기엔 저장된 정보가 없어요. "처음이에요"를 선택해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const Text('🌱', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text('쑥쑥이를 처음 써보시나요?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 22)),
              const SizedBox(height: 8),
              Text(
                '이용 유형을 선택해주세요.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onFirstTime,
                  child: const Text('네, 처음이에요 🌱'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _checking ? null : _handleReturningUser,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _checking
                      ? const SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('아니요, 이미 등록했어요'),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
