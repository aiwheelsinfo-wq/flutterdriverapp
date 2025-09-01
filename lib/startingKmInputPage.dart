import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'tripLiveMaping.dart';

class StartingKmInputPage extends StatefulWidget {
  final String bookingId;
  final String savedOtp;

  const StartingKmInputPage({
    Key? key,
    required this.bookingId,
    required this.savedOtp,
  }) : super(key: key);

  @override
  _StartingKmInputPageState createState() => _StartingKmInputPageState();
}

class _StartingKmInputPageState extends State<StartingKmInputPage> {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _kmController = TextEditingController();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  bool _otpVerified = false;
  String? _errorText;
  bool _isSubmitting = false;

  void _onOtpChanged(String value) {
    if (value.length == 4) {
      if (value == widget.savedOtp) {
        setState(() {
          _otpVerified = true;
          _errorText = null;
        });
      } else {
        setState(() {
          _otpVerified = false;
          _errorText = "Incorrect OTP";
        });
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
    if (km.isEmpty || int.tryParse(km) == null || int.parse(km) < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("Please enter a valid positive number for starting KM")),
      );
      return;
    }

    if (km.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Please enter the starting KM")));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://agnicarrental.com/driver2025/save_starting_km.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'trip_id': widget.bookingId,
          'starting_km': int.parse(km),
        }),
      );

      final data = json.decode(response.body);

      if (data['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Trip started successfully.")),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TripLiveMapping(
              bookingId: widget.bookingId,
              phoneNumber: phoneNumber!,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Failed to start trip")),
        );
      }
    } catch (e) {}
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
      appBar: AppBar(title: Text("Start Trip")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isSubmitting
            ? Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (!_otpVerified) ...[
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: InputDecoration(
                        labelText: "Enter OTP from Customer",
                        errorText: _errorText,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: _onOtpChanged,
                    ),
                  ],
                  if (_otpVerified) ...[
                    TextField(
                      controller: _kmController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Enter Starting KM",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _submitStartTrip,
                      child: Text("Submit"),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
