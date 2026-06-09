import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'checkAndRoot.dart';

class SubmitSuccessPage extends StatefulWidget {
  final String message;
  final String? phoneNumber; // This can be null

  const SubmitSuccessPage(
      {super.key, this.message = "Submission Successful!", this.phoneNumber});

  @override
  State<SubmitSuccessPage> createState() => _SubmitSuccessPageState();
}

class _SubmitSuccessPageState extends State<SubmitSuccessPage> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 80),
              SizedBox(height: 20),
              Text(
                widget.message,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  String contactNumber = '8422001616';
                  if (Platform.isAndroid) {
                    String url =
                        'whatsapp://send?phone=$contactNumber&text=Hello, I am a driver for Agni Car Rental. I am unable to accept trips due to my account being inactive. Please assist in activating my account at the earliest. Thank you!';

                    // Launch the WhatsApp URL
                    await launchUrl(Uri.parse(url));

                    String? storedNumber =
                        await secureStorage.read(key: "phone_number");

                    // After launching WhatsApp, clear the navigation history and navigate to a new screen
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              checAbdRoot()), // Your new screen
                      (Route<dynamic> route) =>
                          false, // Remove all previous routes
                    );
                  }
                },
                child: Text(
                  'WhatsApp Verification',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
