import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';
import '../trip_accepting.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    await NotificationService.instance.setupFlutterNotifications();
    await NotificationService.instance.showNotification(message);
  } catch (e) {
    debugPrint("⚠️ _firebaseMessagingBackgroundHandler error: $e");
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isFlutterLocalNotificationsInitialized = false;

  Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      await _requestPermission();
      await _setupMessageHandlers();

      final token = await _messaging.getToken();
      print('FCM Token: $token');
    } catch (e) {
      debugPrint("⚠️ NotificationService initialize error: $e");
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );
    print('Permission status: ${settings.authorizationStatus}');
  }

  Future<void> setupFlutterNotifications() async {
    if (_isFlutterLocalNotificationsInitialized) {
      return;
    }

    // Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // ID
      'High Importance Notifications', // Name
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization (⚠️ no onDidReceiveLocalNotification in v19)
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combine both
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) async {
        print("Notification clicked: ${details.payload}");
        if (details.payload != null) {
          try {
            final Map<String, dynamic> data = jsonDecode(details.payload!);
            if (data['notification_type'] == 'new_booking') {
              final String? bookingId = data['booking_id'];
              if (bookingId != null && bookingId.isNotEmpty) {
                const storage = FlutterSecureStorage();
                final phoneNumber = await storage.read(key: 'phone_number');
                if (phoneNumber != null && phoneNumber.isNotEmpty) {
                  navigatorKey.currentState?.push(
                    MaterialPageRoute(
                      builder: (context) => DriverTripPage(
                        bookingId: bookingId,
                        phoneNumber: phoneNumber,
                      ),
                    ),
                  );
                }
              }
            }
          } catch (e) {
            print("Error parsing local notification payload: $e");
          }
        }
      },
    );

    _isFlutterLocalNotificationsInitialized = true;
  }

  Future<void> showNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // ID
            'High Importance Notifications', // Name
            channelDescription:
                'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  Future<void> _setupMessageHandlers() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showNotification(message);
      notificationStreamController.add(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
  }

  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    if (message.data['notification_type'] == 'new_booking') {
      final String? bookingId = message.data['booking_id'];
      if (bookingId != null && bookingId.isNotEmpty) {
        const storage = FlutterSecureStorage();
        final phoneNumber = await storage.read(key: 'phone_number');
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => DriverTripPage(
                bookingId: bookingId,
                phoneNumber: phoneNumber,
              ),
            ),
          );
        }
      }
    } else if (message.data['type'] == 'customer_cancelled') {
      // App was opened from a cancellation notification — nothing to navigate,
      // the AccpetedBookingPageVender page will refresh automatically on load.
      debugPrint(
          '[FCM] Customer cancelled booking #${message.data['booking_id']}');
    }
  }
}
