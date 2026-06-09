import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'car_reg_form.dart';
import 'driverComleatedList.dart';
import 'driverLocationTracking.dart';
import 'driver_add_form.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'whatsapp_booking_list.dart';

import 'owner_account.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'startingKmInputPage.dart';
import 'tripLiveMaping.dart'; // For listEquals
import 'package:url_launcher/url_launcher.dart';
import 'api_config.dart';


class JoinSubDriverPage extends StatefulWidget {
  const JoinSubDriverPage({super.key});

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
  final DateTime _selectedDay = DateTime.now();
  final DateTime _focusedDay = DateTime.now();

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

  final List<String> imageUrls = [
    ApiConfig.add1Webp,
    ApiConfig.add2Webp,
    ApiConfig.add3Webp,
    ApiConfig.add4Webp,

  ];

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
        "${ApiConfig.driverCodeFetching}?phone_number=$storedPhoneNumber";


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
        Uri.parse(ApiConfig.getBookingsForDriver),
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
    String url = ApiConfig.updateLocation;

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
                            triptype: booking['trip_type'].toString(),
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
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => NearbyTripsPage()),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(10),
                    padding: const EdgeInsets.all(16),
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // WhatsApp Logo
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/WhatsApp_icon.png',
                            width: 90,
                            height: 90,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Text & Booking Info
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "WhatsApp Booking",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "From 500+ WhatsApp groups",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(255, 34, 197, 40),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "Click to view bookings",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Join Button below
                const SizedBox(height: 4),
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 2), // margin outside
                  child: SizedBox(
                    width: double.infinity, // takes full available width
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final Uri url = Uri.parse(
                          "https://chat.whatsapp.com/IJ6sNowb9nO775kGM4Dzq3?mode=ems_copy_c",
                        );
                        if (!await launchUrl(url,
                            mode: LaunchMode.externalApplication)) {
                          throw Exception("Could not launch $url");
                        }
                      },
                      icon: const Icon(
                        Icons.group,
                        color: Colors.white,
                      ),
                      label: const Text("Join WhatsApp Group"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(236, 158, 235, 249),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12), // inside padding
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchAndUpdateBookings,
              child: _isLoading
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 🔹 No Bookings Image in a Card
                        Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          child: GestureDetector(
                            onTap: () async {
                              final Uri url = Uri.parse("https://oluber.com/");
                              if (!await launchUrl(url,
                                  mode: LaunchMode.externalApplication)) {
                                throw Exception("Could not launch $url");
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                "assets/oluber_add.png", // your asset
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 🔹 Slider below "No Bookings"
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(
                                bottom: 10), // bottom margin
                            child: CarouselSlider(
                              options: CarouselOptions(
                                height: 160.0,
                                autoPlay: true,
                                enlargeCenterPage: true,
                                aspectRatio: 16 / 9,
                                autoPlayInterval: const Duration(seconds: 3),
                                autoPlayCurve: Curves.fastOutSlowIn,
                                enableInfiniteScroll: true,
                              ),
                              items: imageUrls.map((url) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    placeholder: (context, url) => const Center(
                                        child: CircularProgressIndicator()),
                                    errorWidget: (context, url, error) =>
                                        const Center(
                                            child: Icon(Icons.error,
                                                color: Colors.red)),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
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
