// 웹에서 브라우저 탭이 닫혀있거나 백그라운드일 때도 푸시 알림을 받기 위한 서비스워커.
// firebase_options.dart의 web 설정값과 반드시 동일하게 맞춰야 함.

importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBRuLLgpX_7hOu2T6pkzuO21T4L2a5TBF8',
  appId: '1:480625323616:web:4934b3b57db0ad1a2f9d05',
  messagingSenderId: '480625323616',
  projectId: 'it2026-7e56c',
  authDomain: 'it2026-7e56c.firebaseapp.com',
  storageBucket: 'it2026-7e56c.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || '쑥쑥이';
  const body = payload.notification?.body || '';
  self.registration.showNotification(title, {
    body: body,
    icon: '/icons/Icon-192.png',
  });
});
