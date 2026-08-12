import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// 로그인 기능이 아직 없어서, 처음 입력한 아이 프로필을 기기(웹이면
/// 브라우저의 localStorage)에 저장해뒀다가, 다음에 앱을 다시 열었을 때
/// "처음 쓰는 사람인지 아닌지"를 구분하는 용도로 씀.
/// 새로고침해도, 브라우저를 완전히 껐다 켜도 유지됨.
class ChildProfileStorage {
  ChildProfileStorage._();

  static const _key = 'ssuk_ssugi_child_profile';

  static Future<void> save(ChildProfile child) async {
    final prefs = await SharedPreferences.getInstance();
    final data = child.toMap()..['id'] = child.id;
    await prefs.setString(_key, jsonEncode(data));
  }

  /// 저장된 프로필이 있으면 불러오고, 없으면(처음 쓰는 사람이면) null.
  static Future<ChildProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return ChildProfile.fromMap(map['id'] as String? ?? 'local_child', map);
  }

  /// 설정 화면에서 "정보 초기화"할 때 씀 — 저장된 프로필 완전 삭제.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
