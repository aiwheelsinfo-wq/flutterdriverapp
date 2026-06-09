import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'SavePhonePage.dart';
import 'api_config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  bool isNetAvailable = true;
  bool isSendingOtp = false;
  bool otpSent = false;
  String? generatedOtp;

  late AnimationController _fadeController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
    checkNet();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> checkNet() async {
    try {
      final response = await http.get(Uri.parse(
          "${ApiConfig.selectCarCostList}?tripType=One-way"));
      setState(() => isNetAvailable = response.statusCode == 200);
    } catch (e) {
      setState(() => isNetAvailable = false);
    }
  }

  void _loadPhoneNumber() async {
    String? storedPhone = await storage.read(key: "phone_number");
    if (storedPhone != null) {
      setState(() => _phoneController.text = storedPhone);
    }
  }

  String generateOTP(int length) {
    return List.generate(length, (i) => Random().nextInt(10)).join();
  }

  Future<void> handleSendOtp() async {
    String phoneNumber = _phoneController.text.trim();
    if (phoneNumber.length != 10) {
      Fluttertoast.showToast(msg: "Please enter a valid 10-digit number");
      return;
    }

    setState(() => isSendingOtp = true);
    String otp = generateOTP(6);
    debugPrint("🔥 DEBUG: Generated OTP for $phoneNumber is: $otp");

    try {
      String apiUrl =
          "${ApiConfig.fast2smsUrl}?authorization=p9J1ofaxrnDXePcsUTdlRu630Vg7KQiWMC24OEmjwFSByh8AH5R5n6sSBzCuvQATbf2g87hV9mtqd0GD&route=dlt&sender_id=agni&message=170275&variables_values=$otp&flash=0&numbers=$phoneNumber";
      var response = await http.get(Uri.parse(apiUrl));
      var json = jsonDecode(response.body);

      if (json["return"] == true) {
        setState(() {
          otpSent = true;
          generatedOtp = otp;
        });
        Fluttertoast.showToast(msg: "OTP sent to $phoneNumber");
      } else {
        String errMsg = json["message"] ?? "Failed to send OTP.";
        Fluttertoast.showToast(msg: "SMS Error: $errMsg");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Service unavailable: $e");
    } finally {
      setState(() => isSendingOtp = false);
    }
  }

  void handleLogin() {
    if (_otpController.text.trim() == generatedOtp && generatedOtp != null) {
      // Defer secure storage writing until backend verification succeeds in SavePhonePage
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SavePhonePage(phoneNumber: _phoneController.text)),
      );
    } else {
      Fluttertoast.showToast(msg: "Invalid OTP Code");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Professional soft background
      body: !isNetAvailable ? _buildNoNetUI() : _buildMainUI(),
    );
  }

  Widget _buildMainUI() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Stack(
                children: [
                  // Top Design Accent
                  Positioned(
                    top: -100,
                    right: -100,
                    child: CircleAvatar(
                      radius: 150,
                      backgroundColor: Colors.amber.withOpacity(0.1),
                    ),
                  ),

                  FadeTransition(
                    opacity: _fadeIn,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 100),
                          _buildHeader(),
                          const SizedBox(height: 30),
                          _buildLoginCard(constraints),
                          const Spacer(),
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
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            // color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Image.asset("assets/login_img.png",
              width: MediaQuery.of(context).size.width * 0.6),
        ),
        // const SizedBox(height: 20),
        // const Text(
        //   "Agni Car Rental",
        //   style: TextStyle(
        //     color: Color(0xFF2D3436),
        //     fontSize: 20,
        //     fontWeight: FontWeight.w900,
        //     letterSpacing: -0.5,
        //   ),
        // ),
        const SizedBox(height: 5),
        const Text(
          "Premium Journey Starts Here",
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(BoxConstraints constraints) {
    // Limits width on tablets to keep it looking pro
    double cardWidth = constraints.maxWidth > 600 ? 450 : double.infinity;

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "Welcome Back",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Login to manage your car bookings",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 15),
          _buildTextField(
            label: "Phone Number",
            controller: _phoneController,
            icon: Icons.phone_android_rounded,
            keyboard: TextInputType.phone,
            suffix: _buildOtpActionBtn(),
          ),
          const SizedBox(height: 15),
          _buildTextField(
            label: "Enter OTP",
            controller: _otpController,
            icon: Icons.lock_outline_rounded,
            keyboard: TextInputType.number,
            suffix: otpSent
                ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                : null,
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: Text("Need Help?",
                  style: TextStyle(
                      color: Colors.amber[800], fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 2),
          _buildVerifyButton(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required TextInputType keyboard,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F5),
            borderRadius: BorderRadius.circular(15),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboard,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.amber[700], size: 20),
              suffixIcon: suffix,
              border: InputBorder.none,
              hintText:
                  label == "Enter OTP" ? "0 0 0 0 0 0" : "10-digit number",
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpActionBtn() {
    bool isReady = _phoneController.text.length == 10;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: isSendingOtp
          ? const UnconstrainedBox(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.amber),
              ),
            )
          : TextButton(
              onPressed: isReady ? handleSendOtp : null,
              style: TextButton.styleFrom(
                backgroundColor:
                    isReady ? Colors.amber[50] : Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                otpSent ? "RESEND" : "GET OTP",
                style: TextStyle(
                    color: isReady ? Colors.amber[800] : Colors.grey[400],
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
    );
  }

  Widget _buildVerifyButton() {
    bool canLogin = otpSent && _otpController.text.length >= 4;
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: canLogin ? handleLogin : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber[700],
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.amber[100],
          elevation: canLogin ? 4 : 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: const Text(
          "LOGIN TO ACCOUNT",
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Text(
          "By signing in, you agree to our Terms of Service",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield, color: Colors.amber[700], size: 16),
            const SizedBox(width: 8),
            const Text(
              "Secure Car Booking Environment",
              style: TextStyle(
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoNetUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.amber[200], size: 100),
            const SizedBox(height: 20),
            const Text("Offline Mode",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
                "Please check your internet connection to access booking data.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: checkNet,
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.amber[700]),
              child: const Text("RETRY CONNECTION",
                  style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}
