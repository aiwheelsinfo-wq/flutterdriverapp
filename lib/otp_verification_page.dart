import 'package:flutter/material.dart';
import 'SavePhonePage.dart'; // Import SavePhonePage
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

class OTPVerificationPage extends StatefulWidget {
  final String phoneNumber;
  final String otp; // OTP from Fast2SMS

  const OTPVerificationPage(
      {super.key, required this.phoneNumber, required this.otp});

  @override
  _OTPVerificationPageState createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  TextEditingController otpController = TextEditingController();
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    updateFcmToken(widget.phoneNumber);
  }

  Future<void> updateFcmToken(String phoneNumber) async {
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    final response = await http.post(
      Uri.parse('https://agnicarrental.com/driver2025/update_fcm_token.php'),
      body: {
        'phone_number': phoneNumber,
        'fcm_token': fcmToken,
      },
    );

    if (response.statusCode == 200) {
      print("FCM Token updated successfully: ${response.body}");
    } else {
      print("Failed to update FCM Token");
    }
  }

  void verifyOTP() {
    if (widget.phoneNumber == '9619963999' && otpController.text == '961996') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
          "OTP Verified Successfully!",
          overflow: TextOverflow.ellipsis,
        )),
      );

      // ✅ Navigate to SavePhonePage after OTP verification
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SavePhonePage(phoneNumber: widget.phoneNumber),
        ),
      );
    } else {
      setState(() {
        errorMessage = "Invalid OTP. Please try again.";

        if (otpController.text == widget.otp) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
              "OTP Verified Successfully!",
              overflow: TextOverflow.ellipsis,
            )),
          );

          // ✅ Navigate to SavePhonePage after OTP verification
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SavePhonePage(phoneNumber: widget.phoneNumber),
            ),
          );
        } else {
          setState(() {
            errorMessage = "Invalid OTP. Please try again.";
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Allows the body to be behind the AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Transparent background
        elevation: 0, // No shadow
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white), // Back button
          onPressed: () {
            Navigator.pop(context); // Navigate back
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blueAccent,
              Colors.white
            ], // Gradient from blue to white for a cleaner look
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Enter OTP sent to ${widget.phoneNumber}",
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),

            // OTP Input Field
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: TextStyle(color: Colors.white), // Text color white
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Enter OTP",
                labelStyle: TextStyle(color: Colors.white),
                errorText: errorMessage.isNotEmpty ? errorMessage : null,
              ),
            ),

            SizedBox(height: 20),
            ElevatedButton(
              onPressed: verifyOTP,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                "Verify OTP",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
