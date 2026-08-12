import '../models/models.dart';

/// Firestore 데이터가 아직 없을 때 화면 확인용으로 쓰는 더미 데이터.
/// FirebaseService에서 컬렉션이 비어있으면 이 데이터로 폴백하도록 구성.
class DummyData {
  DummyData._();

  static final child = ChildProfile(
    id: 'dummy_child_1',
    name: '김서준',
    birthDate: DateTime.now().subtract(const Duration(days: 30 * 7)),
    gender: '남자아이',
    rfidCardId: 'A2F4',
  );

  static final growthRecords = <GrowthRecord>[
    GrowthRecord(id: '1', date: DateTime(2025, 2, 4), heightCm: 60.5, weightKg: 6.4),
    GrowthRecord(id: '2', date: DateTime(2025, 3, 6), heightCm: 62.8, weightKg: 6.8),
    GrowthRecord(id: '3', date: DateTime(2025, 4, 5), heightCm: 63.9, weightKg: 7.0),
    GrowthRecord(id: '4', date: DateTime(2025, 5, 4), heightCm: 65.2, weightKg: 7.3),
    GrowthRecord(id: '5', date: DateTime(2025, 6, 8), heightCm: 67.6, weightKg: 7.9),
    GrowthRecord(
      id: '6',
      date: DateTime(2025, 7, 10),
      heightCm: 69.8,
      weightKg: 8.4,
      heightPercentile: 75,
      weightPercentile: 60,
    ),
  ];

  static final attendanceToday = AttendanceRecord(
    id: 'today',
    date: DateTime.now(),
    checkInTime: DateTime.now().copyWith(hour: 9, minute: 5),
    checkOutTime: DateTime.now().copyWith(hour: 16, minute: 30),
  );

  static final notifications = <NotificationItem>[
    NotificationItem(
      id: '1',
      type: NotificationType.checkIn,
      message: '서준이 등원 확인됨',
      timestamp: DateTime.now().copyWith(hour: 9, minute: 5),
    ),
    NotificationItem(
      id: '2',
      type: NotificationType.measurement,
      message: '오늘 측정 완료: 키 69.8cm · 몸무게 8.4kg',
      timestamp: DateTime.now().copyWith(hour: 10, minute: 30),
    ),
    NotificationItem(
      id: '3',
      type: NotificationType.checkOut,
      message: '서준이 하원 확인됨',
      timestamp: DateTime.now().copyWith(hour: 16, minute: 30),
    ),
  ];
}
