import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'car_list.dart';
// Ensure these files exist in your project
import 'checkAndRoot.dart';
import 'login_page.dart';
import 'api_config.dart';

// ✅ Professional Light Amber Theme Constants
const Color kPrimaryAmber = Color(0xFFFFB300);
const Color kLightAmber = Color(0xFFFFF8E1);
const Color kDarkText = Color(0xFF3E2723); // Fixed the typo here

Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("📩 Background Message: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 🔥 1. Request permission (MANDATORY)
  await FirebaseMessaging.instance.requestPermission();

  // Request location permission to avoid SecurityException for Foreground Service
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  // 🔥 2. Foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint("📩 Foreground: ${message.notification?.title}");
  });

  // 🔥 3. Background / terminated messages
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
    await _setupTrackingService();
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      service.startService();
    }
  } else {
    debugPrint("⚠️ Location permission not granted. Background service not started.");
  }

  runApp(const RentoxApp());
}

/// ✅ Background Service Logic
Future<void> _setupTrackingService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'driver_tracking',
    'Location Service',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'driver_tracking',
      initialNotificationTitle: 'Rentox Tracking',
      initialNotificationContent: 'Tracking driver location...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async => true;

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  const storage = FlutterSecureStorage();

  Timer.periodic(const Duration(seconds: 15), (timer) async {
    final phoneNumber = await storage.read(key: 'phone_number');
    if (phoneNumber == null) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      final response = await http.post(
        Uri.parse(ApiConfig.updateLocation),
        body: {
          'driver_id': phoneNumber,
          'latitude': position.latitude.toString(),
          'longitude': position.longitude.toString(),
        },
      );

      final data = jsonDecode(response.body);
      if (data['today_trip'] == false) {
        service.stopSelf();
      }
    } catch (e) {
      debugPrint("Update Error: $e");
    }
  });
}

class RentoxApp extends StatelessWidget {
  const RentoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rentox Driver',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryAmber,
          primary: kPrimaryAmber,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SplashScreen(),
    );
  }
}

/// ✅ Splash Screen with Scale Animation (3 Seconds)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();

    // Scale animation setup
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // 1 second per pulse
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _startAppLogic();
  }

  Future<void> _startAppLogic() async {
    final storedPhone = await _storage.read(key: "phone_number");
    Widget nextScreen = const LoginPage();

    if (storedPhone != null && storedPhone.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse(ApiConfig.checkPhone),
          body: {"phone_number": storedPhone},
        ).timeout(const Duration(seconds: 4));

        final data = jsonDecode(response.body);

        if (data["success"] == true) {
          // 🔥 FULL FCM SETUP HERE ONLY
          try {
            // 1. Permission (MANDATORY Android 13+)
            await FirebaseMessaging.instance.requestPermission();

            // 2. Get token
            String? token = await FirebaseMessaging.instance.getToken();

            if (token == null) {
              throw Exception("FCM Token NULL");
            }

            debugPrint("✅ DRIVER TOKEN: $token");

            // 3. Subscribe topics
            await FirebaseMessaging.instance.subscribeToTopic("rentox_driver");
            await FirebaseMessaging.instance.subscribeToTopic("rentox_all");

            debugPrint("✅ Subscribed to driver topics");

            // 4. Send token to backend
            await http.post(
              Uri.parse(ApiConfig.updateFcmToken),
              body: {
                "phone_number": storedPhone,
                "fcm_token": token,
              },
            );
          } catch (e) {
            debugPrint("❌ FCM SETUP FAILED: $e");
          }

          nextScreen = checAbdRoot();
        }
      } catch (e) {
        debugPrint("Check Error: $e");
      }
    }

    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightAmber, // Light Amber Background
      body: Center(
        child: ScaleTransition(
          scale: _animation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo Placeholder (Update path in pubspec.yaml)
              Image.asset(
                'assets/login_img.png',
                width: MediaQuery.of(context).size.width * 0.6,
                errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.directions_car_filled,
                    size: 100,
                    color: kPrimaryAmber),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
