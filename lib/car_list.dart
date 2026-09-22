import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'car_reg_form.dart';
import 'test_car_reg_form.dart';
import 'api_config.dart';
import 'booking_list.dart';
import 'driver_list.dart';
import 'vendor_wallet_page.dart';
import 'owner_account.dart';

class CarListPage extends StatefulWidget {
  const CarListPage({Key? key}) : super(key: key);

  @override
  State<CarListPage> createState() => _CarListPageState();
}

class _CarListPageState extends State<CarListPage> {
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  List allCars = [];
  List filteredCars = [];
  bool isLoading = true;
  String? vendorId;
  String selectedFilter = "All";
  final TextEditingController _searchController = TextEditingController();

  // Industry Standard Palette
  final Color kAmber = const Color(0xFFFFB300);
  final Color kDark = const Color(0xFF121212);
  final Color kLightAmber = const Color(0xFFFFF8E1);
  final Color kBackground = const Color(0xFFF7F8FA);

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    vendorId = await storage.read(key: "phone_number");
    if (vendorId != null) fetchCars();
  }

  // ================= API OPERATIONS =================

  Future<void> fetchCars() async {
    setState(() => isLoading = true);
    try {
      final url =
          "${ApiConfig.carListForVendor}?vendor_id=$vendorId";
      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);

      if (data["status"]) {
        setState(() {
          allCars = data["data"];
          _runFilter(_searchController.text);
          isLoading = false;
        });
      }
    } catch (e) {
      _showSnackBar("Error connecting to server", Colors.red);
      setState(() => isLoading = false);
    }
  }

  Future<void> updateCar(Map carData) async {
    print('carData: $carData');
    const url = ApiConfig.carListForVendor;
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(carData),
      );
      if (response.statusCode == 200) {
        print('somehting ${response.body}');
        _showSnackBar("Vehicle updated successfully", Colors.green);
        fetchCars();
      }
    } catch (e) {
      _showSnackBar("Update failed", Colors.red);
    }
  }

  Future<void> deleteCar(int carId) async {
    const url = ApiConfig.carListForVendor;
    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": carId}),
      );
      if (response.statusCode == 200) {
        _showSnackBar("Vehicle removed from fleet", Colors.orange);
        fetchCars();
      }
    } catch (e) {
      _showSnackBar("Deletion failed", Colors.red);
    }
  }

  // ================= LOGIC =================

  void _runFilter(String query) {
    setState(() {
      filteredCars = allCars.where((car) {
        bool matchesSearch =
            car["vehicle_number"].toLowerCase().contains(query.toLowerCase()) ||
                car["vehicle_name"].toLowerCase().contains(query.toLowerCase());
        bool isBusy = isBookedToday(car["bookings"]);

        if (selectedFilter == "Busy") return matchesSearch && isBusy;
        if (selectedFilter == "Available") return matchesSearch && !isBusy;
        return matchesSearch;
      }).toList();
    });
  }

  bool isBookedToday(List bookings) {
    String today = DateTime.now().toString().split(" ")[0];
    return bookings.any((b) {
      if (b["date"] != today) return false;
      String status = b["status"]?.toString() ?? "";
      return status != "Completed" && status != "Cancelled" && status != "Customer Cancelled";
    });
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ================= UI COMPONENTS =================

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: kBackground,
        body: Column(
          children: [
            _buildCleanHeader(),
            _buildSearchField(),
            _buildFilterChips(),
            const SizedBox(height: 8),
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: kAmber))
                  : RefreshIndicator(
                      onRefresh: fetchCars, child: _buildFleetList()),
            ),
          ],
        ),
        bottomNavigationBar: _buildModernBottomNav(),
      ),
    );
  }

  Widget _buildCleanHeader() {
    final int totalCount = allCars.length;
    final int busyCount = allCars.where((c) => isBookedToday(c["bookings"])).length;
    final int availableCount = (totalCount >= busyCount) ? totalCount - busyCount : 0;

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
                      "Fleet Dashboard",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF171717),
                        fontWeight: FontWeight.w800,
                        fontSize: 21,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (totalCount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        "$totalCount Vehicles · $availableCount Available · $busyCount Busy",
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
                        builder: (context) => const CarFormPage(),
                      ),
                    );
                    fetchCars();
                  },
                  onLongPress: () async {
                    // Quick shortcut: long-press opens Sandbox Test Form
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TestCarFormPage(),
                      ),
                    );
                    fetchCars();
                  },
                  icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF171717)),
                  label: const Text(
                    "Add Car",
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
              if (kDebugMode) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TestCarFormPage(),
                        ),
                      );
                      fetchCars();
                    },
                    icon: const Icon(Icons.science_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      "🧪 Test",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
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
          onChanged: _runFilter,
          style: const TextStyle(
            color: Color(0xFF374151),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: "Search plate or model...",
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
                      _runFilter('');
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

  Widget _buildFilterChips() {
    List<String> options = ["All", "Available", "Busy"];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: options.map((opt) {
          bool active = selectedFilter == opt;
          int count = 0;
          if (opt == "All") {
            count = allCars.length;
          } else if (opt == "Available") {
            count = allCars.where((c) => !isBookedToday(c["bookings"])).length;
          } else if (opt == "Busy") {
            count = allCars.where((c) => isBookedToday(c["bookings"])).length;
          }

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: opt != "Busy" ? 10 : 0,
              ),
              child: InkWell(
                onTap: () {
                  setState(() => selectedFilter = opt);
                  _runFilter(_searchController.text);
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF171717) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active ? const Color(0xFF171717) : const Color(0xFFE5E7EB),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: active ? 0.08 : 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        opt,
                        style: TextStyle(
                          color: active ? Colors.white : const Color(0xFF4B5563),
                          fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (allCars.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: active ? const Color(0xFFFFB000) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "$count",
                            style: TextStyle(
                              color: active ? Colors.black : const Color(0xFF6B7280),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFleetList() {
    if (filteredCars.isEmpty)
      return const Center(child: Text("No Vehicles Found"));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredCars.length,
      itemBuilder: (context, index) {
        final car = filteredCars[index];
        final bool busy = isBookedToday(car["bookings"]);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: busy ? Colors.red.withOpacity(0.3) : Colors.transparent,
                width: 2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                          color: busy ? Colors.red.shade50 : kLightAmber,
                          borderRadius: BorderRadius.circular(15)),
                      child: Icon(Icons.directions_car_filled,
                          color: busy ? Colors.red : kAmber, size: 30),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(car["vehicle_name"].toString().toUpperCase(),
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 5),
                          _buildLicensePlate(car["vehicle_number"]),
                        ],
                      ),
                    ),
                    _buildStatusBadge(busy),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child:
                          _infoText(Icons.local_gas_station, car["fuel_type"]),
                    ),
                    Expanded(
                      child: _infoText(Icons.airline_seat_recline_normal,
                          car["vehicle_type"]),
                    ),
                    Expanded(
                      child: _infoText(
                          Icons.history, "${car["bookings"].length} Trips"),
                    ),
                  ],
                ),
              ),
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text("View Details & Trip History",
                      style: TextStyle(
                          fontSize: 12,
                          color: kAmber,
                          fontWeight: FontWeight.bold)),
                  children: [
                    _buildDetailedTimeline(car["bookings"]),
                    _buildActionButtons(car),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLicensePlate(String plate) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black87, width: 1.5)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 3, height: 15, color: Colors.blue),
            const SizedBox(width: 5),
            Text(plate,
                style: GoogleFonts.robotoCondensed(
                    fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool busy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: busy ? Colors.red.shade50 : Colors.green.shade50,
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
              radius: 3, backgroundColor: busy ? Colors.red : Colors.green),
          const SizedBox(width: 5),
          Text(busy ? "ON TRIP" : "AVAILABLE",
              style: TextStyle(
                  color: busy ? Colors.red : Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _infoText(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.black38),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  // ================= INFORMATIVE TOGGLE (TIMELINE) =================

  Widget _buildDetailedTimeline(List bookings) {
    if (bookings.isEmpty)
      return const Padding(
          padding: EdgeInsets.all(20),
          child: Text("No previous trips recorded for this car."));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: bookings.map((b) {
          bool isToday = b["date"] == DateTime.now().toString().split(" ")[0];
          return Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isToday ? kLightAmber.withOpacity(0.5) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: isToday ? kAmber : Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${b["trip_type"]} Trip",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    if ((b["trip_type"] ?? '') != 'Round-Trip')
                      Text(
                          "₹${b["vendor_amount"] ?? b["amount"] ?? "0"}",
                          style: TextStyle(
                              color: kAmber,
                              fontWeight: FontWeight.bold,
                              fontSize: 14))
                    else if (b["kmRate"] != null && (double.tryParse(b["kmRate"].toString()) ?? 0) > 0)
                      Text(
                          "₹${(double.tryParse(b["kmRate"].toString()) ?? 0).toStringAsFixed(0)}/km",
                          style: TextStyle(
                              color: kAmber,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.radio_button_checked,
                            size: 14, color: Colors.green),
                        Container(
                            width: 1, height: 20, color: Colors.grey.shade300),
                        const Icon(Icons.location_on,
                            size: 14, color: Colors.red),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b["from"] ?? "Unknown Pickup",
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 18),
                          Text(b["to"] ?? "Unknown Drop",
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    )
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${b["date"]} | ${b["time"]}",
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey)),
                    _miniStatusBadge(b["status"]),
                  ],
                )
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _miniStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(),
          style: const TextStyle(
              fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue)),
    );
  }

  // ================= ACTION BUTTONS (EDIT/DELETE) =================

  Widget _buildActionButtons(Map car) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CarFormPage(carData: Map<String, dynamic>.from(car)),
                  ),
                ).then((_) => fetchCars());
              },
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text("Edit Vehicle"),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  side: const BorderSide(color: Colors.blueAccent)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showDeleteConfirmation(car["id"]),
              icon: const Icon(Icons.delete_sweep, size: 16),
              label: const Text("Delete"),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(int id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Remove Car?"),
        content: const Text(
            "Are you sure you want to remove this vehicle from your active fleet?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(c);
              deleteCar(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Confirm Delete"),
          ),
        ],
      ),
    );
  }

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
          _navIcon(1, Icons.directions_car_filled_rounded, () {}),
          _navIcon(2, Icons.person_add_rounded, () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriverListPage()),
            );
          }),
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
    bool isSel = index == 1; // Index 1 is Car List Page (Selected!)
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: isSel ? kAmber : Colors.transparent,
            shape: BoxShape.circle),
        child: Icon(icon, color: isSel ? Colors.black : Colors.white38, size: 26),
      ),
    );
  }
}
