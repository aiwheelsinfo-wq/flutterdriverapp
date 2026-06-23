import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'api_config.dart';


class Drivercomleatedlist extends StatefulWidget {
  const Drivercomleatedlist({super.key});

  @override
  State<Drivercomleatedlist> createState() => _InvoicelistState();
}

class _InvoicelistState extends State<Drivercomleatedlist> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  String? phoneNumber;
  List<dynamic> compleatedBookings = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchBookings();
    // Fetch new bookings every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      fetchBookings();
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  Future<void> fetchBookings() async {
    try {
      String? phoneNumber = await secureStorage.read(key: "phone_number");
      if (phoneNumber == null) {
        print("Phone number not found in secure storage.");
        return;
      }

      String apiUrl =
          "${ApiConfig.getCompletedListForDriver}?phone_number=$phoneNumber";


      var response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse["success"] == true) {
          setState(() {
            compleatedBookings = jsonResponse["compleatedBookings"] ?? [];
          });
        } else {
          print("No completed bookings found.");
        }
      } else {
        print("Failed to fetch bookings. Status Code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching bookings: $e");
    }
  }

  double parseDouble(dynamic value) {
    if (value == null) return 0.0;
    try {
      return double.parse(value.toString());
    } catch (_) {
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Completed Trip"),
        backgroundColor: const Color.fromARGB(255, 247, 233, 192),
      ),
      body: compleatedBookings.isEmpty
          ? const Center(
              child: Text("No booking is found"),
            )
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                itemCount: compleatedBookings.length,
                itemBuilder: (context, index) {
                  var booking = compleatedBookings[index];
                  final double startKm = parseDouble(booking['starting_km']);
                  final double endKm = parseDouble(booking['closing_km']);
                  final double totalKm = endKm - startKm;

                  return Card(
                    margin: const EdgeInsets.all(8),
                    elevation: 5,
                    child: ListTile(
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 247, 233, 192),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("B.ID :${booking['id']}",
                                      style: const TextStyle(fontSize: 20)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("${booking['car_type']}",
                                      style: const TextStyle(fontSize: 16)),
                                  Text("${booking['trip_type']}",
                                      style: const TextStyle(fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                          Divider(),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("From: ${booking['from_address']}"),
                                if (booking['to_address'] != '') ...[
                                  Text("To: ${booking['to_address']}"),
                                ],
                                const Divider(),
                                Text(
                                    "Starting at : ${booking['starting_date']} - ${booking['starting_time']}"),
                                Text(
                                    "Ending at : ${booking['closing_date']} - ${booking['closing_time']}"),
                                const Divider(),
                                Text("Vehicle: ${booking['vehicle_id']}"),
                                const Divider(),
                                Text("Owner No: ${booking['vender_id']}"),
                                const Divider(),
                                Text(
                                  "Total Running $totalKm Km",
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(
                                        255, 247, 233, 192),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Partner Earning"),
                                        Text(
                                          "₹${booking['vendor_amount'].toString()}",
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                      onTap: () {
                        // Handle onTap, like navigation to detailed view
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
