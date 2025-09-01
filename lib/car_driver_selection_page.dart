import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'booking_list.dart';

class CarDriverSelectionScreen extends StatefulWidget {
  final String bookingId;

  const CarDriverSelectionScreen({super.key, required this.bookingId});

  @override
  _CarDriverSelectionScreenState createState() =>
      _CarDriverSelectionScreenState();
}

class _CarDriverSelectionScreenState extends State<CarDriverSelectionScreen> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  List<Map<String, String>> driverWithVehicle = [];
  List<Map<String, String>> driverWithVendor = [];
  List<String> vehicles = [];
  List<String> drivers = [];
  String? selectedVehicle;
  String? selectedDriver;
  bool isLoading = true;
  bool isTripAccepted = false;
  String? phoneNumber;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    phoneNumber = await secureStorage.read(key: "phone_number");
    String apiUrl =
        "https://agnicarrental.com/driver2025/car_driver_selction_page.php?phone_number=$phoneNumber";

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == "success") {
          final driverVehicleData =
              data["data"]["driver_with_vehicle"] as List<dynamic>;
          final driverVendorData =
              data["data"]["driver_with_vendor"] as List<dynamic>;

          setState(() {
            driverWithVehicle = driverVehicleData
                .map(
                  (item) => {
                    "full_name": item["full_name"] as String,
                    "phone_number": item["phone_number"] as String,
                    "vehicle_number": item["vehicle_number"] as String,
                  },
                )
                .toList();

            driverWithVendor = driverVendorData
                .map(
                  (item) => {
                    "full_name": item["full_name"] as String,
                    "phone_number": item["phone_number"] as String,
                  },
                )
                .toList();

            vehicles = driverWithVehicle
                .map((item) => item["vehicle_number"]!)
                .toSet()
                .toList();
            drivers = driverWithVendor
                .map(
                  (item) => "${item["full_name"]}\n${item["phone_number"]}",
                )
                .toSet()
                .toList();

            selectedVehicle = vehicles.isNotEmpty ? vehicles[0] : null;
            selectedDriver = drivers.isNotEmpty ? drivers[0] : null;
            isLoading = false;
          });
        } else {
          throw Exception(data["message"] ?? "Unknown error");
        }
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString()}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    String? phoneNumber = await secureStorage.read(key: "phone_number");

    String vehicle_id = selectedVehicle!;
    List<String> parts = selectedDriver!.split('\n');
    String driver_id = parts.isNotEmpty ? parts.last : "";
    int? booking_id = int.tryParse(widget.bookingId.toString());

    var data = {
      'driver_id': driver_id,
      'vehicle_id': vehicle_id,
      'booking_id': booking_id,
      'vender_id': phoneNumber,
    };

    try {
      var response = await http.post(
        Uri.parse(
          'https://agnicarrental.com/driver2025/submit_car_driver_selction_page.php',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Trip submitted successfully")),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to submit trip")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void showTripAcceptedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              const Text(
                "Are you sure you want to accept this trip?",
                style: TextStyle(fontSize: 16, color: Colors.black),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              BookingListPage(phoneNumber: phoneNumber!),
                        ),
                        (Route<dynamic> route) => false,
                      );
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop(); // Close dialog
                      await _submitForm(); // Submit the form
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              BookingListPage(phoneNumber: phoneNumber!),
                        ),
                        (Route<dynamic> route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Car - Driver Selection",
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        backgroundColor: Colors.blueGrey,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: isLoading
                ? const SizedBox(
                    height: 400,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Vehicle Dropdown
                        buildDropdownCard(
                          label: 'Select Vehicle',
                          icon: Icons.directions_car,
                          value: selectedVehicle,
                          items: vehicles,
                          onChanged: (String? value) {
                            setState(() {
                              selectedVehicle = value;
                            });
                          },
                        ),
                        const SizedBox(height: 20),

                        // Driver Dropdown
                        buildDropdownCard(
                          label: 'Select Driver',
                          icon: Icons.person,
                          value: selectedDriver,
                          items: drivers,
                          onChanged: (String? value) {
                            setState(() {
                              selectedDriver = value;
                            });
                          },
                        ),
                        const SizedBox(height: 20),

                        // Checkbox
                        Row(
                          children: [
                            Checkbox(
                              value: isTripAccepted,
                              onChanged: (bool? value) {
                                setState(() {
                                  isTripAccepted = value ?? false;
                                });
                              },
                              activeColor: Colors.blueGrey,
                            ),
                            const Text(
                              'I accept this trip',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Submit Button
                        ElevatedButton(
                          onPressed: () {
                            if (selectedDriver != null &&
                                selectedVehicle != null &&
                                isTripAccepted) {
                              showTripAcceptedDialog(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please select all fields and accept the trip.',
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isTripAccepted
                                ? Colors.blueGrey
                                : const Color.fromARGB(
                                    255,
                                    199,
                                    198,
                                    197,
                                  ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: const Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
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

  Widget buildDropdownCard({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: value,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                prefixIcon: Icon(icon, color: Colors.blueGrey),
              ),
              borderRadius: BorderRadius.circular(8),
              dropdownColor: const Color.fromARGB(255, 222, 236, 243),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: onChanged,
              hint: Text(
                'Choose a ${label.toLowerCase()}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
