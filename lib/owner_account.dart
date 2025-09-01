import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'booking_list.dart';
import 'checkAndRoot.dart';
import 'document_expered_page.dart';
import 'join_sub_driver_page.dart';
import 'test.dart';
import 'update_document_screen.dart';

class OwnerProfileScreen extends StatefulWidget {
  const OwnerProfileScreen({Key? key}) : super(key: key);

  @override
  _OwnerProfileScreenState createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  Map<String, dynamic>? ownerData;
  bool isLoading = true;
  bool agencyCard = false;
  bool documentCard = false;
  String? userType;
  String? vehicle_no;

  @override
  void initState() {
    super.initState();
    fetchOwnerDetails();
  }

  Future<void> fetchOwnerDetails() async {
    userType = await secureStorage.read(key: "userType");
    print("yyyyyyyyyyyy $userType");
    String? phoneNumber = await secureStorage.read(key: "phone_number");
    final response = await http.get(
      Uri.parse(
        "https://agnicarrental.com/driver2025/driver_details_fetching.php?phone_number=$phoneNumber",
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data["status"] == "success") {
        setState(() {
          ownerData = data["data"];
          vehicle_no = ownerData!['vehicle_id'];
          agencyHideFunction();
          licenLicenseDocumentshidefunction();
          isLoading = false;
        });
      } else {
        setState(() {
          ownerData = null;
          isLoading = false;
        });
      }
    } else {
      setState(() {
        ownerData = null;
        isLoading = false;
      });
    }
  }

  void agencyHideFunction() {
    setState(() {
      if (ownerData != null && ownerData!["agency_name"] != null) {
        agencyCard = ownerData!["agency_name"].toString().trim().isNotEmpty;
      } else {
        agencyCard = false;
      }
    });
  }

  void licenLicenseDocumentshidefunction() {
    setState(() {
      if (ownerData != null && ownerData!["license_no"] != null) {
        documentCard = ownerData!["license_no"].toString().trim().isNotEmpty;
      } else {
        documentCard = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "My Account",
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => checAbdRoot(),
              ),
              (route) => false,
            );
          },
        ),
        backgroundColor: Colors.blueGrey,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ownerData == null
              ? const Center(
                  child: Text("No data found", overflow: TextOverflow.ellipsis),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(30.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (ownerData!["full_name"] ?? "Unknown Name")
                                  .toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              ownerData!["phone_number"] ?? "",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              ownerData!["email"] ?? "No Email",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Personal Details",
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Divider(thickness: 1),
                            if (agencyCard)
                              ProfileCard(
                                icon: Icons.apartment,
                                title: "Agency Name",
                                value: ownerData!["agency_name"],
                              ),
                            ProfileCard(
                              icon: Icons.calendar_today,
                              title: "Date of Birth",
                              value: ownerData!["date_of_birth"],
                            ),
                            ProfileCard(
                              icon: Icons.location_on,
                              title: "Address",
                              value: ownerData!["driver_address"],
                            ),
                            ProfileCard(
                              icon: Icons.location_city,
                              title: "City",
                              value: ownerData!["driver_city"],
                            ),
                            ProfileCard(
                              icon: Icons.pin,
                              title: "Pin Code",
                              value: ownerData!["pin_code"],
                            ),
                            if (documentCard) ...[
                              const SizedBox(height: 20),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Documents",
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Divider(thickness: 1),
                              ProfileCard(
                                icon: Icons.badge,
                                title: "Driveing License Number",
                                value: ownerData!["license_no"],
                              ),
                              ProfileCard(
                                icon: Icons.assignment,
                                title: "Driveing License Type",
                                value: ownerData!["license_type"],
                              ),
                              ProfileCard(
                                icon: Icons.credit_card,
                                title: "Aadhaar Card No",
                                value: ownerData!["adhaar_card_no"],
                              ),
                              ProfileCard(
                                icon: Icons.credit_card,
                                title: "PAN Card No",
                                value: ownerData!["pan_card_no"],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class ProfileCard extends StatelessWidget {
  final String title;
  final String? value;
  final IconData icon;

  const ProfileCard({
    Key? key,
    required this.title,
    this.value,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          value ?? "Not Available",
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
