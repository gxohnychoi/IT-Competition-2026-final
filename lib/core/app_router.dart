import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/alerts_screen.dart';
import '../screens/child_setup_screen.dart';
import '../screens/device_live_screen.dart';
import '../screens/growth_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/teacher_dashboard_screen.dart';
import '../services/firebase_service.dart';
import '../widgets/main_scaffold.dart';

final _tabPaths = ['/home', '/growth', '/alerts', '/settings'];

GoRouter buildRouter() {
  return GoRouter(
    // 흐름: 로고(splash, 로그인 상태 확인) →
    //   로그인 안 됐으면 → 로그인/회원가입
    //   로그인 됐고 선생님 → 선생님 대시보드
    //   로그인 됐고 학부모인데 등록된 아이 없음 → 아이 정보 입력
    //   로그인 됐고 아이도 있음 → 바로 홈
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          onLoggedIn: (role) async {
            if (role == 'teacher') {
              context.go('/teacher');
              return;
            }
            final hasChild = await FirebaseService.instance.hasAnyChild();
            if (context.mounted) context.go(hasChild ? '/home' : '/child-setup');
          },
        ),
      ),
      GoRoute(
        path: '/child-setup',
        builder: (context, state) => ChildSetupScreen(
          onDone: () => context.go('/home'),
        ),
      ),
      GoRoute(
        path: '/teacher',
        builder: (context, state) => TeacherDashboardScreen(
          onLoggedOut: () => context.go('/splash'),
        ),
      ),
      GoRoute(
        path: '/device-live',
        builder: (context, state) => const DeviceLiveScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final index = _tabPaths.indexWhere((p) => state.matchedLocation.startsWith(p));
          return MainScaffold(
            currentIndex: index < 0 ? 0 : index,
            onTabSelected: (i) => context.go(_tabPaths[i]),
            child: child,
          );
        },
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/growth', builder: (context, state) => const GrowthScreen()),
          GoRoute(path: '/alerts', builder: (context, state) => const AlertsScreen()),
          GoRoute(
            path: '/settings',
            builder: (context, state) => SettingsScreen(
              onLoggedOut: () => context.go('/splash'),
            ),
          ),
        ],
      ),
    ],
  );
}
