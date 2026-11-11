import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// 하드웨어팀 ESP32가 쓰는 Realtime Database 읽기 서비스.
///
/// ⚠️ 우리 앱의 Firebase 프로젝트(it2026-7e56c)가 아니라 팀원의 다른
/// 프로젝트(it-competition-2026)에 있음. REST API로 직접 읽어옴 (보안
/// 규칙이 공개라 인증 없이 읽기 가능).
///
/// 실제 구조 (ESP32 펌웨어 기준):
///   records/{RFID_UID}/{YYYY-MM-DD}
///     - uid, height_cm, weight_kg
///     - check_in_time, check_in_epoch
///     - check_out_time, check_out_epoch  (하원 시에만 추가됨)
///     - status: "checked_in" | "checked_out"
class RealtimeMeasurementService {
  RealtimeMeasurementService._internal();
  static final instance = RealtimeMeasurementService._internal();

  static const _baseUrl = 'https://it-competition-2026-default-rtdb.asia-southeast1.firebasedatabase.app';

  Stream<T> _poll<T>(Future<T> Function() fetch) async* {
    while (true) {
      try {
        yield await fetch();
      } catch (_) {
        // 네트워크 순간 오류는 무시하고 다음 폴링에서 재시도
      }
      await Future.delayed(const Duration(seconds: 1)); // 3초 → 1초로 단축 (체감 실시간)
    }
  }

  /// 캐시(브라우저/중간 프록시)가 예전 응답을 그대로 돌려주는 걸 막기 위해
  /// 매번 다른 쿼리파라미터를 붙이고, no-cache 헤더도 같이 보냄.
  Future<http.Response> _getFresh(String path) {
    final url = Uri.parse('$_baseUrl$path').replace(queryParameters: {
      ...Uri.parse('$_baseUrl$path').queryParameters,
      '_ts': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    return http.get(url, headers: {'Cache-Control': 'no-cache'});
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// records 아래에 등록된 모든 RFID UID 목록.
  Stream<List<String>> streamKnownUids() {
    return _poll(() async {
      final res = await _getFresh('/records.json?shallow=true');
      if (res.statusCode != 200 || res.body == 'null') return <String>[];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data.keys.toList();
    });
  }

  /// 특정 RFID UID의 전체 날짜별 기록 (동기화·기기확인 화면용).
  /// key = "YYYY-MM-DD", value = {height_cm, weight_kg, check_in_time, ...}
  /// RTDB에서 지워진 상태면 빈 Map을 반환 → 화면에서도 "데이터 없음"으로 확실히 반영됨.
  Future<Map<String, Map<String, dynamic>>> fetchAllRecords(String rfidUid) async {
    final res = await _getFresh('/records/$rfidUid.json');
    if (res.statusCode != 200 || res.body == 'null') return {};
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
  }

  /// (기기 실시간 확인 화면용) 날짜별 기록 스트림 — 최신 날짜가 앞에 오도록 정렬.
  Stream<List<MapEntry<String, Map<String, dynamic>>>> streamMeasurements(String rfidUid) {
    return _poll(() async {
      final all = await fetchAllRecords(rfidUid);
      final entries = all.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
      return entries;
    });
  }

  /// 오늘 등하원 상태를 실시간으로 확인 (펌웨어가 status 필드로 명확히
  /// 알려주기 때문에, 이전처럼 태그 횟수 홀짝으로 추측할 필요 없음).
  /// RTDB에서 오늘자 데이터가 삭제되면 즉시 "등원/하원 없음" 상태로 반영됨.
  Stream<TodayAttendanceInfo> streamTodayAttendance(String rfidUid) {
    return _poll(() async {
      final res = await _getFresh('/records/$rfidUid/${_todayKey()}.json');
      if (res.statusCode != 200 || res.body == 'null') {
        return TodayAttendanceInfo(checkInTime: null, checkOutTime: null);
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final checkIn = _parseTime(data['check_in_time'] as String?);
      final checkOut = _parseTime(data['check_out_time'] as String?);
      return TodayAttendanceInfo(checkInTime: checkIn, checkOutTime: checkOut);
    });
  }

  DateTime? _parseTime(String? raw) {
    if (raw == null) return null;
    // "YYYY-MM-DD HH:MM:SS" -> ISO 형식으로 바꿔서 파싱
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }

  String _timeString(DateTime t) {
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${t.year.toString().padLeft(4, '0')}-${p2(t.month)}-${p2(t.day)} '
        '${p2(t.hour)}:${p2(t.minute)}:${p2(t.second)}';
  }

  /// 하드웨어 태그 없이 앱에서 직접 "등원 처리" — 실제 ESP32가 쓰는 것과
  /// 완전히 같은 형식으로 기록해서, 우리가 만든 감지/알림 로직이 그대로 먹힘.
  Future<void> simulateCheckIn(String rfidUid, {required double heightCm, required double weightKg}) async {
    final now = DateTime.now();
    final dateKey = _todayKey();
    final payload = {
      'uid': rfidUid,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'check_in_time': _timeString(now),
      'check_in_epoch': now.millisecondsSinceEpoch ~/ 1000,
      'status': 'checked_in',
    };
    await http.put(
      Uri.parse('$_baseUrl/records/$rfidUid/$dateKey.json'),
      body: jsonEncode(payload),
    );
  }

  /// 앱에서 직접 "하원 처리" — 오늘 등원 기록에 하원 시각만 덧붙임
  /// (기존 키/몸무게 값은 그대로 유지).
  Future<void> simulateCheckOut(String rfidUid) async {
    final dateKey = _todayKey();
    final res = await _getFresh('/records/$rfidUid/$dateKey.json');
    if (res.statusCode != 200 || res.body == 'null') {
      throw Exception('오늘 등원 기록이 없어서 하원 처리를 할 수 없어요. 먼저 등원 처리를 해주세요.');
    }
    final existing = jsonDecode(res.body) as Map<String, dynamic>;
    final now = DateTime.now();
    existing['check_out_time'] = _timeString(now);
    existing['check_out_epoch'] = now.millisecondsSinceEpoch ~/ 1000;
    existing['status'] = 'checked_out';

    await http.put(
      Uri.parse('$_baseUrl/records/$rfidUid/$dateKey.json'),
      body: jsonEncode(existing),
    );
  }
}

/// 오늘 등하원 시각
class TodayAttendanceInfo {
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  TodayAttendanceInfo({required this.checkInTime, required this.checkOutTime});

  Duration? get stayDuration {
    if (checkInTime == null || checkOutTime == null) return null;
    return checkOutTime!.difference(checkInTime!);
  }
}
