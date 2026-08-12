import '../models/models.dart';

/// 로그인 기능이 아직 없어서, 시작 화면에서 입력한 아이 프로필을
/// 앱이 켜져있는 동안(세션 동안) 메모리에만 기억해두는 임시 저장소.
/// 나중에 로그인 붙이면 여기 대신 Firestore(FirebaseService)로 완전히
/// 옮기면 됨 — 지금은 그 전 단계용 임시 다리 역할.
class LocalChildStore {
  LocalChildStore._internal();
  static final instance = LocalChildStore._internal();

  ChildProfile? child;

  bool get hasProfile => child != null;
}
