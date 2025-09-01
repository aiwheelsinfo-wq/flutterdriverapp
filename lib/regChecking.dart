import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'driver_reg_success.dart';
import 'trip_accepting.dart';
import 'driver_form_reg.dart';

class RegCheckingPage extends StatefulWidget {
  final String? phoneNumber;
  final String bookingId;

  const RegCheckingPage({super.key, this.phoneNumber, required this.bookingId});

  @override
  _RegCheckingPageState createState() => _RegCheckingPageState();
}

class _RegCheckingPageState extends State<RegCheckingPage> {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  String? storedPhoneNumber;
  String? status; // "active" or "inactive"
  bool isLoading = true; // Show loading until API call is done

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
  }

  Future<void> _loadPhoneNumber() async {
    try {
      String? phone = await storage.read(key: "phone_number");
      setState(() {
        storedPhoneNumber = phone ?? "Not Available"; // Fallback if not found
      });

      if (phone != null) {
        await _checkRegistrationStatus(phone); // Pass the non-null phone
      }
    } catch (e) {
      print("Error loading phone number: $e");
    }
  }

  Future<void> _checkRegistrationStatus(String phoneNumber) async {
    String apiUrl = "https://agnicarrental.com/driver2025/regStatusCheck.php";

    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        body: {"phone_number": phoneNumber},
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);

        setState(() {
          status = jsonResponse["success"] == true
              ? jsonResponse["status"]
              : "unknown";
          isLoading = false;
        });

        if (status == "active") {
          _navigateToBookingList(phoneNumber);
        } else if (status == "filled") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => SubmitSuccessPage(
                    message: "Driver updated successfully!",
                    phoneNumber: widget.phoneNumber!)),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => DriverFormPage(phoneNumber: phoneNumber)),
          );
        }
      } else {
        setState(() {
          status = "error";
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error checking status: $e");
      setState(() {
        status = "error";
        isLoading = false;
      });
    }
  }

  void _navigateToBookingList(String phoneNumber) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => DriverTripPage(
              phoneNumber: phoneNumber, bookingId: widget.bookingId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(), // Loading spinner
    );
  }
}
