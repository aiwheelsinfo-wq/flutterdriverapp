import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';
import '../trip_accepting.dart';
import '../widgets/ride_request_dialog.dart';

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
      debugPrint('FCM Token: $token');
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
    debugPrint('Permission status: ${settings.authorizationStatus}');
  }

  Future<void> setupFlutterNotifications() async {
    if (_isFlutterLocalNotificationsInitialized) {
      return;
    }

    // 15-second pulsing vibration pattern (10 pulses of vibration over 15.0 seconds)
    final Int64List vibrationPattern15Sec = Int64List.fromList([
      0, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000,
      500, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1500,
    ]);

    // 1. High-Priority Uber-style Ride Request Channel (loud alarm sound & 15s repeating vibration)
    final AndroidNotificationChannel rideAlertChannel = AndroidNotificationChannel(
      'rentox_ride_alert_channel',
      'Ride Requests & Booking Alerts',
      description: 'High priority incoming trip notifications with alarm ringtone.',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('preview'),
      enableVibration: true,
      vibrationPattern: vibrationPattern15Sec,
    );

    // 2. Standard Channel for general status updates
    const AndroidNotificationChannel standardChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'General Notifications',
      description: 'Used for status updates and general notifications.',
      importance: Importance.high,
      playSound: true,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(rideAlertChannel);
    await androidPlugin?.createNotificationChannel(standardChannel);

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
        debugPrint("Notification clicked: ${details.payload}");
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
            debugPrint("Error parsing local notification payload: $e");
          }
        }
      },
    );

    _isFlutterLocalNotificationsInitialized = true;
  }

  Future<void> showNotification(RemoteMessage message) async {
    final Map<String, dynamic> data = message.data;
    final bool isNewBooking = (data['notification_type'] == 'new_booking');

    String title = message.notification?.title ??
        (isNewBooking ? 'New Trip Available!' : 'Rentox Alert');
    String body = message.notification?.body ?? '';
    if (body.isEmpty && isNewBooking) {
      final pickup = data['pickup_location'] ?? 'Customer location';
      final earnings = data['vendor_amount'] ?? '0';
      body = 'From: $pickup\nEarnings: ₹$earnings';
    }

    final androidDetails = isNewBooking
        ? AndroidNotificationDetails(
            'rentox_ride_alert_channel',
            'Ride Requests & Booking Alerts',
            channelDescription:
                'High priority incoming trip notifications with alarm ringtone.',
            importance: Importance.max,
            priority: Priority.max,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.call,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('preview'),
            enableVibration: true,
            vibrationPattern: Int64List.fromList([
              0, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000,
              500, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1500,
            ]),
            icon: '@mipmap/ic_launcher',
          )
        : const AndroidNotificationDetails(
            'high_importance_channel',
            'General Notifications',
            channelDescription:
                'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          );

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _setupMessageHandlers() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showNotification(message);
      notificationStreamController.add(message);

      // In-app interactive popup dialog when driver has the app open
      if (message.data['notification_type'] == 'new_booking') {
        _triggerInAppRideRequest(message.data);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
  }

  void _triggerInAppRideRequest(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      final bookingId = data['booking_id']?.toString() ?? '';
      if (bookingId.isNotEmpty) {
        RideRequestDialog.show(
          context,
          bookingId: bookingId,
          tripType: data['booking_type']?.toString() ?? 'Taxi Ride',
          pickupLocation: data['pickup_location']?.toString() ?? '',
          dropLocation: data['drop_location']?.toString() ?? '',
          vendorAmount: data['vendor_amount']?.toString() ?? '0',
        );
      }
    }
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
