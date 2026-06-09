import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'api_config.dart';

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
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: charcoal, size: 20),
          onPressed: () => Navigator.pop(context),
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: charcoal, borderRadius: BorderRadius.circular(12)),
                  child: Text("₹${booking['vendor_amount']}",
                      style: const TextStyle(
                          color: primaryAmber,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
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

          // Billing Receipt Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Row(children: [
                  Text("FARE BREAKDOWN",
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1)),
                  Expanded(child: Divider(indent: 8))
                ]),
                const SizedBox(height: 8),
                ...charges.map((c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(c["label"],
                              style: const TextStyle(
                                  fontSize: 13, color: charcoal)),
                          Text("₹${c["value"].toStringAsFixed(2)}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: charcoal)),
                        ],
                      ),
                    )),
              ],
            ),
          ),

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
