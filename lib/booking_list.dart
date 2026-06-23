import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'api_config.dart';
import 'car_list.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/intl.dart';
import 'driver_list.dart';
import 'main.dart';
// Your existing imports
import 'AccpetedBookingPageVender.dart';
import 'car_driver_selection_page.dart';
import 'document_expered_page.dart';
import 'compleated_List.dart';
import 'show_map.dart';
import 'whatsapp_booking_list.dart';
import 'owner_account.dart';
import 'car_reg_form.dart';
import 'driver_add_form.dart';
import 'settlements_page.dart';

class BookingListPage extends StatefulWidget {
  final String phoneNumber;
  const BookingListPage({super.key, required this.phoneNumber});

  @override
  _BookingListPageState createState() => _BookingListPageState();
}

class _BookingListPageState extends State<BookingListPage> {
  // --- STATE & LOGIC VARIABLES ---
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;
  bool isLoading = true;
  int totalTripCount = 0;
  List<dynamic> bookings = [];
  Timer? _timer;
  StreamSubscription? _notificationSubscription;

  // Professional Color Palette
  final Color primaryAmber = const Color(0xFFFFB300);
  final Color darkCharcoal = const Color(0xFF212121);
  final Color surfaceLight = const Color(0xFFF8F9FA);
  final List<String> imageUrls = [
    ApiConfig.add1Webp,
    ApiConfig.add2Webp,
    ApiConfig.add3Webp,
    ApiConfig.add4Webp,
  ];
  @override
  void initState() {
    super.initState();
    fetchBookings();
    _startLiveUpdateTimer();

    // Listen to foreground notifications to refresh the list automatically
    _notificationSubscription = notificationStreamController.stream.listen((message) {
      if (message.data['notification_type'] == 'new_booking') {
        fetchBookings();
      }
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startLiveUpdateTimer() {
    _timer =
        Timer.periodic(const Duration(seconds: 15), (timer) => fetchBookings());
  }

  // --- API CALLS ---
  Future<void> fetchBookings() async {
    String bookingApiUrl = ApiConfig.getBookings;
    try {
      var response = await http.post(
        Uri.parse(bookingApiUrl),
        body: {"phone_number": widget.phoneNumber},
      );
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            bookings = data["bookings"] ?? [];
            totalTripCount = (data["acceptedBookings"] as List).length;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- NAVIGATION HELPERS ---
  void _navigateTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: surfaceLight,
        appBar: _buildProAppBar(),
        body: isLoading ? _buildLoader() : _buildResponsiveBody(),
        bottomNavigationBar: _buildModernBottomNav(),
      ),
    );
  }

  // --- UI COMPONENTS ---

  PreferredSizeWidget _buildProAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      title: Row(
        children: [
          InkWell(
            onTap: () {
              fetchBookings(); // 🔥 reload function
            },
            child: Image.asset(
              'assets/login_img.png',
              width: MediaQuery.of(context).size.width * 0.30,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.grey),
          onPressed: () => fetchBookings(),
        ),
      ],
    );
  }

  Widget _buildResponsiveBody() {
    return LayoutBuilder(builder: (context, constraints) {
      double hPad = constraints.maxWidth > 600 ? 60 : 16;
      return RefreshIndicator(
        onRefresh: fetchBookings,
        color: primaryAmber,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              _buildActionGrid(),
              const SizedBox(height: 25),
              _buildWhatsAppSection(),
              const SizedBox(height: 30),
              _buildMarketHeader(),
              bookings.isEmpty ? _buildEmptyState() : _buildBookingList(),
              const SizedBox(height: 25),
              _buildPromotionSlider(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildActionGrid() {
    return Row(
      children: [
        _actionChip("Active", Icons.route_rounded, totalTripCount,
            () => _navigateTo(const MergedBookingsPage())),
        const SizedBox(width: 12),
        _actionChip("History", Icons.history_rounded, 0,
            () => _navigateTo(const CompleatedList())),
        const SizedBox(width: 12),
        _actionChip("Docs", Icons.folder_open_rounded, 0,
            () => _navigateTo(const DocumentExperedPage())),
      ],
    );
  }

  Widget _actionChip(
      String label, IconData icon, int count, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: [
              Stack(clipBehavior: Clip.none, children: [
                Icon(icon, color: primaryAmber, size: 26),
                if (count > 0)
                  Positioned(
                      right: -8,
                      top: -8,
                      child: CircleAvatar(
                          radius: 9,
                          backgroundColor: Colors.red,
                          child: Text("$count",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10)))),
              ]),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: darkCharcoal,
                      fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhatsAppSection() {
    return InkWell(
      onTap: () => _navigateTo(const NearbyTripsPage()),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF25D366), Color(0xFF128C7E)]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF128C7E).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8))
          ],
        ),
        child: Row(
          children: [
            Image.asset('assets/WhatsApp_icon.png', height: 45, width: 45),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("WhatsApp Direct",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text("Direct access to 500+ groups",
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: primaryAmber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(booking['trip_type'] ?? 'One-Way',
                      style: TextStyle(
                          color: primaryAmber,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ),
                Text("ID: ${booking['booking_id']}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        fontSize: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildJourneyLine(),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _locationTitle("Pickup", booking['pickup_location']),
                        const SizedBox(height: 20),
                        _locationTitle("Drop", booking['drop_location']),
                      ]),
                ),
                _carLabel(booking['car_type']),
              ],
            ),
          ),
          const Divider(height: 32, thickness: 0.5),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (booking['trip_type'] != 'Round-Trip')
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Partner Earning",
                        style: TextStyle(color: Colors.grey, fontSize: 11)),
                    Text("₹${booking['vendor_amount']}",
                        style: TextStyle(
                            color: darkCharcoal,
                            fontWeight: FontWeight.bold,
                            fontSize: 20)),
                  ])
                else
                  const SizedBox.shrink(),
                ElevatedButton(
                  onPressed: () => _navigateTo(CarDriverSelectionScreen(
                      bookingId: booking['booking_id'].toString(),
                      bookingData: booking)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAmber,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 25, vertical: 12),
                  ),
                  child: const Text("Accept Trip",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- REUSABLE MINI WIDGETS ---

  Widget _buildJourneyLine() {
    return Column(children: [
      Icon(Icons.radio_button_checked, color: primaryAmber, size: 16),
      Container(width: 2, height: 35, color: Colors.grey[200]),
      const Icon(Icons.location_on, color: Colors.redAccent, size: 18),
    ]);
  }

  Widget _locationTitle(String label, String? address) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
      Text(address ?? "N/A",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    ]);
  }

  Widget _carLabel(String? type) {
    return Column(children: [
      Image.asset('assets/sadan-1.webp',
          height: 40,
          errorBuilder: (_, __, ___) => const Icon(Icons.directions_car)),
      Text(type ?? "Sedan",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
    ]);
  }

  Widget _buildModernBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      height: 70,
      decoration: BoxDecoration(
        color: darkCharcoal,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navIcon(0, Icons.dashboard_rounded,
              () => setState(() => _selectedIndex = 0)),
          _navIcon(1, Icons.directions_car_filled_rounded,
              () => _navigateTo(const CarListPage())),
          _navIcon(2, Icons.person_add_rounded,
              () => _navigateTo(const DriverListPage())),
          _navIcon(3, Icons.account_balance_wallet_rounded,
              () => _navigateTo(SettlementsPage(phoneNumber: widget.phoneNumber))),
          _navIcon(4, Icons.account_circle_rounded,
              () => _navigateTo(const OwnerProfileScreen())),
        ],
      ),
    );
  }

  Widget _navIcon(int index, IconData icon, VoidCallback onTap) {
    bool isSel = _selectedIndex == index;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: isSel ? primaryAmber : Colors.transparent,
            shape: BoxShape.circle),
        child:
            Icon(icon, color: isSel ? Colors.black : Colors.white38, size: 26),
      ),
    );
  }

  Widget _buildLoader() =>
      Center(child: CircularProgressIndicator(color: primaryAmber));

  Widget _buildMarketHeader() => Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Marketplace Feed",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextButton(
              onPressed: () {},
              child: Text("Filter", style: TextStyle(color: primaryAmber))),
        ]),
      );
  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Takes only as much height as needed
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 30, // Reduced from 60
              color: Colors.grey[300],
            ),
            const SizedBox(height: 8), // Adds a small gap
            const Text(
              "No active marketplace bookings",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 8, // Smaller font
              ),
            ),
          ],
        ),
      );

  Widget _buildBookingList() => ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: bookings.length,
        itemBuilder: (context, index) => _buildBookingCard(bookings[index]),
      );

  Widget _buildPromotionSlider() {
    return CarouselSlider(
      options: CarouselOptions(
          height: 150,
          autoPlay: true,
          enlargeCenterPage: true,
          viewportFraction: 0.95),
      items: imageUrls
          .map((url) => ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                    imageUrl: url, fit: BoxFit.cover, width: double.infinity),
              ))
          .toList(),
    );
  }
}
