import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'tripLiveMaping.dart';
import 'api_config.dart';


class StartingKmInputPage extends StatefulWidget {
  final String bookingId;
  final String savedOtp;
  final String triptype;

  const StartingKmInputPage({
    super.key,
    required this.bookingId,
    required this.savedOtp,
    required this.triptype,
  });

  @override
  State<StartingKmInputPage> createState() => _StartingKmInputPageState();
}

class _StartingKmInputPageState extends State<StartingKmInputPage> {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _kmController = TextEditingController();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  bool _otpVerified = false;
  String? _errorText;
  bool _isSubmitting = false;

  // Professional Amber Palette
  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color accentAmber = Color(0xFFFF8F00);
  static const Color charcoal = Color(0xFF263238);
  static const Color bgLight = Color(0xFFFFFBF0);

  void _onOtpChanged(String value) {
    if (value.length == 4) {
      if (value == widget.savedOtp) {
        setState(() {
          _otpVerified = true;
          _errorText = null;
          // If trip type doesn't require KM, we could auto-submit,
          // but for UX safety, we let them press the button.
        });
        HapticFeedback.mediumImpact();
      } else {
        setState(() {
          _otpVerified = false;
          _errorText = "Incorrect OTP. Please check again.";
        });
        HapticFeedback.vibrate();
      }
    } else {
      setState(() {
        _otpVerified = false;
        _errorText = null;
      });
    }
  }

  Future<void> _submitStartTrip() async {
    final phoneNumber = await secureStorage.read(key: "phone_number");
    final km = _kmController.text.trim();

    // Logic for skipping KM input for specific trip types
    final bool isSkipKm =
        widget.triptype == "One-way" || widget.triptype == "Local-taxi";

    if (!isSkipKm) {
      if (km.isEmpty || int.tryParse(km) == null || int.parse(km) < 0) {
        _showSnackBar("⚠️ Please enter a valid starting KM", Colors.orange);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final Map<String, dynamic> requestBody = {
        'trip_id': widget.bookingId,
      };
      if (!isSkipKm) {
        requestBody['starting_km'] = int.parse(km);
      }

      final response = await http.post(
        Uri.parse(ApiConfig.saveStartingKm),

        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          _showSnackBar("✅ Trip started successfully!", Colors.green);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TripLiveMapping(
                  bookingId: widget.bookingId,
                  phoneNumber: phoneNumber!,
                ),
              ),
            );
          }
        } else {
          _showSnackBar(data['message'] ?? "Failed to start trip", Colors.red);
        }
      } else {
        _showSnackBar("❌ Server error. Please try again.", Colors.red);
      }
    } catch (e) {
      _showSnackBar("❌ Connection error. Check your internet.", Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    _kmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text("Verify & Start",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: charcoal,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator(color: primaryAmber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildBookingInfoCard(),
                  const SizedBox(height: 32),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child:
                        !_otpVerified ? _buildOtpSection() : _buildKmSection(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBookingInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: primaryAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.receipt_long_rounded,
                color: accentAmber, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("BOOKING ID: #${widget.bookingId}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: charcoal)),
                const SizedBox(height: 4),
                Text(widget.triptype.toUpperCase(),
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpSection() {
    return Column(
      key: const ValueKey(1),
      children: [
        const Icon(Icons.vibration_rounded, size: 64, color: primaryAmber),
        const SizedBox(height: 16),
        const Text("Trip Verification",
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: charcoal)),
        const SizedBox(height: 8),
        const Text("Please enter the 4-digit OTP provided by the customer",
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          onChanged: _onOtpChanged,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 20,
            color: charcoal,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: "",
            hintText: "0000",
            hintStyle: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 20,
              color: Colors.grey.shade400,
            ),
            errorText: _errorText,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: primaryAmber, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKmSection() {
    final bool isSkipKm =
        widget.triptype == "One-way" || widget.triptype == "Local-taxi";

    return Column(
      key: const ValueKey(2),
      children: [
        const Icon(Icons.check_circle_rounded, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        const Text("OTP Verified",
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green)),
        const SizedBox(height: 8),
        Text(
            isSkipKm
                ? "You are ready to start the trip!"
                : "Enter current odometer reading to begin",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        if (!isSkipKm)
          TextField(
            controller: _kmController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: "Starting Kilometers",
              labelStyle: const TextStyle(color: charcoal),
              prefixIcon: const Icon(Icons.speed_rounded, color: primaryAmber),
              filled: true,
              fillColor: Colors.white,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: primaryAmber, width: 2)),
            ),
          ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _submitStartTrip,
            style: ElevatedButton.styleFrom(
              backgroundColor: charcoal,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text("START TRIP NOW",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _otpVerified = false),
          child:
              const Text("Re-verify OTP", style: TextStyle(color: Colors.grey)),
        )
      ],
    );
  }
}
