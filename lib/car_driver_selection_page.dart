import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';
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

  List<Map<String, dynamic>> driverWithVehicle = [];
  List<Map<String, dynamic>> driverWithVendor = [];
  List<String> vehicles = [];
  List<String> drivers = [];
  String? selectedVehicle;
  String? selectedDriver;
  bool isLoading = true;
  bool isTripAccepted = false;
  String? phoneNumber;

  Map<String, String> vehicleStatus = {};
  Map<String, String> driverStatus = {};

  // Theme Colors
  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color lightAmber = Color(0xFFFFF8E1);
  static const Color darkCharcoal = Color(0xFF263238);
  static const Color errorRed = Color(0xFFD32F2F);

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    phoneNumber = await secureStorage.read(key: "phone_number");
    String apiUrl =
        "${ApiConfig.carDriverSelectionPage}?phone_number=$phoneNumber";
    String carsUrl =
        "${ApiConfig.carListForVendor}?vendor_id=$phoneNumber";

    try {
      final response = await http.get(Uri.parse(apiUrl));
      final carsResponse = await http.get(Uri.parse(carsUrl));

      if (response.statusCode == 200 && carsResponse.statusCode == 200) {
        final data = jsonDecode(response.body);
        final carsData = jsonDecode(carsResponse.body);

        if (data["status"] == "success" && carsData["status"] == true) {
          final driverVehicleData =
              data["data"]["driver_with_vehicle"] as List<dynamic>;
          final driverVendorData =
              data["data"]["driver_with_vendor"] as List<dynamic>;
          final carsList = carsData["data"] as List<dynamic>;

          setState(() {
            driverWithVehicle = driverVehicleData
                .map((item) => {
                      "full_name": item["full_name"],
                      "phone_number": item["phone_number"],
                      "vehicle_number": item["vehicle_number"],
                      "availability_status":
                          item["availability_status"] ?? "available",
                    })
                .toList();

            driverWithVendor = driverVendorData
                .map((item) => {
                      "full_name": item["full_name"],
                      "phone_number": item["phone_number"],
                      "availability_status":
                          item["availability_status"] ?? "available",
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
                "${d["full_name"]}\n${d["phone_number"]}":
                    d["availability_status"]
            };

            selectedVehicle = vehicles.cast<String?>().firstWhere(
                (v) => vehicleStatus[v] != "conflict",
                orElse: () => null);

            selectedDriver = drivers.cast<String?>().firstWhere(
                (d) => driverStatus[d] != "conflict",
                orElse: () => null);

            isLoading = false;
          });
        } else {
          throw Exception(data["message"] ?? carsData["message"] ?? "Unknown error");
        }
      } else {
        throw Exception('Failed to load data from server');
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  bool _isBookedToday(List bookings) {
    String today = DateTime.now().toString().split(" ")[0];
    return bookings.any((b) => b["date"] == today);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: darkCharcoal),
    );
  }

  Future<void> _submitForm() async {
    bool driverConflict =
        selectedDriver != null && driverStatus[selectedDriver!] == "conflict";
    bool vehicleConflict = selectedVehicle != null &&
        vehicleStatus[selectedVehicle!] == "conflict";

    if (driverConflict || vehicleConflict) {
      _showConflictDialog(driverConflict, vehicleConflict);
      return;
    }

    String? phoneNumber = await secureStorage.read(key: "phone_number");
    String vehicleId = selectedVehicle!;
    String driverId = selectedDriver!.split('\n').last;
    int? bookingId = int.tryParse(widget.bookingId.toString());

    var data = {
      'driver_id': driverId,
      'vehicle_id': vehicleId,
      'booking_id': bookingId,
      'vender_id': phoneNumber,
    };

    try {
      var response = await http.post(
        Uri.parse(ApiConfig.submitCarDriverSelectionPage),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      final resData = jsonDecode(response.body);

      if (resData['success'] == true) {
        // ✅ Show success dialog
        _showStatusDialog(
          "Success",
          "Assignment completed successfully.",
          Icons.check_circle,
          Colors.green,
        );

        // ✅ Delay a bit so user can see success message
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) => BookingListPage(
                      phoneNumber: phoneNumber.toString(),
                    )),
            (route) => false,
          );
        });
      } else {
        _showStatusDialog(
          "Warning",
          resData['message'] ?? "Selection conflict detected.",
          Icons.warning,
          errorRed,
        );
      }
    } catch (e) {
      _showStatusDialog("Error", e.toString(), Icons.error, errorRed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Assign Assets",
            style: TextStyle(fontWeight: FontWeight.bold, color: darkCharcoal)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: darkCharcoal, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: isLoading ? _buildLoader() : _buildContent(),
    );
  }

  Widget _buildLoader() {
    return const Center(child: CircularProgressIndicator(color: primaryAmber));
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryHeader(),
          const SizedBox(height: 24),
          _buildSelectionCard(
            label: "Vehicle Selection",
            icon: Icons.directions_car_filled_rounded,
            value: selectedVehicle,
            items: vehicles,
            statusMap: vehicleStatus,
            onChanged: (v) => setState(() => selectedVehicle = v),
          ),
          const SizedBox(height: 16),
          _buildSelectionCard(
            label: "Driver Selection",
            icon: Icons.person_pin_rounded,
            value: selectedDriver,
            items: drivers,
            statusMap: driverStatus,
            onChanged: (v) => setState(() => selectedDriver = v),
          ),
          const SizedBox(height: 24),
          _buildAcceptanceBox(),
          const SizedBox(height: 32),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightAmber,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryAmber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_rounded, color: primaryAmber, size: 30),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("BOOKING ID",
                  style: TextStyle(
                      fontSize: 12,
                      color: darkCharcoal.withOpacity(0.6),
                      fontWeight: FontWeight.bold)),
              Text("#${widget.bookingId}",
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: darkCharcoal)),
            ],
          )
        ],
      ),
    );
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryAmber, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: darkCharcoal)),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: primaryAmber),
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
                                color: isConflict ? Colors.grey : darkCharcoal,
                                fontSize: 14))),
                    if (isConflict)
                      const Badge(
                          label: Text("BOOKED"), backgroundColor: errorRed)
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isTripAccepted
              ? primaryAmber.withOpacity(0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isTripAccepted ? primaryAmber : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isTripAccepted,
              onChanged: (v) => setState(() => isTripAccepted = v ?? false),
              activeColor: primaryAmber,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            const Expanded(
              child: Text(
                  "I confirm the availability and accept this trip assignment.",
                  style: TextStyle(
                      fontSize: 14,
                      color: darkCharcoal,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    bool canSubmit =
        selectedDriver != null && selectedVehicle != null && isTripAccepted;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: canSubmit
            ? [
                BoxShadow(
                    color: primaryAmber.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6))
              ]
            : [],
      ),
      child: ElevatedButton(
        onPressed: canSubmit ? _submitForm : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAmber,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: const Text("CONFIRM ASSIGNMENT",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }

  void _showConflictDialog(bool dConflict, bool vConflict) {
    String msg = (dConflict && vConflict)
        ? "Both Driver and Vehicle are already booked."
        : dConflict
            ? "Selected Driver is unavailable."
            : "Selected Vehicle is unavailable.";

    _showStatusDialog("Conflict Detected", msg, Icons.error_outline, errorRed);
  }

  void _showStatusDialog(
      String title, String content, IconData icon, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(title)
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK",
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
