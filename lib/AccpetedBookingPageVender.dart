import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For listEquals
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'car_driver_selection_page.dart';
import 'driverLocationTracking.dart';
import 'startingKmInputPage.dart';
import 'tripLiveMaping.dart';
import 'package:url_launcher/url_launcher.dart';
// Import the TripLiveMapping screen

class AcceptedBookingsPage extends StatefulWidget {
  @override
  _AcceptedBookingsPageState createState() => _AcceptedBookingsPageState();
}

class _AcceptedBookingsPageState extends State<AcceptedBookingsPage> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  List<dynamic> _currentBookings = [];
  bool _isLoading = true;
  String? storedPhoneNumber;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadPhoneNumberAndStartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadPhoneNumberAndStartTimer() async {
    storedPhoneNumber = await secureStorage.read(key: "phone_number");
    await _fetchAndUpdateBookings(); // Initial fetch
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _timer = Timer.periodic(Duration(seconds: 3), (timer) {
      _fetchAndUpdateBookings();
    });
  }

  Future<void> _fetchAndUpdateBookings() async {
    if (storedPhoneNumber == null) return;

    try {
      final response = await http.post(
        Uri.parse('https://agnicarrental.com/driver2025/getBookings.php'),
        body: {'phone_number': storedPhoneNumber},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final List<dynamic> newBookings = data['acceptedBookings'];

          // Only update UI if data has changed
          if (!listEquals(_currentBookings, newBookings)) {
            setState(() {
              _currentBookings = newBookings;
              _isLoading = false;
            });
          } else {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print("Error fetching bookings: $e");
    }
  }

  void _confirmCancelTrip(String bookingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Cancel Trip"),
        content: Text("Are you sure you want to cancel this trip?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("No"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelTrip(bookingId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
            ),
            child: Text(
              "Yes, Cancel",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelTrip(String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse('https://agnicarrental.com/driver2025/cancelBooking.php'),
        body: {'booking_id': bookingId},
      );

      final data = json.decode(response.body);
      if (data['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Trip cancelled successfully.")),
        );
        _fetchAndUpdateBookings();
      } else {
        throw Exception(data['message'] ?? 'Cancellation failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  bool _shouldShowStartButton(Map<String, dynamic> booking) {
    final now = DateTime.now();
    final bookingDate = DateTime.tryParse(booking['date']);
    final bookingTime = booking['time'];

    if (bookingDate == null || bookingTime == null) return false;

    final timeParts = bookingTime.split(":");
    if (timeParts.length < 2) return false;

    final bookingDateTime = DateTime(
      bookingDate.year,
      bookingDate.month,
      bookingDate.day,
      int.tryParse(timeParts[0]) ?? 0,
      int.tryParse(timeParts[1]) ?? 0,
    );

    final diff = bookingDateTime.difference(now).inMinutes;

    return booking['booking_status'] == 'Accepted' &&
        booking['driver_id'] == storedPhoneNumber &&
        now.year == bookingDate.year &&
        now.month == bookingDate.month &&
        now.day == bookingDate.day &&
        diff <= 60;
  }

  Widget buildBookingCard(Map<String, dynamic> booking) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Booking ID: ${booking['booking_id']}",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text("${booking['trip_type']}")
              ],
            ),
            Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${booking['car_type']}"),
                Text("${booking['booking_status']}"),
              ],
            ),
            Divider(),
            const SizedBox(height: 6),
            Text(
              "Pickup",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text("${booking['pickup_location']}"),
            const SizedBox(height: 8),
            if (booking['trip_type'] != 'Local-Duty') ...[
              Text(
                "Drop",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text("${booking['drop_location']}"),
            ],
            if (booking['trip_type'] == 'One-way' ||
                booking['trip_type'] == 'Local-taxi') ...[
              Text("Distance: ${booking['distance']} km"),
            ],
            const Divider(),
            Text(
                "Pick up Date: ${booking['date']}  •  Time: ${booking['time']}"),
            if (booking['trip_type'] == 'Round-Trip') ...[
              const SizedBox(height: 6),
              Text(
                "Return Date: ${booking['return_date']} •  Time: ${booking['return_time']} ",
              ),
            ],
            const Divider(),
            Text(
              "Customer",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text("${booking['name']}"),
            GestureDetector(
              onTap: () =>
                  launchUrl(Uri.parse('tel:${booking['customer_contact']}')),
              child: Text(
                '${booking['customer_contact']}',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            Divider(),
            Text(
              "Driver",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text("${booking['full_name']} "),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('tel:${booking['driver_id']}')),
              child: Text(
                '${booking['driver_id']}',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            Divider(),
            Text("Vehicle No: ${booking['vehicle_id']}"),
            Divider(),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                if (booking['booking_status'] == 'Accepted') ...[
                  // Show "Change Driver & Car" and "Cancel Trip" buttons
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CarDriverSelectionScreen(
                            bookingId: booking['booking_id'].toString(),
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.swap_horiz,
                      color: Colors.white,
                    ),
                    label: Text(
                      "Change Driver & Car",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                    ),
                  ),

                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Driverlocationtracking(
                            bookingId: booking['booking_id'].toString(),
                            phoneNumber: booking['driver_id'],
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.map,
                      color: Colors.white,
                    ),
                    label: Text(
                      "Live Map",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                    ),
                  ),

                  ElevatedButton.icon(
                    onPressed: () =>
                        _confirmCancelTrip(booking['booking_id'].toString()),
                    icon: Icon(Icons.cancel, color: Colors.white),
                    label: Text(
                      "Cancel Trip",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                    ),
                  ),
                ] else ...[
                  // Show "End Trip" button instead when booking status is not "Accepted"
                  if (booking['driver_id'] == storedPhoneNumber)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TripLiveMapping(
                              bookingId: booking['booking_id'].toString(),
                              phoneNumber: booking['driver_id'],
                            ),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.stop,
                        color: Colors.white,
                      ),
                      label: Text(
                        "End Trip",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                      ),
                    ),
                ],
                if (_shouldShowStartButton(booking))
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StartingKmInputPage(
                            bookingId: booking['booking_id'].toString(),
                            savedOtp: booking['otp'].toString(),
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.play_arrow,
                      color: Colors.black,
                    ),
                    label: Text(
                      "Start Trip",
                      style: TextStyle(color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Accepted Bookings",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAndUpdateBookings,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _currentBookings.isEmpty
                ? const Center(child: Text("No accepted bookings found."))
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _currentBookings.length,
                    itemBuilder: (context, index) {
                      return buildBookingCard(_currentBookings[index]);
                    },
                  ),
      ),
    );
  }
}
