importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-messaging.js");

firebase.initializeApp({
    apiKey: "AIzaSyD0lD2lD2lD2lD2lD2lD2lD2lD2lD2lD2l",
    authDomain: "equisplit-d4c74.firebaseapp.com",
    projectId: "equisplit-d4c74",
    storageBucket: "equisplit-d4c74.appspot.com",
    messagingSenderId: "108752414224018650707",
    appId: "1:108752414224018650707:web:cd454e52e6f6ba425d4111",
    measurementId: "G-1234567890"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);
    // Customize notification here
    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        icon: '/icons/Icon-192.png'
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});

self.addEventListener('notificationclick', function (event) {
    console.log('[firebase-messaging-sw.js] Notification click event');
    event.notification.close();
    event.waitUntil(
        clients.openWindow('https://equisplit-d4c74.web.app/')
    );
});