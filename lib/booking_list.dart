import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'AccpetedBookingPageVender.dart';
import 'car_driver_selection_page.dart';
import 'car_reg_form.dart';
import 'document_expered_page.dart';
import 'driver_add_form.dart';
import 'compleated_List.dart';
import 'owner_account.dart';
import 'show_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BookingListPage extends StatefulWidget {
  final String phoneNumber;

  const BookingListPage({super.key, required this.phoneNumber});

  @override
  _BookingListPageState createState() => _BookingListPageState();
}

class _BookingListPageState extends State<BookingListPage> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  final TextEditingController otpController = TextEditingController();
  final TextEditingController startKmController = TextEditingController();
  final TextEditingController closingKmController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool showAcceptedList = false;
  bool showExpanded = true; // Initially hidden
  bool showLoader = false;
  bool myTripBtn = true;
  bool close = false;
  bool showOtpCard = false;
  bool showStartKmCard = false;
  bool showClosingKmCard = false;
  bool showSuccessMessage = false;
  bool otpLoading = false;
  bool closeShowCardBtn = false;
  int indexOtp = -1;
  String otp = '';
  String? phoneNumber;

  //String cotp = '5656';

  List<dynamic> bookings = [];
  List<dynamic> acceptedBookings = [];

  bool isLoading = true;
  Timer? _timer; // Timer for real-time updates
  int acceptedTripCount = 0; // Initialize with 0

  final List<String> imageUrls = [
    'https://agnicarrental.com/driver2025/add/add1.webp',
    'https://agnicarrental.com/driver2025/add/add2.webp',
    'https://agnicarrental.com/driver2025/add/add3.webp',
    'https://agnicarrental.com/driver2025/add/add4.webp',
  ];

  @override
  void initState() {
    super.initState();
    checkForUpdate();
    fetchBookings();

    // Fetch new bookings every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      fetchBookings();
      _getCurrentLocationAndSend();
    });
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
    );
  }

  String apiKey =
      "p9J1ofaxrnDXePcsUTdlRu630Vg7KQiWMC24OEmjwFSByh8AH5R5n6sSBzCuvQATbf2g87hV9mtqd0GD"; // Replace with your actual Fast2SMS API key

  // Method to generate random OTP
  String generateOTP(int length) {
    const characters = '0123456789';
    Random rand = Random();
    otp = '';
    for (int i = 0; i < length; i++) {
      otp += characters[rand.nextInt(characters.length)];
    }

    return otp;
  }

  Future<bool> sendOTP(String phoneNumber, String otp) async {
    String apiUrl =
        "https://www.fast2sms.com/dev/bulkV2?authorization=p9J1ofaxrnDXePcsUTdlRu630Vg7KQiWMC24OEmjwFSByh8AH5R5n6sSBzCuvQATbf2g87hV9mtqd0GD&route=dlt&sender_id=agni&message=170275&variables_values=$otp&flash=0&numbers=$phoneNumber&schedule_time=";

    var response = await http.get(Uri.parse(apiUrl));

    var jsonResponse = jsonDecode(response.body);
    return jsonResponse["return"] == true;
  }

  Future<Map<String, dynamic>?> fetchAppVersion() async {
    String apiUrl =
        "https://agnicarrental.com/driver2025/getAppVersion.php?appName=Agni Driver"; // Replace with your API URL

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print(
            "Error: Failed to fetch app version. Status Code: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error fetching app version: $e");
      return null;
    }
  }

  void checkForUpdate() async {
    final versionData = await fetchAppVersion();

    if (versionData != null) {
      String latestVersion = versionData['latest_version'];

      String minSupportedVersion = versionData['min_supported_version'];

      String updateUrl = versionData['update_url'];

      print("Min Supported Version: $minSupportedVersion");

      // Compare with the current app version
      String currentVersion =
          "9"; // Replace with actual version from package_info

      if (currentVersion.compareTo(minSupportedVersion) < 0) {
        // Force update required
        showUpdateDialog(updateUrl, forceUpdate: true);
      } else if (currentVersion.compareTo(latestVersion) < 0) {
        // Optional update available
        showUpdateDialog(updateUrl, forceUpdate: false);
      }
    }
  }

// Function to show the update popup
  void showUpdateDialog(String updateUrl, {bool forceUpdate = false}) {
    // Call your existing showBottomSheetPopup function here
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showBottomSheetPopup(context, updateUrl);
    });
  }

  void showBottomSheetPopup(BuildContext context, updateUrl) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          height: 350,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Update Available",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 10),
                Text(
                  "A new version of Agni Driver App is available. Please update to continue using the latest features and improvements.",
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    openUpdateUrl(
                        updateUrl); // Call the function with update URL
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  child: Text(
                    "Update Now",
                    style: TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close if user skips
                  },
                  child: Text(
                    "Not Now",
                    style: TextStyle(color: Colors.black),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void openUpdateUrl(String updateUrl) async {
    final Uri url = Uri.parse(updateUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      print("Could not launch $updateUrl");
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    _scrollController.dispose();

    // Cancel the timer if it's active
    _timer?.cancel();

    // Call the superclass's dispose method
    super.dispose();
  }

  Future<void> _getCurrentLocationAndSend() async {
    LocationPermission permission;
    permission = await Geolocator.checkPermission();
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
    print("This is = $latitude");

    await _updateLocationToServer(latitude, longitude);
  }

  Future<void> _updateLocationToServer(
      double latitude, double longitude) async {
    String url = 'https://agnicarrental.com/driver2025/update_location.php';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'driver_id': phoneNumber,
        },
      );
      print(response);
    } catch (e) {
      print("Error updating location: $e");
    }
  }

  Future<void> fetchBookings() async {
    phoneNumber = await secureStorage.read(key: "phone_number");
    String apiUrl = "https://agnicarrental.com/driver2025/getBookings.php";

    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        body: {"phone_number": phoneNumber},
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse["success"] == true) {
          setState(() {
            acceptedBookings = jsonResponse["acceptedBookings"] ?? [];
            bookings = jsonResponse["bookings"] ?? [];
            // ✅ Count accepted trips directly
            acceptedTripCount = acceptedBookings.length;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching bookings: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> saveStartingKm(String bookingId) async {
    otpController.clear();
    String apiUrl = "https://agnicarrental.com/driver2025/save_starting_km.php";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: jsonEncode({
          "trip_id": bookingId, // Send as string
          "starting_km": startKmController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse["success"] == true) {
          //startedTrip(bookingId.toString());
          startKmController.clear();

          return; // Success, no further action needed
        } else {
          print("Error: ${jsonResponse['message']}");
        }
      } else {
        print("Server error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error ending trip: $e");
    }
  }

  Future<void> saveClosingKm(String bookingId) async {
    otpController.clear();
    String apiUrl = "https://agnicarrental.com/driver2025/save_closing_km.php";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: jsonEncode({
          "trip_id": bookingId, // Send as string
          "closing_km": closingKmController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse["success"] == true) {
          //endTrip(bookingId.toString());

          closingKmController.clear();
          setState(() {
            indexOtp = -1;
          });
          print("Trip ended successfully.");
          return; // Success, no further action needed
        } else {
          print("Error: ${jsonResponse['message']}");
        }
      } else {
        print("Server error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error ending trip: $e");
    }
  }

  Future<void> endTrip(String bookingId) async {
    String apiUrl = "https://agnicarrental.com/driver2025/endTrip.php";

    try {
      setState(() {
        showLoader = true; // Start showing the loader
      });
      var response = await http.post(
        Uri.parse(apiUrl),
        body: {"booking_id": bookingId},
      );

      var jsonResponse = jsonDecode(response.body);
      if (jsonResponse["success"] == true) {
        otpController.clear();
        setState(() {
          acceptedBookings
              .removeWhere((booking) => booking['booking_id'] == bookingId);
        });

        // Wait for 10 minutes before hiding the loader
        Future.delayed(const Duration(seconds: 2), () {
          setState(() {
            showLoader = false; // Hide the loader after 10 minutes
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
            "Trip ended successfully.",
            overflow: TextOverflow.ellipsis,
          )),
        );
      }
    } catch (e) {
      print("Error ending trip: $e");
    }
  }

  Future<void> startedTrip(String bookingId) async {
    String apiUrl = "https://agnicarrental.com/driver2025/startTrip.php";

    try {
      setState(() {
        showLoader = true; // Start showing the loader
      });
      var response = await http.post(
        Uri.parse(apiUrl),
        body: {"booking_id": bookingId},
      );

      var jsonResponse = jsonDecode(response.body);
      if (jsonResponse["success"] == true) {
        otpController.clear();
        setState(() {
          acceptedBookings
              .removeWhere((booking) => booking['booking_id'] == bookingId);
        });

        // Wait for 10 minutes before hiding the loader
        Future.delayed(const Duration(seconds: 2), () {
          setState(() {
            showLoader = false; // Hide the loader after 10 minutes
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
            "Trip Started successfully.",
            overflow: TextOverflow.ellipsis,
          )),
        );
      }
    } catch (e) {
      print("Error ending trip: $e");
    }
  }

// Define a function to get car image based on car type
  String getCarImage(String carType) {
    Map<String, String> carImages = {
      'Sedan': 'assets/sadan-1.webp',
      'Innova': 'assets/innova-1.webp',
      'Hatchback': 'assets/hatchback-1.webp',
      'Crysta': 'assets/crysta-1.webp',
      'Ertiga': 'assets/ertiga-1.webp', // Example for Crysta
    };

    return carImages[carType] ??
        'assets/default_car.webp'; // Default image if not found
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevents default navigation popping
      onPopInvokedWithResult: (didPop, result) async {
        // Added result parameter
        if (!didPop) {
          // Exit the app completely when back button is pressed
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "DASHBOARD",
            style: TextStyle(color: Colors.amber),
            overflow: TextOverflow.ellipsis,
          ), // Title of the AppBar
          backgroundColor: Colors.black,
        ),

        // Background color

        backgroundColor: const Color.fromARGB(255, 203, 220, 255),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
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
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AcceptedBookingsPage(),
                                  ),
                                );
                              },
                              child: Text(
                                "My Trips $acceptedTripCount",
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                          ),
                          // Place the second button in the second half
                          Text("|"),
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CompleatedList(),
                                  ),
                                );
                              },
                              child: Text(
                                "Completed",
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
                                      builder: (context) =>
                                          DocumentExperedPage()),
                                );
                              },
                              child: Text(
                                "Documents",
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  //Whatsapp Card
                  Center(
                    child: Text("Whatsapp Card"),
                  ),
                  //Wahatsapp card end
                  SizedBox(),
                  if (showExpanded)
                    Expanded(
                      child: bookings.isEmpty
                          ? const Center(
                              child: Text(
                                "No bookings available.",
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 18, color: Colors.black54),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              itemCount: bookings.length,
                              itemBuilder: (context, index) {
                                final booking = bookings[index];

                                final bookingId = booking['booking_id'];
                                final carType =
                                    booking['car_type'] ?? 'Unknown';
                                final pickup =
                                    booking['pickup_location'] ?? 'N/A';
                                final drop = booking['drop_location'] ?? 'N/A';
                                final double distance = double.tryParse(
                                        booking['distance'].toString()) ??
                                    0;
                                final date = booking['date'] ?? '';
                                final time = booking['time'] ?? '';
                                final returnDate = booking['return_date'] ?? '';
                                final returnTime = booking['return_time'] ?? '';
                                final double totalAmount = double.tryParse(
                                        booking['total_amount'].toString()) ??
                                    0;

                                final contact =
                                    booking['customer_contact'] ?? '';
                                final tripType = booking['trip_type'] ?? '';
                                final double kmRate = double.tryParse(
                                        booking['kmRate'].toString()) ??
                                    0;
                                final double agni_share = double.tryParse(
                                        booking['agni_share'].toString()) ??
                                    0;
                                final kmRateRoundTrip = kmRate - agni_share;

                                print("objectttttttttt $agni_share");
                                final packageKm =
                                    booking['packageKm']?.toString() ?? '';
                                final packageHours =
                                    booking['packageHours']?.toString() ?? '';
                                final baseAmount =
                                    booking['baseAmount']?.toString() ?? '';
                                final extraKMAmount =
                                    booking['extraKMAmount']?.toString() ?? '';
                                final extraHoursAmount =
                                    booking['extraHoursAmount']?.toString() ??
                                        '';
                                final driverRate =
                                    booking['driverRate']?.toString() ?? '';
                                final extraKMAmountFroDriver =
                                    booking['extraKMAmountFroDriver']
                                            ?.toString() ??
                                        '';
                                final extraHoursAmountForDriver =
                                    booking['extraHoursAmountForDriver']
                                            ?.toString() ??
                                        '';

                                print('$extraHoursAmountForDriver');

                                final extraKmRate =
                                    booking['extraKmRate']?.toString() ?? '';
                                final extraHoursRate =
                                    booking['extraHoursRate']?.toString() ?? '';
                                final double agentCommission = double.tryParse(
                                        booking['agent_commission']
                                            .toString()) ??
                                    0;

                                final vendor_amount =
                                    booking['vendor_amount']?.toString() ?? '';

                                final driver_allowance =
                                    booking['driver_allowance']?.toString() ??
                                        '';

                                final agniPart =
                                    ((distance * kmRate) + agentCommission) *
                                            0.05 +
                                        agentCommission +
                                        (distance * kmRate * 0.15);

                                final OneWayvenderPart = totalAmount - agniPart;

                                final image = getCarImage(carType);

                                return Column(
                                  children: [
                                    SizedBox(
                                      height: 10,
                                    ),
                                    if (index == 0 || (index + 1) % 4 == 0)
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: buildSlider(),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: Card(
                                        color: Colors.white,
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 0, horizontal: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          side: BorderSide(
                                            color: Colors.amber, // Border color
                                            width: 2, // Border width
                                          ),
                                        ),
                                        elevation: 8,
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      child: Image.asset(
                                                        image,
                                                        width: 200,
                                                        height: 90,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          "B.ID: $bookingId",
                                                          style:
                                                              const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 16),
                                                        ),
                                                        Text("$carType"),
                                                        Text("$tripType"),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Divider(
                                                  height: 20, thickness: 1),
                                              buildDetailRow(Icons.location_on,
                                                  "Pickup", pickup),

                                              if (tripType != 'Local-Duty')
                                                buildDetailRow(
                                                    Icons.flag, "Drop", drop),

                                              Padding(
                                                padding: EdgeInsets.symmetric(
                                                    vertical:
                                                        8.0), // Top & bottom spacing
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Divider(
                                                        color: Colors.black,
                                                        thickness: 0.5,
                                                      ),
                                                    ),
                                                    TextButton.icon(
                                                      onPressed: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) => ShowMap(
                                                                fromAddress:
                                                                    booking[
                                                                        'pickup_location'],
                                                                toAddress: booking[
                                                                    'drop_location'],
                                                                phoneNumber: widget
                                                                    .phoneNumber),
                                                          ),
                                                        );
                                                      },
                                                      icon: Icon(Icons.map,
                                                          color: Colors.green,
                                                          size: 18),
                                                      label: Text(
                                                        "Map",
                                                        style: TextStyle(
                                                            color:
                                                                Colors.green),
                                                      ),
                                                      style:
                                                          TextButton.styleFrom(
                                                        padding:
                                                            EdgeInsets.zero,
                                                        minimumSize: Size(0, 0),
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (tripType == 'Local-Duty' ||
                                                  tripType == 'Round-Trip') ...[
                                                SizedBox(),
                                              ] else ...[
                                                buildDetailRow(Icons.map,
                                                    "Distance", "$distance KM"),
                                                Divider(),
                                              ],

                                              buildDetailRow(Icons.access_time,
                                                  "Time", "$time on $date"),

                                              if (tripType == 'Round-Trip') ...[
                                                buildDetailRow(
                                                    Icons.calendar_today,
                                                    "Return",
                                                    "$returnTime on $returnDate"),
                                                Divider(),
                                              ],

                                              if (tripType == 'One-way') ...[
                                                buildDetailRow(
                                                    Icons.calendar_today,
                                                    "Total Amount",
                                                    "$vendor_amount"),
                                              ],

                                              if (tripType == 'Local-taxi') ...[
                                                buildDetailRow(
                                                    Icons.calendar_today,
                                                    "Total Amount",
                                                    "$totalAmount"),
                                              ],
                                              //LocalDuty
                                              if (tripType == 'Local-Duty') ...[
                                                buildDetailRow(
                                                    Icons.wallet,
                                                    "Package",
                                                    "$packageHours Hours/$packageKm KM  "),
                                                buildDetailRow(
                                                    Icons.currency_rupee_sharp,
                                                    "Base Charge",
                                                    "₹$driverRate /-"),
                                                buildDetailRow(
                                                    Icons.currency_rupee_sharp,
                                                    "For Extra Km",
                                                    "₹$extraKMAmountFroDriver/Km"),
                                                buildDetailRow(
                                                    Icons.currency_rupee_sharp,
                                                    "For Extra Hours",
                                                    "₹$extraHoursAmountForDriver/Hours"),
                                                buildDetailRow(
                                                    Icons.scale,
                                                    "Km & Timing",
                                                    "Garage to Garage"),
                                                buildDetailRow(
                                                    Icons.local_parking,
                                                    "Toll & Parking",
                                                    "Extra"),
                                                Text(
                                                    "(Extra Driver Allowance ₹$driver_allowance/- After 11.30 pm Before 6.30 am) "),
                                              ],

                                              if (tripType == 'Round-Trip') ...[
                                                buildDetailRow(
                                                    Icons.wallet,
                                                    "Package",
                                                    "$packageKm KM/Day  "),
                                                buildDetailRow(
                                                    Icons.currency_rupee,
                                                    "Km Charge",
                                                    "₹$kmRateRoundTrip/km"),
                                                buildDetailRow(
                                                    Icons.currency_rupee,
                                                    "Driver Allowance",
                                                    "₹$driver_allowance/day + Food"),
                                                buildDetailRow(
                                                    Icons.scale,
                                                    "Km & Timing",
                                                    "Garage to Garage"),
                                                buildDetailRow(
                                                    Icons.local_parking,
                                                    "Toll & Parking",
                                                    "Extra"),
                                                buildDetailRow(
                                                    Icons.handshake,
                                                    "Pickup & Drop",
                                                    "6.00 am & 11.30 pm"),
                                              ],

                                              const SizedBox(height: 10),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              CarDriverSelectionScreen(
                                                            bookingId: booking[
                                                                    'booking_id']
                                                                .toString(),
                                                          ),
                                                        ),
                                                      );
                                                      // Accept logic (e.g. send to backend)
                                                    },
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                            backgroundColor:
                                                                Colors.amber),
                                                    child: const Text("Accept",
                                                        style: TextStyle(
                                                            color:
                                                                Colors.black)),
                                                  ),
                                                  const SizedBox(width: 10),
                                                ],
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15), // Round top-left corner
                      topRight: Radius.circular(15), // Round top-right corner
                    ),
                    child: Container(
                      width: double.infinity, // Ensures full width
                      color: const Color.fromARGB(
                          255, 243, 233, 179), // Background color set to white
                      padding: const EdgeInsets.symmetric(
                          vertical: 10), // Adjusted padding
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              _scrollToTop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.transparent, // Remove background color
                              elevation: 0, // Remove shadow
                              padding: EdgeInsets
                                  .zero, // Optional: Remove padding if needed
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.home,
                                  color: Colors.amber,
                                ),
                                Text(
                                  "Home",
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => CarFormPage()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.transparent, // Remove background color
                              elevation: 0, // Remove shadow
                              padding: EdgeInsets
                                  .zero, // Optional: Remove padding if needed
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.directions_car,
                                  color: Colors.amber,
                                ),
                                Text(
                                  "Add Cab",
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.black),
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
                              backgroundColor:
                                  Colors.transparent, // Remove background color
                              elevation: 0, // Remove shadow
                              padding: EdgeInsets
                                  .zero, // Optional: Remove padding if needed
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.person_add_alt_1_rounded,
                                  color: Colors.amber,
                                ),
                                Text(
                                  "Add Driver",
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.black),
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
                              backgroundColor:
                                  Colors.transparent, // Remove background color
                              elevation: 0, // Remove shadow
                              padding: EdgeInsets
                                  .zero, // Optional: Remove padding if needed
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.person_add_alt_1_rounded,
                                  color: Colors.amber,
                                ),
                                Text(
                                  "Account",
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
      ),
    );
  }

  Widget buildSlider() {
    return Container(
      child: CarouselSlider(
        options: CarouselOptions(
          height: 160.0, // Adjust height as needed
          autoPlay: true, // Enable auto-sliding
          enlargeCenterPage: true, // Zoom effect on the active image
          aspectRatio: 16 / 9,
          autoPlayInterval: Duration(seconds: 3), // Duration per slide
          autoPlayCurve: Curves.fastOutSlowIn,
          enableInfiniteScroll: true, // Infinite loop
        ),
        items: imageUrls.map((url) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (context, url) => Center(
                child: CircularProgressIndicator(),
              ), // Show loading
              errorWidget: (context, url, error) => Center(
                child: Icon(Icons.error, color: Colors.red),
              ), // Show error icon
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text("$title: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          if (title == 'Pickup' || title == 'Drop') ...[
            Expanded(
                child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              maxLines: 10,
            )),
          ] else ...[
            Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
          ]
        ],
      ),
    );
  }
}
