import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  final Completer<String> _registration = Completer<String>();
  static const String _vapidKey =
      'BHFYMw81dqq6kMHJuhv7A4E9_wcx_gFAMu-UpeLS9-grGliRMNbChXeROniX6aZPOn9x8AGHXQs52PugaU5jlMw';

  Future<void> init() async {
    // Local notifications are not supported on Windows; Firebase Messaging is
    // only available on Android, iOS and Web. Everything here is best-effort so
    // a desktop launch never crashes on notification setup.
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
            macOS: initializationSettingsIOS,
          );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
        },
      );
    } catch (error) {
      debugPrint('Local notifications unavailable: $error');
    }

    // Initialize Firebase Messaging (fire and forget, don't block startup)
    _initFirebaseMessaging();
  }

  bool get _supportsMessaging {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _initFirebaseMessaging() async {
    if (!_supportsMessaging) {
      debugPrint('Firebase Messaging is not supported on this platform.');
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission
      // On Web this triggers a prompt. If we await this in main(), app might hang until user interacts.
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted permission');

        // FID registrations arrive on this stream. Keep listening so refreshes
        // are picked up after the first registration.
        messaging.onRegistered.listen((registrationId) {
          _fcmToken = registrationId;
          if (!_registration.isCompleted) {
            _registration.complete(registrationId);
          }
          debugPrint('FCM registration id: $registrationId');
        });

        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          String? apnsToken = await messaging.getAPNSToken();

          // Retry checking for APNS token
          if (apnsToken == null) {
            debugPrint('APNS token not available yet, polling...');
            for (int i = 0; i < 5; i++) {
              await Future.delayed(const Duration(seconds: 2));
              apnsToken = await messaging.getAPNSToken();
              if (apnsToken != null) {
                debugPrint('APNS token found after retry ${i + 1}');
                break;
              }
            }
          }

          if (apnsToken == null) {
            debugPrint(
              'APNS token still null after retries. FCM registration will likely fail.',
            );
          }
        }

        await messaging.register(vapidKey: kIsWeb ? _vapidKey : null);

        // Handle Foreground Messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Got a message whilst in the foreground!');
          debugPrint('Message data: ${message.data}');

          if (message.notification != null) {
            debugPrint(
              'Message also contained a notification: ${message.notification}',
            );
            showNotification(
              title: message.notification!.title,
              body: message.notification!.body,
            );
          }
        });
      } else {
        debugPrint('User declined or has not accepted permission');
      }
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
    }
  }

  Future<String?> getFcmToken() async {
    if (!_supportsMessaging) return null;
    if (_fcmToken != null) return _fcmToken;

    try {
      await FirebaseMessaging.instance.register(
        vapidKey: kIsWeb ? _vapidKey : null,
      );
      return await _registration.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => _fcmToken ?? '',
      );
    } catch (e) {
      debugPrint('Failed to register for FCM: $e');
      return _fcmToken;
    }
  }

  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'default_channel',
          'Default',
          channelDescription: 'Default notification channel',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> requestPermissions() async {
    if (!_supportsMessaging) return;

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await FirebaseMessaging.instance.requestPermission();
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
