import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';
import 'api_config.dart';
import 'checkAndRoot.dart';

class CompleatedList extends StatefulWidget {
  const CompleatedList({super.key});

  @override
  State<CompleatedList> createState() => _CompleatedListState();
}

class _CompleatedListState extends State<CompleatedList> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  List<dynamic> compleatedBookings = [];
  List<dynamic> filteredBookings = [];
  Timer? _timer;
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Professional Amber Palette
  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color accentAmber = Color(0xFFFF8F00);
  static const Color charcoal = Color(0xFF263238);
  static const Color bgLight = Color(0xFFFFFBF0);

  @override
  void initState() {
    super.initState();
    fetchBookings();
    _timer =
        Timer.periodic(const Duration(seconds: 10), (timer) => fetchBookings());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _filterBookings(String query) {
    setState(() {
      filteredBookings = compleatedBookings.where((booking) {
        final id = booking['id'].toString().toLowerCase();
        final from = booking['from_address'].toString().toLowerCase();
        return id.contains(query.toLowerCase()) ||
            from.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> fetchBookings() async {
    try {
      String? phoneNumber = await secureStorage.read(key: "phone_number");
      if (phoneNumber == null) return;

      String apiUrl =
          "${ApiConfig.getCompletedListForVendor}?phone_number=$phoneNumber";

      var response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        print("daataa $jsonResponse");

        if (jsonResponse["compleatedBookings"] != null &&
            jsonResponse["compleatedBookings"].length > 0 &&
            jsonResponse["success"] == true) {
          if (mounted) {
            setState(() {
              compleatedBookings = jsonResponse["compleatedBookings"] ?? [];
              if (_searchController.text.isEmpty) {
                filteredBookings = compleatedBookings;
              }
              isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() => isLoading = false);
          }
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  double parseDouble(dynamic value) =>
      double.tryParse(value?.toString() ?? '0') ?? 0.0;

  List<Map<String, dynamic>> calculateCharges(Map booking) {
    List<Map<String, dynamic>> charges = [];
    double totalKm = parseDouble(booking['closing_km']) -
        parseDouble(booking['starting_km']);
    String tripType = booking['trip_type'] ?? "";

    if (tripType.contains("Local Duty")) {
      double pkg = parseDouble(booking['base_charge']);
      double extraKmCharge = parseDouble(booking['extra_km_charge']);
      double includedKm = parseDouble(booking['local_package_km']);
      double extraKm = totalKm > includedKm ? totalKm - includedKm : 0;

      charges = [
        {"label": "Package Charge", "value": pkg, "note": "$includedKm KM Pkg"},
        {
          "label": "Extra KM Charge",
          "value": extraKm * extraKmCharge,
          "note": "$extraKm × ₹$extraKmCharge"
        },
        {
          "label": "Driver Allowance",
          "value": parseDouble(booking['driver_ta'])
        },
        {"label": "Tolls", "value": parseDouble(booking['toll_charge'])},
        {"label": "Parking", "value": parseDouble(booking['parking_charge'])},
      ];
    } else if (tripType.contains("One Way")) {
      charges = [
        {"label": "Base Fare", "value": parseDouble(booking['base_charge'])},
        {"label": "Tolls", "value": parseDouble(booking['toll_charge'])},
        {"label": "Permit", "value": parseDouble(booking['permit_charge'])},
      ];
    } else if (tripType.contains("Round")) {
      double perKmCharge = parseDouble(booking['base_charge']);
      charges = [
        {
          "label": "Distance Fare",
          "value": totalKm * perKmCharge,
          "note": "$totalKm KM × ₹$perKmCharge"
        },
        {
          "label": "Driver Allowance",
          "value": parseDouble(booking['driver_ta'])
        },
        {"label": "Tolls", "value": parseDouble(booking['toll_charge'])},
      ];
    }
    return charges;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (Navigator.canPop(context)) {
          return true;
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const checAbdRoot()),
          );
          return false;
        }
      },
      child: Scaffold(
        backgroundColor: bgLight,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: charcoal, size: 20),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const checAbdRoot()),
                );
              }
            },
          ),
          title: const Text("History",
            style: TextStyle(
                color: charcoal, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryAmber))
                : filteredBookings.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredBookings.length,
                        itemBuilder: (context, index) =>
                            _buildTripTicket(filteredBookings[index]),
                      ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        onChanged: _filterBookings,
        decoration: InputDecoration(
          hintText: "Search Trip ID or Location...",
          prefixIcon: const Icon(Icons.search, color: primaryAmber),
          filled: true,
          fillColor: bgLight,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildTripTicket(Map booking) {
    double totalKm = parseDouble(booking['closing_km']) -
        parseDouble(booking['starting_km']);
    List<Map<String, dynamic>> charges = calculateCharges(booking);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // Header: Trip ID & Amount
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("TRIP ID #${booking['id']}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(booking['trip_type'].toString().toUpperCase(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: charcoal,
                            fontSize: 14)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                        (booking['trip_type'] ?? '').toString().toLowerCase().contains('round')
                            ? "Remaining Balance"
                            : ((booking['trip_type'] ?? '').toString().toLowerCase().contains('duty')
                                ? "Collect & Earning"
                                : "Partner Earning"),
                        style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: charcoal, borderRadius: BorderRadius.circular(12)),
                      child: Builder(builder: (context) {
                        String tType = (booking['trip_type'] ?? '').toString().toLowerCase();
                        if (tType.contains('round')) {
                          int rtDays = 1;
                          try {
                            final s = booking['date']?.toString() ?? '';
                            final r = booking['return_date']?.toString() ?? '';
                            if (s.isNotEmpty && r.isNotEmpty && s != '0000-00-00' && r != '0000-00-00') {
                              try {
                                rtDays = DateFormat('dd MMM yyyy').parse(r).difference(DateFormat('dd MMM yyyy').parse(s)).inDays + 1;
                              } catch (_) {
                                rtDays = DateTime.parse(r).difference(DateTime.parse(s)).inDays + 1;
                              }
                            }
                          } catch (_) {}
                          if (rtDays <= 0) rtDays = 1;

                          double rtDailyLimit = double.tryParse(booking['daily_limit']?.toString() ?? '0') ?? 300.0;
                          if (rtDailyLimit == 0) rtDailyLimit = 300.0;

                          double rtStartKm = double.tryParse(booking['starting_km']?.toString() ?? '0') ?? 0.0;
                          double rtCloseKm = double.tryParse(booking['closing_km']?.toString() ?? '0') ?? 0.0;
                          double rtRunKm = (rtCloseKm - rtStartKm).clamp(0, double.infinity);
                          double rtMaxKm = max(rtRunKm, rtDailyLimit * rtDays);

                          double rtKmRate = double.tryParse(booking['kmRate']?.toString() ?? '0') ?? 13.0;
                          if (rtKmRate == 0) rtKmRate = 13.0;

                          double baseFare = rtMaxKm * rtKmRate;
                          double rtAllowDay = double.tryParse(booking['driver_allowance']?.toString() ?? '0') ?? 400.0;
                          if (rtAllowDay == 0) rtAllowDay = 400.0;
                          double driverAllowance = rtAllowDay * rtDays;
                          double gstAmount = baseFare * 0.05;

                          double rtPark = double.tryParse(booking['parking_charge']?.toString() ?? '0') ?? 0.0;
                          double rtToll = double.tryParse(booking['toll_charge']?.toString() ?? '0') ?? 0.0;
                          double rtPermit = double.tryParse(booking['permit_charge']?.toString() ?? '0') ?? 0.0;

                          double finalTotalAmount = double.tryParse(booking['total_amount']?.toString() ?? '') ?? 0.0;
                          if (finalTotalAmount == 0) {
                            finalTotalAmount = baseFare + driverAllowance + gstAmount + rtPark + rtToll + rtPermit;
                          }
                          double advancePaid = double.tryParse(booking['paid_amount']?.toString() ?? '0') ?? 0.0;
                          String payType = (booking['payment_type'] ?? '').toString();
                          if (payType.toLowerCase().contains('driver') || payType.toLowerCase().contains('cash')) {
                            advancePaid = 0.0;
                          }
                          double remainingCollect = (finalTotalAmount - advancePaid).clamp(0, double.infinity);

                          return Text("₹${remainingCollect.toStringAsFixed(2)}",
                              style: const TextStyle(
                                  color: primaryAmber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16));
                        }
                        if (tType.contains('duty')) {
                          double totalFare = double.tryParse(booking['total_amount']?.toString() ?? '') ?? 0.0;
                          double advancePaid = double.tryParse(booking['paid_amount']?.toString() ?? '0') ?? 0.0;
                          String payType = (booking['payment_type'] ?? '').toString();
                          if (payType.toLowerCase().contains('driver') || payType.toLowerCase().contains('cash')) {
                            advancePaid = 0.0;
                          }
                          double collectAmount = (totalFare - advancePaid).clamp(0, double.infinity);
                          double netEarning = double.tryParse(booking['vendor_amount']?.toString() ?? '') ?? 0.0;
                          if (netEarning == 0 && totalFare > 0) {
                            netEarning = totalFare * 0.90;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text("Collect: ",
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                  Text("₹${collectAmount.toStringAsFixed(0)}",
                                      style: const TextStyle(
                                          color: primaryAmber,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text("Net: ",
                                      style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500)),
                                  Text("₹${netEarning.toStringAsFixed(0)}",
                                      style: const TextStyle(
                                          color: Color(0xFF34D399),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12)),
                                ],
                              ),
                            ],
                          );
                        }
                        if (tType.contains('local') && tType.contains('taxi')) {
                          double vAmt = double.tryParse(booking['vendor_amount']?.toString() ?? '') ?? 0.0;
                          if (vAmt == 0) {
                            double rawFare = double.tryParse(booking['total_amount']?.toString() ?? '') ?? 0.0;
                            vAmt = rawFare * 0.90;
                          }
                          return Text("₹${vAmt.toStringAsFixed(2)}",
                              style: const TextStyle(
                                  color: primaryAmber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16));
                        }
                        if (tType.contains('one-way') || tType.contains('one way')) {
                          double rawFare = double.tryParse(booking['total_amount']?.toString() ?? '') ?? 0.0;
                          double agentComm = double.tryParse(booking['agent_commission']?.toString() ?? '0') ?? 0.0;
                          double fare = (agentComm > 0 && rawFare > agentComm) ? (rawFare - agentComm) : rawFare;
                          if (fare == 0) {
                            double vendorAmt = double.tryParse(booking['vendor_amount']?.toString() ?? '') ?? 0.0;
                            fare = vendorAmt / 0.90;
                          }
                          double vendorEarnings = fare * 0.90;
                          return Text("₹${vendorEarnings.toStringAsFixed(2)}",
                              style: const TextStyle(
                                  color: primaryAmber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16));
                        }
                        return Text("₹${booking['vendor_amount']}",
                            style: const TextStyle(
                                color: primaryAmber,
                                fontWeight: FontWeight.bold,
                                fontSize: 16));
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Route Display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Column(
                  children: [
                    Icon(Icons.radio_button_checked,
                        color: primaryAmber, size: 16),
                    SizedBox(
                        height: 4, child: VerticalDivider(color: Colors.grey)),
                    Icon(Icons.location_on, color: accentAmber, size: 16),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking['from_address'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 13, color: charcoal)),
                      const SizedBox(height: 8),
                      Text(
                          booking['to_address'] == ''
                              ? 'Local Trip'
                              : booking['to_address'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              color: charcoal,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Trip Stats (KM & Dates)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: bgLight, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatIcon(
                    Icons.history, "${totalKm.toStringAsFixed(1)} KM"),
                _buildStatIcon(Icons.calendar_today, booking['starting_date']),
                _buildStatIcon(Icons.drive_eta, booking['car_type']),
              ],
            ),
          ),

          // Fare breakdown for trips
          if ((booking['trip_type'] ?? '').toString().toLowerCase().contains('one-way') ||
              (booking['trip_type'] ?? '').toString().toLowerCase().contains('one way') ||
              (booking['trip_type'] ?? '').toString().toLowerCase().contains('round') ||
              (booking['trip_type'] ?? '').toString().toLowerCase().contains('local-taxi') ||
              (booking['trip_type'] ?? '').toString().toLowerCase().contains('local_taxi') ||
              (booking['trip_type'] ?? '').toString().toLowerCase().contains('local taxi') ||
              (booking['trip_type'] ?? '').toString().toLowerCase().contains('local-duty') ||
              (booking['trip_type'] ?? '').toString().toLowerCase().contains('local duty') ||
              (booking['trip_type'] ?? '').toString().toLowerCase().contains('duty')) ...[
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: const Text(
                  "View Fare & Earnings Breakdown",
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryAmber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: [
                  Builder(
                    builder: (context) {
                      String tType = (booking['trip_type'] ?? '').toString().toLowerCase();
                      if (tType.contains('local') && tType.contains('taxi')) {
                        double rawTotal = double.tryParse(booking['total_amount']?.toString() ?? '') ?? 0.0;
                        double agentComm = double.tryParse(booking['agent_commission']?.toString() ?? '0') ?? 0.0;
                        double customerTotal = (agentComm > 0 && rawTotal > agentComm) ? (rawTotal - agentComm) : rawTotal;
                        double vendorEarnings = double.tryParse(booking['vendor_amount']?.toString() ?? '') ?? 0.0;
                        double platformCommission = double.tryParse(booking['agni_amount']?.toString() ?? '') ?? 0.0;

                        if (customerTotal == 0 && vendorEarnings > 0) {
                          customerTotal = vendorEarnings / 0.90;
                        }
                        if (vendorEarnings == 0 && customerTotal > 0) {
                          vendorEarnings = customerTotal * 0.90;
                        }
                        if (platformCommission == 0 && customerTotal > vendorEarnings) {
                          platformCommission = customerTotal - vendorEarnings;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFinancialSummaryRow("Total Customer Fare", "₹${customerTotal.toStringAsFixed(0)}"),
                              _buildFinancialSummaryRow("Collected from Customer", "₹${customerTotal.toStringAsFixed(0)}", isHighlight: true, highlightColor: primaryAmber),
                              _buildFinancialSummaryRow("Platform Fee", "₹${platformCommission.toStringAsFixed(0)} (Wallet Deducted)"),
                              const Divider(height: 16, thickness: 0.8),
                              _buildFinancialSummaryRow("Your Net Earnings", "₹${vendorEarnings.toStringAsFixed(0)}", isHighlight: true, highlightColor: Colors.green),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.green.shade100),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.check_circle_outline, color: Colors.green[800], size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        "Trip completed successfully. 100% fare was collected directly from the customer, and the platform fee was deducted from your prepaid wallet.",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.green[900],
                                          fontWeight: FontWeight.w500,
                                          height: 1.3,
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
                      if (tType.contains('duty')) {
                        double totalFare = double.tryParse(booking['total_amount']?.toString() ?? '') ?? 0.0;
                        double baseCharge = double.tryParse(booking['base_charge']?.toString() ?? '') ?? 
                            (double.tryParse(booking['baseAmount']?.toString() ?? '') ?? 0.0);
                        if (baseCharge == 0 && totalFare > 0) {
                          baseCharge = 2200.0;
                        }
                        double parkingCharge = double.tryParse(booking['parking_charge']?.toString() ?? '0') ?? 0.0;
                        double tollCharge = double.tryParse(booking['toll_charge']?.toString() ?? '0') ?? 0.0;

                        double subtotalBeforeGst = baseCharge + parkingCharge + tollCharge;
                        double totalGst = (totalFare > subtotalBeforeGst) 
                            ? (totalFare - subtotalBeforeGst) 
                            : (subtotalBeforeGst * 0.05);
                        double cgst = totalGst / 2;
                        double sgst = totalGst / 2;

                        if (totalFare == 0) {
                          totalFare = subtotalBeforeGst + totalGst;
                        }

                        double advancePaid = double.tryParse(booking['paid_amount']?.toString() ?? '0') ?? 0.0;
                        String payType = (booking['payment_type'] ?? '').toString();
                        if (payType.toLowerCase().contains('driver') || payType.toLowerCase().contains('cash')) {
                          advancePaid = 0.0;
                        }
                        double collectFromCustomer = (totalFare - advancePaid).clamp(0, double.infinity);

                        double vendorEarnings = double.tryParse(booking['vendor_amount']?.toString() ?? '') ?? 0.0;
                        if (vendorEarnings == 0 && totalFare > 0) {
                          vendorEarnings = totalFare * 0.90;
                        }

                        double platformCommission = double.tryParse(booking['agni_amount']?.toString() ?? '') ?? 0.0;
                        if (platformCommission == 0 && totalFare > vendorEarnings) {
                          platformCommission = totalFare - vendorEarnings;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFinancialSummaryRow("Package Base Fare", "₹${baseCharge.toStringAsFixed(0)} (80 KM / 8 Hours)"),
                              if (parkingCharge > 0)
                                _buildFinancialSummaryRow("Parking Charges", "₹${parkingCharge.toStringAsFixed(0)}"),
                              if (tollCharge > 0)
                                _buildFinancialSummaryRow("Toll Charges", "₹${tollCharge.toStringAsFixed(0)}"),
                              _buildFinancialSummaryRow("CGST (2.5%)", "₹${cgst.toStringAsFixed(0)}"),
                              _buildFinancialSummaryRow("SGST (2.5%)", "₹${sgst.toStringAsFixed(0)}"),
                              const Divider(height: 16, thickness: 0.8),
                              _buildFinancialSummaryRow("Total Customer Bill", "₹${totalFare.toStringAsFixed(0)}"),
                              if (advancePaid > 0)
                                _buildFinancialSummaryRow("Advance Paid Online", "₹${advancePaid.toStringAsFixed(0)}"),
                              _buildFinancialSummaryRow(
                                "Collect from Customer",
                                "₹${collectFromCustomer.toStringAsFixed(0)}",
                                isHighlight: true,
                                highlightColor: const Color(0xFFD97706),
                              ),
                              _buildFinancialSummaryRow("Platform Fee (Wallet Deducted)", "₹${platformCommission.toStringAsFixed(0)}"),
                              const Divider(height: 16, thickness: 0.8),
                              _buildFinancialSummaryRow(
                                "Your Net Earning",
                                "₹${vendorEarnings.toStringAsFixed(0)}",
                                isHighlight: true,
                                highlightColor: Colors.green,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.green.shade100),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.check_circle_outline, color: Colors.green[800], size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        "Local Duty completed. Collect ₹${collectFromCustomer.toStringAsFixed(0)} from customer via Cash or UPI. Platform fee was deducted from your prepaid wallet.",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.green[900],
                                          fontWeight: FontWeight.w500,
                                          height: 1.3,
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
                      if (tType.contains('round')) {
                        int rtDays = 1;
                        try {
                          final s = booking['date']?.toString() ?? '';
                          final r = booking['return_date']?.toString() ?? '';
                          if (s.isNotEmpty && r.isNotEmpty && s != '0000-00-00' && r != '0000-00-00') {
                            try {
                              rtDays = DateFormat('dd MMM yyyy').parse(r).difference(DateFormat('dd MMM yyyy').parse(s)).inDays + 1;
                            } catch (_) {
                              rtDays = DateTime.parse(r).difference(DateTime.parse(s)).inDays + 1;
                            }
                          }
                        } catch (_) {}
                        if (rtDays <= 0) rtDays = 1;

                        double rtDailyLimit = double.tryParse(booking['daily_limit']?.toString() ?? '0') ?? 300.0;
                        if (rtDailyLimit == 0) rtDailyLimit = 300.0;

                        double rtStartKm = double.tryParse(booking['starting_km']?.toString() ?? '0') ?? 0.0;
                        double rtCloseKm = double.tryParse(booking['closing_km']?.toString() ?? '0') ?? 0.0;
                        double rtRunKm = (rtCloseKm - rtStartKm).clamp(0, double.infinity);
                        double rtMaxKm = max(rtRunKm, rtDailyLimit * rtDays);

                        double rtKmRate = double.tryParse(booking['kmRate']?.toString() ?? '0') ?? 13.0;
                        if (rtKmRate == 0) rtKmRate = 13.0;

                        double baseFare = rtMaxKm * rtKmRate;
                        double rtAllowDay = double.tryParse(booking['driver_allowance']?.toString() ?? '0') ?? 400.0;
                        if (rtAllowDay == 0) rtAllowDay = 400.0;
                        double driverAllowance = rtAllowDay * rtDays;
                        double gstAmount = baseFare * 0.05;

                        double rtPark = double.tryParse(booking['parking_charge']?.toString() ?? '0') ?? 0.0;
                        double rtToll = double.tryParse(booking['toll_charge']?.toString() ?? '0') ?? 0.0;
                        double rtPermit = double.tryParse(booking['permit_charge']?.toString() ?? '0') ?? 0.0;

                        double finalTotalAmount = double.tryParse(booking['total_amount']?.toString() ?? '') ?? 0.0;
                        if (finalTotalAmount == 0) {
                          finalTotalAmount = baseFare + driverAllowance + gstAmount + rtPark + rtToll + rtPermit;
                        }

                        double advancePaid = double.tryParse(booking['paid_amount']?.toString() ?? '0') ?? 0.0;
                        String payType = (booking['payment_type'] ?? '').toString();
                        if (payType.toLowerCase().contains('driver') || payType.toLowerCase().contains('cash')) {
                          advancePaid = 0.0;
                        }
                        double remainingCollect = (finalTotalAmount - advancePaid).clamp(0, double.infinity);

                        double vendorAmount = double.tryParse(booking['vendor_amount']?.toString() ?? '') ?? 0.0;
                        if (vendorAmount == 0) {
                          vendorAmount = max(0, finalTotalAmount * 0.85);
                        }

                        double platformDeduction = double.tryParse(booking['agni_amount']?.toString() ?? '') ?? 0.0;
                        if (platformDeduction == 0 && finalTotalAmount > vendorAmount) {
                          platformDeduction = finalTotalAmount - vendorAmount;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Trip Details & Fare Breakdown",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: charcoal),
                              ),
                              const Divider(height: 12),
                              _buildFinancialSummaryRow("Total Days", "$rtDays Day(s)"),
                              _buildFinancialSummaryRow("Running KMs", "${rtRunKm.toStringAsFixed(1)} KM (Start: ${rtStartKm.toStringAsFixed(0)} - End: ${rtCloseKm.toStringAsFixed(0)})"),
                              _buildFinancialSummaryRow("Min KM Limit", "${(rtDailyLimit * rtDays).toStringAsFixed(0)} KM ($rtDailyLimit KM/day)"),
                              _buildFinancialSummaryRow("Chargeable KM", "${rtMaxKm.toStringAsFixed(0)} KM"),
                              _buildFinancialSummaryRow("KM Rate", "₹$rtKmRate / KM"),
                              _buildFinancialSummaryRow("Base Fare", "₹${baseFare.toStringAsFixed(0)}"),
                              _buildFinancialSummaryRow("Driver Allowance", "₹${driverAllowance.toStringAsFixed(0)} (₹$rtAllowDay/day)"),
                              _buildFinancialSummaryRow("GST (5%)", "₹${gstAmount.toStringAsFixed(0)}"),
                              if (rtToll > 0) _buildFinancialSummaryRow("Toll Charges", "₹${rtToll.toStringAsFixed(0)}"),
                              if (rtPark > 0) _buildFinancialSummaryRow("Parking Charges", "₹${rtPark.toStringAsFixed(0)}"),
                              if (rtPermit > 0) _buildFinancialSummaryRow("Permit Charges", "₹${rtPermit.toStringAsFixed(0)}"),
                              const Divider(height: 16, thickness: 0.8),
                              _buildFinancialSummaryRow("Total Trip Amount", "₹${finalTotalAmount.toStringAsFixed(0)}"),
                              if (advancePaid > 0)
                                _buildFinancialSummaryRow("Customer Advance Paid Online", "₹${advancePaid.toStringAsFixed(0)}"),
                              _buildFinancialSummaryRow("Payable to Driver (Cash/UPI)", "₹${remainingCollect.toStringAsFixed(0)}", isHighlight: true),
                              _buildFinancialSummaryRow("Your Net Earnings", "₹${vendorAmount.toStringAsFixed(0)}"),
                              if (platformDeduction > 0)
                                _buildFinancialSummaryRow("Wallet Deducted (Commission + GST)", "₹${platformDeduction.toStringAsFixed(0)}", isHighlight: true, highlightColor: const Color(0xFF7C3AED)),
                            ],
                          ),
                        );
                      }

                      double rawFare = double.tryParse(booking['total_amount']?.toString() ?? '') ?? 0.0;
                      double agentComm = double.tryParse(booking['agent_commission']?.toString() ?? '0') ?? 0.0;
                      double baseFare = (agentComm > 0 && rawFare > agentComm) ? (rawFare - agentComm) : rawFare;
                      if (baseFare == 0) {
                        double vendorAmt = double.tryParse(booking['vendor_amount']?.toString() ?? '') ?? 0.0;
                        baseFare = vendorAmt / 0.90;
                      }
                      double vendorEarnings = baseFare * 0.90;

                      double gstAmount = baseFare * 0.05;
                      double platformCommission = baseFare * 0.10;
                      double toll = double.tryParse(booking['toll_charge']?.toString() ?? '0') ?? 0.0;
                      double parking = double.tryParse(booking['parking_charge']?.toString() ?? '0') ?? 0.0;
                      double extraCharges = toll + parking;
                      double totalCollected = baseFare + gstAmount + extraCharges;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFinancialSummaryRow("Base Trip Fare", "₹${baseFare.toStringAsFixed(0)}"),
                            _buildFinancialSummaryRow("GST (5%)", "₹${gstAmount.toStringAsFixed(0)}"),
                            if (extraCharges > 0) _buildFinancialSummaryRow("Toll / Parking (Included)", "₹${extraCharges.toStringAsFixed(0)}"),
                            _buildFinancialSummaryRow("Collected from Customer", "₹${totalCollected.toStringAsFixed(0)}", isHighlight: true, highlightColor: primaryAmber),
                            _buildFinancialSummaryRow("Platform Fee (10%)", "₹${platformCommission.toStringAsFixed(0)} (Wallet Deducted)"),
                            _buildFinancialSummaryRow("GST (5%)", "₹${gstAmount.toStringAsFixed(0)} (Wallet Deducted)"),
                            const Divider(height: 16, thickness: 0.8),
                            _buildFinancialSummaryRow("Your Net Earnings", "₹${vendorEarnings.toStringAsFixed(0)}", isHighlight: true, highlightColor: Colors.green),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.green.shade100),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check_circle_outline, color: Colors.green[800], size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      "Trip completed successfully. 100% fare (₹${totalCollected.toStringAsFixed(0)}) was collected directly from the customer, and the platform fee (₹${platformCommission.toStringAsFixed(0)}) + 5% GST (₹${gstAmount.toStringAsFixed(0)}) were deducted from your prepaid wallet.",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green[900],
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      );
                    }
                  ),
                ],
              ),
            ),
          ],

          // Bottom Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(
                color: charcoal,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(20))),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.white70, size: 14),
                const SizedBox(width: 8),
                Text(booking['driver_name'],
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
                const Spacer(),
                const Text("COMPLETED",
                    style: TextStyle(
                        color: primaryAmber,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatIcon(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, size: 16, color: charcoal.withOpacity(0.6)),
        const SizedBox(height: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: charcoal)),
      ],
    );
  }

  Widget _buildFinancialSummaryRow(String label, String value, {bool isHighlight = false, Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? charcoal : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isHighlight ? (highlightColor ?? primaryAmber) : charcoal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off,
              size: 64, color: charcoal.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text("No completed trips found",
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
