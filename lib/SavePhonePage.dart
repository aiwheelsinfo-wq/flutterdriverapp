import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart'; // Ensure this is in pubspec.yaml
import 'account_selection_page.dart';
import 'api_config.dart';


class SavePhonePage extends StatefulWidget {
  final String phoneNumber;

  const SavePhonePage({super.key, required this.phoneNumber});

  @override
  _SavePhonePageState createState() => _SavePhonePageState();
}

class _SavePhonePageState extends State<SavePhonePage>
    with SingleTickerProviderStateMixin {
  bool isError = false;
  String currentStatus = "Establishing Secure Link...";
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    savePhoneNumber();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _updateStatus(String msg) {
    if (mounted) setState(() => currentStatus = msg);
  }

  Future<void> savePhoneNumber() async {
    _updateStatus("Refining Security Protocols...");

    try {
      _updateStatus("Syncing Profile with Rentox...");

      String apiUrl = ApiConfig.saveDriverPhone;


      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        debugPrint("FCM Token fetch failed: $e");
      }

      var response = await http.post(
        Uri.parse(apiUrl),
        body: {
          "phone_number": widget.phoneNumber,
          "fcm_token": fcmToken ?? "",
        },
      ).timeout(const Duration(seconds: 15));

      var jsonResponse = jsonDecode(response.body);

      if (jsonResponse["success"] == true) {
        _updateStatus("Identity Verified Successfully!");

        await storage.write(key: "phone_number", value: widget.phoneNumber);

        await Future.delayed(const Duration(milliseconds: 1200));

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 800),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const DriverOwnerSelectionPage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
            (route) => false,
          );
        }
      } else {
        _handleError("Server rejected request");
      }
    } catch (e) {
      debugPrint("🔥 SAVE PHONE ERROR: $e");
      _handleError("Network failure. Retry.");
    }
  }

  void _handleError(String msg) {
    if (mounted) {
      setState(() {
        isError = true;
        currentStatus = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: isError,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await storage.delete(key: "phone_number");
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA), // Professional Off-White
        body: LayoutBuilder(
          builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Stack(
                  children: [
                    // Decorative Amber Background Accent
                    Positioned(
                      top: -150,
                      left: -100,
                      child: CircleAvatar(
                        radius: 200,
                        backgroundColor: Colors.amber.withOpacity(0.05),
                      ),
                    ),

                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Spacer(),

                            // 1. Animated Visual
                            _buildAnimatedLoader(),

                            const SizedBox(height: 50),

                            // 2. Status Card
                            _buildStatusCard(constraints),

                            const Spacer(),

                            // 3. Footer Branding
                            _buildFooter(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

  Widget _buildAnimatedLoader() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isError
                  ? Colors.red.withOpacity(0.1)
                  : Colors.amber.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 10,
            )
          ],
        ),
        child: Center(
          child: isError
              ? const Icon(Icons.cloud_off_rounded,
                  color: Colors.redAccent, size: 50)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.vpn_key_rounded,
                        color: Colors.amber[700], size: 40),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.amber[700],
                      ),
                    )
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(BoxConstraints constraints) {
    double cardWidth = constraints.maxWidth > 600 ? 450 : double.infinity;

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            isError ? "Connection Failed" : "Authenticating Profile",
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isError ? Colors.redAccent : Colors.grey[600],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            currentStatus,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 30),
          if (!isError)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                minHeight: 6,
                backgroundColor: Colors.amber[50],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber[700]!),
              ),
            )
          else
            _buildRetryButton(),
        ],
      ),
    );
  }

  Widget _buildRetryButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() {
            isError = false;
            currentStatus = "Re-establishing Link...";
          });
          savePhoneNumber();
        },
        icon: const Icon(Icons.refresh_rounded),
        label: const Text("RETRY CONNECTION"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded,
                color: Colors.amber[700], size: 16),
            const SizedBox(width: 8),
            Text(
              "Rentox End-to-End Encryption",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          "Ensuring your data privacy & security",
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[400]),
        ),
      ],
    );
  }
}
