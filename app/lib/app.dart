import 'package:flutter/material.dart';
import 'core/app_router.dart';
import 'core/app_theme.dart';
import 'core/web_notification.dart';
import 'services/attendance_watch_service.dart';

class SsukSsugiApp extends StatefulWidget {
  const SsukSsugiApp({super.key});

  @override
  State<SsukSsugiApp> createState() => _SsukSsugiAppState();
}

class _SsukSsugiAppState extends State<SsukSsugiApp> {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    // 앱이 켜져있는 상태(포그라운드)에서 RTDB 등원/하원이 새로 감지되면:
    //  1) 진짜 브라우저(OS) 알림 시도 (iOS는 홈화면 추가+권한 허용 안 되어있으면 실패할 수 있음)
    //  2) 그거랑 상관없이 앱 안에서도 항상 확실하게 토스트(스낵바)로 보여줌
    //     — iOS 네이티브 알림이 막혀도 최소한 이건 100% 뜸
    AttendanceWatchService.instance.events.listen((event) {
      final isCheckIn = event.type == 'checkin';
      final title = isCheckIn ? '${event.childName} 등원 🏠' : '${event.childName} 하원 👋';

      showBrowserNotification(title, event.message); // 1) 네이티브 알림 시도

      _scaffoldMessengerKey.currentState?.showSnackBar( // 2) 인앱 토스트 (항상 뜸)
        SnackBar(
          content: Row(
            children: [
              Icon(isCheckIn ? Icons.login_rounded : Icons.logout_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(event.message)),
            ],
          ),
          backgroundColor: isCheckIn ? AppColors.primaryGreen : const Color(0xFF4A7FD6),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '쑥쑥이',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scaffoldMessengerKey: _scaffoldMessengerKey,
      routerConfig: buildRouter(),
    );
  }
}
