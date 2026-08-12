import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_theme.dart';
import '../services/firebase_service.dart';

/// 앱 실행 직후 뜨는 로고 화면.
/// 로고 보여주는 동안 실제 로그인 상태를 확인해서:
///  - 로그인 안 되어있으면 → 로그인 화면
///  - 로그인 되어있고 선생님이면 → 선생님 대시보드
///  - 로그인 되어있고 학부모인데 등록된 아이가 없으면 → 아이 정보 입력
///  - 로그인 되어있고 아이도 있으면 → 바로 홈
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 1400)); // 로고 최소 노출 시간
    if (!mounted) return;

    final user = FirebaseService.instance.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }

    final role = await FirebaseService.instance.fetchUserRole();
    if (!mounted) return;

    if (role == 'teacher') {
      context.go('/teacher');
      return;
    }

    final hasChild = await FirebaseService.instance.hasAnyChild();
    if (!mounted) return;
    context.go(hasChild ? '/home' : '/child-setup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.eco_rounded, color: AppColors.primaryGreen, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              '쑥쑥이',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '우리 아이의 소중한 성장을 기록해요',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
