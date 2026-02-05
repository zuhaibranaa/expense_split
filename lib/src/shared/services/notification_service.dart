import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  static const String _vapidKey =
      'BHFYMw81dqq6kMHJuhv7A4E9_wcx_gFAMu-UpeLS9-grGliRMNbChXeROniX6aZPOn9x8AGHXQs52PugaU5jlMw';

  Future<void> init() async {
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
        );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );

    // Initialize Firebase Messaging (Fire and forget, don't block startup)
    _initFirebaseMessaging();
  }

  Future<void> _initFirebaseMessaging() async {
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

        // Get Token
        if (kIsWeb) {
          _fcmToken = await messaging.getToken(vapidKey: _vapidKey);
        } else {
          if (defaultTargetPlatform == TargetPlatform.iOS) {
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

            if (apnsToken != null) {
              _fcmToken = await messaging.getToken();
            } else {
              debugPrint(
                'APNS token still null after retries. FCM token fetch will likely fail.',
              );
              // Try anyway, sometimes getToken handles it internally or it's a simulator issue
              try {
                _fcmToken = await messaging.getToken();
              } catch (e) {
                debugPrint('Failed to get FCM token without APNS token: $e');
              }
            }
          } else {
            _fcmToken = await messaging.getToken();
          }
        }
        debugPrint('FCM Token: $_fcmToken');

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
    if (kIsWeb) {
      return _fcmToken ??
          await FirebaseMessaging.instance.getToken(vapidKey: _vapidKey);
    }
    return _fcmToken ?? await FirebaseMessaging.instance.getToken();
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
