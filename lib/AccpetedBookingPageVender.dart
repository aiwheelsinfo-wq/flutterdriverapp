import 'dart:async';
import 'dart:convert';
import 'api_config.dart';
import 'booking_list.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'startingKmInputPage.dart';
import 'tripLiveMaping.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class MergedBookingsPage extends StatefulWidget {
  const MergedBookingsPage({super.key});

  @override
  State<MergedBookingsPage> createState() => _MergedBookingsPageState();
}

class _MergedBookingsPageState extends State<MergedBookingsPage> {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  List<dynamic> acceptedBookings = [];
  bool isLoading = true;
  String? storedPhoneNumber;
  Timer? _timer;

  // Theme Colors
  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color accentAmber = Color(0xFFFF8F00);
  static const Color bgLight = Color(0xFFFFFBF0);
  static const Color charcoal = Color(0xFF263238);

  @override
  void initState() {
    super.initState();
    _loadPhoneNumberAndFetch();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadPhoneNumberAndFetch() async {
    storedPhoneNumber = await storage.read(key: "phone_number");
    if (storedPhoneNumber != null) {
      await _fetchAcceptedBookings();
      _startAutoRefresh();
    } else {
      setState(() => isLoading = false);
    }
  }

  void _startAutoRefresh() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchAcceptedBookings();
    });
  }

  Future<void> _fetchAcceptedBookings() async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.getBookings),
        body: {"phone_number": storedPhoneNumber},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('data: $data');
        if (data['success'] &&
            data['acceptedBookings'] != null &&
            data['acceptedBookings'].isNotEmpty) {
          final List<dynamic> newBookings = data['acceptedBookings'];
          if (!listEquals(acceptedBookings, newBookings)) {
            if (mounted) {
              setState(() {
                acceptedBookings = newBookings;
                isLoading = false;
              });
            }
          }
        } else {
          if (mounted) {
            setState(() => isLoading = false);
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching bookings: $e");
    }
  }

  String formatTime(String timeStr) {
    try {
      final time = DateFormat('HH:mm').parse(timeStr);
      return DateFormat('hh:mm a').format(time);
    } catch (e) {
      return timeStr;
    }
  }

  String capitalizeFirst(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  void _confirmCancelTrip(String bookingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text("Cancel Trip?", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text("This action cannot be undone. Are you sure?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("No", style: TextStyle(color: charcoal))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _cancelTrip(bookingId);
            },
            child: const Text("Yes, Cancel",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelTrip(String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.cancelBooking),
        body: {"booking_id": bookingId},
      );
      if (json.decode(response.body)['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Trip cancelled successfully.")));

        Future.delayed(const Duration(seconds: 1), () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) => BookingListPage(
                      phoneNumber: storedPhoneNumber.toString(),
                    )),
            (route) => false,
          );
        });
      }
    } catch (e) {
      debugPrint("Cancel Error: $e");
    }
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
        title: const Text("My Active Trips",
            style: TextStyle(
                color: charcoal, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryAmber))
          : acceptedBookings.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: primaryAmber,
                  onRefresh: _fetchAcceptedBookings,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: acceptedBookings.length,
                    itemBuilder: (context, index) =>
                        _buildModernBookingCard(acceptedBookings[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_filled_outlined,
              size: 80, color: charcoal.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text("No active bookings found",
              style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildModernBookingCard(Map<String, dynamic> booking) {
    final bool isLive = booking['booking_status'] != 'Accepted';
    final DateTime? date = DateTime.tryParse(booking['date'] ?? "");
    final String formattedDate =
        date != null ? DateFormat('dd MMM, yyyy').format(date) : "N/A";

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
          // Header Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("ID: #${booking['booking_id']}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            fontSize: 12)),
                    Text(booking['trip_type'].toString().toUpperCase(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: charcoal)),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isLive
                        ? Colors.green.withOpacity(0.1)
                        : primaryAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isLive ? "● LIVE TRIP" : "UPCOMING",
                    style: TextStyle(
                        color: isLive ? Colors.green : accentAmber,
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // Route Visualization
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const Icon(Icons.circle, size: 12, color: primaryAmber),
                    Container(
                        width: 2, height: 40, color: Colors.grey.shade200),
                    const Icon(Icons.location_on,
                        size: 16, color: Colors.redAccent),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking['pickup_location'] ?? "Pickup",
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: charcoal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 25),
                      Text(booking['drop_location'] ?? "Local Trip / Drop",
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: charcoal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Date/Time/Car Info Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: bgLight.withOpacity(0.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSmallInfo(Icons.calendar_today, formattedDate),
                _buildSmallInfo(Icons.access_time, formatTime(booking['time'])),
                _buildSmallInfo(Icons.drive_eta, booking['car_type'] ?? "Car"),
              ],
            ),
          ),

          // Customer & Vehicle Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailedRow(Icons.person, "Customer",
                    "${capitalizeFirst(booking['customer_name'])}"),
                const SizedBox(height: 8),
                _buildDetailedRow(Icons.car_repair, "Vehicle",
                    "${booking['vehicle_id']} (${booking['vehicle_name'] ?? 'N/A'})"),
                const SizedBox(height: 8),
                _buildDetailedRow(Icons.face, "Driver",
                    "${capitalizeFirst(booking['driver_name'])}"),
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                // Call Button
                Container(
                  decoration: BoxDecoration(
                      color: primaryAmber,
                      borderRadius: BorderRadius.circular(12)),
                  child: IconButton(
                    icon: const Icon(Icons.phone, color: Colors.white),
                    onPressed: () => _launchCaller(booking['customer_contact']),
                  ),
                ),
                const SizedBox(width: 12),
                // Main Action (Start/Continue)
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: charcoal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => _handleMainAction(booking),
                    child: Text(
                      isLive ? "CONTINUE TRIP" : "START TRIP",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
                // Cancel (Only if not started)
                if (!isLive) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () =>
                        _confirmCancelTrip(booking['booking_id'].toString()),
                    child: const Icon(Icons.close, size: 20),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInfo(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: primaryAmber),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: charcoal)),
      ],
    );
  }

  Widget _buildDetailedRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text("$label: ",
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: charcoal),
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  void _launchCaller(String? contact) async {
    if (contact == null) return;
    final Uri callUri = Uri(scheme: 'tel', path: contact);
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    }
  }

  void _handleMainAction(Map<String, dynamic> booking) {
    if (booking['booking_status'] == "Accepted") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StartingKmInputPage(
            bookingId: booking['booking_id'].toString(),
            savedOtp: booking['otp'].toString(),
            triptype: booking['trip_type'].toString(),
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TripLiveMapping(
            bookingId: booking['booking_id'].toString(),
            phoneNumber: storedPhoneNumber!,
          ),
        ),
      );
    }
  }
}
