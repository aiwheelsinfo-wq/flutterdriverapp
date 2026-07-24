import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';

// Import your pages
import 'owner_reg_page.dart';
import 'sub_driver_page.dart';
import 'booking_list.dart';

class DriverOwnerSelectionPage extends StatefulWidget {
  const DriverOwnerSelectionPage({super.key});

  @override
  State<DriverOwnerSelectionPage> createState() =>
      _DriverOwnerSelectionPageState();
}

class _DriverOwnerSelectionPageState extends State<DriverOwnerSelectionPage> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  bool _isLoading = false;

  Future<void> _handleSelection(String type) async {
    setState(() => _isLoading = true);

    // Save selection locally
    await secureStorage.write(key: "userType", value: type);
    String? storedNumber = await secureStorage.read(key: "phone_number");

    final String apiUrl = type == "Vender"
        ? ApiConfig.statusChangeNotFilled
        : ApiConfig.statusChangeNotJoin;

    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        body: {"stored_number": storedNumber},
      ).timeout(const Duration(seconds: 10));

      var data = jsonDecode(response.body);

      if (data["success"] == true) {
        final statusVal = (data["current_status"] ?? data["new_status"] ?? "").toString().toLowerCase();
        if (type == "Vender") {
          if (statusVal == "active" || statusVal == "filled" || statusVal == "not car" || statusVal == "notified") {
            _navigateTo(BookingListPage(phoneNumber: storedNumber ?? ""));
          } else {
            _navigateTo(const OwnerRegPage());
          }
        } else {
          _navigateTo(const SubDriverPage());
        }
      } else {
        _showError(data["message"] ?? "Setup Failed");
      }
    } catch (e) {
      _showError("Network Error. Check your connection.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Professional Off-White
      body: Stack(
        children: [
          // Background Aesthetic Accents
          Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(
                radius: 120, backgroundColor: Colors.amber.withOpacity(0.05)),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 600), // tablet/web support
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildProgressIndicator(),
                      const SizedBox(height: 40),
                      _buildHeader(),
                      const SizedBox(height: 40),
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildSelectionCard(
                              title: "VENDOR / OWNER",
                              subtitle: "Manage Fleet & Fleet Owners",
                              // benefit:
                              //     "• Earn by providing cars\n• Manage multiple drivers",
                              icon: Icons.business_center_rounded,
                              onTap: () => _handleSelection("Vender"),
                            ),
                            const SizedBox(height: 20),
                            _buildSelectionCard(
                              title: "DRIVER",
                              subtitle: "Service provider for agencies",
                              icon: Icons.assignment_ind_rounded,
                              onTap: () => _handleSelection("Driver"),
                            ),
                            const SizedBox(height: 30),
                            _buildInfoSection(),
                          ],
                        ),
                      ),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.amber, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.amber, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2))),
        const Spacer(),
        Text("STEP 2/3",
            style: GoogleFonts.poppins(
                fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Choose Your Account",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF2D3436),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "How would you like to partner with Rentox Car Rental today?",
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Colors.grey[600],
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    // required String benefit,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.amber.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(15)),
                  child: Icon(icon, color: Colors.amber[800], size: 28),
                ),
                SizedBox(width: 15),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_rounded, color: Colors.amber),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.amber[800],
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blueGrey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "You can change your role later from the profile settings.",
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.blueGrey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Text("Need Assistance?",
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
            TextButton(
              onPressed: () {},
              child: Text(
                "Contact Rentox Support Team",
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.amber[900],
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white.withOpacity(0.8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.amber),
              SizedBox(height: 20),
              Text("Setting up your account...",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
