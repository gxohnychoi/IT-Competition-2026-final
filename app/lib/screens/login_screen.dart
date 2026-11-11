import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/web_notification.dart';
import '../services/firebase_service.dart';

class LoginScreen extends StatefulWidget {
  /// 로그인/가입 성공 후 역할('parent' | 'teacher')을 넘겨줌 — 라우터가 이걸로 화면 분기.
  final void Function(String role) onLoggedIn;
  const LoginScreen({super.key, required this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _classNameCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;
  String _role = 'parent'; // 'parent' | 'teacher' — 회원가입 시에만 선택

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isSignUp) {
        await FirebaseService.instance.signUp(_emailCtrl.text.trim(), _passwordCtrl.text);
        await FirebaseService.instance.setUserRole(_role);
        await FirebaseService.instance.registerForPushNotifications();
        await requestNotificationPermission(); // 브라우저 기본 API로 직접 한 번 더 요청 (iOS 대응)

        if (_role == 'teacher') {
          final className = _classNameCtrl.text.trim().isEmpty ? '우리반' : _classNameCtrl.text.trim();
          final code = await FirebaseService.instance.createClass(className);
          if (mounted) await _showClassCodeDialog(code);
        }
        widget.onLoggedIn(_role);
      } else {
        await FirebaseService.instance.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
        await FirebaseService.instance.registerForPushNotifications();
        await requestNotificationPermission(); // 브라우저 기본 API로 직접 한 번 더 요청 (iOS 대응)
        final role = await FirebaseService.instance.fetchUserRole();
        widget.onLoggedIn(role);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showClassCodeDialog(String code) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('반 코드가 발급됐어요'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('학부모님들께 아래 코드를 공유해주세요.\n앱 설정 화면에서 이 코드로 아이를 반에 연결할 수 있어요.'),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.lightGreenBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 6,
                    color: AppColors.darkGreen,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isSignUp ? '회원가입' : '로그인')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isSignUp) ...[
              const Text('가입 유형', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _RoleChip(
                      label: '👨‍👩‍👧 부모님',
                      selected: _role == 'parent',
                      onTap: () => setState(() => _role = 'parent'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RoleChip(
                      label: '🏫 선생님',
                      selected: _role == 'teacher',
                      onTap: () => setState(() => _role = 'teacher'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_role == 'teacher')
                TextField(
                  controller: _classNameCtrl,
                  decoration: const InputDecoration(labelText: '반 이름 (예: 새싹반)', border: OutlineInputBorder()),
                ),
              if (_role == 'teacher') const SizedBox(height: 12),
            ],
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '이메일', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호', border: OutlineInputBorder()),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isSignUp ? '가입하기' : '로그인'),
            ),
            TextButton(
              onPressed: () => setState(() => _isSignUp = !_isSignUp),
              child: Text(_isSignUp ? '이미 계정이 있어요' : '계정이 없어요 · 회원가입'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RoleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
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
