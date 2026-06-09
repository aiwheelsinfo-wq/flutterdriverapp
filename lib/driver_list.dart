import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'driver_add_form.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';


class DriverListPage extends StatefulWidget {
  const DriverListPage({Key? key}) : super(key: key);

  @override
  State<DriverListPage> createState() => _DriverListPageState();
}

class _DriverListPageState extends State<DriverListPage> {
  List drivers = [];
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  String? vendorId;

  List filteredDrivers = [];
  bool isLoading = true;
  String selectedFilter = "All";
  final TextEditingController _searchController = TextEditingController();

  final String baseUrl = ApiConfig.driverListForVendor;


  Set<int> expandedDrivers = {};

  final Color kAmberPrimary = const Color(0xFFFFB300);
  final Color kAmberLight = const Color(0xFFFFF8E1);
  final Color kDarkBG = const Color(0xFF1A1A1A);
  final Color kSurface = Colors.white;

  @override
  void initState() {
    super.initState();
    _initialize();
    _searchController.addListener(_applyFilters);
  }

  Future<void> _initialize() async {
    vendorId = await storage.read(key: "phone_number");

    if (vendorId == null) {
      setState(() => isLoading = false);
      return;
    }

    await fetchDrivers();
  }

  Future<void> fetchDrivers() async {
    if (vendorId == null) return;

    setState(() => isLoading = true);

    try {
      final response =
          await http.get(Uri.parse("$baseUrl?vendor_id=$vendorId"));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          drivers = data["data"] ?? [];
          _applyFilters();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      filteredDrivers = drivers.where((driver) {
        bool matchesSearch =
            driver["full_name"].toString().toLowerCase().contains(query) ||
                driver["phone_number"].toString().contains(query);
        bool matchesStatus =
            selectedFilter == "All" || driver["status"] == selectedFilter;
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Number $text copied"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: kDarkBG,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _launchAction(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFA),
      body: Column(
        children: [
          _buildHeroHeader(),
          _buildFilterBar(),
          Expanded(
            child: isLoading ? _buildShimmerLoading() : _buildDriverList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: fetchDrivers,
        backgroundColor: kAmberPrimary,
        child: const Icon(Icons.refresh, color: Colors.black87),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 24),
      decoration: BoxDecoration(
        color: kDarkBG,
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (Navigator.canPop(context)) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Fleet Dashboard",
                          style: GoogleFonts.poppins(
                              color: Colors.white70, fontSize: 13)),
                      Text("Welcome, Vendor",
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              SizedBox(
                height: 38,
                child: FloatingActionButton.extended(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const DriverFormPage())),
                  backgroundColor: kAmberPrimary,
                  icon: const Icon(Icons.add, color: Colors.black87, size: 18),
                  label: const Text('ADD DRIVER',
                      style: TextStyle(
                          color: Colors.black87,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search name or phone...",
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.amber, size: 20),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    List<String> statuses = [
      "All",
      "active",
      "filled",
      "not filled",
      "inactive"
    ];
    return SizedBox(
      height: 55,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: statuses.length,
        itemBuilder: (context, index) {
          bool isSelected = selectedFilter == statuses[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(statuses[index],
                  style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.black : Colors.grey.shade700)),
              selected: isSelected,
              selectedColor: kAmberPrimary,
              backgroundColor: Colors.grey.shade200,
              onSelected: (val) {
                setState(() => selectedFilter = statuses[index]);
                _applyFilters();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDriverList() {
    if (filteredDrivers.isEmpty) {
      return Center(
          child: Text("No drivers found",
              style: GoogleFonts.inter(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredDrivers.length,
      itemBuilder: (context, index) {
        final driver = filteredDrivers[index];
        return _buildDriverCard(driver);
      },
    );
  }

  Widget _buildDriverCard(dynamic driver) {
    final int driverId = driver["driver_id"];
    final bool isExpanded = expandedDrivers.contains(driverId);
    Color statusColor =
        driver["status"] == "Active" ? Colors.green : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: kAmberLight,
                      child: Text((driver["full_name"][0]).toUpperCase(),
                          style: TextStyle(
                              color: kAmberPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 20)),
                    ),
                    Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                            height: 12,
                            width: 12,
                            decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2)))),
                  ],
                ),
                const SizedBox(width: 12),

                // 2. Info (Flexible to prevent overflow)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver["full_name"],
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.star, color: kAmberPrimary, size: 12),
                          const SizedBox(width: 4),
                          Text("4.8 • ${driver["bookings"].length} Trips",
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Actions Row moved inside the Flexible column to take only needed space
                      _buildQuickActions(driver["phone_number"]),
                    ],
                  ),
                ),

                // 3. Delete Button (Isolated to prevent row overflow)
                IconButton(
                  onPressed: () => _confirmDelete(driverId),
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => setState(() => isExpanded
                ? expandedDrivers.remove(driverId)
                : expandedDrivers.add(driverId)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                  color: kAmberLight.withOpacity(0.4),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(16))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(isExpanded ? "Hide History" : "View Recent Trips",
                      style: TextStyle(
                          color: kAmberPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                  Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: kAmberPrimary,
                      size: 18),
                ],
              ),
            ),
          ),
          if (isExpanded) _buildBookingTimeline(driver["bookings"]),
        ],
      ),
    );
  }

  Widget _buildQuickActions(String phone) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconBtn(Icons.call, Colors.green, () => _launchAction("tel:$phone")),
        const SizedBox(width: 10),
        _iconBtn(
            Icons.content_copy, kAmberPrimary, () => _copyToClipboard(phone)),
        const SizedBox(width: 10),
        _iconBtn(Icons.chat_bubble, Colors.blue,
            () => _launchAction("whatsapp://send?phone=+91$phone")),
      ],
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _buildBookingTimeline(List bookings) {
    if (bookings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history_toggle_off, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                "No trip history found",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final String today = DateTime.now().toIso8601String().split('T').first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: List.generate(bookings.length, (i) {
          final b = bookings[i];
          final bool isLast = i == bookings.length - 1;

          final bool isTodayBooking =
              b["date"] != null && b["date"].toString().startsWith(today);

          final bool isLiveTrip =
              b["booking_status"]?.toString().toLowerCase() == "ongoing";

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---------- Timeline ----------
                Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: kAmberPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: kAmberPrimary.withOpacity(0.3),
                            blurRadius: 4,
                          )
                        ],
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 1.5,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: kAmberPrimary.withOpacity(0.2),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 15),

                // ---------- Trip Card ----------
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isTodayBooking ? Colors.red.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isTodayBooking
                            ? Colors.red.shade300
                            : Colors.grey.shade100,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // -------- Header --------
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  b["trip_type"].toString().toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isTodayBooking
                                        ? Colors.red
                                        : kAmberPrimary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (isTodayBooking) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isLiveTrip
                                          ? Colors.red
                                          : Colors.orange,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isLiveTrip ? "LIVE TRIP" : "ON DUTY",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            _statusChip(b["booking_status"]),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // -------- Route --------
                        _buildRouteRow(
                          Icons.radio_button_checked,
                          Colors.green,
                          b["from_address"],
                        ),

                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            width: 1,
                            height: 12,
                            color: Colors.grey.shade300,
                          ),
                        ),

                        _buildRouteRow(
                          Icons.location_on,
                          Colors.red,
                          b["to_address"],
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, thickness: 0.5),
                        ),

                        // -------- Date & Time --------
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              b["date"] ?? "N/A",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              b["time"] ?? "N/A",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

// Helper Widget for Route Addresses
  Widget _buildRouteRow(IconData icon, Color color, String address) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            address,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

// Advanced Status Badge
  Widget _statusChip(String status) {
    Color bgColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'completed':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      case 'cancelled':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        break;
      default:
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
            color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Remove Driver?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("Remove", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() =>
      const Center(child: CircularProgressIndicator(color: Colors.amber));
}
