/// 웹이 아닌 플랫폼(안드로이드/iOS 네이티브 빌드 등)에서는 아무 동작도
/// 하지 않음 — 그 플랫폼에서는 FCM이 기본적으로 OS 알림을 직접 띄워주기
/// 때문에 별도 처리 필요 없음.
void showBrowserNotification(String title, String body) {}

Future<bool> requestNotificationPermission() async => false;
