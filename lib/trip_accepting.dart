import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';
import 'booking_list.dart';
import 'vendor_wallet_page.dart';
import 'package:google_fonts/google_fonts.dart';

// Brand Color Palette
const Color kRentoxOrange = Color(0xFFFFB000);
const Color kDarkText = Color(0xFF171717);
const Color kWhite = Color(0xFFFFFFFF);
const Color kSecondaryText = Color(0xFF6B7280);
const Color kSuccessGreen = Color(0xFF16A34A);
const Color kDangerRed = Color(0xFFEF4444);
const Color kLightOrange = Color(0xFFFFF7E6);
const Color kSurfaceGray = Color(0xFFF9FAFB);
const Color kBorderGray = Color(0xFFE5E7EB);

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

class _DriverTripPageState extends State<DriverTripPage>
    with SingleTickerProviderStateMixin {
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
  bool isTripAccepted = true; // Pre-checked for quick driver acceptance
  bool isEarningsExpanded = false;

  // Countdown Timer
  static const int _totalSeconds = 60;
  int _remainingSeconds = _totalSeconds;
  late AnimationController _countdownController;
  Timer? _timer;

  bool get _isUrgent => _remainingSeconds <= 15;

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();

    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _totalSeconds),
    )..forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        Navigator.pop(context);
      } else {
        setState(() {
          _remainingSeconds--;
        });
        if (_remainingSeconds == 15 || _remainingSeconds == 10 || _remainingSeconds == 5) {
          try {
            HapticFeedback.mediumImpact();
          } catch (_) {}
        }
      }
    });
  }

  @override
  void dispose() {
    _countdownController.dispose();
    _timer?.cancel();
    super.dispose();
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

    final String detailsUrl =
        "${ApiConfig.legacyPath}/get_booking_details.php?booking_id=${widget.bookingId}";

    try {
      final detailsResponse = await http.get(Uri.parse(detailsUrl));
      if (detailsResponse.statusCode == 200) {
        final Map<String, dynamic> jsonResponse =
            jsonDecode(detailsResponse.body);
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
                  backgroundColor: kRentoxOrange,
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
        String apiUrl =
            "${ApiConfig.carDriverSelectionPage}?phone_number=$storedPhoneNumber";
        String carsUrl =
            "${ApiConfig.carListForVendor}?vendor_id=$storedPhoneNumber";

        final response = await http.get(Uri.parse(apiUrl));
        final carsResponse = await http.get(Uri.parse(carsUrl));

        if (response.statusCode == 200 && carsResponse.statusCode == 200) {
          final data = jsonDecode(response.body);
          final carsData = jsonDecode(carsResponse.body);

          if (data["status"] == "success" && carsData["status"] == true) {
            final driverVendorData =
                data["data"]["driver_with_vendor"] as List<dynamic>;
            final carsList = carsData["data"] as List<dynamic>;

            driverWithVendor = driverVendorData
                .map((item) => {
                      "full_name": item["full_name"],
                      "phone_number": item["phone_number"],
                      "availability_status":
                          item["availability_status"] ?? "available",
                    })
                .toList();

            vehicles = carsList
                .where((car) => car["status"] != "inactive")
                .map((car) => car["vehicle_number"].toString())
                .toSet()
                .toList();

            drivers = driverWithVendor
                .map((item) => "${item["full_name"]}\n${item["phone_number"]}")
                .toSet()
                .toList();

            vehicleStatus = {
              for (var car in carsList)
                car["vehicle_number"].toString():
                    _isBookedToday(car["bookings"] ?? [])
                        ? "conflict"
                        : "available"
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
          }
        }
      }

      setState(() {
        isLoadingDetails = false;
      });
    } catch (e) {
      debugPrint("Error fetching data: $e");
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
    return bookings.any((b) {
      if (b["date"] != today) return false;
      String status = b["status"]?.toString() ?? "";
      return status != "Completed" &&
          status != "Cancelled" &&
          status != "Customer Cancelled";
    });
  }

  Future<void> acceptTrip() async {
    if (storedPhoneNumber == null) return;

    if (vehicles.isNotEmpty && selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a vehicle to assign this trip."),
          backgroundColor: kDangerRed,
        ),
      );
      return;
    }

    if (drivers.isNotEmpty && selectedDriver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a driver to assign this trip."),
          backgroundColor: kDangerRed,
        ),
      );
      return;
    }

    if (!isTripAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please confirm trip acceptance checkbox."),
          backgroundColor: kRentoxOrange,
        ),
      );
      return;
    }

    _timer?.cancel();

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
                  backgroundColor: kWhite,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 28.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: const BoxDecoration(
                            color: kLightOrange,
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: const BoxDecoration(
                              color: kRentoxOrange,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: kWhite,
                              size: 36.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        Text(
                          "Trip Accepted!",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: kDarkText,
                            fontWeight: FontWeight.bold,
                            fontSize: 22.0,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          "Booking has been confirmed and assigned to your fleet.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: kSecondaryText,
                            fontSize: 13.0,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        if (selectedVehicle != null || driverNameOnly != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 12.0),
                            decoration: BoxDecoration(
                              color: kSurfaceGray,
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(color: kBorderGray),
                            ),
                            child: Column(
                              children: [
                                if (selectedVehicle != null)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Vehicle:",
                                        style: GoogleFonts.poppins(
                                          color: kSecondaryText,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13.0,
                                        ),
                                      ),
                                      Text(
                                        selectedVehicle!,
                                        style: GoogleFonts.poppins(
                                          color: kDarkText,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (selectedVehicle != null &&
                                    driverNameOnly != null)
                                  const SizedBox(height: 8.0),
                                if (driverNameOnly != null)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Driver:",
                                        style: GoogleFonts.poppins(
                                          color: kSecondaryText,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13.0,
                                        ),
                                      ),
                                      Text(
                                        driverNameOnly,
                                        style: GoogleFonts.poppins(
                                          color: kDarkText,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.0,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24.0),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
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
                              backgroundColor: kRentoxOrange,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.0),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              "View My Trips",
                              style: GoogleFonts.poppins(
                                color: kDarkText,
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
        } else {
          if (mounted) {
            if (jsonResponse["status"] == "low_wallet_balance") {
              _showLowWalletBalanceDialog(jsonResponse["message"] ?? "Insufficient wallet balance.");
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(jsonResponse["message"] ?? "Could not accept booking")),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Accept trip error: $e");
    }
  }

  void _showLowWalletBalanceDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: const [
            Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFFF8F00), size: 26),
            SizedBox(width: 10),
            Text("Recharge Required", style: TextStyle(color: Color(0xFF263238), fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF546E7A), fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8F00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => VendorWalletPage(vendorPhone: storedPhoneNumber),
                ),
              );
            },
            icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
            label: const Text("Recharge Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (storedPhoneNumber == null || isLoadingDetails) {
      return const Scaffold(
        backgroundColor: kWhite,
        body: Center(
          child: CircularProgressIndicator(color: kRentoxOrange),
        ),
      );
    }

    if (showDetails) {
      return const Scaffold(
        backgroundColor: kWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: kRentoxOrange),
              SizedBox(height: 16),
              Text(
                "Processing assignment...",
                style: TextStyle(color: kSecondaryText, fontWeight: FontWeight.w500),
              )
            ],
          ),
        ),
      );
    }

    final details = bookingDetails ?? {};
    final String tripType = details['trip_type'] ?? 'Local-taxi';
    final String formattedDate = details['formatted_date'] ?? '';
    final String formattedTime = details['formatted_time'] ?? '';
    final String pickupLocation = details['from_address'] ?? 'Customer Pickup';
    final String dropLocation = details['to_address'] ?? '';
    final String vehicleType = details['car_type'] ?? 'Hatchback';
    final String customerName = details['customer_name'] ?? 'Customer';
    final String bookingIdVal =
        details['id'] != null ? '#TRIP${details['id']}' : '#TRIP';

    final double vendorAmount =
        double.tryParse(details['vendor_amount']?.toString() ?? '0') ?? 0.0;
    final double baseFare =
        double.tryParse(details['base_charge']?.toString() ?? '0') ?? 0.0;
    final double totalFare =
        double.tryParse(details['total_amount']?.toString() ?? '0') ??
            baseFare;
    final double paidAmount =
        double.tryParse(details['paid_amount']?.toString() ?? '0') ?? 0.0;
    final double agniAmount =
        double.tryParse(details['agni_amount']?.toString() ?? '0') ?? 0.0;

    return Scaffold(
      backgroundColor: kSurfaceGray,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Compact Header
            _buildCompactHeader(bookingIdVal),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 2. Hero Earnings & Animated Circular Countdown Card
                    _buildHeroEarningsCard(vendorAmount),

                    const SizedBox(height: 12.0),

                    // 3. Dynamic Trip Information Chips
                    _buildTripInfoChips(tripType, vehicleType, formattedDate,
                        formattedTime, customerName),

                    const SizedBox(height: 12.0),

                    // 4. Visual Route Component
                    _buildVisualRouteCard(tripType, pickupLocation, dropLocation),

                    const SizedBox(height: 12.0),

                    // 5. Expandable Fare & Earnings Card
                    _buildEarningsCard(
                      vendorAmount: vendorAmount,
                      totalFare: totalFare,
                      agniAmount: agniAmount,
                      paidAmount: paidAmount,
                      baseFare: baseFare,
                      tripType: tripType,
                    ),

                    // 6. Fleet Asset Assignment (If vendor has vehicles or drivers)
                    if (vehicles.isNotEmpty || drivers.isNotEmpty) ...[
                      const SizedBox(height: 12.0),
                      _buildAssetAssignmentSection(),
                    ],

                    const SizedBox(height: 12.0),

                    // 7. Quick Confirmation Agreement
                    _buildAgreementBox(),

                    const SizedBox(height: 16.0),
                  ],
                ),
              ),
            ),

            // 8. Fixed Bottom Action Buttons
            _buildBottomActionButtons(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1. COMPACT HEADER
  // ==========================================
  Widget _buildCompactHeader(String bookingId) {
    return Container(
      color: kWhite,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: kDarkText, size: 20),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "NEW TRIP REQUEST",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: kDarkText,
                ),
              ),
              Text(
                "Review route and confirm payout",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: kSecondaryText,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: kLightOrange,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kRentoxOrange.withValues(alpha: 0.3)),
            ),
            child: Text(
              bookingId,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. HERO EARNINGS & COUNTDOWN CARD
  // ==========================================
  Widget _buildHeroEarningsCard(double vendorAmount) {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: _isUrgent
              ? kDangerRed.withValues(alpha: 0.5)
              : kBorderGray,
          width: _isUrgent ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _isUrgent
                ? kDangerRed.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Earnings Left
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "YOUR EARNINGS",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: kSecondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "₹${vendorAmount.toStringAsFixed(2)}",
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: kDarkText,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: kSuccessGreen, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "Driver payout • Guaranteed",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kSuccessGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Circular Animated Countdown Right
          AnimatedBuilder(
            animation: _countdownController,
            builder: (context, child) {
              return Container(
                width: 68,
                height: 68,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isUrgent
                      ? kDangerRed.withValues(alpha: 0.06)
                      : kLightOrange,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1.0 - _countdownController.value,
                      strokeWidth: 4.5,
                      backgroundColor: _isUrgent
                          ? kDangerRed.withValues(alpha: 0.2)
                          : kRentoxOrange.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isUrgent ? kDangerRed : kRentoxOrange,
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "$_remainingSeconds",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _isUrgent ? kDangerRed : kDarkText,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            "seconds",
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: _isUrgent ? kDangerRed : kSecondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. TRIP INFORMATION CHIPS
  // ==========================================
  Widget _buildTripInfoChips(String tripType, String vehicleType, String date,
      String time, String customerName) {
    IconData typeIcon = Icons.local_taxi_rounded;
    String cleanType = tripType;

    final lower = tripType.toLowerCase();
    if (lower.contains('one-way') || lower.contains('oneway')) {
      typeIcon = Icons.arrow_forward_rounded;
      cleanType = "One-Way Outstation";
    } else if (lower.contains('round')) {
      typeIcon = Icons.sync_alt_rounded;
      cleanType = "Round-Trip Outstation";
    } else if (lower.contains('duty')) {
      typeIcon = Icons.schedule_rounded;
      cleanType = "Hourly Rental";
    } else if (lower.contains('airport')) {
      typeIcon = Icons.flight_takeoff_rounded;
      cleanType = "Airport Transfer";
    } else {
      typeIcon = Icons.local_taxi_rounded;
      cleanType = "Local Taxi";
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: [
        // Chip 1: Trip Type
        _buildChip(
          icon: typeIcon,
          label: cleanType,
          isHighlight: true,
        ),
        // Chip 2: Vehicle
        _buildChip(
          icon: Icons.directions_car_filled_rounded,
          label: vehicleType,
        ),
        // Chip 3: Date & Time
        if (date.isNotEmpty)
          _buildChip(
            icon: Icons.calendar_today_rounded,
            label: "$date${time.isNotEmpty ? ' • $time' : ''}",
          ),
        // Chip 4: Customer
        if (customerName.isNotEmpty && customerName != 'Customer')
          _buildChip(
            icon: Icons.person_outline_rounded,
            label: customerName,
          ),
      ],
    );
  }

  Widget _buildChip(
      {required IconData icon,
      required String label,
      bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
      decoration: BoxDecoration(
        color: isHighlight ? kLightOrange : kWhite,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isHighlight
              ? kRentoxOrange.withValues(alpha: 0.5)
              : kBorderGray,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isHighlight ? const Color(0xFFB45309) : kSecondaryText,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isHighlight ? const Color(0xFFB45309) : kDarkText,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. VISUAL ROUTE COMPONENT
  // ==========================================
  Widget _buildVisualRouteCard(
      String tripType, String pickupLocation, String dropLocation) {
    final bool hasDrop = dropLocation.isNotEmpty && dropLocation != 'N/A';

    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: kBorderGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "ROUTE & DESTINATION",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: kSecondaryText,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: kSurfaceGray,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.navigation_rounded,
                        size: 11, color: kSecondaryText),
                    const SizedBox(width: 4),
                    Text(
                      "GPS Live",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: kSecondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          // Pickup Location
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Orange Circle Indicator
              Column(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: kRentoxOrange,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: kRentoxOrange.withValues(alpha: 0.3),
                        width: 3,
                      ),
                    ),
                  ),
                  // Connecting Line
                  Container(
                    width: 2,
                    height: hasDrop ? 36 : 14,
                    color: kBorderGray,
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "PICKUP",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB45309),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pickupLocation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kDarkText,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Drop Location (or Flexible package note)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: hasDrop ? kDangerRed : kSuccessGreen,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (hasDrop ? kDangerRed : kSuccessGreen)
                        .withValues(alpha: 0.3),
                    width: 3,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasDrop ? "DESTINATION" : "DUTY DETAILS",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: hasDrop ? kDangerRed : kSuccessGreen,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasDrop
                          ? dropLocation
                          : "City Package / As directed by customer",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kDarkText,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. EXPANDABLE EARNINGS BREAKDOWN
  // ==========================================
  Widget _buildEarningsCard({
    required double vendorAmount,
    required double totalFare,
    required double agniAmount,
    required double paidAmount,
    required double baseFare,
    String tripType = '',
  }) {
    final double rawBase = totalFare > 0 ? totalFare : baseFare;
    final bool isOneWay = tripType.toLowerCase().contains('one-way') || tripType.toLowerCase().contains('oneway');
    final double gstAmt = isOneWay ? (rawBase * 0.05) : 0.0;
    final double totalCustomerFare = rawBase + gstAmt;
    final double remainingCollect = paidAmount > 0
        ? ((totalCustomerFare - paidAmount) > 0 ? (totalCustomerFare - paidAmount) : 0.0)
        : totalCustomerFare;

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: kBorderGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header / Tap to expand
          InkWell(
            onTap: () {
              setState(() {
                isEarningsExpanded = !isEarningsExpanded;
              });
            },
            borderRadius: BorderRadius.circular(24.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: const BoxDecoration(
                      color: kLightOrange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: Color(0xFFB45309), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Fare & Payout Breakdown",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kDarkText,
                        ),
                      ),
                      Text(
                        "Tap to ${isEarningsExpanded ? 'collapse' : 'view'} detailed fare",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: kSecondaryText,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(
                    isEarningsExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: kSecondaryText,
                  ),
                ],
              ),
            ),
          ),

          // Collapsible breakdown body
          if (isEarningsExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: Column(
                children: [
                  const Divider(height: 1, color: kBorderGray),
                  const SizedBox(height: 12),
                  _buildBreakdownRow("Base Customer Fare",
                      "₹${rawBase.toStringAsFixed(2)}"),
                  if (gstAmt > 0)
                    _buildBreakdownRow("GST (5%)",
                        "₹${gstAmt.toStringAsFixed(2)}"),
                  if (gstAmt > 0)
                    _buildBreakdownRow("Total Fare (incl. GST)",
                        "₹${totalCustomerFare.toStringAsFixed(2)}"),
                  if (agniAmount > 0)
                    _buildBreakdownRow("Platform / Commission",
                        "- ₹${agniAmount.toStringAsFixed(2)}",
                        isDeduction: true),
                  if (paidAmount > 0) ...[
                    _buildBreakdownRow("Advance / Online Paid",
                        "₹${paidAmount.toStringAsFixed(2)}"),
                    _buildBreakdownRow("Remaining to Collect",
                        "₹${remainingCollect.toStringAsFixed(2)}"),
                  ],
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: kBorderGray),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Net Driver Payout",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kDarkText,
                        ),
                      ),
                      Text(
                        "₹${vendorAmount.toStringAsFixed(2)}",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value,
      {bool isDeduction = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: kSecondaryText,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDeduction ? kDangerRed : kDarkText,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 6. FLEET ASSET ASSIGNMENT
  // ==========================================
  Widget _buildAssetAssignmentSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: kBorderGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "ASSET ASSIGNMENT",
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: kSecondaryText,
            ),
          ),
          const SizedBox(height: 12),
          if (vehicles.isNotEmpty)
            _buildDropdown(
              label: "Vehicle",
              icon: Icons.directions_car_rounded,
              value: selectedVehicle,
              items: vehicles,
              statusMap: vehicleStatus,
              onChanged: (v) => setState(() => selectedVehicle = v),
            ),
          if (vehicles.isNotEmpty && drivers.isNotEmpty)
            const SizedBox(height: 12),
          if (drivers.isNotEmpty)
            _buildDropdown(
              label: "Driver",
              icon: Icons.person_rounded,
              value: selectedDriver,
              items: drivers,
              statusMap: driverStatus,
              onChanged: (v) => setState(() => selectedDriver = v),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required Map<String, String> statusMap,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: kSecondaryText),
            const SizedBox(width: 6),
            Text(
              "Select $label",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kDarkText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          hint: Text("Choose $label",
              style: GoogleFonts.poppins(fontSize: 13, color: kSecondaryText)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: kSecondaryText),
          decoration: InputDecoration(
            filled: true,
            fillColor: kSurfaceGray,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kBorderGray),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kBorderGray),
            ),
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
                    child: Text(
                      item,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isConflict ? Colors.grey : kDarkText,
                      ),
                    ),
                  ),
                  if (isConflict)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: kDangerRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "BUSY",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: kDangerRed,
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 16, color: kSuccessGreen),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ==========================================
  // 7. AGREEMENT BOX
  // ==========================================
  Widget _buildAgreementBox() {
    return InkWell(
      onTap: () => setState(() => isTripAccepted = !isTripAccepted),
      borderRadius: BorderRadius.circular(16.0),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isTripAccepted ? kLightOrange : kWhite,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: isTripAccepted
                ? kRentoxOrange.withValues(alpha: 0.4)
                : kBorderGray,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isTripAccepted,
              onChanged: (v) => setState(() => isTripAccepted = v ?? false),
              activeColor: kRentoxOrange,
              checkColor: kDarkText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                "I confirm vehicle & driver availability to accept this booking.",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: kDarkText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 8. FIXED BOTTOM ACTION BUTTONS
  // ==========================================
  Widget _buildBottomActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 14.0),
      decoration: BoxDecoration(
        color: kWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
        border: const Border(
          top: BorderSide(color: kBorderGray, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // 1. DECLINE Button
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: () {
                _timer?.cancel();
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: kWhite,
                side: const BorderSide(color: kBorderGray, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 15.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
              ),
              child: Text(
                "DECLINE",
                style: GoogleFonts.poppins(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: kDarkText,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12.0),

          // 2. ACCEPT TRIP Button (Vibrant Rentox Orange #FFB000)
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: acceptTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: kRentoxOrange,
                elevation: 3,
                shadowColor: kRentoxOrange.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 15.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "ACCEPT TRIP",
                    style: GoogleFonts.poppins(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: kWhite,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded,
                      color: kWhite, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
