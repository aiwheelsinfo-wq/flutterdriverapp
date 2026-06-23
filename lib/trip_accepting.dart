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
  bool isLoadingDetails = true;
  Map<String, dynamic>? bookingDetails;

  String? storedPhoneNumber;

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
    // Automatically pop the page after 45 seconds (increased to allow load/review)
    Future.delayed(const Duration(seconds: 45), () {
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

    _fetchBookingDetails();
  }

  Future<void> _fetchBookingDetails() async {
    if (!mounted) return;
    setState(() {
      isLoadingDetails = true;
    });

    final String url = "${ApiConfig.legacyPath}/get_booking_details.php?booking_id=${widget.bookingId}";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          setState(() {
            bookingDetails = jsonResponse['data'];
            isLoadingDetails = false;
          });
          if (mounted) {
            showAcceptDialog();
          }
          return;
        }
      }
    } catch (e) {
      print("Error fetching booking details: $e");
    }

    setState(() {
      isLoadingDetails = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load trip details.")),
      );
      Navigator.pop(context);
    }
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
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final details = bookingDetails ?? {};
            final tripType = details['trip_type'] ?? 'N/A';
            final formattedDate = details['formatted_date'] ?? '';
            final formattedTime = details['formatted_time'] ?? '';
            final pickupLocation = details['from_address'] ?? 'N/A';
            final dropLocation = details['to_address'] ?? 'N/A';
            final vehicleType = details['car_type'] ?? 'N/A';
            final customerName = details['customer_name'] ?? 'Customer';
            final bookingIdVal = details['id'] != null ? '#TRIP${details['id']}' : '#TRIP';
            
            final double vendorAmount = double.tryParse(details['vendor_amount']?.toString() ?? '0') ?? 0.0;
            final double baseFare = double.tryParse(details['base_charge']?.toString() ?? '0') ?? 0.0;
            final double paidAmount = double.tryParse(details['paid_amount']?.toString() ?? '0') ?? 0.0;
            final double agniAmount = double.tryParse(details['agni_amount']?.toString() ?? '0') ?? 0.0;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.0),
              ),
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24.0),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.9,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Green Accent with Check Icon
                      Container(
                        width: double.infinity,
                        color: const Color(0xFF0F4C3A), // Dark Green
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Color(0xFF0F4C3A),
                                size: 36.0,
                              ),
                            ),
                            const SizedBox(height: 16.0),
                            const Text(
                              "Confirm Trip Acceptance",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20.0,
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            const Text(
                              "You are about to accept this trip\nPlease review trip details & your earnings",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Scrollable Details Content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Trip Details Heading
                              Row(
                                children: [
                                  Icon(Icons.map_outlined, color: const Color(0xFF0F4C3A), size: 20.0),
                                  const SizedBox(width: 8.0),
                                  const Text(
                                    "Trip Details",
                                    style: TextStyle(
                                      color: Color(0xFF0F4C3A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15.0,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20.0, thickness: 1.0),
                              
                              // Detail Rows
                              _buildDetailRow(Icons.alt_route, "Trip Type", tripType),
                              _buildDetailRow(Icons.calendar_month, "Date & Time", "$formattedDate • $formattedTime"),
                              _buildDetailRow(Icons.location_on, "Pickup Location", pickupLocation, isHighlight: true),
                              if (dropLocation.isNotEmpty && dropLocation != 'N/A')
                                _buildDetailRow(Icons.location_on_outlined, "Drop Location", dropLocation, isHighlight: true),
                              _buildDetailRow(Icons.directions_car, "Vehicle Type", vehicleType),
                              _buildDetailRow(Icons.person, "Customer Name", customerName),
                              _buildDetailRow(Icons.article, "Booking ID", bookingIdVal),
                              
                              const SizedBox(height: 20.0),
                              
                              // 2. Earnings Block (Card Layout)
                              Container(
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F8F5), // Very Light Green Background
                                  borderRadius: BorderRadius.circular(16.0),
                                  border: Border.all(color: const Color(0xFFD0E8DD), width: 1.0),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.account_balance_wallet, color: const Color(0xFF0F4C3A), size: 24.0),
                                        const SizedBox(width: 8.0),
                                        const Text(
                                          "Your Earnings",
                                          style: TextStyle(
                                            color: Color(0xFF0F4C3A),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8.0),
                                    Text(
                                      "₹ ${vendorAmount.toStringAsFixed(2)}",
                                      style: const TextStyle(
                                        color: Color(0xFF0F4C3A),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 26.0,
                                      ),
                                    ),
                                    const SizedBox(height: 12.0),
                                    _buildEarningsRow("Base Fare", "₹ ${baseFare.toStringAsFixed(2)}"),
                                    _buildEarningsRow("Advance Received", "₹ ${paidAmount.toStringAsFixed(2)}"),
                                    _buildEarningsRow("Your Commission", "₹ ${agniAmount.toStringAsFixed(2)}", isGreen: true),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 16.0),
                              
                              // 3. Agreement / Info Block
                              Container(
                                padding: const EdgeInsets.all(12.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9F9F9),
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(color: Colors.grey.shade200, width: 1.0),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.verified_user, color: const Color(0xFF2E7D32).withOpacity(0.7), size: 18.0),
                                    const SizedBox(width: 8.0),
                                    const Expanded(
                                      child: Text(
                                        "By accepting this trip, you agree to provide the service as per the booking details.",
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 11.0,
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
                      
                      // Bottom Actions Buttons (Sticky)
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1.0)),
                        ),
                        child: Row(
                          children: [
                            // Cancel Button
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context); // Close dialog
                                  Navigator.pop(context); // Go back
                                },
                                icon: const Icon(Icons.close, color: Colors.grey, size: 16.0),
                                label: const Text(
                                  "Cancel",
                                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.grey),
                                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            
                            // Accept Trip Button
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context); // Close dialog
                                  acceptTrip(); // Accept trip logic
                                },
                                icon: const Icon(Icons.check, color: Colors.white, size: 16.0),
                                label: const Text(
                                  "Accept Trip",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F4C3A), // Dark Green
                                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
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
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 18.0),
          const SizedBox(width: 12.0),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13.0,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isHighlight ? const Color(0xFF0F4C3A) : Colors.black,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                fontSize: 13.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsRow(String label, String value, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isGreen ? const Color(0xFF2E7D32) : Colors.grey.shade700,
              fontWeight: isGreen ? FontWeight.bold : const TextStyle().fontWeight,
              fontSize: 12.0,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isGreen ? const Color(0xFF2E7D32) : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 12.0,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: storedPhoneNumber == null || isLoadingDetails
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
