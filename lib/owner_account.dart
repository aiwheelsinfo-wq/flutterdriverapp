import 'dart:convert';
import 'package:agnidriver2025/login_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'checkAndRoot.dart';
import 'api_config.dart';
import 'settlements_page.dart';


class OwnerProfileScreen extends StatefulWidget {
  const OwnerProfileScreen({super.key});

  @override
  _OwnerProfileScreenState createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  Map<String, dynamic>? ownerData;
  bool isLoading = true;
  bool documentCard = false;
  String? userType;

  // Theme Colors
  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color accentAmber = Color(0xFFFF8F00);
  static const Color charcoal = Color(0xFF263238);
  static const Color bgLight = Color(0xFFFFFBF0);

  @override
  void initState() {
    super.initState();
    fetchOwnerDetails();
  }

  Future<void> fetchOwnerDetails() async {
    try {
      userType = await secureStorage.read(key: "userType");
      String? phoneNumber = await secureStorage.read(key: "phone_number");

      final response = await http.get(
        Uri.parse(
            "${ApiConfig.driverDetailsFetching}?phone_number=$phoneNumber"),
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == "success") {
          setState(() {
            ownerData = data["data"];
            documentCard =
                ownerData!["license_no"]?.toString().trim().isNotEmpty ?? false;
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> logout() async {
    await secureStorage.delete(key: "phone_number");
    await secureStorage.delete(key: "userType");
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text("My Account",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: charcoal,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryAmber))
          : ownerData == null
              ? _buildErrorState()
              : _buildProfileBody(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text("No profile data found",
              style: TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildProfileBody() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildSectionTitle("Identity & Contact"),
                    _buildInfoCard([
                      _infoTile(Icons.phone, "Phone Number",
                          ownerData!["phone_number"]),
                      _infoTile(
                          Icons.email, "Email Address", ownerData!["email"]),
                    ]),
                    const SizedBox(height: 20),
                    _buildSectionTitle("Payments & Settlements"),
                    _buildInfoCard([
                      ListTile(
                        leading: const Icon(Icons.account_balance_wallet, color: primaryAmber, size: 20),
                        title: const Text("Vendor Settlements", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: charcoal)),
                        subtitle: const Text("Track trip advance settlements", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SettlementsPage(
                                phoneNumber: ownerData!["phone_number"] ?? "",
                              ),
                            ),
                          );
                        },
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _buildSectionTitle("Personal Details"),
                    _buildInfoCard([
                      _infoTile(Icons.business, "Agency Name",
                          ownerData!["agency_name"]),
                      _infoTile(Icons.cake, "Date of Birth",
                          ownerData!["date_of_birth"]),
                      _infoTile(Icons.location_on, "Full Address",
                          ownerData!["driver_address"]),
                      _infoTile(Icons.location_city, "City",
                          ownerData!["driver_city"]),
                      _infoTile(
                          Icons.pin_drop, "Pin Code", ownerData!["pin_code"]),
                    ]),
                    if (documentCard) ...[
                      const SizedBox(height: 20),
                      _buildSectionTitle("Verified Documents"),
                      _buildInfoCard([
                        _infoTile(Icons.badge, "License Number",
                            ownerData!["license_no"]),
                        _infoTile(Icons.category, "License Type",
                            ownerData!["license_type"]),
                        _infoTile(Icons.fingerprint, "Aadhaar Card",
                            ownerData!["adhaar_card_no"]),
                        _infoTile(Icons.credit_card, "PAN Card",
                            ownerData!["pan_card_no"]),
                      ]),
                    ],
                    const SizedBox(height: 40),
                    _buildLogoutButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String initials = ownerData!["full_name"] != null
        ? ownerData!["full_name"]
            .trim()
            .split(' ')
            .map((l) => l[0])
            .take(2)
            .join()
            .toUpperCase()
        : "??";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 30, top: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: primaryAmber,
                child: Text(initials,
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
              const CircleAvatar(
                radius: 14,
                backgroundColor: Colors.green,
                child: Icon(Icons.verified, color: Colors.white, size: 16),
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(
            (ownerData!["full_name"] ?? "Vendor").toUpperCase(),
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: charcoal),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                color: primaryAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(
              (userType ?? "Owner").toUpperCase(),
              style: const TextStyle(
                  fontSize: 12,
                  color: accentAmber,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: charcoal.withOpacity(0.5),
              letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _infoTile(IconData icon, String label, String? value) {
    return ListTile(
      leading: Icon(icon, color: primaryAmber, size: 20),
      title:
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      subtitle: Text(
        (value == null || value.isEmpty) ? "Not Provided" : value.toUpperCase(),
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: charcoal),
      ),
      trailing: (value == null || value.isEmpty)
          ? const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 16)
          : null,
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showLogoutDialog,
        icon: const Icon(Icons.logout, size: 18),
        label: const Text("LOGOUT ACCOUNT",
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Logout Confirmation"),
        content:
            const Text("Are you sure you want to log out of your account?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: charcoal))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Navigator.pop(context);
              logout();
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
