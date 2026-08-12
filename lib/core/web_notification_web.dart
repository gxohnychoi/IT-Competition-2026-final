// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;

/// 브라우저 알림 권한을 "직접" 요청 — Firebase Messaging(FCM) 내부 로직을
/// 거치지 않고 브라우저 표준 Notification API로 바로 요청함.
///
/// ⚠️ iOS 사파리는 FCM(firebase_messaging) 방식의 권한 요청이 잘 안 먹히는
/// 경우가 있어서, 이 방식으로 따로 요청해야 실제로 "허용" 팝업이 뜸.
/// 반드시 버튼 탭 같은 사용자 동작(제스처) 직후에 호출해야 브라우저가
/// 권한 요청을 막지 않음.
Future<bool> requestNotificationPermission() async {
  try {
    if (!html.Notification.supported) return false;
    if (html.Notification.permission == 'granted') return true;
    final result = await html.Notification.requestPermission();
    return result == 'granted';
  } catch (_) {
    return false;
  }
}

/// 실제 폰/PC 알림센터에 뜨는 진짜 OS 알림을 띄움.
///
/// ⚠️ 앱 화면 안에 우리가 그리는 배너가 아니라, 카톡 알림처럼 앱 밖에서도
/// (다른 앱 보고 있을 때, 화면 잠겨있을 때 등) 뜨는 진짜 시스템 알림임.
///
/// iOS는 이 방식(서비스워커의 showNotification)만 공식적으로 지원해서
/// (평범한 `new Notification()` 생성자는 iOS에서 지원이 불안정함),
/// 서비스워커를 거쳐서 띄우는 걸 우선 시도하고, 안 되는 환경(일부 데스크톱
/// 브라우저 등)에서는 기본 방식으로 폴백함.
void showBrowserNotification(String title, String body) {
  _show(title, body);
}

Future<void> _show(String title, String body) async {
  if (html.Notification.permission != 'granted') return;

  // 1순위: 서비스워커 경유 (iOS 16.4+ 홈화면 추가 앱에서 공식 지원되는 방식)
  try {
    final navigator = html.window.navigator;
    final swContainer = js_util.getProperty(navigator, 'serviceWorker');
    if (swContainer != null) {
      final registration = await js_util.promiseToFuture(js_util.getProperty(swContainer, 'ready'));
      final options = js_util.jsify({
        'body': body,
        'icon': '/icons/Icon-192.png',
        'badge': '/icons/Icon-192.png',
      });
      js_util.callMethod(registration, 'showNotification', [title, options]);
      return;
    }
  } catch (_) {
    // 서비스워커 경로 실패하면 아래 기본 방식으로 폴백
  }

  // 2순위: 기본 Notification 생성자 (서비스워커 없는 환경용 폴백)
  try {
    if (html.Notification.supported) {
      html.Notification(title, body: body, icon: '/icons/Icon-192.png');
    }
  } catch (_) {
    // 둘 다 안 되면 조용히 포기 (이 기기/브라우저는 알림 자체를 지원 안 하는 것)
  }
}
