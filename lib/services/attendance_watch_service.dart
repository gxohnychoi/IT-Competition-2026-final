import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'realtime_measurement_service.dart';

/// 등원/하원 알림 이벤트 하나
class AttendanceEvent {
  final String childName;
  final String type; // 'checkin' | 'checkout'
  final DateTime time;
  AttendanceEvent({required this.childName, required this.type, required this.time});

  String get message {
    final ampm = time.hour < 12 ? '오전' : '오후';
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final timeStr = '$ampm $hour12:${time.minute.toString().padLeft(2, '0')}';
    return type == 'checkin' ? '$childName이가 $timeStr에 등원했어요' : '$childName이가 $timeStr에 하원했어요';
  }
}

/// 앱이 켜져있는 동안(포그라운드), RTDB를 계속 감시하다가 등원/하원이
/// "새로" 감지되면 이벤트를 흘려보내는 서비스.
/// FCM/백그라운드 알림은 안 씀 — 화면 보고 있을 때만 작동하면 충분해서
/// (iOS Safari는 홈화면 추가 없인 진짜 OS 알림이 아예 안 뜨는 제약이 있어서,
/// 기기 상관없이 항상 똑같이 작동하는 이 방식으로 감).
class AttendanceWatchService {
  AttendanceWatchService._internal();
  static final instance = AttendanceWatchService._internal();

  final _controller = StreamController<AttendanceEvent>.broadcast();
  Stream<AttendanceEvent> get events => _controller.stream;

  /// 지금까지 알려진 가장 최신 등원/하원 상태 — 화면들은 이걸 직접 구독해서
  /// 보여줌 (별도로 스트림을 또 만들지 않고, 이미 검증된 이 폴링 루프 하나만 씀).
  final ValueNotifier<TodayAttendanceInfo?> currentInfo = ValueNotifier(null);

  /// 화면(알림 탭 등)이 나중에 열려도 그동안 쌓인 알림을 볼 수 있게
  /// 메모리에 히스토리로 들고 있음 (최신이 앞).
  final List<AttendanceEvent> history = [];

  Timer? _timer;
  bool _checkedInSeen = false;
  bool _checkedOutSeen = false;
  String? _watchingRfid;

  bool get isRunning => _timer != null;

  /// 감시 시작. 이미 같은 아이를 감시 중이면 아무것도 안 함(중복 방지).
  void start(ChildProfile child) {
    final rfid = child.rfidCardId;
    if (rfid == null || rfid.isEmpty) return;
    if (_watchingRfid == rfid && _timer != null) return; // 이미 감시 중

    stop(); // 다른 아이 감시 중이었으면 정리
    _watchingRfid = rfid;
    _checkedInSeen = false;
    _checkedOutSeen = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final info = await RealtimeMeasurementService.instance.streamTodayAttendance(rfid).first;
      currentInfo.value = info; // 화면에서 바로 보여줄 수 있게 항상 최신값 갱신

      if (info.checkInTime != null && !_checkedInSeen) {
        _checkedInSeen = true;
        _emit(AttendanceEvent(childName: child.name, type: 'checkin', time: info.checkInTime!));
      }
      if (info.checkOutTime != null && !_checkedOutSeen) {
        _checkedOutSeen = true;
        _emit(AttendanceEvent(childName: child.name, type: 'checkout', time: info.checkOutTime!));
      }
      // RTDB에서 오늘 기록이 삭제됐으면(테스트 중 지웠다 다시 태그하는 경우)
      // 다시 감지할 수 있도록 상태 초기화.
      if (info.checkInTime == null) _checkedInSeen = false;
      if (info.checkOutTime == null) _checkedOutSeen = false;
    });
  }

  void _emit(AttendanceEvent event) {
    history.insert(0, event);
    _controller.add(event);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _watchingRfid = null;
    currentInfo.value = null;
  }
}
