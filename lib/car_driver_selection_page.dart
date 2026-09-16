import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';
import 'booking_list.dart';
import 'vendor_wallet_page.dart';
import 'package:google_fonts/google_fonts.dart';

class CarDriverSelectionScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic>? bookingData;
  const CarDriverSelectionScreen({super.key, required this.bookingId, this.bookingData});

  @override
  _CarDriverSelectionScreenState createState() =>
      _CarDriverSelectionScreenState();
}

class _CarDriverSelectionScreenState extends State<CarDriverSelectionScreen> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  List<Map<String, dynamic>> driverWithVehicle = [];
  List<Map<String, dynamic>> driverWithVendor = [];
  List<String> vehicles = [];
  List<String> drivers = [];
  String? selectedVehicle;
  String? selectedDriver;
  bool isLoading = true;
  bool isTripAccepted = false;
  bool isSubmitting = false;
  String? phoneNumber;

  Map<String, String> vehicleStatus = {};
  Map<String, String> driverStatus = {};

  double? totalAmount;
  double? vendorAmount; // Raw vendor_amount from API — for local taxi this IS the customer's fare
  double? paidAmount;
  String? tripType;
  String? paymentType;
  bool isFetchingBooking = true;
  double? walletBalance;
  double? minWalletBalance;
  bool isWalletEligible = true;

  // Theme Colors
  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color lightAmber = Color(0xFFFFF8E1);
  static const Color darkCharcoal = Color(0xFF263238);
  static const Color errorRed = Color(0xFFD32F2F);

  @override
  void initState() {
    super.initState();
    fetchData();
    _fetchBookingDetails();
    _fetchWalletStatus();
  }

  Future<void> _fetchWalletStatus() async {
    String? phone = await secureStorage.read(key: "phone_number");
    if (phone == null || phone.isEmpty) return;
    try {
      final uri = Uri.parse("${ApiConfig.vendorWallet}?action=get_wallet&phone_number=$phone");
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          if (mounted) {
            setState(() {
              walletBalance = (data['wallet_balance'] as num?)?.toDouble() ?? 0.0;
              minWalletBalance = (data['min_wallet_balance'] as num?)?.toDouble() ?? 0.0;
              isWalletEligible = walletBalance! > minWalletBalance!;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching wallet status: $e");
    }
  }

  Future<void> _fetchBookingDetails() async {
    // 1. Try to use passed bookingData
    if (widget.bookingData != null) {
      final bd = widget.bookingData!;
      String tType = bd['trip_type']?.toString() ?? '';
      bool isLocalTaxi = tType.toLowerCase().contains('local') && tType.toLowerCase().contains('taxi');

      double? parsedFare;

      // Priority 1: total_amount field (most reliable)
      if (bd['total_amount'] != null) {
        parsedFare = double.tryParse(bd['total_amount'].toString());
      }

      // Priority 2: amount field
      if ((parsedFare == null || parsedFare == 0) && bd['amount'] != null) {
        parsedFare = double.tryParse(bd['amount'].toString());
      }

      // Priority 3: vendor_amount field
      if ((parsedFare == null || parsedFare == 0) && bd['vendor_amount'] != null) {
        double vendorAmt = double.tryParse(bd['vendor_amount'].toString()) ?? 0.0;
        if (vendorAmt > 0) {
          // For local taxi: vendor_amount == total_amount (100%)
          // For others: vendor_amount == 90% of total, so reverse to get total
          parsedFare = isLocalTaxi ? vendorAmt : (vendorAmt / 0.90);
        }
      }

      double agentComm = double.tryParse(bd['agent_commission']?.toString() ?? '0') ?? 0.0;
      if (agentComm > 0 && parsedFare != null && parsedFare > agentComm) {
        parsedFare = parsedFare - agentComm;
      }

      if (parsedFare != null && parsedFare > 0) {
        setState(() {
          totalAmount = parsedFare;
          // Store vendor_amount directly — for local taxi this equals total customer fare
          vendorAmount = double.tryParse(bd['vendor_amount']?.toString() ?? '');
          tripType = tType;
          paymentType = bd['payment_type']?.toString();
          paidAmount = double.tryParse(bd['paid_amount']?.toString() ?? '') ?? 0.0;
          isFetchingBooking = false;
        });
        return;
      }
    }

    // 2. Fallback to API call
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.tripLiveMappingBackend),
        body: {'action': 'get_booking_otp', 'booking_id': widget.bookingId.toString()},
      );
      final data = json.decode(response.body);
      if (data['success'] == true) {
        double rawTot = double.tryParse(data['total_amount']?.toString() ?? '') ?? 0.0;
        double aComm = double.tryParse(data['agent_commission']?.toString() ?? '0') ?? 0.0;
        double cleanTot = (aComm > 0 && rawTot > aComm) ? (rawTot - aComm) : rawTot;
        setState(() {
          totalAmount = cleanTot;
          tripType = data['trip_type'];
          paymentType = data['payment_type'];
          paidAmount = double.tryParse(data['paid_amount']?.toString() ?? '') ?? 0.0;
          isFetchingBooking = false;
        });
      } else {
        setState(() => isFetchingBooking = false);
      }
    } catch (e) {
      setState(() => isFetchingBooking = false);
    }
  }


  Widget _buildFinancialSummary() {
    if (isFetchingBooking) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: primaryAmber)),
      );
    }

    if (totalAmount == null || totalAmount == 0) {
      return const SizedBox.shrink();
    }

    if (tripType == 'Round-Trip') {
      return const SizedBox.shrink();
    }

    double fare = totalAmount!;
    bool isLocalTaxi = (tripType?.toLowerCase() ?? '').contains('local') && (tripType?.toLowerCase() ?? '').contains('taxi');
    bool isLocalDuty = (tripType?.toLowerCase() ?? '').contains('duty');

    double baseFare = fare;
    double gstAmount = isLocalTaxi ? 0.0 : (baseFare * 0.05);
    double customerTotal = baseFare + gstAmount;
    double platformFee = isLocalDuty
        ? (customerTotal * 0.10)
        : ((vendorAmount != null && vendorAmount! > 0 && customerTotal > vendorAmount!)
            ? (isLocalTaxi ? (customerTotal - vendorAmount!) : (baseFare * 0.10))
            : (baseFare * 0.10));
    double vendorEarnings = customerTotal - (platformFee + gstAmount);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: primaryAmber, size: 22),
              const SizedBox(width: 8),
              Text(
                "Fare & Earnings Summary",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: darkCharcoal,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildSummaryRow("Base Trip Fare", "₹${baseFare.toStringAsFixed(0)}", isHighlight: false),
          if (gstAmount > 0) ...[
            const SizedBox(height: 12),
            _buildSummaryRow("GST (5%)", "₹${gstAmount.toStringAsFixed(0)}", isHighlight: false),
          ],
          const SizedBox(height: 12),
          _buildSummaryRow(
            "Collect from Customer", 
            "₹${customerTotal.toStringAsFixed(0)}", 
            isHighlight: true, 
            highlightColor: primaryAmber,
            subtitle: "100% payable by customer at trip end (Cash / UPI)",
          ),
          const SizedBox(height: 12),
          _buildSummaryRow("Platform Fee (10%)", "₹${platformFee.toStringAsFixed(0)} (Wallet Deducted)", isHighlight: false),
          if (gstAmount > 0) ...[
            const SizedBox(height: 12),
            _buildSummaryRow("GST (5%)", "₹${gstAmount.toStringAsFixed(0)} (Wallet Deducted)", isHighlight: false),
          ],
          const SizedBox(height: 12),
          _buildSummaryRow(
            "Your Net Earnings", 
            "₹${vendorEarnings.toStringAsFixed(0)}", 
            isHighlight: true, 
            highlightColor: Colors.green,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade800, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    gstAmount > 0
                        ? "Collect ₹${customerTotal.toStringAsFixed(0)} directly from customer. Platform fee (₹${platformFee.toStringAsFixed(0)}) + 5% GST (₹${gstAmount.toStringAsFixed(0)}) will be automatically deducted from your prepaid wallet upon trip completion."
                        : "Customer pays 100% directly to you. Platform fee is deducted automatically from your prepaid wallet upon trip completion.",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label, 
    String value, {
    required bool isHighlight,
    Color? highlightColor,
    Color? valueColor,
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: isHighlight ? 13 : 12,
                  fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                  color: isHighlight ? darkCharcoal : Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: isHighlight ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4) : null,
              decoration: isHighlight
                  ? BoxDecoration(
                      color: (highlightColor ?? primaryAmber).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: isHighlight ? 15 : 13,
                  fontWeight: FontWeight.bold,
                  color: isHighlight ? (highlightColor ?? primaryAmber) : (valueColor ?? darkCharcoal),
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
          ),
        ]
      ],
    );
  }

  Future<void> fetchData() async {
    phoneNumber = await secureStorage.read(key: "phone_number");
    String apiUrl =
        "${ApiConfig.carDriverSelectionPage}?phone_number=$phoneNumber";
    String carsUrl =
        "${ApiConfig.carListForVendor}?vendor_id=$phoneNumber";

    try {
      final response = await http.get(Uri.parse(apiUrl));
      final carsResponse = await http.get(Uri.parse(carsUrl));

      if (response.statusCode == 200 && carsResponse.statusCode == 200) {
        final data = jsonDecode(response.body);
        final carsData = jsonDecode(carsResponse.body);

        if (data["status"] == "success" && carsData["status"] == true) {
          final driverVehicleData =
              data["data"]["driver_with_vehicle"] as List<dynamic>;
          final driverVendorData =
              data["data"]["driver_with_vendor"] as List<dynamic>;
          final carsList = carsData["data"] as List<dynamic>;

          setState(() {
            driverWithVehicle = driverVehicleData
                .map((item) => {
                      "full_name": item["full_name"],
                      "phone_number": item["phone_number"],
                      "vehicle_number": item["vehicle_number"],
                      "availability_status":
                          item["availability_status"] ?? "available",
                    })
                .toList();

            driverWithVendor = driverVendorData
                .map((item) => {
                      "full_name": item["full_name"],
                      "phone_number": item["phone_number"],
                      "availability_status":
                          item["availability_status"] ?? "available",
                    })
                .toList();

            // Populate vehicles from the vendor's actual active/approved cars list
            vehicles = carsList
                .where((car) => car["status"] != "inactive")
                .map((car) => car["vehicle_number"].toString())
                .toSet()
                .toList();

            drivers = driverWithVendor
                .map((item) => "${item["full_name"]}\n${item["phone_number"]}")
                .toSet()
                .toList();

            // Map vehicle status based on today's bookings in the car list
            vehicleStatus = {
              for (var car in carsList)
                car["vehicle_number"].toString(): _isBookedToday(car["bookings"] ?? []) ? "conflict" : "available"
            };

            driverStatus = {
              for (var d in driverWithVendor)
                "${d["full_name"]}\n${d["phone_number"]}":
                    d["availability_status"]
            };

            selectedVehicle = vehicles.cast<String?>().firstWhere(
                (v) => vehicleStatus[v] != "conflict",
                orElse: () => null);

            selectedDriver = drivers.cast<String?>().firstWhere(
                (d) => driverStatus[d] != "conflict",
                orElse: () => null);

            isLoading = false;
          });
        } else {
          throw Exception(data["message"] ?? carsData["message"] ?? "Unknown error");
        }
      } else {
        throw Exception('Failed to load data from server');
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  bool _isBookedToday(List bookings) {
    String today = DateTime.now().toString().split(" ")[0];
    return bookings.any((b) {
      if (b["date"] != today) return false;
      String status = b["status"]?.toString() ?? "";
      return status != "Completed" && status != "Cancelled" && status != "Customer Cancelled";
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: darkCharcoal),
    );
  }

  Future<void> _submitForm() async {
    bool driverConflict =
        selectedDriver != null && driverStatus[selectedDriver!] == "conflict";
    bool vehicleConflict = selectedVehicle != null &&
        vehicleStatus[selectedVehicle!] == "conflict";

    if (driverConflict || vehicleConflict) {
      _showConflictDialog(driverConflict, vehicleConflict);
      return;
    }

    // 🔒 Wallet Balance Pre-Check
    bool isLocalOrOneWay = (tripType?.toLowerCase() ?? '').contains('taxi') ||
        (tripType?.toLowerCase() ?? '').contains('local') ||
        (tripType?.toLowerCase() ?? '').contains('one-way') ||
        (tripType?.toLowerCase() ?? '').contains('one way');
    if (isLocalOrOneWay && walletBalance != null && minWalletBalance != null && !isWalletEligible) {
      _showLowWalletBalanceDialog(
        "Insufficient wallet balance (₹${walletBalance!.toStringAsFixed(2)}). Minimum ₹${minWalletBalance!.toStringAsFixed(0)} required to accept trips. Please recharge your wallet."
      );
      return;
    }

    setState(() => isSubmitting = true);

    String? phoneNumber = await secureStorage.read(key: "phone_number");
    String vehicleId = selectedVehicle!;
    String driverId = selectedDriver!.split('\n').last;
    int? bookingId = int.tryParse(widget.bookingId.toString());

    var data = {
      'driver_id': driverId,
      'vehicle_id': vehicleId,
      'booking_id': bookingId,
      'vender_id': phoneNumber,
    };

    try {
      var response = await http.post(
        Uri.parse(ApiConfig.submitCarDriverSelectionPage),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      final resData = jsonDecode(response.body);

      if (resData['success'] == true) {
        // ✅ Show success dialog
        _showStatusDialog(
          "Success",
          "Assignment completed successfully.",
          Icons.check_circle,
          Colors.green,
        );

        // ✅ Delay a bit so user can see success message
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() => isSubmitting = false);
          }
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) => BookingListPage(
                      phoneNumber: phoneNumber.toString(),
                    )),
            (route) => false,
          );
        });
      } else {
        setState(() => isSubmitting = false);
        if (resData['status'] == 'low_wallet_balance') {
          _showLowWalletBalanceDialog(resData['message'] ?? "Insufficient wallet balance.");
        } else {
          _showStatusDialog(
            "Warning",
            resData['message'] ?? "Selection conflict detected.",
            Icons.warning,
            errorRed,
          );
        }
      }
    } catch (e) {
      setState(() => isSubmitting = false);
      _showStatusDialog("Error", e.toString(), Icons.error, errorRed);
    }
  }

  void _showLowWalletBalanceDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: const [
            Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFFF8F00), size: 26),
            SizedBox(width: 10),
            Text("Recharge Required", style: TextStyle(color: Color(0xFF263238), fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF546E7A), fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8F00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => VendorWalletPage(vendorPhone: phoneNumber),
                ),
              ).then((_) => _fetchWalletStatus());
            },
            icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
            label: const Text("Recharge Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLowWalletBanner() {
    bool isLocalOrOneWay = (tripType?.toLowerCase() ?? '').contains('taxi') ||
        (tripType?.toLowerCase() ?? '').contains('local') ||
        (tripType?.toLowerCase() ?? '').contains('one-way') ||
        (tripType?.toLowerCase() ?? '').contains('one way');
    if (!isLocalOrOneWay || walletBalance == null || isWalletEligible) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Low Wallet Balance",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFE65100)),
                ),
                const SizedBox(height: 2),
                Text(
                  "Balance: ₹${walletBalance!.toStringAsFixed(2)} (Min ₹${minWalletBalance!.toStringAsFixed(0)} required). Please recharge to accept.",
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF5D4037)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8F00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => VendorWalletPage(vendorPhone: phoneNumber)),
              ).then((_) => _fetchWalletStatus());
            },
            child: const Text("Recharge", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Assign Assets",
            style: TextStyle(fontWeight: FontWeight.bold, color: darkCharcoal)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: darkCharcoal, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: isLoading ? _buildLoader() : _buildContent(),
    );
  }

  Widget _buildLoader() {
    return const Center(child: CircularProgressIndicator(color: primaryAmber));
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryHeader(),
          const SizedBox(height: 16),
          _buildFinancialSummary(),
          _buildLowWalletBanner(),
          const SizedBox(height: 24),
          _buildSelectionCard(
            label: "Vehicle Selection",
            icon: Icons.directions_car_filled_rounded,
            value: selectedVehicle,
            items: vehicles,
            statusMap: vehicleStatus,
            onChanged: (v) => setState(() => selectedVehicle = v),
          ),
          const SizedBox(height: 16),
          _buildSelectionCard(
            label: "Driver Selection",
            icon: Icons.person_pin_rounded,
            value: selectedDriver,
            items: drivers,
            statusMap: driverStatus,
            onChanged: (v) => setState(() => selectedDriver = v),
          ),
          const SizedBox(height: 24),
          _buildAcceptanceBox(),
          const SizedBox(height: 32),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightAmber,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryAmber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_rounded, color: primaryAmber, size: 30),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("BOOKING ID",
                  style: TextStyle(
                      fontSize: 12,
                      color: darkCharcoal.withOpacity(0.6),
                      fontWeight: FontWeight.bold)),
              Text("#${widget.bookingId}",
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: darkCharcoal)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSelectionCard({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required Map<String, String> statusMap,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryAmber, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: darkCharcoal)),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: primaryAmber),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            items: items.map((String item) {
              bool isConflict = statusMap[item] == "conflict";
              return DropdownMenuItem<String>(
                value: item,
                enabled: !isConflict,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Text(item,
                            style: TextStyle(
                                color: isConflict ? Colors.grey : darkCharcoal,
                                fontSize: 14))),
                    if (isConflict)
                      const Badge(
                          label: Text("BOOKED"), backgroundColor: errorRed)
                    else
                      const Icon(Icons.check_circle_outline,
                          size: 16, color: Colors.green),
                  ],
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptanceBox() {
    return InkWell(
      onTap: () => setState(() => isTripAccepted = !isTripAccepted),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isTripAccepted
              ? primaryAmber.withOpacity(0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isTripAccepted ? primaryAmber : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isTripAccepted,
              onChanged: (v) => setState(() => isTripAccepted = v ?? false),
              activeColor: primaryAmber,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            const Expanded(
              child: Text(
                  "I confirm the availability and accept this trip assignment.",
                  style: TextStyle(
                      fontSize: 14,
                      color: darkCharcoal,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    bool canSubmit =
        selectedDriver != null && selectedVehicle != null && isTripAccepted && !isSubmitting;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: canSubmit
            ? [
                BoxShadow(
                    color: primaryAmber.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6))
              ]
            : [],
      ),
      child: ElevatedButton(
        onPressed: canSubmit ? _submitForm : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAmber,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: isSubmitting
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : const Text("CONFIRM ASSIGNMENT",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }

  void _showConflictDialog(bool dConflict, bool vConflict) {
    String msg = (dConflict && vConflict)
        ? "Both Driver and Vehicle are already booked."
        : dConflict
            ? "Selected Driver is unavailable."
            : "Selected Vehicle is unavailable.";

    _showStatusDialog("Conflict Detected", msg, Icons.error_outline, errorRed);
  }

  void _showStatusDialog(
      String title, String content, IconData icon, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(title)
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK",
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
