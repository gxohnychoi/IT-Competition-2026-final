import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class OnboardingScreen extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onLogin;

  const OnboardingScreen({super.key, required this.onStart, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primaryGreen,
                child: Icon(Icons.eco_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              Text('쑥쑥이', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 28)),
              const SizedBox(height: 8),
              Text(
                '우리 아이의 소중한 성장을\n기록하고 함께해요 🌱',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: onStart, child: const Text('시작하기 🚀')),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onLogin,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('이미 계정이 있어요'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '가입 시 서비스 이용약관 및 개인정보처리방침에 동의합니다',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
