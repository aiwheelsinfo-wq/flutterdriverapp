import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'compleated_List.dart';
import 'api_config.dart';


class EndingKmInputPage extends StatefulWidget {
  final String bookingId;

  const EndingKmInputPage({super.key, required this.bookingId});

  @override
  _EndingKmInputPageState createState() => _EndingKmInputPageState();
}

class _EndingKmInputPageState extends State<EndingKmInputPage> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  // Controllers
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _closingKmController = TextEditingController();
  final TextEditingController _permitChargeController = TextEditingController();
  final TextEditingController _parkingChargeController =
      TextEditingController();
  final TextEditingController _tollChargeController = TextEditingController();

  // State
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isOtpVerified = false;
  String? _otpFromBackend;
  String? userType;

  // Trip Data Variables (Preserved from original logic)
  String? date,
      time,
      returnDate,
      returnTime,
      startingDate,
      startingTime,
      startingKm,
      distance,
      tripType;
  double? kmRate,
      driverAllowance,
      agniShare,
      dailyLimit,
      extraKMAmount,
      extraHoursAmount,
      extraKMAmountForDriver,
      extraHoursAmountForDriver,
      packageKm,
      packageHours,
      baseAmount,
      driverRate,
      totalAmountDB,
      agniAmountDB,
      vendorAmountDB,
      agentCommission,
      gstPercent;

  // Theme Colors
  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color accentAmber = Color(0xFFFF8F00);
  static const Color charcoal = Color(0xFF263238);
  static const Color bgLight = Color(0xFFFFFBF0);

  @override
  void initState() {
    super.initState();
    _fetchTripDetails();
  }

  Future<void> _fetchTripDetails() async {
    userType = await secureStorage.read(key: "userType");
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.tripLiveMappingBackend),

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
          startingDate = data['starting_date'];
          startingTime = data['starting_time'];
          startingKm = data['starting_km']?.toString();
          distance = data['distance']?.toString();
          agniShare = double.tryParse(data['agni_share'] ?? '0') ?? 0;
          kmRate = double.tryParse(data['kmRate'] ?? '0') ?? 0;
          dailyLimit = double.tryParse(data['daily_limit'] ?? '0') ?? 0;
          driverAllowance =
              double.tryParse(data['driver_allowance'] ?? '0') ?? 0;
          tripType = data['trip_type'];
          extraKMAmount = double.tryParse(data['extraKMAmount'] ?? '0') ?? 0;
          extraHoursAmount =
              double.tryParse(data['extraHoursAmount'] ?? '0') ?? 0;
          extraKMAmountForDriver =
              double.tryParse(data['extraKMAmountFroDriver'] ?? '0') ?? 0;
          extraHoursAmountForDriver =
              double.tryParse(data['extraHoursAmountForDriver'] ?? '0') ?? 0;
          packageKm = double.tryParse(data['packageKm'] ?? '0') ?? 0;
          packageHours = double.tryParse(data['packageHours'] ?? '0') ?? 0;
          baseAmount = double.tryParse(data['baseAmount'] ?? '0') ?? 0;
          driverRate = double.tryParse(data['driverRate'] ?? '0') ?? 0;
          totalAmountDB = double.tryParse(data['total_amount'] ?? '0') ?? 0;
          agniAmountDB = double.tryParse(data['agni_amount'] ?? '0') ?? 0;
          vendorAmountDB = double.tryParse(data['vendor_amount'] ?? '0') ?? 0;
          agentCommission =
              double.tryParse(data['agent_commission'] ?? '0') ?? 0;
          gstPercent = double.tryParse(data['gstPercent'] ?? '0') ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      _showError("Failed to fetch trip details.");
    }
  }

  Future<void> _updateBookingStatus() async {
    setState(() => _isSubmitting = true);

    double? finalAgniAmount, finalVendorAmount, finalTotalAmount;
    double parking = double.tryParse(_parkingChargeController.text) ?? 0;
    double toll = double.tryParse(_tollChargeController.text) ?? 0;
    double permit = double.tryParse(_permitChargeController.text) ?? 0;

    final double closingKm = double.tryParse(_closingKmController.text) ?? 0;
    final double sKm = double.tryParse(startingKm ?? '0') ?? 0;

    // Validate closing KM for non-skip trip types (Local-Duty, Round-Trip)
    final bool isKmRequired = tripType != 'One-way' && tripType != 'Local-taxi';
    if (isKmRequired) {
      if (_closingKmController.text.trim().isEmpty) {
        _showError("⚠️ Please enter a closing kilometer reading.");
        setState(() => _isSubmitting = false);
        return;
      }
      if (closingKm < sKm) {
        _showError("⚠️ Closing KM ($closingKm) cannot be less than Starting KM ($sKm).");
        setState(() => _isSubmitting = false);
        return;
      }
    }

    try {
      final double runningKm = closingKm - sKm;

      final dateTimeFormat = DateFormat("yyyy-MM-dd HH:mm");
      final now = dateTimeFormat.format(DateTime.now());
      final endDateTime = dateTimeFormat.parse(now);
      final startDateTime = dateTimeFormat.parse("$startingDate $startingTime");
      final duration = endDateTime.difference(startDateTime);
      final hoursDifference = duration.inHours;

      // Logic Branching (As per your original formulas)
      if (tripType == 'One-way') {
        finalTotalAmount = totalAmountDB! + parking + toll + permit;
        finalVendorAmount = (totalAmountDB! * 0.90) + parking + toll + permit;
        finalAgniAmount = totalAmountDB! * 0.10;
      } else if (tripType == 'Local-taxi') {
        finalTotalAmount = totalAmountDB! + parking + toll + permit;
        finalVendorAmount = vendorAmountDB! + parking + toll + permit;
        finalAgniAmount = agniAmountDB;
      } else if (tripType == 'Local-Duty') {
        double exKmCharge = 0,
            exHrsCharge = 0,
            exKmChargeDr = 0,
            exHrsChargeDr = 0;
        
        final int minutes = duration.inMinutes.remainder(60);
        int roundedHours = duration.inHours;
        if (minutes > 30) {
          roundedHours += 1;
        }

        if (runningKm > packageKm!) {
          double exKM = runningKm - packageKm!;
          exKmCharge = exKM * extraKMAmount!;
          exKmChargeDr = exKM * extraKMAmountForDriver!;
        }
        if (roundedHours > packageHours!) {
          double exHrs = roundedHours - packageHours!;
          exHrsCharge = exHrs * extraHoursAmount!;
          exHrsChargeDr = exHrs * extraHoursAmountForDriver!;
        }
        double localDriverAllowance = 0.0;
        bool isStartBefore5AM = startDateTime.hour < 5;
        bool isEndAfter1130PM = endDateTime.hour > 23 ||
            (endDateTime.hour == 23 && endDateTime.minute > 30);
        if (isStartBefore5AM || isEndAfter1130PM) {
          localDriverAllowance = driverAllowance ?? 0.0;
        }

        double totalBeforGst = baseAmount! + exKmCharge + exHrsCharge;
        finalTotalAmount = totalBeforGst +
            (totalBeforGst * (gstPercent ?? 0) / 100) +
            toll +
            parking +
            permit +
            agentCommission! +
            (agentCommission! * (gstPercent ?? 0) / 100) +
            localDriverAllowance;
        finalVendorAmount = driverRate! +
            exKmChargeDr +
            exHrsChargeDr +
            toll +
            parking +
            permit +
            localDriverAllowance;
        finalAgniAmount = finalTotalAmount - finalVendorAmount;
      } else if (tripType == 'Round-Trip') {
        int days = 1;
        try {
          final bStartStr = date ?? '';
          final bReturnStr = returnDate ?? '';
          if (bStartStr.isNotEmpty && bReturnStr.isNotEmpty && bStartStr != '0000-00-00' && bReturnStr != '0000-00-00') {
            try {
              final bStart = DateFormat('dd MMM yyyy').parse(bStartStr);
              final bReturn = DateFormat('dd MMM yyyy').parse(bReturnStr);
              days = bReturn.difference(bStart).inDays + 1;
            } catch (_) {
              final bStart = DateTime.parse(bStartStr);
              final bReturn = DateTime.parse(bReturnStr);
              days = bReturn.difference(bStart).inDays + 1;
            }
          }
        } catch (e) {
          debugPrint("Error parsing booked dates: $e");
        }
        if (days <= 0) days = 1;
        double mKm = max(runningKm, dailyLimit! * days);
        double drAllowXDays = driverAllowance! * days;
        double bAmount = mKm * (kmRate ?? 0);
        double beforGst = bAmount + agentCommission!;
        double gst = beforGst * gstPercent! / 100;
        finalAgniAmount = mKm * agniShare! + agentCommission! + gst;
        finalVendorAmount = (bAmount - mKm * agniShare!) +
            drAllowXDays +
            parking +
            toll +
            permit;
        finalTotalAmount = bAmount +
            drAllowXDays +
            parking +
            toll +
            permit +
            agentCommission! +
            gst;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.updateEndTripDetails),

        body: {
          'booking_id': widget.bookingId,
          'status': 'Completed',
          'closing_km': closingKm.toString(),
          'running_km': runningKm.toString(),
          'closing_date': DateTime.now().toIso8601String(),
          'closing_time': DateTime.now().toIso8601String(),
          'totalAmount': finalTotalAmount?.toStringAsFixed(2),
          'vendor_amount': finalVendorAmount?.toStringAsFixed(2),
          'agni_amount': finalAgniAmount?.toStringAsFixed(2),
          'trip_type': tripType ?? '',
          'toll_charge': _tollChargeController.text,
          'parking_charge': _parkingChargeController.text,
          'permit_charge': _permitChargeController.text,
        },
      );

      if (json.decode(response.body)['success']) {
        _showSuccess("Trip successfully completed!");
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const CompleatedList()),
          (route) => false,
        );
      }
    } catch (e) {
      _showError("Update failed. Please check inputs.");
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green));

  @override
  Widget build(BuildContext context) {
    bool isOneWay = tripType?.toLowerCase() == 'one-way';
    bool isLocalTaxi = tripType?.toLowerCase() == 'local-taxi';

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text("Complete Journey",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: charcoal,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryAmber))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isLocalTaxi && !isOneWay) _buildTripTicket(),
                  const SizedBox(height: 24),
                  if (!isLocalTaxi) _buildInputSection(isOneWay),
                  const SizedBox(height: 24),
                  _buildOtpSection(),
                  const SizedBox(height: 40),
                  _buildSubmitButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildTripTicket() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: charcoal,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("JOURNEY START",
                    style: TextStyle(
                        color: primaryAmber,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                Text("#${widget.bookingId}",
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ticketData("Date", startingDate),
                _ticketData("Time", startingTime),
                _ticketData("Starting KM", "$startingKm km"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ticketData(String label, String? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value ?? "-",
            style: const TextStyle(
                color: charcoal, fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  Widget _buildInputSection(bool isOneWay) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel("Final Readings & Expenses"),
        const SizedBox(height: 12),
        if (!isOneWay)
          _customTextField(
              _closingKmController,
              "Closing Kilometer",
              "0.00"
                  "Enter final KM",
              Icons.speed),
        _customTextField(_parkingChargeController, "Parking Charges", "0.00",
            Icons.local_parking),
        if (!isOneWay) ...[
          _customTextField(
              _tollChargeController, "Toll Charges", "0.00", Icons.toll),
          _customTextField(_permitChargeController, "Permit Charges", "0.00",
              Icons.assignment_turned_in),
        ],
      ],
    );
  }

  Widget _buildOtpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel("Customer Verification"),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _isOtpVerified ? Colors.green : Colors.grey.shade200),
          ),
          child: Column(
            children: [
              const Text("Ask customer for the 4-digit completion OTP",
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 15,
                    color: charcoal),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (val) {
                  if (val.length == 4) {
                    if (val == _otpFromBackend) {
                      setState(() => _isOtpVerified = true);
                      FocusScope.of(context).unfocus();
                    } else {
                      _showError("OTP Mismatch");
                    }
                  } else {
                    setState(() => _isOtpVerified = false);
                  }
                },
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "0000",
                  hintStyle: TextStyle(color: Colors.grey.shade200),
                  border: InputBorder.none,
                ),
              ),
              if (_isOtpVerified)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text("Verified",
                          style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed:
            (_isOtpVerified && !_isSubmitting) ? _updateBookingStatus : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: charcoal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("FINISH TRIP",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text.toUpperCase(),
        style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1));
  }

  Widget _customTextField(TextEditingController controller, String label,
      String hint, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontWeight: FontWeight.bold, color: charcoal),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: primaryAmber, size: 20),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
