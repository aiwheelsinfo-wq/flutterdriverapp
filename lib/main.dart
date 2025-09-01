import 'package:agnidriver2025/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'account_selection_page.dart';
import 'checkAndRoot.dart';
import 'login_page.dart'; // Import Login Page
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter is ready
  await Firebase.initializeApp(); // ✅ Initialize Firebase
  await FirebaseMessaging.instance
      .requestPermission(); // Request Notification Permissions
  await NotificationService.instance.initialize(); // Initialize Notifications

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FlutterSecureStorage storage = FlutterSecureStorage();
  bool isChecking = true; // To show a loading screen
  Widget initialScreen =
      const Scaffold(body: Center(child: CircularProgressIndicator()));

  @override
  void initState() {
    super.initState();
    checkStoredPhoneNumber();
  }

  Future<void> checkStoredPhoneNumber() async {
    String? storedPhone = await storage.read(key: "phone_number");

    if (storedPhone != null && storedPhone.isNotEmpty) {
      // Check if the phone exists in the database
      bool exists = await checkPhoneInDatabase(storedPhone);

      if (exists) {
        setState(() {
          initialScreen = checAbdRoot();
        });

        // Update FCM token in the background
      } else {
        setState(() {
          initialScreen = const LoginPage();
        });
      }
    } else {
      setState(() {
        initialScreen = const LoginPage();
      });
    }
  }

  Future<bool> checkPhoneInDatabase(String phoneNumber) async {
    String apiUrl = "https://agnicarrental.com/driver2025/checkPhone.php";

    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        body: {"phone_number": phoneNumber},
      );

      var jsonResponse = jsonDecode(response.body);
      return jsonResponse["success"] == true;
    } catch (e) {
      print("Error checking phone: $e");
      return false; // Default to false if there's an error
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Hides the debug banner
      title: 'Agni Driver App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: initialScreen, // Show appropriate screen
    );
  }
}
