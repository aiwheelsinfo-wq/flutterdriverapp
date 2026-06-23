import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';
import 'booking_list.dart';
import 'package:google_fonts/google_fonts.dart';


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

  List<String> vehicles = [];
  List<String> drivers = [];
  String? selectedVehicle;
  String? selectedDriver;
  Map<String, String> vehicleStatus = {};
  Map<String, String> driverStatus = {};
  List<Map<String, dynamic>> driverWithVendor = [];
  bool isTripAccepted = false;

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
    // Automatically pop the page after 90 seconds to allow time for vehicle/driver selection
    Future.delayed(const Duration(seconds: 90), () {
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

    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      isLoadingDetails = true;
    });

    final String detailsUrl = "${ApiConfig.legacyPath}/get_booking_details.php?booking_id=${widget.bookingId}";

    try {
      final detailsResponse = await http.get(Uri.parse(detailsUrl));
      if (detailsResponse.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(detailsResponse.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          bookingDetails = jsonResponse['data'];

          // Check if already accepted
          final String status = bookingDetails!['booking_status'] ?? 'Pending';
          final String acceptedVendor = bookingDetails!['vender_id'] ?? '';

          if (status != 'Pending') {
            if (mounted) {
              String msg = "This trip has already been accepted.";
              if (acceptedVendor == (storedPhoneNumber ?? widget.phoneNumber)) {
                msg = "You have already accepted this trip.";
              } else if (acceptedVendor.isNotEmpty) {
                msg = "This trip has been accepted by another vendor.";
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(msg),
                  backgroundColor: Colors.orange.shade800,
                ),
              );

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingListPage(
                    phoneNumber: storedPhoneNumber ?? widget.phoneNumber,
                  ),
                ),
                (route) => false,
              );
              return;
            }
          }
        } else {
          throw Exception("Failed to load booking details");
        }
      } else {
        throw Exception("Failed to load booking details");
      }

      // 2. Fetch Cars and Drivers if vendor phone is loaded
      if (storedPhoneNumber != null) {
        String apiUrl = "${ApiConfig.carDriverSelectionPage}?phone_number=$storedPhoneNumber";
        String carsUrl = "${ApiConfig.carListForVendor}?vendor_id=$storedPhoneNumber";

        final response = await http.get(Uri.parse(apiUrl));
        final carsResponse = await http.get(Uri.parse(carsUrl));

        if (response.statusCode == 200 && carsResponse.statusCode == 200) {
          final data = jsonDecode(response.body);
          final carsData = jsonDecode(carsResponse.body);

          if (data["status"] == "success" && carsData["status"] == true) {
            final driverVehicleData = data["data"]["driver_with_vehicle"] as List<dynamic>;
            final driverVendorData = data["data"]["driver_with_vendor"] as List<dynamic>;
            final carsList = carsData["data"] as List<dynamic>;

            driverWithVendor = driverVendorData
                .map((item) => {
                      "full_name": item["full_name"],
                      "phone_number": item["phone_number"],
                      "availability_status": item["availability_status"] ?? "available",
                    })
                .toList();

            // Populate vehicles from the vendor's actual active/approved cars list
            vehicles = carsList
                .where((car) => car["status"] != "inactive")
                .map((car) => car["vehicle_number"].toString())
                .toSet()
                .toList();

            drivers = driverWithVendor
                .map((item) => "${item["full_name"]}\n${item["phone_number"]}")
                .toSet()
                .toList();

            // Map vehicle status based on today's bookings in the car list
            vehicleStatus = {
              for (var car in carsList)
                car["vehicle_number"].toString(): _isBookedToday(car["bookings"] ?? []) ? "conflict" : "available"
            };

            driverStatus = {
              for (var d in driverWithVendor)
                "${d["full_name"]}\n${d["phone_number"]}": d["availability_status"]
            };

            selectedVehicle = vehicles.cast<String?>().firstWhere(
                (v) => vehicleStatus[v] != "conflict",
                orElse: () => null);

            selectedDriver = drivers.cast<String?>().firstWhere(
                (d) => driverStatus[d] != "conflict",
                orElse: () => null);
          }
        }
      }

      setState(() {
        isLoadingDetails = false;
      });
    } catch (e) {
      print("Error fetching data: $e");
      setState(() {
        isLoadingDetails = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load details: $e")),
        );
        Navigator.pop(context);
      }
    }
  }

  bool _isBookedToday(List bookings) {
    String today = DateTime.now().toString().split(" ")[0];
    return bookings.any((b) => b["date"] == today);
  }

  Future<void> acceptTrip() async {
    if (storedPhoneNumber == null) return;

    String apiUrl = ApiConfig.acceptBooking;

    String? driverPhone;
    if (selectedDriver != null) {
      driverPhone = selectedDriver!.split('\n').last.trim();
    }

    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        body: {
          "booking_id": widget.bookingId,
          "vendor_id": storedPhoneNumber,
          "driver_id": driverPhone ?? storedPhoneNumber,
          "vehicle_id": selectedVehicle ?? '',
        },
      );

      print("Sent Booking ID: ${widget.bookingId}");
      print("Sent Vendor ID: $storedPhoneNumber");
      print("Sent Driver ID: ${driverPhone ?? storedPhoneNumber}");
      print("Sent Vehicle ID: ${selectedVehicle ?? ''}");
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
                String? driverNameOnly;
                if (selectedDriver != null) {
                  driverNameOnly = selectedDriver!.split('\n').first;
                }

                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Success Check Circle with pulsing-like background
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E9), // Light green tint
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0F4C3A), // Dark Green matching the theme
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 40.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24.0),

                        // Title
                        Text(
                          "Trip Accepted!",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF0F4C3A),
                            fontWeight: FontWeight.bold,
                            fontSize: 22.0,
                          ),
                        ),
                        const SizedBox(height: 12.0),

                        // Description
                        Text(
                          "You have successfully accepted this booking and assigned assets to it.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14.0,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20.0),

                        // Assigned Assets Card
                        if (selectedVehicle != null || driverNameOnly != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9F9F9),
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                if (selectedVehicle != null)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Vehicle:",
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13.0,
                                        ),
                                      ),
                                      Text(
                                        selectedVehicle!,
                                        style: const TextStyle(
                                          color: Color(0xFF263238),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (selectedVehicle != null && driverNameOnly != null)
                                  const SizedBox(height: 8.0),
                                if (driverNameOnly != null)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Driver:",
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13.0,
                                        ),
                                      ),
                                      Text(
                                        driverNameOnly,
                                        style: const TextStyle(
                                          color: Color(0xFF263238),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.0,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 28.0),

                        // OK Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F4C3A), // Dark Green matching the theme
                              padding: const EdgeInsets.symmetric(vertical: 14.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              "View My Trips",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                "Booking accepted successfully!",
                overflow: TextOverflow.ellipsis,
              )),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  jsonResponse["message"] ?? "Failed to accept booking",
                  overflow: TextOverflow.ellipsis,
                ),
                backgroundColor: Colors.red.shade800,
              ),
            );
          }
        }
      } else {
        print("Unexpected response format. Check API output.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to accept booking: Invalid server response"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print("Error accepting booking: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error accepting booking: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSelectionCard({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required Map<String, String> statusMap,
    required Function(String?) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0F4C3A), size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF263238),
                  fontSize: 14.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            hint: Text("Select ${label.split(' ')[0]}"),
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF0F4C3A)),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            items: items.map((String item) {
              bool isConflict = statusMap[item] == "conflict";
              return DropdownMenuItem<String>(
                value: item,
                enabled: !isConflict,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Text(item,
                            style: TextStyle(
                                color: isConflict ? Colors.grey : const Color(0xFF263238),
                                fontSize: 13))),
                    if (isConflict)
                      const Badge(
                          label: Text("BOOKED"), backgroundColor: Colors.red)
                    else
                      const Icon(Icons.check_circle_outline,
                          size: 16, color: Colors.green),
                  ],
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptanceBox() {
    return InkWell(
      onTap: () => setState(() => isTripAccepted = !isTripAccepted),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(top: 16.0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isTripAccepted
              ? const Color(0xFF0F4C3A).withOpacity(0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isTripAccepted ? const Color(0xFF0F4C3A) : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isTripAccepted,
              onChanged: (v) => setState(() => isTripAccepted = v ?? false),
              activeColor: const Color(0xFF0F4C3A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            const Expanded(
              child: Text(
                  "I confirm the availability and accept this trip assignment.",
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF263238),
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
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
              fontWeight: isGreen ? FontWeight.bold : FontWeight.w500,
              fontSize: 13.0,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isGreen ? const Color(0xFF2E7D32) : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 13.0,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (storedPhoneNumber == null || isLoadingDetails) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0F4C3A))),
      );
    }

    if (showDetails) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF0F4C3A)),
              SizedBox(height: 16),
              Text(
                "Processing assignment...",
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
              )
            ],
          ),
        ),
      );
    }

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

    // Check if the vendor can submit the trip
    bool canAccept = isTripAccepted;
    if (vehicles.isNotEmpty && selectedVehicle == null) canAccept = false;
    if (drivers.isNotEmpty && selectedDriver == null) canAccept = false;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false, // Let green header reach the top status bar area for full bleed look
        child: Column(
          children: [
            // Scrollable Main Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Top Green Accent with Check Icon
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F4C3A), // Dark Green
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(32.0),
                          bottomRight: Radius.circular(32.0),
                        ),
                      ),
                      padding: const EdgeInsets.only(
                        top: 60.0, // Extra top padding for safe area since safeArea top is false
                        bottom: 32.0,
                        left: 16.0,
                        right: 16.0,
                      ),
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
                              size: 32.0,
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          Text(
                            "Confirm Trip Acceptance",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22.0,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          const Text(
                            "You are about to accept this trip\nPlease review trip details & your earnings",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13.0,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Trip Details Heading & Card
                          Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20.0),
                              border: Border.all(color: Colors.grey.shade200, width: 1.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.01),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.map_outlined, color: Color(0xFF0F4C3A), size: 20.0),
                                    const SizedBox(width: 8.0),
                                    Text(
                                      "Trip Details",
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF0F4C3A),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15.0,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24.0, thickness: 1.0),
                                _buildDetailRow(Icons.alt_route, "Trip Type", tripType),
                                _buildDetailRow(Icons.calendar_month, "Date & Time", "$formattedDate • $formattedTime"),
                                _buildDetailRow(Icons.location_on, "Pickup Location", pickupLocation, isHighlight: true),
                                if (dropLocation.isNotEmpty && dropLocation != 'N/A')
                                  _buildDetailRow(Icons.location_on_outlined, "Drop Location", dropLocation, isHighlight: true),
                                _buildDetailRow(Icons.directions_car, "Vehicle Type", vehicleType),
                                _buildDetailRow(Icons.person, "Customer Name", customerName),
                                _buildDetailRow(Icons.article, "Booking ID", bookingIdVal),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16.0),

                          // 2. Earnings Block (Card Layout)
                          Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F8F5), // Very Light Green Background
                              borderRadius: BorderRadius.circular(20.0),
                              border: Border.all(color: const Color(0xFFD0E8DD), width: 1.0),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.account_balance_wallet, color: Color(0xFF0F4C3A), size: 22.0),
                                    const SizedBox(width: 8.0),
                                    Text(
                                      "Your Earnings",
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF0F4C3A),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.0,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  "₹ ${vendorAmount.toStringAsFixed(2)}",
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF0F4C3A),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 26.0,
                                  ),
                                ),
                                const Divider(height: 24.0, color: Color(0xFFD0E8DD), thickness: 1.0),
                                _buildEarningsRow("Base Fare", "₹ ${baseFare.toStringAsFixed(2)}"),
                                _buildEarningsRow("Advance Received", "₹ ${paidAmount.toStringAsFixed(2)}"),
                                _buildEarningsRow("Your Commission", "₹ ${agniAmount.toStringAsFixed(2)}", isGreen: true),
                              ],
                            ),
                          ),

                          // 3. Selection Dropdowns
                          if (vehicles.isNotEmpty)
                            _buildSelectionCard(
                              label: "Vehicle Selection",
                              icon: Icons.directions_car_filled_rounded,
                              value: selectedVehicle,
                              items: vehicles,
                              statusMap: vehicleStatus,
                              onChanged: (v) => setState(() => selectedVehicle = v),
                            ),

                          if (drivers.isNotEmpty)
                            _buildSelectionCard(
                              label: "Driver Selection",
                              icon: Icons.person_pin_rounded,
                              value: selectedDriver,
                              items: drivers,
                              statusMap: driverStatus,
                              onChanged: (v) => setState(() => selectedDriver = v),
                            ),

                          const SizedBox(height: 16.0),

                          // 4. Agreement / Info Block
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
                                      fontSize: 12.0,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 5. Checkbox Agreement
                          _buildAcceptanceBox(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sticky Bottom Actions
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  )
                ],
                border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1.0)),
              ),
              child: Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
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
                      onPressed: canAccept ? acceptTrip : null,
                      icon: const Icon(Icons.check, color: Colors.white, size: 16.0),
                      label: const Text(
                        "Accept Trip",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F4C3A), // Dark Green
                        disabledBackgroundColor: Colors.grey.shade300,
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
    );
  }
}
