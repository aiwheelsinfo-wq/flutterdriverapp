import 'dart:math';
import 'package:intl/intl.dart';
import 'package:agnidriver2025/booking_list.dart';
import 'package:agnidriver2025/join_sub_driver_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'compleated_List.dart';
// Make sure you have this import

class EndingKmInputPage extends StatefulWidget {
  final String bookingId;

  EndingKmInputPage({required this.bookingId});

  @override
  _EndingKmInputPageState createState() => _EndingKmInputPageState();
}

class _EndingKmInputPageState extends State<EndingKmInputPage> {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _closingKmController = TextEditingController();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  final TextEditingController _permit_chargeController =
      TextEditingController();
  final TextEditingController _parking_chargeController =
      TextEditingController();
  final TextEditingController _toll_chargeController = TextEditingController();

  bool _isOtpVerified = false;
  String? _otpFromBackend; // OTP from the backend
  String? userType;

  String? date;
  String? time;
  String? returnDate;
  String? returnTime;
  String? starting_date;
  String? starting_time;
  String? starting_km;
  String? distance;
  String? car_type;
  double? kmRate;
  double? driver_allowance;
  double? agniShare;
  double? dilyLimit;
  String? trip_type;
  double? extraKMAmount;
  double? extraHoursAmount;
  double? extraKMAmountFroDriver;
  double? extraHoursAmountForDriver;
  double? packageKm;
  double? packageHours;
  double? baseAmount;
  double? driverRate;
  double? total_amountDB;
  double? agni_amountDB;
  double? vendor_amountDB;
  double? toll_charge;
  double? parking_charge;
  double? permit_charge;
  double? agent_commission;
  double? gstPercent;

  @override
  void initState() {
    super.initState();
    _fetchOtpFromBackend(); // Fetch OTP on screen load
  }

  // Fetch OTP from the backend based on booking ID
  Future<void> _fetchOtpFromBackend() async {
    userType = await secureStorage.read(key: "userType");

    try {
      final response = await http.post(
        Uri.parse(
          "https://agnicarrental.com/driver2025/trip_live_mapping_backend.php",
        ),
        body: {'action': 'get_booking_otp', 'booking_id': widget.bookingId},
      );

      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          _otpFromBackend = data['otp'];
          date = data['date'];
          time = data['time'];
          returnDate = data['return_date'];
          returnTime = data['return_time'];
          starting_date = data['starting_date'];
          starting_time = data['starting_time'];
          starting_km = data['starting_km']?.toString();
          distance = data['distance']?.toString();
          agniShare = double.tryParse(data['agni_share'] ?? '0') ?? 0;
          kmRate = double.tryParse(data['kmRate'] ?? '0') ?? 0;
          dilyLimit = double.tryParse(data['daily_limit'] ?? '0') ?? 0;
          driver_allowance =
              double.tryParse(data['driver_allowance'] ?? '0') ?? 0;
          trip_type = data['trip_type'];
          extraKMAmount = double.tryParse(data['extraKMAmount'] ?? '0') ?? 0;
          extraHoursAmount =
              double.tryParse(data['extraHoursAmount'] ?? '0') ?? 0;
          extraKMAmountFroDriver =
              double.tryParse(data['extraKMAmountFroDriver'] ?? '0') ?? 0;
          extraHoursAmountForDriver =
              double.tryParse(data['extraHoursAmountForDriver'] ?? '0') ?? 0;
          packageKm = double.tryParse(data['packageKm'] ?? '0') ?? 0;
          packageHours = double.tryParse(data['packageHours'] ?? '0') ?? 0;
          baseAmount = double.tryParse(data['baseAmount'] ?? '0') ?? 0;
          driverRate = double.tryParse(data['driverRate'] ?? '0') ?? 0;
          total_amountDB = double.tryParse(data['total_amount'] ?? '0') ?? 0;
          agni_amountDB = double.tryParse(data['agni_amount'] ?? '0') ?? 0;
          vendor_amountDB = double.tryParse(data['vendor_amount'] ?? '0') ?? 0;
          agent_commission =
              double.tryParse(data['agent_commission'] ?? '0') ?? 0;
          gstPercent = double.tryParse(data['gstPercent'] ?? '0') ?? 0;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to fetch OTP or trip details")),
        );
      }
    } catch (e) {
      print("Error fetching OTP and trip details: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching OTP and trip details")),
      );
    }
  }

  // Verify OTP and show the closing KM input field
  void _verifyOtp() {
    if (_otpController.text.length == 4) {
      if (_otpController.text == _otpFromBackend) {
        setState(() {
          _isOtpVerified = true; // OTP verified successfully
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("OTP does not match")));
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("OTP must be 4 digits")));
    }
  }

  // Update the booking status and closing KM
  Future<void> _updateBookingStatus() async {
    double? agniBaceAmount;
    double? vendorAmount;
    double? totalAmount;

    parking_charge =
        double.tryParse(_parking_chargeController.text.toString()) ?? 0;

    toll_charge = double.tryParse(_toll_chargeController.text.toString()) ?? 0;
    permit_charge =
        double.tryParse(_permit_chargeController.text.toString()) ?? 0;

    try {
      // Convert closing and starting KM to integers
      final double closingKm = double.tryParse(_closingKmController.text) ?? 0;
      final double startingKm = double.tryParse(starting_km ?? '0') ?? 0;
      final double runningKm = closingKm - startingKm;

      final dateTimeFormat = DateFormat("yyyy-MM-dd HH:mm");
      final now = dateTimeFormat.format(DateTime.now());
      final endDateTime = dateTimeFormat.parse(now);
      final startDateTime = dateTimeFormat.parse(
        "$starting_date $starting_time",
      );

      double? baceAmount;

      final duration = endDateTime.difference(startDateTime);
      final hoursDifference = duration.inHours;

      if (trip_type == 'One-way') {
        totalAmount =
            total_amountDB! + parking_charge! + toll_charge! + permit_charge!;
        agniBaceAmount = agni_amountDB;
        vendorAmount =
            vendor_amountDB! + parking_charge! + toll_charge! + permit_charge!;
      }

      if (trip_type == 'Local-taxi') {
        double maxKm = max(runningKm, double.tryParse(distance ?? '0') ?? 0);
        totalAmount = (baseAmount ?? 0) +
            (maxKm * (kmRate ?? 0)) +
            toll_charge! +
            parking_charge! +
            permit_charge!;

        vendorAmount = totalAmount;

        agniBaceAmount = 0;
      }

      if (trip_type == 'Local-Duty') {
        totalAmount = baseAmount;
        agniBaceAmount = agniShare;
        vendorAmount = driverRate;

        double extrakmXextraCharge = 0;
        double extraHrsXextraCharge = 0;
        double extraKmXextraChargeForDriver = 0;
        double extraHrsXextraChargeForDriver = 0;

        double totalAmountBeforGst = 0;

        if (runningKm > packageKm!) {
          double extraKM = runningKm - packageKm!;
          extrakmXextraCharge = extraKM * extraKMAmount!;
          extraKmXextraChargeForDriver = extraKM * extraKMAmountFroDriver!;
        }

        if (hoursDifference > packageHours!) {
          double extraHrs = hoursDifference - packageHours!;
          extraHrsXextraCharge = extraHrs * extraHoursAmount!;
          extraHrsXextraChargeForDriver = extraHrs * extraHoursAmountForDriver!;
        }

        totalAmountBeforGst =
            baseAmount! + extrakmXextraCharge + extraHrsXextraCharge;
        totalAmount = totalAmountBeforGst +
            (totalAmountBeforGst * (gstPercent ?? 0) / 100) +
            (toll_charge ?? 0) +
            (parking_charge ?? 0) +
            (permit_charge ?? 0) +
            (agent_commission ?? 0) +
            ((agent_commission ?? 0) * (gstPercent ?? 0) / 100);

        vendorAmount = driverRate! +
            extraKmXextraChargeForDriver +
            extraHrsXextraChargeForDriver +
            (toll_charge ?? 0) +
            (parking_charge ?? 0) +
            (permit_charge ?? 0);

        agniBaceAmount = totalAmount - vendorAmount;
      }

      if (trip_type == 'Round-Trip') {
        Duration diff = endDateTime.difference(startDateTime);
        int days = diff.inDays;

        // int kmDays = days;
        // int allowanceDays = days;
        var maxKm;
        double? driver_allowanceXdays;

        if (startDateTime.day == endDateTime.day) {
          days += 1;

          // allowanceDays += 1;
        } else {
          days += 1;
          print('33333: $days');
          if (diff < Duration(hours: 24)) {
            days += 1;
            // allowanceDays += 1;
          }

          // if (endDateTime.hour >= 2) {
          //   kmDays += 1;
          // }

          //driver_allowanceXdays = driver_allowance! * allowanceDays;

          if ((endDateTime.hour == 23)) {
            days += 1;
          }

          if (endDateTime.hour < 6 ||
              (endDateTime.hour == 6 && endDateTime.minute < 30)) {
            days += 1;
          }

          if (startDateTime.hour < 6 ||
              (startDateTime.hour == 6 && startDateTime.minute < 30)) {
            days += 1;
          }
        }
        maxKm = max(runningKm, dilyLimit! * days);
        driver_allowanceXdays = driver_allowance! * days;
        baceAmount = (maxKm ?? 0) * (kmRate ?? 0);

        double beforGst = baceAmount! + agent_commission!;
        double gst = beforGst * gstPercent! / 100;

        agniBaceAmount = maxKm * agniShare! + agent_commission + gst;
        double venderBaceAmount = baceAmount - maxKm * agniShare!;
        totalAmount = baceAmount +
            driver_allowanceXdays +
            parking_charge! +
            toll_charge! +
            permit_charge! +
            agent_commission! +
            gst;
        vendorAmount = venderBaceAmount +
            driver_allowanceXdays +
            parking_charge! +
            toll_charge! +
            permit_charge!;
      }

      final response = await http.post(
        Uri.parse(
          "https://agnicarrental.com/driver2025/update_endTrip_Details.php",
        ),
        body: {
          'booking_id': widget.bookingId,
          'status': 'Completed',
          'closing_km': closingKm.toString(),
          'running_km': runningKm.toString(), // Send running_km to backend
          'closing_date': DateTime.now().toIso8601String(),
          'closing_time': DateTime.now().toIso8601String(),
          'totalAmount': totalAmount?.toStringAsFixed(2),
          'vendor_amount': vendorAmount?.toStringAsFixed(2),
          'agni_amount': agniBaceAmount?.toStringAsFixed(2),
          'trip_type': trip_type ?? '',
          'toll_charge': _toll_chargeController.text.toString(),
          'parking_charge': _parking_chargeController.text.toString(),
          'permit_charge': _permit_chargeController.text.toString(),
        },
      );

      final data = json.decode(response.body);

      if (data['success']) {
        print("tttttttttt : $data");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Booking successfully completed")),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) =>
                userType == "Driver" ? CompleatedList() : CompleatedList(),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to update booking")));
      }
    } catch (e) {
      print("Error updating booking: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error updating booking  ")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Trip Completion",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: false,
        backgroundColor: Colors.blueGrey,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildCard(
                title: "Trip Information",
                children: [
                  _buildInfoRow("Start Date", starting_date),
                  _buildInfoRow("Start Time", starting_time),
                  _buildInfoRow("Starting KM", starting_km),
                ],
              ),
              const SizedBox(height: 16),
              _buildCard(
                title: "Charges Input",
                children: [
                  _buildTextField(
                      _closingKmController, "Closing KM", "Enter Closing KM"),
                  _buildTextField(_toll_chargeController, "Toll Charge",
                      "Enter Toll Charge"),
                  _buildTextField(_parking_chargeController, "Parking Charge",
                      "Enter Parking Charge"),
                  _buildTextField(_permit_chargeController, "Permit Charge",
                      "Enter Permit Charge"),
                ],
              ),
              const SizedBox(height: 16),
              _buildCard(
                title: "OTP Verification",
                children: [
                  _buildTextField(
                    _otpController,
                    "OTP",
                    "Enter 4-digit OTP",
                    maxLength: 4,
                    onChanged: (value) {
                      if (value.length == 4) {
                        if (_closingKmController.text.isEmpty) {
                          _showSnack("Closing KM cannot be empty");
                          _otpController.clear();
                        } else {
                          _verifyOtp();
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_isOtpVerified)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  icon: const Icon(
                    Icons.check,
                    color: Colors.white,
                  ),
                  label: const Text(
                    "Trip Completed",
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () {
                    if (_closingKmController.text.isEmpty) {
                      _showSnack("Closing KM cannot be empty");
                    } else {
                      _updateBookingStatus();
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    int? maxLength,
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: maxLength,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value ?? '-', style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
