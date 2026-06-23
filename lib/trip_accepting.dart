import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';
import 'booking_list.dart';


class DriverTripPage extends StatefulWidget {
  final String bookingId;
  final String phoneNumber;

  const DriverTripPage({
    super.key,
    required this.bookingId,
    required this.phoneNumber,
  });

  @override
  _DriverTripPageState createState() => _DriverTripPageState();
}

class _DriverTripPageState extends State<DriverTripPage> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  bool isChecked = false;
  bool showDetails = false;

  String? storedPhoneNumber;

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
    // Automatically pop the page after 15 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> _loadPhoneNumber() async {
    String? phoneNumber = await secureStorage.read(key: "phone_number");

    setState(() {
      storedPhoneNumber = phoneNumber;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => showAcceptDialog());
  }

  Future<void> acceptTrip() async {
    if (storedPhoneNumber == null) return;

    String apiUrl = ApiConfig.acceptBooking;

    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        body: {
          "booking_id": widget.bookingId,
          "driver_id": storedPhoneNumber,
        },
      );

      print("Sent Booking ID: ${widget.bookingId}");
      print("Sent Driver ID: $storedPhoneNumber");
      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.headers["content-type"]?.contains("application/json") ==
          true) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse["success"] == true) {
          setState(() {
            showDetails = true;
          });

          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text(
                    "Trip Accepted",
                    overflow: TextOverflow.ellipsis,
                  ),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 80),
                      SizedBox(height: 10),
                      Text(
                        "You have successfully accepted the trip!",
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookingListPage(
                              phoneNumber: storedPhoneNumber!,
                            ),
                          ),
                          (route) => false,
                        );
                      },
                      child: const Text(
                        "OK",
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
              "Booking accepted successfully!",
              overflow: TextOverflow.ellipsis,
            )),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                jsonResponse["message"] ?? "Failed to accept booking",
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
          if (mounted) Navigator.pop(context); // Go back
        }
      } else {
        print("Unexpected response format. Check API output.");
        if (mounted) Navigator.pop(context); // Go back
      }
    } catch (e) {
      print("Error accepting booking: $e");
      if (mounted) Navigator.pop(context); // Go back
    }
  }

  void showAcceptDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool localChecked = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                "Confirm Trip Acceptance",
                overflow: TextOverflow.ellipsis,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Are you sure you want to accept this trip?",
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: localChecked,
                        onChanged: (bool? value) {
                          setDialogState(() {
                            localChecked = value ?? false;
                          });
                        },
                      ),
                      const Text(
                        "I confirm the trip",
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: localChecked
                      ? () {
                          setState(() {
                            isChecked = localChecked;
                          });
                          Navigator.pop(context);
                          acceptTrip();
                        }
                      : null,
                  child: const Text(
                    "OK",
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: storedPhoneNumber == null
          ? const Center(child: CircularProgressIndicator())
          : showDetails
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center, // Center vertically
                    crossAxisAlignment:
                        CrossAxisAlignment.center, // Center horizontally
                    children: [
                      const SizedBox(height: 10),

                      const SizedBox(height: 20),

                      // Centering CircularProgressIndicator
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ],
                  ),
                )
              : const Center(child: CircularProgressIndicator()),
    );
  }
}
