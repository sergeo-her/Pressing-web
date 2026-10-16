/* firebase-messaging-sw.js — FCM background messages */
importScripts("https://www.gstatic.com/firebasejs/10.14.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.14.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCsjiM0VMf4W6Fy_QNi1j9lj5OV2aWNS3Q",
  authDomain: "pressingconnect-b6f08.firebaseapp.com",
  projectId: "pressingconnect-b6f08",
  storageBucket: "pressingconnect-b6f08.firebasestorage.app",
  messagingSenderId: "1067312541714",
  appId: "1:1067312541714:web:1099b5e383bde2c96868cb"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  const title = (payload.notification && payload.notification.title) || (payload.data && payload.data.title) || "Pressing Connecté";
  const body = (payload.notification && payload.notification.body) || (payload.data && payload.data.body) || "";
  const options = {
    body: body,
    icon: "/icon-192.png",
    badge: "/icon-192.png",
    data: payload.data || {},
    tag: "pc-fcm-" + Date.now()
  };
  self.registration.showNotification(title, options);
});

self.addEventListener("notificationclick", function(event) {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || "/";
  event.waitUntil(clients.openWindow(url));
});
