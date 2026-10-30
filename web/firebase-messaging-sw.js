// Firebase Cloud Messaging service worker for the EquiSplit web app.
// Keep this config in sync with the `web` entry in lib/firebase_options.dart.
importScripts(
  'https://www.gstatic.com/firebasejs/13.1.0/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/13.1.0/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'AIzaSyBJVfTWvOFYsZPxPqfNHbe_LtF5m8pShvs',
  appId: '1:931195916704:web:576425aea48bb46a6294c5',
  messagingSenderId: '931195916704',
  projectId: 'equisplit-d4c74',
  authDomain: 'equisplit-d4c74.firebaseapp.com',
  storageBucket: 'equisplit-d4c74.firebasestorage.app',
  measurementId: 'G-9JMENZQ0BH',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  // Notification messages are displayed by the SDK. Only data-only messages
  // need a manual notification here.
  if (payload.notification) return;

  const data = payload.data || {};
  const title = data.title || 'EquiSplit';
  const body = data.body || 'You have a new update.';

  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data,
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const data = event.notification.data || {};
  const groupId = data.group_id;
  const targetUrl = groupId
    ? `/?group=${encodeURIComponent(groupId)}`
    : '/';

  event.waitUntil(
    (async () => {
      const windows = await clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      });

      for (const client of windows) {
        if ('focus' in client) {
          await client.focus();
          if ('navigate' in client) {
            await client.navigate(targetUrl);
          }
          return;
        }
      }

      return clients.openWindow(targetUrl);
    })(),
  );
});
