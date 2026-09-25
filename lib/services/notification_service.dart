import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';
import '../trip_accepting.dart';
import 'overlay_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    if (message.data['notification_type'] == 'new_booking') {
      const storage = FlutterSecureStorage();
      final String? bookingCarType = message.data['car_type']?.toString();
      final String? storedVType = await storage.read(key: 'driver_vehicle_type') ??
          await storage.read(key: 'vehicle_type');
      if (storedVType != null && storedVType.isNotEmpty && bookingCarType != null && bookingCarType.isNotEmpty) {
        if (!NotificationService.isVehicleMatch(bookingCarType, storedVType)) {
          debugPrint("🚫 [_firebaseMessagingBackgroundHandler] Mismatched car type ($bookingCarType vs driver $storedVType). Suppressing background alert.");
          return;
        }
      }
    }

    await NotificationService.instance.setupFlutterNotifications();
    await NotificationService.instance.showNotification(message);

    if (message.data['notification_type'] == 'new_booking') {
      await OverlayService.instance.handleIncomingRideAlert(message.data);
    }
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

    // 1. High-Priority Uber-style Ride Request Channel (preview ringtone + vibration)
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

    // 2. Ride Request Channel (Sound Only, No Vibration)
    final AndroidNotificationChannel rideAlertNoVibChannel = AndroidNotificationChannel(
      'rentox_ride_alert_no_vib',
      'Ride Requests (Sound Only)',
      description: 'Incoming trip notifications with sound only, no vibration.',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('preview'),
      enableVibration: false,
    );

    // 3. High Alert Siren Channel (Sound + Vibrate)
    final AndroidNotificationChannel loudAlarmChannel = AndroidNotificationChannel(
      'rentox_alert_loud_alarm',
      'High Alert Siren',
      description: 'Urgent siren ringtone for incoming rides.',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('preview'),
      enableVibration: true,
      vibrationPattern: vibrationPattern15Sec,
    );

    // 4. High Alert Siren Channel (Sound Only, No Vibrate)
    final AndroidNotificationChannel loudAlarmNoVibChannel = AndroidNotificationChannel(
      'rentox_alert_loud_alarm_no_vib',
      'High Alert Siren (No Vibrate)',
      description: 'Urgent siren ringtone without vibration.',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('preview'),
      enableVibration: false,
    );

    // 5. Radar Pulse Channel (Sound + Vibrate)
    final AndroidNotificationChannel uberPulseChannel = AndroidNotificationChannel(
      'rentox_alert_uber_pulse',
      'Radar Pulse Alerts',
      description: 'Pulse tone for incoming rides.',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('preview'),
      enableVibration: true,
      vibrationPattern: vibrationPattern15Sec,
    );

    // 6. Radar Pulse Channel (Sound Only, No Vibrate)
    final AndroidNotificationChannel uberPulseNoVibChannel = AndroidNotificationChannel(
      'rentox_alert_uber_pulse_no_vib',
      'Radar Pulse Alerts (No Vibrate)',
      description: 'Pulse tone without vibration.',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('preview'),
      enableVibration: false,
    );

    // 7. Vibrate Only Channel (No Sound, Vibrate ON)
    final AndroidNotificationChannel rideAlertSilentVibChannel = AndroidNotificationChannel(
      'rentox_alert_silent_vib',
      'Ride Requests (Vibrate Only)',
      description: 'Incoming trip notifications with vibration only, no sound.',
      importance: Importance.max,
      playSound: false,
      enableVibration: true,
      vibrationPattern: vibrationPattern15Sec,
    );

    // 8. Silent Channel (No Sound, No Vibrate)
    const AndroidNotificationChannel rideAlertSilentNoVibChannel = AndroidNotificationChannel(
      'rentox_alert_silent_no_vib',
      'Ride Requests (Silent)',
      description: 'Silent incoming trip notifications.',
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
    );

    // 9. Standard Channel for general status updates (Sound + Vibrate)
    const AndroidNotificationChannel standardChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'General Notifications',
      description: 'Used for status updates and general notifications.',
      importance: Importance.max,
      playSound: true,
    );

    // 10. Standard Channel without vibration
    const AndroidNotificationChannel standardNoVibChannel = AndroidNotificationChannel(
      'high_importance_channel_no_vib',
      'General Notifications (No Vibrate)',
      description: 'Used for status updates without vibration.',
      importance: Importance.high,
      playSound: true,
      enableVibration: false,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(rideAlertChannel);
    await androidPlugin?.createNotificationChannel(rideAlertNoVibChannel);
    await androidPlugin?.createNotificationChannel(loudAlarmChannel);
    await androidPlugin?.createNotificationChannel(loudAlarmNoVibChannel);
    await androidPlugin?.createNotificationChannel(uberPulseChannel);
    await androidPlugin?.createNotificationChannel(uberPulseNoVibChannel);
    await androidPlugin?.createNotificationChannel(rideAlertSilentVibChannel);
    await androidPlugin?.createNotificationChannel(rideAlertSilentNoVibChannel);
    await androidPlugin?.createNotificationChannel(standardChannel);
    await androidPlugin?.createNotificationChannel(standardNoVibChannel);

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
              final String? bookingId = data['booking_id']?.toString();
              if (bookingId != null && bookingId.isNotEmpty) {
                final bool isAdvance = (data['is_advance_booking'] == 'true');
                if (isAdvance) {
                  final bool canDraw = await OverlayService.instance.hasPermission();
                  if (canDraw) {
                    await OverlayService.instance.bringToFront();
                  }
                } else {
                  OverlayService.instance.handleIncomingRideAlert(data);
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

  static bool isVehicleMatch(String? bookingCarType, String? driverVehicleStr) {
    if (bookingCarType == null || bookingCarType.trim().isEmpty) return true;
    final bType = bookingCarType.trim().toLowerCase();
    if (bType == 'all' || bType == 'any') return true;

    if (driverVehicleStr == null || driverVehicleStr.trim().isEmpty) return false;
    final dStr = driverVehicleStr.trim().toLowerCase();

    final wantsSedan = bType.contains('sedan') ||
        bType.contains('sadan') ||
        bType.contains('sadden') ||
        bType.contains('dzire') ||
        bType.contains('aura') ||
        bType.contains('etios') ||
        bType.contains('amaze');

    final wantsHatchback = bType.contains('hatch') ||
        bType.contains('hack') ||
        bType.contains('hash') ||
        bType.contains('wagon') ||
        bType.contains('celerio') ||
        bType.contains('tiago') ||
        bType.contains('i10');

    final wantsErtiga = bType.contains('ertiga') ||
        bType.contains('ertigl') ||
        bType.contains('romiyon') ||
        bType.contains('rumion');

    final wantsCrystaInnova = bType.contains('crysta') || bType.contains('innova');

    final wantsSuv = bType.contains('suv') ||
        bType.contains('auv') ||
        bType.contains('xuv') ||
        bType.contains('mpv') ||
        wantsErtiga ||
        wantsCrystaInnova;

    final wantsTempo = bType.contains('tempo') ||
        bType.contains('traveller') ||
        bType.contains('urabainia');

    final entries = dStr.split(RegExp(r'[,|\n/]+'));
    for (var entry in entries) {
      final e = entry.trim();
      if (e.isEmpty) continue;

      final isSedan = e.contains('sedan') ||
          e.contains('sadan') ||
          e.contains('sadden') ||
          e.contains('seden') ||
          e.contains('sedaan') ||
          e.contains('sudan') ||
          e.contains('dzire') ||
          e.contains('dizayr') ||
          e.contains('aura') ||
          e.contains('etios') ||
          e.contains('amaze') ||
          e.contains('bmw');

      final isHatchback = e.contains('hatch') ||
          e.contains('hack back') ||
          e.contains('hashback') ||
          e.contains('wagon') ||
          e.contains('celerio') ||
          e.contains('tiago') ||
          e.contains('i10') ||
          e.contains('alto') ||
          e.contains('kwid') ||
          (e.contains('swift') && !e.contains('dzire') && !e.contains('dizayr'));

      final isErtiga = e.contains('ertiga') ||
          e.contains('ertigl') ||
          e.contains('romiyon') ||
          e.contains('rumion');

      final isCrystaInnova = e.contains('crysta') || e.contains('innova');

      final isSuv = e.contains('suv') ||
          e.contains('auv') ||
          e.contains('xuv') ||
          e.contains('mpv') ||
          e.contains('carens') ||
          e.contains('7 seater') ||
          e.contains('scorpio') ||
          e.contains('bolero') ||
          e.contains('safari') ||
          e.contains('harrier') ||
          e.contains('marazzo') ||
          isErtiga ||
          isCrystaInnova;

      final isTempo = e.contains('tempo') ||
          e.contains('traveller') ||
          e.contains('urabainia') ||
          e == '14';

      if (wantsSedan && isSedan) return true;
      if (wantsHatchback && isHatchback) return true;
      if (wantsCrystaInnova) {
        if (isCrystaInnova || (isSuv && e.contains('premium'))) return true;
      } else if (wantsErtiga) {
        if (isErtiga || isSuv) return true;
      } else if (wantsSuv && isSuv) {
        return true;
      }
      if (wantsTempo && isTempo) return true;

      if (e == bType || (e.length > 3 && bType.contains(e)) || (bType.length > 3 && e.contains(bType))) {
        return true;
      }
    }

    return false;
  }

  static Int64List _generateVibrationPattern(int seconds) {
    final List<int> pattern = [0];
    double elapsed = 0.0;
    while (elapsed < seconds) {
      pattern.addAll([1000, 500]);
      elapsed += 1.5;
    }
    return Int64List.fromList(pattern);
  }

  Future<void> showNotification(RemoteMessage message) async {
    final Map<String, dynamic> data = message.data;
    final bool isNewBooking = (data['notification_type'] == 'new_booking');

    // Read Driver/Vendor notification preferences from Secure Storage
    const storage = FlutterSecureStorage();

    if (isNewBooking) {
      final String? bookingCarType = data['car_type']?.toString();
      final String? storedVType = await storage.read(key: 'driver_vehicle_type') ??
          await storage.read(key: 'vehicle_type');
      if (storedVType != null && storedVType.isNotEmpty && bookingCarType != null && bookingCarType.isNotEmpty) {
        if (!isVehicleMatch(bookingCarType, storedVType)) {
          debugPrint("🚫 [NotificationService] Mismatched car type ($bookingCarType vs driver $storedVType). Suppressing notification.");
          return;
        }
      }
    }

    String? storedVib;
    String? storedSnd;
    try {
      storedVib = await storage.read(key: 'alert_vibration_enabled');
      storedSnd = await storage.read(key: 'alert_sound_enabled');
    } catch (e) {
      debugPrint("⚠️ Error reading alert preferences in showNotification: $e");
    }
    final bool isVibrationEnabled = (storedVib != 'false');
    final bool isSoundEnabled = (storedSnd != 'false');

    String title = data['title']?.toString() ??
        message.notification?.title ??
        (isNewBooking ? 'New Trip Available!' : 'Rentox Alert');
    String body = data['body']?.toString() ??
        message.notification?.body ?? '';
    body = body.replaceAll(r'\n', '\n');
    if (body.isEmpty && isNewBooking) {
      final pickup = data['pickup_location'] ?? 'Customer location';
      final earnings = data['vendor_amount'] ?? '0';
      body = 'From: $pickup\nEarnings: ₹$earnings';
    }

    AndroidNotificationDetails androidDetails;
    final bool isAdvanceBooking = (data['is_advance_booking'] == 'true');

    if (isNewBooking && isAdvanceBooking) {
      // Gentle notification for Advance Bookings
      final String channelId = isVibrationEnabled
          ? 'high_importance_channel'
          : 'high_importance_channel_no_vib';
      androidDetails = AndroidNotificationDetails(
        channelId,
        'Advance Trip Bookings',
        channelDescription:
            'Scheduled and advance booking notices for upcoming dates.',
        importance: Importance.high,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        playSound: isSoundEnabled,
        enableVibration: isVibrationEnabled,
        icon: '@mipmap/ic_launcher',
      );
    } else if (isNewBooking) {
      final int vibrateSec = int.tryParse(data['vibrate_seconds']?.toString() ?? '') ?? 15;
      final String ringtoneName = data['ringtone_name']?.toString() ?? 'preview';

      // Pick channel based on user sound & vibration preferences
      String channelId;
      if (isSoundEnabled && isVibrationEnabled) {
        if (ringtoneName == 'loud_alarm') {
          channelId = 'rentox_alert_loud_alarm';
        } else if (ringtoneName == 'uber_pulse') {
          channelId = 'rentox_alert_uber_pulse';
        } else if (ringtoneName == 'default') {
          channelId = 'high_importance_channel';
        } else {
          channelId = 'rentox_ride_alert_channel';
        }
      } else if (isSoundEnabled && !isVibrationEnabled) {
        if (ringtoneName == 'loud_alarm') {
          channelId = 'rentox_alert_loud_alarm_no_vib';
        } else if (ringtoneName == 'uber_pulse') {
          channelId = 'rentox_alert_uber_pulse_no_vib';
        } else if (ringtoneName == 'default') {
          channelId = 'high_importance_channel_no_vib';
        } else {
          channelId = 'rentox_ride_alert_no_vib';
        }
      } else if (!isSoundEnabled && isVibrationEnabled) {
        channelId = 'rentox_alert_silent_vib';
      } else {
        channelId = 'rentox_alert_silent_no_vib';
      }

      final dynamicVibration = isVibrationEnabled
          ? _generateVibrationPattern(vibrateSec)
          : null;

      final AndroidNotificationSound? soundResource = (!isSoundEnabled || ringtoneName == 'default')
          ? null
          : const RawResourceAndroidNotificationSound('preview');

      androidDetails = AndroidNotificationDetails(
        channelId,
        'Ride Requests & Booking Alerts',
        channelDescription:
            'High priority incoming trip notifications.',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        visibility: NotificationVisibility.public,
        playSound: isSoundEnabled,
        sound: soundResource,
        enableVibration: isVibrationEnabled,
        vibrationPattern: dynamicVibration,
        icon: '@mipmap/ic_launcher',
        ticker: title,
      );
    } else {
      final String channelId = isVibrationEnabled
          ? 'high_importance_channel'
          : 'high_importance_channel_no_vib';
      androidDetails = AndroidNotificationDetails(
        channelId,
        'General Notifications',
        channelDescription:
            'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        playSound: isSoundEnabled,
        enableVibration: isVibrationEnabled,
        icon: '@mipmap/ic_launcher',
      );
    }

    final int notificationId =
        int.tryParse(data['booking_id']?.toString() ?? '') ?? message.hashCode;

    await _localNotifications.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: isSoundEnabled,
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
    OverlayService.instance.handleIncomingRideAlert(data);
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
