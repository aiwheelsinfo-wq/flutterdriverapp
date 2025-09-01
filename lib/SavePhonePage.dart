import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Import secure storage
import 'account_selection_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class SavePhonePage extends StatefulWidget {
  final String phoneNumber;

  const SavePhonePage({super.key, required this.phoneNumber});

  @override
  _SavePhonePageState createState() => _SavePhonePageState();
}

class _SavePhonePageState extends State<SavePhonePage> {
  bool isSaving = true;
  String message = "Saving phone number...";
  String? storedPhoneNumber; // Variable to hold stored phone number
  final FlutterSecureStorage storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    savePhoneNumber();
  }

  void savePhoneNumber() async {
    String apiUrl = "https://agnicarrental.com/driver2025/saveDriverPhone.php";

    String? fcmToken = await FirebaseMessaging.instance.getToken();

    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        body: {"phone_number": widget.phoneNumber, "fcm_token": fcmToken},
      );

      // Check if response is valid JSON
      try {
        var jsonResponse = jsonDecode(response.body);

        if (jsonResponse["success"] == true) {
          // ✅ Store phone number securely
          await storage.write(key: "phone_number", value: widget.phoneNumber);

          // ✅ Navigate to Trip Selection Page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DriverOwnerSelectionPage(),
            ),
          );
        } else {
          setState(() {
            isSaving = false;
            message = "Failed to Save Phone Number.";
          });
        }
      } catch (jsonError) {
        print("JSON Parsing Error: $jsonError");
        setState(() {
          isSaving = false;
          message = "Invalid JSON response!";
        });
      }
    } catch (e) {
      print("Error: $e");
      setState(() {
        isSaving = false;
        message = "Error saving phone number!";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
        "Save Phone Number",
        overflow: TextOverflow.ellipsis,
      )),
      body: Center(
        child: isSaving
            ? CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    message,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18, color: Colors.black),
                  ),
                  SizedBox(height: 20),
                  storedPhoneNumber != null
                      ? Text(
                          "Stored Phone: $storedPhoneNumber",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        )
                      : SizedBox(), // If null, show nothing
                ],
              ),
      ),
    );
  }
}
