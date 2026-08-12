/// 자녀 프로필
class ChildProfile {
  final String id;
  final String name;
  final DateTime birthDate;
  final String gender; // '남자아이' | '여자아이'
  final String? rfidCardId;

  ChildProfile({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.gender,
    this.rfidCardId,
  });

  /// 개월 수 계산 (홈 화면 "생후 N개월" 표시용, 현재 시점 기준)
  int get ageInMonths => ageInMonthsAt(DateTime.now());

  /// 특정 시점(측정일 등) 기준 개월 수 — 백분위 계산은 "지금 나이"가 아니라
  /// "그 측정을 했던 시점의 나이"로 해야 정확함
  int ageInMonthsAt(DateTime date) {
    return (date.year - birthDate.year) * 12 + (date.month - birthDate.month);
  }

  factory ChildProfile.fromMap(String id, Map<String, dynamic> map) {
    return ChildProfile(
      id: id,
      name: map['name'] as String,
      birthDate: DateTime.parse(map['birthDate'] as String),
      gender: map['gender'] as String,
      rfidCardId: map['rfidCardId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'birthDate': birthDate.toIso8601String(),
        'gender': gender,
        'rfidCardId': rfidCardId,
      };
}

/// 성장 측정 기록 (키/몸무게)
class GrowthRecord {
  final String id;
  final DateTime date;
  final double heightCm;
  final double weightKg;
  final double? heightPercentile;
  final double? weightPercentile;

  GrowthRecord({
    required this.id,
    required this.date,
    required this.heightCm,
    required this.weightKg,
    this.heightPercentile,
    this.weightPercentile,
  });

  factory GrowthRecord.fromMap(String id, Map<String, dynamic> map) {
    return GrowthRecord(
      id: id,
      date: DateTime.parse(map['date'] as String),
      heightCm: (map['heightCm'] as num).toDouble(),
      weightKg: (map['weightKg'] as num).toDouble(),
      heightPercentile: (map['heightPercentile'] as num?)?.toDouble(),
      weightPercentile: (map['weightPercentile'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'heightCm': heightCm,
        'weightKg': weightKg,
        'heightPercentile': heightPercentile,
        'weightPercentile': weightPercentile,
      };
}

/// RFID 기반 등하원 기록
class AttendanceRecord {
  final String id;
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;

  AttendanceRecord({
    required this.id,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
  });

  Duration? get stayDuration {
    if (checkInTime == null || checkOutTime == null) return null;
    return checkOutTime!.difference(checkInTime!);
  }

  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> map) {
    return AttendanceRecord(
      id: id,
      date: DateTime.parse(map['date'] as String),
      checkInTime: map['checkInTime'] != null ? DateTime.parse(map['checkInTime']) : null,
      checkOutTime: map['checkOutTime'] != null ? DateTime.parse(map['checkOutTime']) : null,
    );
  }
}

/// 알림 히스토리 항목
enum NotificationType { checkIn, checkOut, measurement, weeklyReport }

class NotificationItem {
  final String id;
  final NotificationType type;
  final String message;
  final DateTime timestamp;

  NotificationItem({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
  });
}
