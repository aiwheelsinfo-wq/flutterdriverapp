import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'driver_add_form.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';
import 'booking_list.dart';
import 'car_list.dart';
import 'vendor_wallet_page.dart';
import 'owner_account.dart';


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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: Column(
          children: [
            _buildCleanHeader(),
            _buildSearchField(),
            _buildFilterBar(),
            const SizedBox(height: 8),
            Expanded(
              child: isLoading ? _buildShimmerLoading() : _buildDriverList(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: fetchDrivers,
          backgroundColor: kAmberPrimary,
          elevation: 2,
          child: const Icon(Icons.refresh, color: Colors.black87),
        ),
        bottomNavigationBar: _buildModernBottomNav(),
      ),
    );
  }

  Widget _buildCleanHeader() {
    final int totalDrivers = drivers.length;
    final int activeDrivers = drivers.where((d) => (d["status"] ?? '').toString().toLowerCase() == "active").length;

    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFF1F2F4), width: 1),
            ),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF171717),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Driver Dashboard",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF171717),
                        fontWeight: FontWeight.w800,
                        fontSize: 21,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (totalDrivers > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        "$totalDrivers Drivers · $activeDrivers Active",
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DriverFormPage(),
                      ),
                    );
                    fetchDrivers();
                  },
                  icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF171717)),
                  label: const Text(
                    "Add Driver",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF171717),
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB000),
                    foregroundColor: const Color(0xFF171717),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(
            color: Color(0xFF374151),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: "Search name or phone...",
            hintStyle: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFFF59E0B),
              size: 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF9CA3AF)),
                    onPressed: () {
                      _searchController.clear();
                      _applyFilters();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final List<Map<String, String>> statuses = [
      {"key": "All", "label": "All"},
      {"key": "active", "label": "Active"},
      {"key": "filled", "label": "Filled"},
      {"key": "not filled", "label": "Pending"},
      {"key": "inactive", "label": "Inactive"},
    ];

    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: statuses.length,
        itemBuilder: (context, index) {
          final item = statuses[index];
          final String key = item["key"]!;
          final String label = item["label"]!;
          final bool isSelected = selectedFilter == key;

          int count = 0;
          if (key == "All") {
            count = drivers.length;
          } else {
            count = drivers.where((d) => (d["status"] ?? '').toString().toLowerCase() == key.toLowerCase()).length;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() => selectedFilter = key);
                _applyFilters();
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF171717) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF171717) : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isSelected ? 0.08 : 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF4B5563),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    if (drivers.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFFB000) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "$count",
                          style: TextStyle(
                            color: isSelected ? Colors.black : const Color(0xFF6B7280),
                            fontWeight: FontWeight.bold,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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

                // 3. Edit & Delete Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: "Edit Driver",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DriverFormPage(driverData: driver),
                          ),
                        ).then((_) => fetchDrivers());
                      },
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.blueAccent, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      tooltip: "Delete Driver",
                      onPressed: () => _confirmDelete(driverId),
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
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

  Future<void> deleteDriver(int driverId) async {
    if (vendorId == null) return;
    try {
      final response = await http.delete(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "driver_id": driverId,
          "vendor_id": vendorId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Driver removed successfully"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          fetchDrivers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data["message"] ?? "Failed to remove driver"),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Server error. Failed to remove driver."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Network error. Failed to remove driver."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Remove Driver?"),
        content: const Text(
            "Are you sure you want to remove this driver from your active fleet?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          TextButton(
              onPressed: () {
                Navigator.pop(c);
                deleteDriver(id);
              },
              child: const Text("Remove", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() =>
      const Center(child: CircularProgressIndicator(color: Colors.amber));

  Widget _buildModernBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
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
          _navIcon(0, Icons.dashboard_rounded, () {
            if (vendorId != null) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => BookingListPage(phoneNumber: vendorId!)),
                (route) => false,
              );
            } else {
              Navigator.popUntil(context, (route) => route.isFirst);
            }
          }),
          _navIcon(1, Icons.directions_car_filled_rounded, () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CarListPage()),
            );
          }),
          _navIcon(2, Icons.person_add_rounded, () {}),
          _navIcon(3, Icons.account_balance_wallet_rounded, () {
            if (vendorId != null) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => VendorWalletPage(vendorPhone: vendorId!)),
              );
            }
          }),
          _navIcon(4, Icons.account_circle_rounded, () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const OwnerProfileScreen()),
            );
          }),
        ],
      ),
    );
  }

  Widget _navIcon(int index, IconData icon, VoidCallback onTap) {
    bool isSel = index == 2; // Index 2 is Driver List Page (Selected!)
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: isSel ? const Color(0xFFFFB300) : Colors.transparent,
            shape: BoxShape.circle),
        child: Icon(icon, color: isSel ? Colors.black : Colors.white38, size: 26),
      ),
    );
  }
}
