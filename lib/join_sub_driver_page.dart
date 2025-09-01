import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'car_reg_form.dart';
import 'driverComleatedList.dart';
import 'driverLocationTracking.dart';
import 'driver_add_form.dart';
import 'owner_account.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:table_calendar/table_calendar.dart';
import 'startingKmInputPage.dart';
import 'tripLiveMaping.dart'; // For listEquals
import 'package:url_launcher/url_launcher.dart';

class JoinSubDriverPage extends StatefulWidget {
  @override
  State<JoinSubDriverPage> createState() => _SubDriverPageState();
}

class _SubDriverPageState extends State<JoinSubDriverPage> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  List<dynamic> _currentBookings = [];
  bool isLoading = true;
  bool showLoader = false;
  bool _isLoading = true;
  String? phoneNumber;
  String? storedPhoneNumber;
  Timer? _timer;
  String driverCode = "";
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadPhoneNumberAndStartTimer();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _getCurrentLocationAndSend();
    });
    _fetchDriverCode();
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

  Future<void> _fetchDriverCode() async {
    storedPhoneNumber = await secureStorage.read(key: "phone_number");
    final String apiUrl =
        "https://agnicarrental.com/driver2025/driver_code_fetching.php?phone_number=$storedPhoneNumber";

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData["status"] == "success") {
          setState(() {
            driverCode = responseData['driver_code'];
          });
        } else {
          setState(() {
            driverCode = "Error: ${responseData['message']}";
          });
        }
      } else {
        setState(() {
          driverCode = "Server Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        driverCode = "Network Error: $e";
      });
    }
  }

  Future<void> _fetchAndUpdateBookings() async {
    if (storedPhoneNumber == null) return;
    print("Phone Number :$storedPhoneNumber");
    try {
      final response = await http.post(
        Uri.parse(
            'https://agnicarrental.com/driver2025/get_bookings_for_driver.php'),
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
          }
        }
      }
    } catch (e) {
      print("Error fetching bookings: $e");
    }
  }

  Future<void> _getCurrentLocationAndSend() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Location permissions are denied.");
        return;
      }
    }
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    double latitude = position.latitude;
    double longitude = position.longitude;
    await _updateLocationToServer(latitude, longitude);
  }

  Future<void> _updateLocationToServer(
      double latitude, double longitude) async {
    String url = 'https://agnicarrental.com/driver2025/update_location.php';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'driver_id': phoneNumber ?? '',
        },
      );
      print("Location update response: ${response.body}");
    } catch (e) {
      print("Error updating location: $e");
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
                Text("${booking['trip_type']}"),
              ],
            ),
            Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Car Type: ${booking['car_type']}"),
                Text("Status: ${booking['booking_status']}"),
              ],
            ),
            const SizedBox(height: 6),
            Text("Pickup: ${booking['pickup_location']}"),
            if (booking['drop_location'] != '')
              Text("Drop: ${booking['drop_location']}"),
            if (booking['distance'] != 0)
              Text("Distance: ${booking['distance']} km"),
            const Divider(),
            Text("Date: ${booking['date']}  •  Time: ${booking['time']}"),
            if (booking['trip_type'] == 'Round-Trip') ...[
              Text(
                  "Return Date: ${booking['return_date']}  •  Time: ${booking['reture_time']}"),
            ],
            const Divider(),
            Text("Customer: ${booking['name']} "),
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
            Text("Vehicle No: ${booking['vehicle_id']}"),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('tel:${booking['vender_id']}')),
              child: Text(
                '${booking['vender_id']}',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                if (booking['booking_status'] == 'Started') ...[
                  // Show "End Trip" button instead when booking status is not "Accepted"
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
                    icon: Icon(Icons.stop),
                    label: Text("End Trip"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
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
                    icon: Icon(Icons.play_arrow, color: Colors.white),
                    label: Text(
                      "Start Trip",
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
                    label: Text("Map"))
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
      backgroundColor: const Color.fromARGB(255, 199, 232, 247),
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Agni Driver",
              style: TextStyle(color: Colors.white),
            ),
            Text(
              "#$driverCode",
              style: TextStyle(color: Colors.white),
            )
          ],
        ),
        backgroundColor: Colors.blueGrey,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            color: const Color.fromARGB(255, 244, 193, 54),
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.only(left: 10.0, right: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Place the first button in the first half

                  // Place the second button in the second half

                  Expanded(
                    child: TextButton(
                      onPressed: () {},
                      child: Text(
                        "Bookings",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                  Text("|"),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => Drivercomleatedlist()),
                        );
                      },
                      child: Text(
                        "Completed",
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchAndUpdateBookings,
              child: _isLoading
                  ? Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text("Not bookings available"),
                        ),
                        TableCalendar(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2025, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDay, day),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                          },
                        ),
                      ],
                    )
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
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
            child: Container(
              width: double.infinity,
              color: const Color.fromARGB(255, 223, 245, 252),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.home, color: Colors.blueGrey),
                        Text(
                          "Home",
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CarFormPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.directions_car, color: Colors.blueGrey),
                        Text(
                          "Add Cab",
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => DriverFormPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.person_add_alt_1_rounded,
                            color: Colors.blueGrey),
                        Text(
                          "Add Driver",
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => OwnerProfileScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.person_add_alt_1_rounded,
                            color: Colors.blueGrey),
                        Text(
                          "Account",
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
