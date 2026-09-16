import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../booking_list.dart';
import '../main.dart';
import '../trip_accepting.dart';
import '../vendor_wallet_page.dart';

class RideRequestDialog extends StatefulWidget {
  final String bookingId;
  final String tripType;
  final String pickupLocation;
  final String dropLocation;
  final String vendorAmount;
  final int countdownSeconds;

  const RideRequestDialog({
    super.key,
    required this.bookingId,
    required this.tripType,
    required this.pickupLocation,
    required this.dropLocation,
    required this.vendorAmount,
    this.countdownSeconds = 45,
  });

  static Future<void> show(
    BuildContext context, {
    required String bookingId,
    required String tripType,
    required String pickupLocation,
    required String dropLocation,
    required String vendorAmount,
    int countdownSeconds = 45,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'RideRequest',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return RideRequestDialog(
          bookingId: bookingId,
          tripType: tripType,
          pickupLocation: pickupLocation,
          dropLocation: dropLocation,
          vendorAmount: vendorAmount,
          countdownSeconds: countdownSeconds,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutBack,
          ),
          child: child,
        );
      },
    );
  }

  @override
  State<RideRequestDialog> createState() => _RideRequestDialogState();
}

class _RideRequestDialogState extends State<RideRequestDialog>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  Timer? _countdownTimer;
  late AnimationController _progressController;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _storedPhoneNumber;

  List<String> vehicles = [];
  List<String> drivers = [];
  String? selectedVehicle;
  String? selectedDriver;
  Map<String, String> vehicleStatus = {};
  Map<String, String> driverStatus = {};
  List<Map<String, dynamic>> driverWithVendor = [];

  bool isLoadingAssets = true;
  bool isAccepting = false;
  bool _isVibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.countdownSeconds;
    _checkVibrationPref();

    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.countdownSeconds),
    )..forward();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        Navigator.of(context, rootNavigator: true).pop();
      } else {
        setState(() {
          _remainingSeconds--;
        });
        if (_remainingSeconds % 3 == 0) {
          _playAlertHaptic();
        }
      }
    });

    _fetchAssets();
  }

  Future<void> _checkVibrationPref() async {
    try {
      final vib = await _storage.read(key: "alert_vibration_enabled");
      if (mounted) {
        setState(() {
          _isVibrationEnabled = (vib != 'false');
        });
        if (_isVibrationEnabled) {
          _playAlertHaptic();
        }
      }
    } catch (_) {}
  }

  void _playAlertHaptic() {
    if (!_isVibrationEnabled) return;
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _fetchAssets() async {
    try {
      final phoneNumber = await _storage.read(key: 'phone_number');
      if (!mounted) return;
      _storedPhoneNumber = phoneNumber;

      if (phoneNumber == null || phoneNumber.isEmpty) {
        setState(() {
          isLoadingAssets = false;
        });
        return;
      }

      final String apiUrl =
          "${ApiConfig.carDriverSelectionPage}?phone_number=$phoneNumber";
      final String carsUrl =
          "${ApiConfig.carListForVendor}?vendor_id=$phoneNumber";

      final response = await http.get(Uri.parse(apiUrl));
      final carsResponse = await http.get(Uri.parse(carsUrl));

      if (!mounted) return;

      if (response.statusCode == 200 && carsResponse.statusCode == 200) {
        final data = jsonDecode(response.body);
        final carsData = jsonDecode(carsResponse.body);

        if (data["status"] == "success" && carsData["status"] == true) {
          final driverVendorData =
              data["data"]["driver_with_vendor"] as List<dynamic>? ?? [];
          final carsList = carsData["data"] as List<dynamic>? ?? [];

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
                  d["availability_status"]?.toString() ?? "available"
          };

          selectedVehicle = vehicles.cast<String?>().firstWhere(
              (v) => vehicleStatus[v] != "conflict",
              orElse: () => vehicles.isNotEmpty ? vehicles.first : null);

          selectedDriver = drivers.cast<String?>().firstWhere(
              (d) => driverStatus[d] != "conflict",
              orElse: () => drivers.isNotEmpty ? drivers.first : null);
        }
      }
    } catch (e) {
      debugPrint("Error fetching assets in RideRequestDialog: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoadingAssets = false;
        });
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

  Future<void> _handleDirectAccept() async {
    if (isAccepting) return;

    if (_storedPhoneNumber == null || _storedPhoneNumber!.isEmpty) {
      _storedPhoneNumber = await _storage.read(key: 'phone_number');
    }

    if (!mounted) return;

    if (_storedPhoneNumber == null || _storedPhoneNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expired. Please log in again.")),
      );
      return;
    }

    if (vehicles.isNotEmpty && selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a vehicle to assign this trip."),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (drivers.isNotEmpty && selectedDriver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a driver to assign this trip."),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      isAccepting = true;
    });

    _countdownTimer?.cancel();

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
          "vendor_id": _storedPhoneNumber!,
          "driver_id": driverPhone ?? _storedPhoneNumber!,
          "vehicle_id": selectedVehicle ?? '',
        },
      );

      if (!mounted) return;

      if (response.headers["content-type"]?.contains("application/json") ==
          true) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse["success"] == true) {
          try {
            HapticFeedback.heavyImpact();
          } catch (_) {}

          final String? acceptedDriverName = selectedDriver?.split('\n').first;
          final String? acceptedVehicleNumber = selectedVehicle;
          final String currentVendorPhone = _storedPhoneNumber!;

          Navigator.of(context, rootNavigator: true).pop();

          _showSuccessConfirmation(
            vendorPhone: currentVendorPhone,
            driverName: acceptedDriverName,
            vehicleNumber: acceptedVehicleNumber,
          );
          return;
        } else {
          final msg = jsonResponse["message"] ?? "Failed to accept trip.";
          if (jsonResponse["status"] == "low_wallet_balance") {
            _showLowWalletBalanceDialog(msg);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
            _resumeCountdownIfNeeded();
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Server response error. Please try again."),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        _resumeCountdownIfNeeded();
      }
    } catch (e) {
      debugPrint("Direct accept error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error accepting trip: $e"),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        _resumeCountdownIfNeeded();
      }
    } finally {
      if (mounted) {
        setState(() {
          isAccepting = false;
        });
      }
    }
  }

  void _resumeCountdownIfNeeded() {
    if (_remainingSeconds > 1) {
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_remainingSeconds <= 1) {
          timer.cancel();
          Navigator.of(context, rootNavigator: true).pop();
        } else {
          setState(() {
            _remainingSeconds--;
          });
        }
      });
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
            onPressed: () {
              Navigator.pop(ctx);
              _resumeCountdownIfNeeded();
            },
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
              Navigator.of(context, rootNavigator: true).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => VendorWalletPage(vendorPhone: _storedPhoneNumber),
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

  void _showSuccessConfirmation({
    required String vendorPhone,
    String? driverName,
    String? vehicleNumber,
  }) {
    final navContext = navigatorKey.currentContext ?? context;
    showDialog(
      context: navContext,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF7E6),
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFB000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 36.0,
                    ),
                  ),
                ),
                const SizedBox(height: 20.0),
                Text(
                  "Trip Accepted!",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF171717),
                    fontWeight: FontWeight.bold,
                    fontSize: 22.0,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  "Booking has been confirmed and assigned to your fleet.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF6B7280),
                    fontSize: 13.0,
                    height: 1.4,
                  ),
                ),
                if (vehicleNumber != null || driverName != null) ...[
                  const SizedBox(height: 20.0),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: [
                        if (vehicleNumber != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Vehicle:",
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13.0,
                                ),
                              ),
                              Text(
                                vehicleNumber,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF171717),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.0,
                                ),
                              ),
                            ],
                          ),
                        if (vehicleNumber != null && driverName != null)
                          const SizedBox(height: 8.0),
                        if (driverName != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Driver:",
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13.0,
                                ),
                              ),
                              Text(
                                driverName,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF171717),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.0,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24.0),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushAndRemoveUntil(
                        ctx,
                        MaterialPageRoute(
                          builder: (context) => BookingListPage(
                            phoneNumber: vendorPhone,
                          ),
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB000),
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "View My Trips",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF171717),
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

  Future<void> _handleViewDetails() async {
    _countdownTimer?.cancel();
    Navigator.of(context, rootNavigator: true).pop();

    final phoneNumber =
        _storedPhoneNumber ?? await _storage.read(key: 'phone_number');
    if (phoneNumber != null && phoneNumber.isNotEmpty && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DriverTripPage(
            bookingId: widget.bookingId,
            phoneNumber: phoneNumber,
          ),
        ),
      );
    }
  }

  void _handleDecline() {
    _countdownTimer?.cancel();
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isLocal = widget.tripType.toLowerCase().contains('local') ||
        widget.tripType.toLowerCase().contains('taxi');
    final double amount = double.tryParse(widget.vendorAmount) ?? 0.0;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.92,
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB300).withValues(alpha: 0.35),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Timer Progress Bar (at top edge)
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: 1.0 - _progressController.value,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _remainingSeconds > 15
                            ? const Color(0xFFFFB300)
                            : Colors.redAccent,
                      ),
                      minHeight: 6,
                    );
                  },
                ),

                // 2. Header with pulsing badge and countdown pill
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isLocal
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isLocal
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFFFB300),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLocal
                                  ? Icons.local_taxi
                                  : Icons.directions_car_filled,
                              size: 16,
                              color: isLocal
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFE65100),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.tripType.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isLocal
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFE65100),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Countdown Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _remainingSeconds > 15
                              ? Colors.black.withValues(alpha: 0.06)
                              : Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: _remainingSeconds > 15
                                  ? Colors.black87
                                  : Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_remainingSeconds}s',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _remainingSeconds > 15
                                    ? Colors.black87
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Scrollable middle body (Earnings + Route + Asset Assignment)
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Earnings Card
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ESTIMATED EARNINGS',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${amount > 0 ? amount.toStringAsFixed(0) : widget.vendorAmount}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFFFC107),
                                    ),
                                  ),
                                  if (isLocal) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Net Earnings (after commission)',
                                      style: GoogleFonts.poppins(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white60,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: Color(0xFFFFC107),
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Route Details (Pickup & Drop)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                          child: Column(
                            children: [
                              // Pickup
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.3),
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'PICKUP',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade500,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                        Text(
                                          widget.pickupLocation.isNotEmpty
                                              ? widget.pickupLocation
                                              : 'Customer pickup location',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              if (widget.dropLocation.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      width: 2,
                                      height: 16,
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                // Drop
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFEF4444)
                                              .withValues(alpha: 0.3),
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'DROP',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade500,
                                              letterSpacing: 0.6,
                                            ),
                                          ),
                                          Text(
                                            widget.dropLocation,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Fleet Selection Section (Vehicle & Driver)
                        _buildFleetSelectionSection(),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // 4. Fixed Action Bar (Decline & Accept + View Details Link)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          // Decline button
                          Expanded(
                            flex: 2,
                            child: OutlinedButton(
                              onPressed: isAccepting ? null : _handleDecline,
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'Decline',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Direct Accept button
                          Expanded(
                            flex: 3,
                            child: ElevatedButton(
                              onPressed:
                                  isAccepting ? null : _handleDirectAccept,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFB000),
                                disabledBackgroundColor: const Color(0xFFFFB000)
                                    .withValues(alpha: 0.6),
                                elevation: 2,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: isAccepting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Color(0xFF3E2723),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Accept Trip',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF3E2723),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 18,
                                          color: Color(0xFF3E2723),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // View Full Trip Details fallback link
                      InkWell(
                        onTap: isAccepting ? null : _handleViewDetails,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View full trip details & map',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 13,
                                color: Color(0xFFB45309),
                              ),
                            ],
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
      ),
    );
  }

  Widget _buildFleetSelectionSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.alt_route_rounded,
                size: 14,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                'ASSIGN FLEET ASSET',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: const Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              if (isLoadingAssets)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFFB000),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (isLoadingAssets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: Text(
                  'Loading available vehicles & drivers...',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else ...[
            // Vehicle Selector
            _buildDropdownField(
              label: 'Vehicle',
              icon: Icons.directions_car_rounded,
              value: selectedVehicle,
              items: vehicles,
              statusMap: vehicleStatus,
              emptyHint: 'Self / Default Vehicle',
              onChanged: (val) {
                setState(() {
                  selectedVehicle = val;
                });
              },
            ),

            const SizedBox(height: 10),

            // Driver Selector
            _buildDropdownField(
              label: 'Driver',
              icon: Icons.person_rounded,
              value: selectedDriver,
              items: drivers,
              statusMap: driverStatus,
              emptyHint: 'Self (Owner Driver)',
              onChanged: (val) {
                setState(() {
                  selectedDriver = val;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required Map<String, String> statusMap,
    required String emptyHint,
    required ValueChanged<String?> onChanged,
  }) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              "$label: ",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            Text(
              emptyHint,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: value,
      isExpanded: true,
      isDense: true,
      decoration: InputDecoration(
        labelText: 'Select $label',
        labelStyle: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF64748B),
        ),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFFFFB000)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFB000), width: 1.5),
        ),
      ),
      items: items.map((String item) {
        final bool isConflict = statusMap[item] == "conflict";
        final String displayName =
            label == 'Driver' ? item.split('\n').first : item;
        final String? subtext = label == 'Driver' && item.contains('\n')
            ? item.split('\n').last
            : null;

        return DropdownMenuItem<String>(
          value: item,
          enabled: !isConflict,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    text: displayName,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isConflict ? Colors.grey : const Color(0xFF1E293B),
                    ),
                    children: [
                      if (subtext != null)
                        TextSpan(
                          text: ' ($subtext)',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.normal,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (isConflict)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "BUSY",
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 14,
                  color: Color(0xFF10B981),
                ),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
