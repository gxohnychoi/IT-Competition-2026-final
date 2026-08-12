import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'services/growth_comment_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ko_KR');

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // firebase_options.dart가 아직 flutterfire configure로 생성되지 않은 경우.
    // FirebaseService가 currentUser == null일 때 더미 데이터로 폴백하므로
    // 앱 자체는 정상적으로 UI 확인이 가능합니다.
    debugPrint('⚠️ Firebase 초기화 실패 (설정 전): $e');
  }

  // Cloud Function 배포 후 아래 주석 해제하면 AI(Claude) 코멘트로 전환됨.
  // 배포 안 해도(주석 처리 상태) 로컬 룰 기반 코멘트로 정상 작동함.
  // GrowthCommentService.instance.aiEndpoint =
  //     'https://asia-northeast3-it2026-7e56c.cloudfunctions.net/growthComment';

  runApp(const SsukSsugiApp());
}
