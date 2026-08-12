import '../models/models.dart';
import 'firebase_service.dart';
import 'realtime_measurement_service.dart';

/// ESP32가 Realtime Database(records/{RFID}/{날짜})에 쓴 실측값을,
/// 우리 앱의 성장분석(백분위/BMI/코멘트)이 읽는 Firestore growthRecords로
/// 옮겨주는 다리 역할.
///
/// 왜 필요하냐면: 백분위·BMI·성장코멘트 계산 로직은 전부 Firestore의
/// growthRecords를 기준으로 동작하는데, 하드웨어 실측값은 팀원의 다른
/// Firebase 프로젝트(Realtime Database)에 있어서 자동으로 안 이어짐.
/// 그래서 화면 열릴 때마다 이 동기화를 한 번 돌려서 최신 실측값을
/// Firestore에도 반영해줌 — 이후로는 기존 백분위 계산 로직이 그대로 먹힘.
class GrowthSyncService {
  GrowthSyncService._();
  static final instance = GrowthSyncService._();

  /// 아이의 RFID로 하드웨어 기록을 전부 가져와서:
  ///  1) height_cm/weight_kg가 있는 날짜들을 Firestore growthRecords에 upsert
  ///  2) check_in_time/check_out_time이 있으면 등원/하원 이벤트도 함께 기록
  ///     (Cloud Function이 이 이벤트를 보고 등원/하원 알림을 보냄)
  ///  3) ⚠️ RTDB에서 이미 지워진 날짜가 Firestore엔 예전 값으로 남아있으면
  ///     같이 지워줌 — 지금까지는 이 부분이 없어서 "RTDB엔 없는데 앱엔
  ///     계속 보이는" 문제가 있었음 (한쪽 방향으로만 복사되던 구조).
  Future<void> syncFromHardware(ChildProfile child) async {
    final rfid = child.rfidCardId;
    if (rfid == null || rfid.isEmpty) return;

    try {
      // RTDB 조회 + 기존 Firestore 기록 조회를 동시에 (순서대로 기다리지 않음)
      final results = await Future.wait([
        RealtimeMeasurementService.instance.fetchAllRecords(rfid),
        FirebaseService.instance.fetchGrowthRecords(child.id),
      ]);
      final records = results[0] as Map<String, Map<String, dynamic>>;
      final existing = results[1] as List<GrowthRecord>;

      final validRecordIds = <String>{};
      final writeFutures = <Future<void>>[];

      for (final entry in records.entries) {
        final dateKey = entry.key; // "YYYY-MM-DD"
        final fields = entry.value;

        final heightCm = _asDouble(fields['height_cm']);
        final weightKg = _asDouble(fields['weight_kg']);
        if (heightCm != null && weightKg != null && heightCm > 0 && weightKg > 0) {
          final date = DateTime.tryParse(dateKey);
          if (date != null) {
            final recordId = dateKey.replaceAll('-', ''); // 같은 날짜는 항상 같은 문서 ID → 자동 덮어쓰기
            validRecordIds.add(recordId);
            final record = GrowthRecord(id: recordId, date: date, heightCm: heightCm, weightKg: weightKg);
            writeFutures.add(FirebaseService.instance.addGrowthRecord(child.id, record));
          }
        }

        final checkInTime = _parseDateTime(fields['check_in_time'] as String?);
        if (checkInTime != null) {
          writeFutures.add(FirebaseService.instance.recordAttendanceEvent(
            childId: child.id,
            dateKey: dateKey,
            type: 'checkin',
            time: checkInTime,
          ));
        }

        final checkOutTime = _parseDateTime(fields['check_out_time'] as String?);
        if (checkOutTime != null) {
          writeFutures.add(FirebaseService.instance.recordAttendanceEvent(
            childId: child.id,
            dateKey: dateKey,
            type: 'checkout',
            time: checkOutTime,
          ));
        }
      }

      // ── 정리(reconcile): RTDB엔 더 이상 없는 하드웨어 동기화 레코드는 삭제
      //    (id가 "YYYYMMDD" 8자리 숫자인 것만 — 사람이 직접 입력한 값은 안 건드림)
      for (final r in existing) {
        final looksLikeHardwareSynced = RegExp(r'^\d{8}$').hasMatch(r.id);
        if (looksLikeHardwareSynced && !validRecordIds.contains(r.id)) {
          writeFutures.add(FirebaseService.instance.deleteGrowthRecord(child.id, r.id));
        }
      }

      // 모든 쓰기 작업을 동시에 실행 (순서대로 하나씩 기다리지 않음 → 훨씬 빠름)
      await Future.wait(writeFutures);
    } catch (_) {
      // 하드웨어 쪽 네트워크 문제 등으로 동기화 실패해도 앱 사용엔 지장 없게 조용히 무시
    }
  }

  DateTime? _parseDateTime(String? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
