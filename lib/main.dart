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
import 'booking_list.dart';
import 'trip_accepting.dart';
import 'services/notification_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final StreamController<RemoteMessage> notificationStreamController = StreamController<RemoteMessage>.broadcast();

// ✅ Professional Light Amber Theme Constants
const Color kPrimaryAmber = Color(0xFFFFB300);
const Color kLightAmber = Color(0xFFFFF8E1);
const Color kDarkText = Color(0xFF3E2723); // Fixed the typo here

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Safe Firebase Init
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("⚠️ Firebase.initializeApp error: $e");
  }

  // 2. Safe Notification Init
  try {
    await NotificationService.instance.initialize();
    await NotificationService.instance.setupFlutterNotifications();
  } catch (e) {
    debugPrint("⚠️ NotificationService init error: $e");
  }

  // 3. Safe Firebase Messaging Permission
  try {
    await FirebaseMessaging.instance.requestPermission();
  } catch (e) {
    debugPrint("⚠️ FirebaseMessaging requestPermission error: $e");
  }

  // 4. Safe Location & Service Check
  try {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      await _setupTrackingService();
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        await service.startService();
      }
    } else {
      debugPrint("⚠️ Location permission not granted. Background service not started.");
    }
  } catch (e) {
    debugPrint("⚠️ Location/Background service error in main: $e");
  }

  runApp(const RentoxApp());
}

/// ✅ Background Service Logic
Future<void> _setupTrackingService() async {
  try {
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
  } catch (e) {
    debugPrint("⚠️ _setupTrackingService error: $e");
  }
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
      // Background service continues running to keep location coordinates updated.
      // if (data['today_trip'] == false) {
      //   service.stopSelf();
      // }
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
      navigatorKey: navigatorKey,
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
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/check_version.php?app_type=driver&version=$currentVersion")
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["force_update"] == true) {
          final playStoreUrl = data["play_store_url"] ?? "";
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ForceUpdateScreen(playStoreUrl: playStoreUrl),
              ),
            );
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("Version Check Error: $e");
    }

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

    // Check if there was an initial message that opened the app
    try {
      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null && initialMessage.data['notification_type'] == 'new_booking') {
        final String? bookingId = initialMessage.data['booking_id'];
        if (bookingId != null && bookingId.isNotEmpty && storedPhone != null && storedPhone.isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => BookingListPage(phoneNumber: storedPhone)),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverTripPage(
                bookingId: bookingId,
                phoneNumber: storedPhone,
              ),
            ),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint("Error handling initial message: $e");
    }

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

class ForceUpdateScreen extends StatelessWidget {
  final String playStoreUrl;

  const ForceUpdateScreen({super.key, required this.playStoreUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: kLightAmber,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  size: 80,
                  color: kPrimaryAmber,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                "Update Required",
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kDarkText,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                "A new version of the app is available on the Play Store with important updates. Please update to continue using the application.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryAmber,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () async {
                    if (playStoreUrl.isNotEmpty) {
                      final uri = Uri.parse(playStoreUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                  child: Text(
                    "UPDATE NOW",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kDarkText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
