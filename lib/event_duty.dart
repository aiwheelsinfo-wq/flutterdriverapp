import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';


class EventDutyPage extends StatefulWidget {
  const EventDutyPage({super.key});

  @override
  State<EventDutyPage> createState() => _EventDutyPageState();
}

class _EventDutyPageState extends State<EventDutyPage> {
  final storage = const FlutterSecureStorage();
  List<dynamic> trips = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTrips();
  }

  Future<void> fetchTrips() async {
    try {
      // 1. Read phone number from secure storage
      String? phoneNumber = await storage.read(key: "phone_number");

      if (phoneNumber == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      // 2. Fetch trips from API
      final url = Uri.parse(
          "${ApiConfig.passengerBooking}?driver_id=$phoneNumber");


      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          trips = data;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint("Error fetching trips: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Duty'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : trips.isEmpty
              ? const Center(child: Text("No trips found"))
              : ListView.builder(
                  itemCount: trips.length,
                  itemBuilder: (context, index) {
                    final trip = trips[index];
                    return Card(
                      margin: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip["trip_type"] ?? "Unknown Trip",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text("Passenger: ${trip["passenger_name"]}"),
                            Text("From: ${trip["from_destination"]}"),
                            Text("To: ${trip["to_destination"]}"),
                            Text("Date: ${trip["from_date"]}"),
                            Text("Time: ${trip["from_time"]}"),
                            Text(
                                "Vehicle: ${trip["vehicle_type"]} (${trip["vehicle_number"]})"),
                            Text("Booking Status: ${trip["booking_status"]}"),
                            const SizedBox(height: 8),
                            Text(
                              "KM: ${trip["starting_km"]} → ${trip["ending_km"]}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
