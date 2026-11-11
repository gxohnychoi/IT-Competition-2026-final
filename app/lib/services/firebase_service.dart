import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../core/dummy_data.dart';
import '../models/models.dart';
import 'local_child_store.dart';
import 'realtime_measurement_service.dart';

/// Firestore 구조 (제안)
/// users/{uid}/children/{childId}
/// users/{uid}/children/{childId}/growthRecords/{recordId}
/// users/{uid}/children/{childId}/attendance/{yyyy-mm-dd}
/// users/{uid}/children/{childId}/notifications/{notificationId}
/// pairing_codes/{6자리코드}   ← ESP32 기기 등록용 (15분간 유효)
class FirebaseService {
  FirebaseService._internal();
  static final FirebaseService instance = FirebaseService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── 인증 ──────────────────────────────────────────
  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUp(String email, String password) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  // ── 푸시 알림 (FCM) ─────────────────────────────
  /// 로그인 직후 호출 — 알림 권한 요청 + 이 기기의 FCM 토큰을
  /// Firestore(users/{uid}.fcmToken)에 저장해둠. 나중에 측정값이
  /// 새로 들어오면 Cloud Function이 이 토큰으로 푸시를 보냄.
  ///
  /// 웹에서 실제로 브라우저 알림을 받으려면 Firebase 콘솔 > 프로젝트 설정
  /// > Cloud Messaging 탭에서 "웹 푸시 인증서(VAPID 키)"를 발급받아
  /// vapidKey 파라미터에 넣어줘야 함 (지금은 비워둬도 앱은 정상 작동함,
  /// 실제 브라우저 알림만 안 뜸).
  Future<void> registerForPushNotifications({String? vapidKey}) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    try {
      await _messaging.requestPermission();
      final token = await _messaging.getToken(vapidKey: vapidKey);
      if (token != null) {
        await _db.collection('users').doc(uid).set({'fcmToken': token}, SetOptions(merge: true));
      }
    } catch (e) {
      // 알림 권한 거부, 웹 VAPID 키 미설정 등으로 실패해도 앱 사용엔 지장 없음.
    }
  }

  // ── 자녀 프로필 ────────────────────────────────────
  CollectionReference<Map<String, dynamic>> _childrenRef(String uid) =>
      _db.collection('users').doc(uid).collection('children');

  Future<List<ChildProfile>> fetchChildren() async {
    final uid = currentUser?.uid;
    if (uid == null) {
      // 로그인 전이라 Firestore에 못 넣지만, 시작 화면에서 입력받은
      // 프로필이 있으면 그걸 우선 사용 (없으면 더미 데이터로 폴백)
      return [LocalChildStore.instance.child ?? DummyData.child];
    }

    final snap = await _childrenRef(uid).get();
    if (snap.docs.isEmpty) return [DummyData.child];

    return snap.docs.map((d) => ChildProfile.fromMap(d.id, d.data())).toList();
  }

  /// 로그인 직후 "이 계정에 진짜로 등록된 아이가 있는지" 정확히 확인용.
  /// (fetchChildren은 없으면 더미로 폴백해서 화면 표시용으론 좋지만,
  /// "아이 등록 화면으로 보낼지 홈으로 보낼지" 판단에는 이걸 써야 함)
  Future<bool> hasAnyChild() async {
    final uid = currentUser?.uid;
    if (uid == null) return false;
    final snap = await _childrenRef(uid).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  Future<void> addChild(ChildProfile child) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    await _childrenRef(uid).doc(child.id).set(child.toMap());
  }

  // ── 성장 기록 ──────────────────────────────────────
  Future<List<GrowthRecord>> fetchGrowthRecords(String childId) async {
    final uid = currentUser?.uid;
    if (uid == null) return DummyData.growthRecords;

    final snap = await _childrenRef(uid)
        .doc(childId)
        .collection('growthRecords')
        .orderBy('date')
        .get();

    // 로그인된 실제 계정은 데이터가 없으면 빈 리스트를 그대로 반환.
    // (더미데이터로 자동 채워지지 않게 — 실제 측정값만 보여주고 싶을 때)
    return snap.docs.map((d) => GrowthRecord.fromMap(d.id, d.data())).toList();
  }

  Future<void> addGrowthRecord(String childId, GrowthRecord record) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    await _childrenRef(uid)
        .doc(childId)
        .collection('growthRecords')
        .doc(record.id)
        .set(record.toMap());
  }

  /// RTDB 쪽 원본 데이터가 삭제됐을 때, Firestore에 남아있는 예전 복사본을
  /// 같이 지우기 위한 메서드 (동기화가 "한쪽 방향"으로만 일어나던 문제 수정).
  Future<void> deleteGrowthRecord(String childId, String recordId) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    await _childrenRef(uid).doc(childId).collection('growthRecords').doc(recordId).delete();
  }

  /// 등원/하원 이벤트를 Firestore에 기록 — 문서가 "새로 생성"될 때만
  /// Cloud Function 트리거가 발동하도록, 문서 ID를 날짜+종류로 고정해서
  /// 같은 이벤트가 중복으로 알림 안 가게 함.
  Future<void> recordAttendanceEvent({
    required String childId,
    required String dateKey, // "YYYY-MM-DD"
    required String type, // 'checkin' | 'checkout'
    required DateTime time,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    final docId = '${dateKey}_$type';
    final ref = _childrenRef(uid).doc(childId).collection('attendanceEvents').doc(docId);
    final existing = await ref.get();
    if (existing.exists) return; // 이미 기록된 이벤트면 다시 안 씀 (중복 알림 방지)
    await ref.set({'type': type, 'time': time.toIso8601String()});
  }

  // ── 알림 히스토리 ──────────────────────────────────
  Future<List<NotificationItem>> fetchNotifications(String childId) async {
    final uid = currentUser?.uid;
    if (uid == null) return DummyData.notifications;
    // TODO: notifications 서브컬렉션 조회 구현
    return DummyData.notifications;
  }

  // ── 등하원(RFID) ───────────────────────────────────
  Future<AttendanceRecord> fetchTodayAttendance(String childId) async {
    final uid = currentUser?.uid;
    if (uid == null) return DummyData.attendanceToday;

    final todayKey = DateTime.now().toIso8601String().substring(0, 10); // "YYYY-MM-DD"
    final doc = await _childrenRef(uid).doc(childId).collection('attendance').doc(todayKey).get();
    if (!doc.exists) {
      // 오늘 기록 자체가 없으면 "데이터 없음" 상태로 — 더미값으로 채우지 않음
      return AttendanceRecord(id: todayKey, date: DateTime.now(), checkInTime: null, checkOutTime: null);
    }
    return AttendanceRecord.fromMap(doc.id, doc.data()!);
  }

  // ── ESP32 기기 등록 (페어링 코드) ───────────────────
  /// 6자리 숫자 코드를 발급해서 pairing_codes 컬렉션에 저장.
  /// ESP32 설정 웹페이지에서 보호자가 이 코드를 입력하면,
  /// ESP32가 이 문서를 조회해서 uid/childId를 얻어감.
  Future<String> issuePairingCode(String childId) async {
    final uid = currentUser?.uid;
    if (uid == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final code = (100000 + Random().nextInt(900000)).toString();
    await _db.collection('pairing_codes').doc(code).set({
      'uid': uid,
      'childId': childId,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 15))),
      'used': false,
    });
    return code;
  }

  /// 코드가 아직 유효한지(만료 전 + 미사용) 확인용 — 발급 화면에서 상태 표시할 때 사용 가능.
  Future<bool> isPairingCodeActive(String code) async {
    final doc = await _db.collection('pairing_codes').doc(code).get();
    if (!doc.exists) return false;
    final data = doc.data()!;
    final used = data['used'] as bool? ?? false;
    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
    if (used || expiresAt == null) return false;
    return DateTime.now().isBefore(expiresAt);
  }

  // ── 사용자 역할 (부모님 / 선생님) ────────────────────
  Future<void> setUserRole(String role) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({'role': role}, SetOptions(merge: true));
  }

  /// 역할이 아직 없으면(로그인만 하고 선택 안 한 옛 계정 등) 'parent'로 간주.
  Future<String> fetchUserRole() async {
    final uid = currentUser?.uid;
    if (uid == null) return 'parent';
    final doc = await _db.collection('users').doc(uid).get();
    return (doc.data()?['role'] as String?) ?? 'parent';
  }

  // ── 알림 설정 (등원/하원) ────────────────────────────
  Future<void> saveNotificationPreferences({required bool checkIn, required bool checkOut}) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'notifyCheckIn': checkIn,
      'notifyCheckOut': checkOut,
    }, SetOptions(merge: true));
  }

  /// 저장된 값이 없으면(처음 설정) 기본값 true.
  Future<({bool checkIn, bool checkOut})> fetchNotificationPreferences() async {
    final uid = currentUser?.uid;
    if (uid == null) return (checkIn: true, checkOut: true);
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    return (
      checkIn: (data?['notifyCheckIn'] as bool?) ?? true,
      checkOut: (data?['notifyCheckOut'] as bool?) ?? true,
    );
  }

  // ── 반(Class) 관리 — 선생님용 ─────────────────────
  /// 선생님이 회원가입할 때 자동으로 반 하나를 만들고 6자리 코드를 발급.
  /// 이 코드를 학부모에게 공유하면 학부모가 자녀를 이 반에 연결할 수 있음.
  Future<String> createClass(String className) async {
    final uid = currentUser?.uid;
    if (uid == null) throw StateError('로그인이 필요합니다.');

    final code = (100000 + Random().nextInt(900000)).toString();
    await _db.collection('classes').doc(code).set({
      'teacherUid': uid,
      'className': className,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  /// 현재 로그인한 선생님이 만든 반 코드를 다시 조회 (설정 화면 등에서 재확인용).
  Future<String?> fetchMyClassCode() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final snap = await _db.collection('classes').where('teacherUid', isEqualTo: uid).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  /// 학부모가 반 코드를 입력해서 자녀를 그 반에 연결.
  /// children_directory에 (uid, childId, classCode) 매핑을 저장 — 선생님이
  /// 이 컬렉션을 classCode로 조회해서 반 전체 원아 명단을 볼 수 있음.
  Future<bool> joinClassAsChild(String classCode, String childId) async {
    final uid = currentUser?.uid;
    if (uid == null) return false;

    final classDoc = await _db.collection('classes').doc(classCode).get();
    if (!classDoc.exists) return false;

    await _db.collection('children_directory').doc('${uid}_$childId').set({
      'uid': uid,
      'childId': childId,
      'classCode': classCode,
      'linkedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  /// 선생님 대시보드용 — 반에 속한 원아 전체 명단 + 오늘 등원 현황 + 최신 측정값을 가져옴.
  Future<List<RosterEntry>> fetchClassRoster(String classCode) async {
    final dirSnap =
        await _db.collection('children_directory').where('classCode', isEqualTo: classCode).get();

    // 원아마다 순서대로 기다리지 않고, 전원 동시에 조회 → 반 인원이 많아도 빠름
    final entryFutures = dirSnap.docs.map((doc) async {
      final uid = doc['uid'] as String;
      final childId = doc['childId'] as String;

      final childDoc = await _db.collection('users').doc(uid).collection('children').doc(childId).get();
      if (!childDoc.exists) return null;
      final child = ChildProfile.fromMap(childId, childDoc.data()!);

      final recordsFuture = _childrenRef(uid)
          .doc(childId)
          .collection('growthRecords')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      // RFID 있으면 하드웨어(RTDB)에서 오늘 등원/하원을 직접 가져옴 —
      // Firestore의 attendance 문서는 아무도 안 써서 항상 비어있었음.
      final Future<AttendanceRecord> attendanceFuture;
      if (child.rfidCardId != null && child.rfidCardId!.isNotEmpty) {
        attendanceFuture =
            RealtimeMeasurementService.instance.streamTodayAttendance(child.rfidCardId!).first.then(
                  (info) => AttendanceRecord(
                    id: 'today',
                    date: DateTime.now(),
                    checkInTime: info.checkInTime,
                    checkOutTime: info.checkOutTime,
                  ),
                );
      } else {
        attendanceFuture = fetchTodayAttendance(childId);
      }

      final results = await Future.wait([recordsFuture, attendanceFuture]);
      final recordsSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final attendance = results[1] as AttendanceRecord;

      final latestRecord =
          recordsSnap.docs.isEmpty ? null : GrowthRecord.fromMap(recordsSnap.docs.first.id, recordsSnap.docs.first.data());

      return RosterEntry(uid: uid, child: child, attendance: attendance, latestRecord: latestRecord);
    });

    final entries = await Future.wait(entryFutures);
    return entries.whereType<RosterEntry>().toList();
  }

  /// 선생님이 원아 카드를 눌렀을 때 — 그 아이(다른 학부모 계정 소속)의
  /// 전체 성장기록을 조회. Firestore가 테스트 모드(공개 읽기)라 로그인
  /// 계정이 달라도 조회 가능.
  Future<List<GrowthRecord>> fetchGrowthRecordsForChild(String uid, String childId) async {
    final snap = await _childrenRef(uid)
        .doc(childId)
        .collection('growthRecords')
        .orderBy('date')
        .get();
    return snap.docs.map((d) => GrowthRecord.fromMap(d.id, d.data())).toList();
  }
}

/// 선생님 대시보드에서 한 아이당 표시할 정보(프로필 + 오늘 등원 현황 + 최신 측정값) 묶음
class RosterEntry {
  final String uid;
  final ChildProfile child;
  final AttendanceRecord attendance;
  final GrowthRecord? latestRecord;
  RosterEntry({required this.uid, required this.child, required this.attendance, this.latestRecord});
}
