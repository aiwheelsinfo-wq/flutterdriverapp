import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'otp_verification_page.dart'; // Import OTP verification page
import 'dart:convert'; // This is essential for using jsonDecode
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Import secure storage

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();

  final FlutterSecureStorage storage = FlutterSecureStorage();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
    checkNet();
  }

  Future<void> checkNet() async {
    try {
      final response = await http.get(Uri.parse(
          'https://agnicarrental.com/2025/selectCarCostList.php?tripType=One-way'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load cars");
      }
    } catch (e) {
      print("❌ Error: $e");
      setState(() {
        isLoading = true;
      });
    }
  }

// Function to load stored phone number
  void _loadPhoneNumber() async {
    String? storedPhone = await storage.read(key: "phone_number");
    setState(() {
      _phoneController.text = storedPhone ?? '';
    });
  }

  // Your Fast2SMS API key
  String apiKey =
      "p9J1ofaxrnDXePcsUTdlRu630Vg7KQiWMC24OEmjwFSByh8AH5R5n6sSBzCuvQATbf2g87hV9mtqd0GD"; // Replace with your actual Fast2SMS API key

  // Method to generate random OTP
  String generateOTP(int length) {
    const characters = '0123456789';
    Random rand = Random();

    String otp = '';
    for (int i = 0; i < length; i++) {
      otp += characters[rand.nextInt(characters.length)];
    }

    return otp;
  }

  // Method to send OTP using Fast2SMS API
  Future<bool> sendOTP(String phoneNumber, String otp) async {
    String apiUrl =
        "https://www.fast2sms.com/dev/bulkV2?authorization=p9J1ofaxrnDXePcsUTdlRu630Vg7KQiWMC24OEmjwFSByh8AH5R5n6sSBzCuvQATbf2g87hV9mtqd0GD&route=dlt&sender_id=agni&message=170275&variables_values=$otp&flash=0&numbers=$phoneNumber&schedule_time=";

    var response = await http.get(Uri.parse(apiUrl));

    var jsonResponse = jsonDecode(response.body);
    return jsonResponse["return"] == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? Center(
              child: Text(
              "Internet is not available",
              style: TextStyle(
                fontSize: 20,
              ),
            ))
          : Container(
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        //+20 tex
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text(
                            '20+',
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 150,
                              color:
                                  Colors.white, // Simplified color definition
                              height: 0.6, // Adjust line height to reduce space
                            ),
                          ),
                        ),
                        //years
                        Padding(
                          padding: const EdgeInsets.only(top: 0),
                          child: Text(
                            'years',
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              color:
                                  Colors.white, // Fixed incorrect color syntax
                            ),
                          ),
                        ),
                        // Car Icon for Driver Login

                        Padding(
                          padding: const EdgeInsets.only(bottom: 40, top: 40),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                  20), // Apply rounded corners to shadow
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26, // Light shadow
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                  offset: Offset(0, 3), // Adds depth effect
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                  20), // Same rounded corners for the image
                              child: Image.asset(
                                'assets/loginTop.webp',
                                width: 500,
                                fit: BoxFit
                                    .fill, // Ensures the image fills the container
                              ),
                            ),
                          ),
                        ),

                        // Phone number input field
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Enter your phone number',
                              border: InputBorder.none,
                            ),
                            keyboardType: TextInputType.phone,
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Send OTP button with custom styling
                        ElevatedButton(
                          onPressed: () {
                            String phoneNumber = _phoneController.text.trim();
                            if (phoneNumber.isNotEmpty) {
                              String otp = generateOTP(6);
                              sendOTP(phoneNumber, otp).then((success) {
                                if (success) {
                                  // OTP sent successfully, navigate to OTP verification page
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => OTPVerificationPage(
                                        phoneNumber: phoneNumber,
                                        otp: otp,
                                      ),
                                    ),
                                  );
                                } else {
                                  Fluttertoast.showToast(
                                      msg: 'Failed to send OTP');
                                }
                              });
                            } else {
                              Fluttertoast.showToast(
                                  msg: 'Please enter a valid phone number');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 15.0, horizontal: 30.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            shadowColor: Colors.black26,
                            elevation: 5,
                          ),
                          child: const Text(
                            'Send OTP',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        // Footer contact details
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text(
                            'www.agnicarrental.com\nagnicarrental@gmail.com\n',
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              color: const Color.fromARGB(255, 74, 99, 207)
                                  .withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
