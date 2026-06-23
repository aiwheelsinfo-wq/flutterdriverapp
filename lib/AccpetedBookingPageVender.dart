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
import 'package:firebase_messaging/firebase_messaging.dart';

class MergedBookingsPage extends StatefulWidget {
  const MergedBookingsPage({super.key});

  @override
  State<MergedBookingsPage> createState() => _MergedBookingsPageState();
}

class _MergedBookingsPageState extends State<MergedBookingsPage>
    with SingleTickerProviderStateMixin {
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  List<dynamic> activeBookings = [];
  List<dynamic> cancelledBookings = [];
  bool isLoading = true;
  String? storedPhoneNumber;
  Timer? _timer;
  StreamSubscription<RemoteMessage>? _fcmSub;

  late TabController _tabController;

  // Theme Colors
  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color accentAmber = Color(0xFFFF8F00);
  static const Color bgLight = Color(0xFFFFFBF0);
  static const Color charcoal = Color(0xFF263238);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPhoneNumberAndFetch();
    _listenForCancellations();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fcmSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // ── FCM real-time listener ────────────────────────────────────────────────
  void _listenForCancellations() {
    _fcmSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'customer_cancelled') {
        // Refresh both active trips and cancellation history immediately
        _fetchAcceptedBookings();
        _fetchCancelledBookings();
        // Switch to the cancellation history tab
        if (mounted) {
          _tabController.animateTo(1);
        }
      }
    });
  }

  Future<void> _loadPhoneNumberAndFetch() async {
    storedPhoneNumber = await storage.read(key: "phone_number");
    if (storedPhoneNumber != null) {
      // Fetch both in parallel
      await Future.wait([
        _fetchAcceptedBookings(),
        _fetchCancelledBookings(),
      ]);
      _startAutoRefresh();
    } else {
      setState(() => isLoading = false);
    }
  }

  void _startAutoRefresh() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchAcceptedBookings();
      _fetchCancelledBookings();
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
        if (data['success'] == true) {
          // acceptedBookings may include all statuses OR only active ones
          // depending on the server version. We handle both cases.
          final List<dynamic> all =
              (data['acceptedBookings'] as List<dynamic>?) ?? [];

          // Split into active vs customer-cancelled
          final active = all
              .where((b) =>
                  b['booking_status'] != 'Customer Cancelled' &&
                  b['booking_status'] != 'Cancelled' &&
                  b['booking_status'] != 'Cancellation Requested')
              .toList();

          // Customer Cancelled bookings may come either inside acceptedBookings
          // or in a separate 'cancelledBookings' key from the server
          final serverCancelled = all
              .where((b) =>
                  b['booking_status'] == 'Customer Cancelled' ||
                  b['booking_status'] == 'Cancellation Requested' ||
                  b['booking_status'] == 'Cancelled')
              .toList();

          // Also merge any separate cancelledBookings array the server may return
          final extraCancelled =
              (data['cancelledBookings'] as List<dynamic>?) ?? [];
          final allCancelled = [...serverCancelled, ...extraCancelled];

          if (mounted) {
            setState(() {
              // ALWAYS update — even if empty — so trips disappear instantly
              activeBookings = active;
              
              // Merge any new cancelled bookings returned by this endpoint,
              // without wiping out the list populated by the dedicated _fetchCancelledBookings() API.
              if (allCancelled.isNotEmpty) {
                final existingIds = cancelledBookings.map((b) => b['booking_id']?.toString()).toSet();
                for (var b in allCancelled) {
                  final bId = b['booking_id']?.toString();
                  if (bId != null && !existingIds.contains(bId)) {
                    cancelledBookings.add(b);
                    existingIds.add(bId);
                  }
                }
              }
              isLoading = false;
            });
          }
        } else {
          // success == false → clear everything
          if (mounted) {
            setState(() {
              activeBookings = [];
              cancelledBookings = [];
              isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching bookings: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }


  // ── Separate fetch for cancellation history ──────────────────────────────
  Future<void> _fetchCancelledBookings() async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.getCancelledBookings),
        body: {"phone_number": storedPhoneNumber},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> fromServer =
              (data['cancelledBookings'] as List<dynamic>?) ?? [];
          if (mounted) {
            setState(() {
              // Directly use the authoritative list of cancelled bookings from the server
              cancelledBookings = fromServer;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching cancelled bookings: $e");
    }
  }
  // ─────────────────────────────────────────────────────────────────────────

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

  // ── Cancel trip (driver-side) ─────────────────────────────────────────────
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
      if (!mounted) return;
      if (json.decode(response.body)['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Trip cancelled successfully.")));

        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
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

  // ── Build ──────────────────────────────────────────────────────────────────
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
        title: const Text("My Trips",
            style: TextStyle(
                color: charcoal, fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: accentAmber,
          unselectedLabelColor: Colors.grey,
          indicatorColor: accentAmber,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_car, size: 16),
                  const SizedBox(width: 6),
                  const Text("Active Trips"),
                  if (activeBookings.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _buildBadge(activeBookings.length, Colors.green),
                  ]
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cancel_outlined, size: 16),
                  const SizedBox(width: 6),
                  const Text("Cancelled"),
                  if (cancelledBookings.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _buildBadge(cancelledBookings.length, Colors.red),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryAmber))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildActiveTripsTab(),
                _buildCancellationHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ── Active Trips Tab ────────────────────────────────────────────────────────
  Widget _buildActiveTripsTab() {
    if (activeBookings.isEmpty) return _buildEmptyState("No active bookings");
    return RefreshIndicator(
      color: primaryAmber,
      onRefresh: _fetchAcceptedBookings,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: activeBookings.length,
        itemBuilder: (context, index) =>
            _buildModernBookingCard(activeBookings[index]),
      ),
    );
  }

  // ── Cancellation History Tab ──────────────────────────────────────────────
  Widget _buildCancellationHistoryTab() {
    if (cancelledBookings.isEmpty) {
      return _buildEmptyState("No cancellations yet");
    }
    return RefreshIndicator(
      color: primaryAmber,
      onRefresh: _fetchAcceptedBookings,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: cancelledBookings.length,
        itemBuilder: (context, index) =>
            _buildCancelledCard(cancelledBookings[index]),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_filled_outlined,
              size: 80, color: charcoal.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  // ── Cancellation History Card ─────────────────────────────────────────────
  Widget _buildCancelledCard(Map<String, dynamic> booking) {
    final bool isLocalTaxi = (booking['trip_type'] ?? '').toString().toLowerCase().contains('local') &&
                             (booking['trip_type'] ?? '').toString().toLowerCase().contains('taxi');
    final DateTime? date = DateTime.tryParse(booking['date'] ?? "");
    final String formattedDate =
        date != null ? DateFormat('dd MMM, yyyy').format(date) : "N/A";

    final double refundAmount =
        double.tryParse(booking['refund_amount']?.toString() ?? '0') ?? 0.0;
    final double cancelCharge =
        double.tryParse(booking['cancellation_charge']?.toString() ?? '0') ??
            0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.red.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Red banner header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cancel, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            isLocalTaxi ? "BOOKING CANCELLED BY CUSTOMER" : "CUSTOMER CANCELLED",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  "ID: #${booking['booking_id']}",
                  style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ],
            ),
          ),

          // Booking info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking['trip_type'].toString().toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: charcoal),
                ),
                const SizedBox(height: 8),
                _buildDetailedRow(Icons.person, "Customer",
                    capitalizeFirst(booking['customer_name'])),
                const SizedBox(height: 4),
                _buildDetailedRow(Icons.calendar_today, "Date",
                    "$formattedDate  ${formatTime(booking['time'] ?? '')}"),
                const SizedBox(height: 4),
                _buildDetailedRow(Icons.location_on, "Pickup",
                    booking['pickup_location'] ?? 'N/A'),
                const SizedBox(height: 4),
                if ((booking['drop_location'] ?? '').toString().isNotEmpty)
                  _buildDetailedRow(Icons.flag, "Drop",
                      booking['drop_location']),

                const SizedBox(height: 12),
                // Refund info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Column(
                    children: [
                      _buildRefundRow(
                        Icons.currency_rupee,
                        "Refund to Customer",
                        "₹${refundAmount.toStringAsFixed(2)}",
                        Colors.green,
                      ),
                      const Divider(height: 12),
                      _buildRefundRow(
                        Icons.percent,
                        "Cancellation Charge",
                        "₹${cancelCharge.toStringAsFixed(2)}",
                        Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundRow(
      IconData icon, String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // ── Active Trip Card (unchanged from previous) ────────────────────────────
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
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    children: [
                      const Icon(Icons.circle, size: 12, color: primaryAmber),
                      Container(
                          width: 2, height: 48, color: Colors.grey.shade200),
                      const Icon(Icons.location_on,
                          size: 16, color: Colors.redAccent),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pickup Location interactive Card
                      InkWell(
                        onTap: () async {
                          final pickup = booking['pickup_location'] ?? '';
                          if (pickup.isNotEmpty) {
                            final url = Uri.parse(
                                "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(pickup)}");
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url,
                                  mode: LaunchMode.externalApplication);
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.amber.shade50.withOpacity(0.8),
                                Colors.white,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.amber.shade300.withOpacity(0.5),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.gps_fixed_rounded,
                                  color: accentAmber,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "CUSTOMER PICKUP LOCATION",
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      booking['pickup_location'] ?? "Pickup",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: charcoal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                    color: charcoal,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: charcoal.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      )
                                    ]),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "MAP",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.directions_rounded,
                                      color: primaryAmber,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Drop Location Info
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "DROP LOCATION",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade500,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              booking['drop_location'] ?? "Local Trip / Drop",
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
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
                _buildSmallInfo(
                    Icons.access_time, formatTime(booking['time'])),
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
                    onPressed: () =>
                        _launchCaller(booking['customer_contact']),
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
