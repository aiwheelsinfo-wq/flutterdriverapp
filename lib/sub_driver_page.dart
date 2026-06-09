import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'driver_account.dart';
import 'api_config.dart';

// Current Logic Imports
import 'document_expered_page.dart';
import 'compleated_List.dart';
import 'AccpetedBookingPageVender.dart';
import 'car_reg_form.dart';
import 'checkAndRoot.dart';
import 'driver_add_form.dart';
import 'owner_account.dart';
import 'whatsapp_booking_list.dart';

class SubDriverPage extends StatefulWidget {
  const SubDriverPage({super.key});

  @override
  State<SubDriverPage> createState() => _SubDriverPageState();
}

class _SubDriverPageState extends State<SubDriverPage> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  String driverCode = "---";
  String? storedNumber;
  int totalTripCount = 0;
  List<dynamic> bookings = [];
  int acceptedTripCount = 0;

  // Calendar State
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  int _selectedIndex = 0;
  String currentVersion = "";

  // Theme Colors
  final Color primaryAmber = Colors.amber.shade700;
  final Color darkGrey = const Color(0xFF2C2C2C);

  @override
  void initState() {
    super.initState();
    _fetchDriverCode();
    checkForUpdate();
    _getAppVersion();
    fetchBookings();
  }

  // --- LOGIC ---
  Future<void> fetchBookings() async {
    storedNumber = await secureStorage.read(key: "phone_number");
    String bookingApiUrl = ApiConfig.getBookings;

    try {
      var bookingResponse = await http
          .post(Uri.parse(bookingApiUrl), body: {"phone_number": storedNumber});
      if (bookingResponse.statusCode == 200) {
        var jsonResponse = jsonDecode(bookingResponse.body);
        if (jsonResponse["success"] == true) {
          setState(() {
            totalTripCount = (jsonResponse["acceptedBookings"] ?? []).length;
          });
        }
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> _getAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      currentVersion = packageInfo.buildNumber;
    });
  }

  void checkForUpdate() async {
    final versionData = await fetchAppVersion();
    if (versionData != null &&
        currentVersion.compareTo(versionData['min_supported_version']) < 0) {
      showUpdateDialog(versionData['update_url'], forceUpdate: true);
    }
  }

  Future<Map<String, dynamic>?> fetchAppVersion() async {
    try {
      final response = await http.get(Uri.parse(
          "${ApiConfig.getAppVersion}?appName=Agni Driver"));

      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<void> _fetchDriverCode() async {
    storedNumber = await secureStorage.read(key: "phone_number");
    try {
      final response = await http.get(Uri.parse(
          "${ApiConfig.driverCodeFetching}?phone_number=$storedNumber"));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == "success")
          setState(() {
            driverCode = data['driver_code'];
          });
      }
    } catch (e) {
      setState(() {
        driverCode = "ERR";
      });
    }
  }

  void showUpdateDialog(String updateUrl, {bool forceUpdate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showModalBottomSheet(
        context: context,
        isDismissible: !forceUpdate,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.system_update, size: 50, color: primaryAmber),
              const SizedBox(height: 16),
              const Text("Update Available",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("A new version of Rentox Driver is available.",
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryAmber,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () => openUpdateUrl(updateUrl),
                  child: const Text("UPDATE NOW",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      );
    });
  }

  void openUpdateUrl(String updateUrl) async {
    final Uri url = Uri.parse(updateUrl);
    if (await canLaunchUrl(url))
      await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // --- UI WIDGETS ---

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap,
      {int badgeCount = 0}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: primaryAmber, size: 28),
                  if (badgeCount > 0)
                    Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text("$badgeCount",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                      ),
                    )
                ],
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: darkGrey)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          title: Image.asset("assets/login_img.png", width: 120),
          centerTitle: true,
          actions: [
            IconButton(
                icon: Icon(Icons.notifications_none, color: darkGrey),
                onPressed: () {}),
          ],
        ),
        body: RefreshIndicator(
          color: primaryAmber,
          onRefresh: fetchBookings,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row
                Row(
                  children: [
                    _buildActionButton(
                        "My Trips",
                        Icons.route,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => MergedBookingsPage())),
                        badgeCount: totalTripCount),
                    _buildActionButton(
                        "History",
                        Icons.history,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CompleatedList()))),
                    _buildActionButton(
                        "Docs",
                        Icons.file_present,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => DocumentExperedPage()))),
                  ],
                ),

                const SizedBox(height: 20),

                // Digital Driver Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [primaryAmber, Colors.orange.shade800],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: primaryAmber.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("DRIVER PASS",
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1)),
                          Icon(Icons.qr_code_scanner, color: Colors.white54),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(driverCode,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8)),
                      const SizedBox(height: 10),
                      const Text("RENTOX CAR RENTAL OFFICIAL PARTNER",
                          style:
                              TextStyle(color: Colors.white60, fontSize: 10)),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // WhatsApp Bookings
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => NearbyTripsPage())),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border:
                            Border.all(color: Colors.green.withOpacity(0.2))),
                    child: Row(
                      children: [
                        Image.asset('assets/WhatsApp_icon.png',
                            width: 45, height: 45),
                        const SizedBox(width: 15),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("WhatsApp Bookings",
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold)),
                              Text("View active community trips",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios,
                            size: 14, color: primaryAmber),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified_user_outlined,
                              color: Colors.blue.shade700),
                          const SizedBox(width: 10),
                          const Text("Account Verification",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            String contactNumber = '7400452852';
                            String url =
                                'whatsapp://send?phone=$contactNumber&text=Requesting account activation.';
                            await launchUrl(Uri.parse(url));
                          },
                          icon: const Icon(Icons.verified, color: Colors.white),
                          label: const Text(
                            "Chat To Verify",
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                        ),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Fixed Calendar Section
                const Text("Your Schedule",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.03), blurRadius: 10)
                    ],
                  ),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 1, 1),
                    focusedDay: _focusedDay,

                    // CALENDAR SELECTION LOGIC
                    selectedDayPredicate: (day) {
                      return isSameDay(_selectedDay, day);
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay; // update focusedDay as well
                      });
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },

                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                          color: primaryAmber.withOpacity(0.2),
                          shape: BoxShape.circle),
                      todayTextStyle: TextStyle(
                          color: primaryAmber, fontWeight: FontWeight.bold),
                      selectedDecoration: BoxDecoration(
                          color: primaryAmber, shape: BoxShape.circle),
                      markerDecoration: BoxDecoration(
                          color: primaryAmber, shape: BoxShape.circle),
                    ),
                    headerStyle: const HeaderStyle(
                        formatButtonVisible: false, titleCentered: true),
                  ),
                ),

                // Verification Status Card
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),

        // Navigation Bar
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 20), // Increased horizontal padding to control width
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A), // Ultra-premium charcoal
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: primaryAmber.withOpacity(0.08),
                    blurRadius: 10,
                    spreadRadius: -2,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavIcon(
                    index: 0,
                    icon: Icons.grid_view_rounded,
                    label: "Home",
                  ),
                  // Vertical separator line
                  Container(
                    height: 24,
                    width: 1,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  _buildNavIcon(
                    index: 1,
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: "Profile",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SimpleAccountScreen()),
                    ).then((_) => setState(() => _selectedIndex = 0)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon({
    required int index,
    required IconData icon,
    IconData? activeIcon,
    required String label,
    VoidCallback? onTap,
  }) {
    bool isSelected = _selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!isSelected) {
            HapticFeedback.lightImpact();
            setState(() => _selectedIndex = index);
            if (onTap != null) onTap();
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryAmber.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isSelected ? (activeIcon ?? icon) : icon,
                color:
                    isSelected ? primaryAmber : Colors.white.withOpacity(0.3),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            // Micro-animation for the label and dot
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: primaryAmber,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
