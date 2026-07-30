import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'login_page.dart';
import 'api_config.dart';
import 'booking_list.dart';
import 'owner_reg_page.dart';

class SimpleAccountScreen extends StatelessWidget {
  const SimpleAccountScreen({super.key});

  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color charcoal = Color(0xFF263238);
  static const Color bgLight = Color(0xFFFFFBF0);

  Future<void> _switchToVendor(BuildContext context) async {
    const secureStorage = FlutterSecureStorage();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      ),
    );

    try {
      await secureStorage.write(key: "userType", value: "Vender");
      String? storedNumber = await secureStorage.read(key: "phone_number");

      var response = await http.post(
        Uri.parse(ApiConfig.statusChangeNotFilled),
        body: {"stored_number": storedNumber ?? ""},
      ).timeout(const Duration(seconds: 10));

      if (context.mounted) Navigator.pop(context);

      var data = jsonDecode(response.body);

      if (data["success"] == true) {
        final statusVal = (data["current_status"] ?? data["new_status"] ?? "").toString().toLowerCase();
        if (statusVal == "active" || statusVal == "filled" || statusVal == "not car" || statusVal == "notified") {
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => BookingListPage(phoneNumber: storedNumber ?? "")),
              (route) => false,
            );
          }
        } else {
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const OwnerRegPage()),
              (route) => false,
            );
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data["message"] ?? "Vendor switch failed")),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error switching to Vendor mode. Please try again.")),
        );
      }
    }
  }

  Future<void> logout(BuildContext context) async {
    const storage = FlutterSecureStorage();

    await storage.delete(key: "phone_number");
    await storage.delete(key: "userType");

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Logout Confirmation"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: charcoal)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () {
              Navigator.pop(context);
              logout(context);
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text(
          "My Account",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: charcoal,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: primaryAmber,
                child: Icon(Icons.person, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                "DRIVER ACCOUNT",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: charcoal,
                ),
              ),
              const SizedBox(height: 30),

              // Switch to Vendor Mode Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _switchToVendor(context),
                  icon: const Icon(Icons.sync_alt, color: Colors.white),
                  label: const Text(
                    "SWITCH TO VENDOR APP",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAmber,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showLogoutDialog(context),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text(
                    "LOGOUT ACCOUNT",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
