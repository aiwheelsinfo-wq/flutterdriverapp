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
import 'owner_account.dart';
import 'package:geolocator/geolocator.dart';
import 'support_chat_page.dart';
import 'vendor_wallet_page.dart';

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
  List<dynamic> allBookings = [];
  List<dynamic> bookings = [];
  Timer? _timer;
  StreamSubscription? _notificationSubscription;
  double _walletBalance = 0.0;
  double _minWalletBalance = 0.0;
  bool _isEligibleForLocalTaxi = true;
  double _minWalletBalanceRoundTrip = 1000.0;
  bool _isEligibleForRoundTrip = true;

  // Online / Offline State
  bool isOnline = true;
  bool isTogglingStatus = false;
  bool isBlocked = false;
  String blockReason = '';

  // Filter & Sort State
  String selectedQuickFilter = 'All'; // 'All', 'Today', 'Advance', 'Local-taxi', 'One-way', 'Round-Trip'
  String selectedDateFilter = 'All'; // 'All', 'Today', 'Advance', 'Custom'
  DateTime? customFilterDate;
  String selectedTripTypeFilter = 'All'; // 'All', 'Local-taxi', 'One-way', 'Round-Trip', 'Local-duty'
  String selectedCarTypeFilter = 'All'; // 'All', 'Sedan', 'SUV', 'Hatchback'
  String selectedSortFilter = 'Default'; // 'Default', 'PriceHighToLow', 'DistanceNearest', 'PickupTime'

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
    _loadInitialOnlineStatus();
    _updateCurrentLocation();
    fetchBookings();
    _startLiveUpdateTimer();

    // Listen to foreground notifications to refresh the list automatically
    _notificationSubscription = notificationStreamController.stream.listen((message) {
      if (message.data['notification_type'] == 'new_booking') {
        fetchBookings();
      }
    });
  }

  Future<void> _loadInitialOnlineStatus() async {
    try {
      final stored = await secureStorage.read(key: "is_driver_online");
      if (stored != null && mounted) {
        setState(() => isOnline = (stored == 'true'));
      }
      final res = await http.get(Uri.parse("${ApiConfig.updateDriverStatus}?phone_number=${widget.phoneNumber}"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['is_blocked'] == true || data['status'] == 'blocked' || data['driver_status'] == 'blocked') {
          if (mounted) {
            setState(() {
              isBlocked = true;
              blockReason = data['block_reason'] ?? 'Administrative restriction';
              isOnline = false;
            });
            await secureStorage.write(key: "is_driver_online", value: "false");
          }
        } else if (data['status'] == 'success' && data['is_online'] != null) {
          final serverOnline = (data['is_online'] == true);
          if (mounted) {
            setState(() {
              isBlocked = false;
              isOnline = serverOnline;
            });
            await secureStorage.write(key: "is_driver_online", value: serverOnline.toString());
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking online status: $e");
    }
  }

  Future<void> _toggleOnlineOffline(bool newValue) async {
    if (isBlocked) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Account Suspended: Cannot go online. $blockReason"),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (isTogglingStatus) return;
    setState(() {
      isTogglingStatus = true;
      isOnline = newValue;
    });

    try {
      await secureStorage.write(key: "is_driver_online", value: newValue.toString());
      final res = await http.post(
        Uri.parse(ApiConfig.updateDriverStatus),
        body: {
          "phone_number": widget.phoneNumber,
          "status": newValue ? "active" : "offline"
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['is_blocked'] == true || data['status'] == 'blocked') {
          if (mounted) {
            setState(() {
              isBlocked = true;
              blockReason = data['block_reason'] ?? 'Administrative restriction';
              isOnline = false;
            });
            await secureStorage.write(key: "is_driver_online", value: "false");
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Account Blocked: ${data['message'] ?? blockReason}"),
                backgroundColor: const Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
        if (data['status'] == 'success') {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(
                      newValue ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        newValue
                            ? "You are ONLINE • Ready for trips"
                            : "You are OFFLINE • Siren alerts paused",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                backgroundColor: newValue ? const Color(0xFF059669) : const Color(0xFF1F2937),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 95),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
            if (newValue) {
              fetchBookings();
              _updateCurrentLocation();
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error updating driver status: $e");
    } finally {
      if (mounted) setState(() => isTogglingStatus = false);
    }
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

  Future<void> _updateCurrentLocation() async {
    if (!isOnline || isBlocked) return; // Save phone battery when offline or blocked!
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium);
        
        await http.post(
          Uri.parse(ApiConfig.updateLocation),
          body: {
            'driver_id': widget.phoneNumber,
            'latitude': position.latitude.toString(),
            'longitude': position.longitude.toString(),
          },
        );
      }
    } catch (e) {
      debugPrint("Update location on dashboard error: $e");
    }
  }

  // --- API CALLS ---
  Future<void> fetchBookings() async {
    _updateCurrentLocation();
    String bookingApiUrl = ApiConfig.getBookings;
    try {
      var response = await http.post(
        Uri.parse(bookingApiUrl),
        body: {"phone_number": widget.phoneNumber},
      );
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data["is_blocked"] == true || data["status"] == "blocked") {
          if (mounted) {
            setState(() {
              isBlocked = true;
              blockReason = data["block_reason"] ?? "Administrative restriction";
              isOnline = false;
              allBookings = [];
              bookings = [];
              totalTripCount = 0;
              isLoading = false;
            });
            await secureStorage.write(key: "is_driver_online", value: "false");
          }
          return;
        }
        if (mounted) {
          setState(() {
            isBlocked = false;
            _walletBalance = (data["wallet_balance"] as num?)?.toDouble() ?? 0.0;
            _minWalletBalance = (data["min_wallet_balance"] as num?)?.toDouble() ?? 0.0;
            _isEligibleForLocalTaxi = data["is_eligible_for_local_taxi"] ?? (_walletBalance > _minWalletBalance);
            _minWalletBalanceRoundTrip = (data["min_wallet_balance_round_trip"] as num?)?.toDouble() ?? 1000.0;
            _isEligibleForRoundTrip = data["is_eligible_for_round_trip"] ?? (_walletBalance > _minWalletBalanceRoundTrip);
            allBookings = data["bookings"] ?? [];
            bookings = _applyFilters(allBookings);
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

  // --- FILTER & SORT LOGIC ---
  List<dynamic> _applyFilters(List<dynamic> rawList) {
    List<dynamic> list = List.from(rawList);
    final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 1. Quick Filter Pills
    if (selectedQuickFilter == 'Today') {
      list = list.where((b) => (b['date'] ?? '').toString().trim() == todayStr).toList();
    } else if (selectedQuickFilter == 'Advance') {
      list = list.where((b) {
        final d = (b['date'] ?? '').toString().trim();
        return d.isNotEmpty && d.compareTo(todayStr) > 0;
      }).toList();
    } else if (selectedQuickFilter == 'Local-taxi') {
      list = list.where((b) => (b['trip_type'] ?? '').toString().toLowerCase().contains('taxi')).toList();
    } else if (selectedQuickFilter == 'One-way') {
      list = list.where((b) {
        final t = (b['trip_type'] ?? '').toString().toLowerCase();
        return t.contains('one-way') || t.contains('oneway');
      }).toList();
    } else if (selectedQuickFilter == 'Round-Trip') {
      list = list.where((b) => (b['trip_type'] ?? '').toString().toLowerCase().contains('round')).toList();
    }

    // 2. Date Filter (from bottom sheet modal)
    if (selectedDateFilter == 'Today') {
      list = list.where((b) => (b['date'] ?? '').toString().trim() == todayStr).toList();
    } else if (selectedDateFilter == 'Advance') {
      list = list.where((b) {
        final d = (b['date'] ?? '').toString().trim();
        return d.isNotEmpty && d.compareTo(todayStr) > 0;
      }).toList();
    } else if (selectedDateFilter == 'Custom' && customFilterDate != null) {
      final String customStr = DateFormat('yyyy-MM-dd').format(customFilterDate!);
      list = list.where((b) => (b['date'] ?? '').toString().trim() == customStr).toList();
    }

    // 3. Trip Type Filter (from modal)
    if (selectedTripTypeFilter != 'All') {
      final sel = selectedTripTypeFilter.toLowerCase();
      list = list.where((b) {
        final t = (b['trip_type'] ?? '').toString().toLowerCase();
        return t.contains(sel);
      }).toList();
    }

    // 4. Car Type Filter (from modal)
    if (selectedCarTypeFilter != 'All') {
      final selCar = selectedCarTypeFilter.toLowerCase();
      list = list.where((b) {
        final c = (b['car_type'] ?? '').toString().toLowerCase();
        return c.contains(selCar);
      }).toList();
    }

    // 5. Sorting
    if (selectedSortFilter == 'PriceHighToLow') {
      list.sort((a, b) {
        final double pA = double.tryParse(a['vendor_amount']?.toString() ?? '0') ?? 0.0;
        final double pB = double.tryParse(b['vendor_amount']?.toString() ?? '0') ?? 0.0;
        return pB.compareTo(pA);
      });
    } else if (selectedSortFilter == 'DistanceNearest') {
      list.sort((a, b) {
        final double dA = double.tryParse(a['distance']?.toString() ?? '9999') ?? 9999.0;
        final double dB = double.tryParse(b['distance']?.toString() ?? '9999') ?? 9999.0;
        return dA.compareTo(dB);
      });
    } else if (selectedSortFilter == 'PickupTime') {
      list.sort((a, b) {
        final String tA = "${a['date'] ?? ''} ${a['time'] ?? ''}";
        final String tB = "${b['date'] ?? ''} ${b['time'] ?? ''}";
        return tA.compareTo(tB);
      });
    }

    return list;
  }

  int get _activeFilterCount {
    int count = 0;
    if (selectedQuickFilter != 'All') count++;
    if (selectedDateFilter != 'All') count++;
    if (selectedTripTypeFilter != 'All') count++;
    if (selectedCarTypeFilter != 'All') count++;
    if (selectedSortFilter != 'Default') count++;
    return count;
  }

  int _countForQuickFilter(String filterKey) {
    final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (filterKey == 'All') return allBookings.length;
    if (filterKey == 'Today') {
      return allBookings.where((b) => (b['date'] ?? '').toString().trim() == todayStr).length;
    }
    if (filterKey == 'Advance') {
      return allBookings.where((b) {
        final d = (b['date'] ?? '').toString().trim();
        return d.isNotEmpty && d.compareTo(todayStr) > 0;
      }).length;
    }
    if (filterKey == 'Local-taxi') {
      return allBookings.where((b) => (b['trip_type'] ?? '').toString().toLowerCase().contains('taxi')).length;
    }
    if (filterKey == 'One-way') {
      return allBookings.where((b) {
        final t = (b['trip_type'] ?? '').toString().toLowerCase();
        return t.contains('one-way') || t.contains('oneway');
      }).length;
    }
    if (filterKey == 'Round-Trip') {
      return allBookings.where((b) => (b['trip_type'] ?? '').toString().toLowerCase().contains('round')).length;
    }
    return 0;
  }

  void _resetAllFilters() {
    setState(() {
      selectedQuickFilter = 'All';
      selectedDateFilter = 'All';
      customFilterDate = null;
      selectedTripTypeFilter = 'All';
      selectedCarTypeFilter = 'All';
      selectedSortFilter = 'Default';
      bookings = _applyFilters(allBookings);
    });
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
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _buildOnlineOfflineToggle(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.support_agent_rounded, color: Color(0xFF475569)),
          tooltip: "Helpdesk Support Chat",
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SupportChatPage(
                  phoneNumber: widget.phoneNumber,
                  blockReason: blockReason,
                  isBlocked: isBlocked,
                ),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.grey),
          onPressed: () => fetchBookings(),
        ),
      ],
    );
  }

  Widget _buildOnlineOfflineToggle() {
    const Color activeGreen = Color(0xFF10B981);
    const Color inactiveGrey = Color(0xFF6B7280);
    const Color blockedRed = Color(0xFFDC2626);

    return InkWell(
      onTap: isBlocked
          ? () {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Account Blocked: $blockReason"),
                  backgroundColor: const Color(0xFFDC2626),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          : (isTogglingStatus ? null : () => _toggleOnlineOffline(!isOnline)),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isBlocked
              ? const Color(0xFFFEF2F2)
              : (isOnline ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isBlocked
                ? blockedRed
                : (isOnline ? activeGreen : const Color(0xFFD1D5DB)),
            width: 1.5,
          ),
          boxShadow: isBlocked
              ? [
                  BoxShadow(
                    color: blockedRed.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : (isOnline
                  ? [
                      BoxShadow(
                        color: activeGreen.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null),
        ),
        child: isTogglingStatus
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  isBlocked
                      ? const Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 14)
                      : RadarScanWidget(
                          isOnline: isOnline,
                          activeColor: activeGreen,
                          inactiveColor: inactiveGrey,
                        ),
                  const SizedBox(width: 6),
                  Text(
                    isBlocked ? "BLOCKED" : (isOnline ? "ONLINE" : "OFFLINE"),
                    style: TextStyle(
                      color: isBlocked
                          ? const Color(0xFF991B1B)
                          : (isOnline ? const Color(0xFF065F46) : const Color(0xFF374151)),
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBlockedSuspensionBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_rounded,
                  color: Color(0xFFDC2626),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ACCOUNT SUSPENDED / BLOCKED",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF991B1B),
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "All trip assignments and online status are restricted",
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFEE2E2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "REASON SPECIFIED BY ADMIN:",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7F1D1D),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  blockReason.isNotEmpty ? blockReason : "Administrative restriction applied by admin.",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SupportChatPage(
                      phoneNumber: widget.phoneNumber,
                      blockReason: blockReason,
                      isBlocked: isBlocked,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_rounded, size: 18),
              label: const Text("CHAT WITH HELPDESK TO RE-ACTIVATE"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineWarningBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bedtime_rounded,
              color: Color(0xFFD97706),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "You are OFFLINE",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Siren alerts & live GPS paused",
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: isTogglingStatus ? null : () => _toggleOnlineOffline(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              "GO ONLINE",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.3),
            ),
          ),
        ],
      ),
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
              if (isBlocked)
                _buildBlockedSuspensionBanner()
              else if (!isOnline)
                _buildOfflineWarningBanner(),
              _buildActionGrid(),
              const SizedBox(height: 25),
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
        const SizedBox(width: 8),
        _actionChip("History", Icons.history_rounded, 0,
            () => _navigateTo(const CompleatedList())),
        const SizedBox(width: 8),
        _actionChip("Docs", Icons.folder_open_rounded, 0,
            () => _navigateTo(const DocumentExperedPage())),
        const SizedBox(width: 8),
        _actionChip("Wallet", Icons.account_balance_wallet_rounded, 0,
            () => _navigateTo(VendorWalletPage(vendorPhone: widget.phoneNumber))),
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

  bool _isOneWayOrLocalTaxi(String? tripType) {
    if (tripType == null || tripType.isEmpty) return false;
    final lower = tripType.toLowerCase();
    if (lower.contains('round')) return false;
    if (lower.contains('duty')) return false;
    return lower.contains('one-way') ||
        lower.contains('oneway') ||
        lower.contains('one way') ||
        lower.contains('taxi') ||
        lower.contains('local');
  }

  String _formatDistance(dynamic dist) {
    if (dist == null) return '';
    double? d = double.tryParse(dist.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
    if (d == null || d <= 0) return '';
    if (d == d.toInt()) {
      return '${d.toInt()}';
    }
    return d.toStringAsFixed(1);
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
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: primaryAmber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(
                            (booking['trip_type'] ?? '') == 'Local-Duty' || (booking['trip_type'] ?? '') == 'Local-duty'
                                ? 'Hourly Rental'
                                : (booking['trip_type'] ?? 'One-Way'),
                            style: TextStyle(
                                color: primaryAmber,
                                fontWeight: FontWeight.bold,
                                fontSize: 11)),
                      ),
                      if (_isOneWayOrLocalTaxi(booking['trip_type']) &&
                          _formatDistance(booking['distance']).isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFFBFDBFE), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.route_rounded,
                                  size: 13, color: Color(0xFF2563EB)),
                              const SizedBox(width: 4),
                              Text(
                                "${_formatDistance(booking['distance'])} km",
                                style: const TextStyle(
                                  color: Color(0xFF1E40AF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (booking['date'] != null &&
                          booking['date'].toString().isNotEmpty) ...[
                        _buildDateChip(booking['date'].toString(),
                            booking['time']?.toString()),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
                _carLabel(
                  booking['car_type'],
                  _isOneWayOrLocalTaxi(booking['trip_type'])
                      ? _formatDistance(booking['distance'])
                      : null,
                ),
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
                    Text(
                      () {
                        double vAmt = double.tryParse(booking['vendor_amount']?.toString() ?? '') ?? 0.0;
                        if (vAmt > 0) {
                          return "₹${vAmt.toStringAsFixed(0)}";
                        }
                        double tAmt = double.tryParse(booking['total_amount']?.toString() ?? '') ?? 0.0;
                        double agentComm = double.tryParse(booking['agent_commission']?.toString() ?? '0') ?? 0.0;
                        double cleanBase = (agentComm > 0 && tAmt > agentComm) ? (tAmt - agentComm) : tAmt;
                        if (cleanBase > 0) {
                          return "₹${(cleanBase * 0.90).toStringAsFixed(0)}";
                        }
                        return "₹${booking['vendor_amount'] ?? '0'}";
                      }(),
                      style: TextStyle(
                          color: darkCharcoal,
                          fontWeight: FontWeight.bold,
                          fontSize: 20),
                    ),
                  ])
                else
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Rate / KM",
                        style: TextStyle(color: Colors.grey, fontSize: 11)),
                    Text(
                      () {
                        double kmR = double.tryParse(booking['kmRate']?.toString() ?? '') ?? 0.0;
                        if (kmR > 0) {
                          return "₹${kmR.toStringAsFixed(0)}/km";
                        }
                        return "₹10/km";
                      }(),
                      style: TextStyle(
                          color: darkCharcoal,
                          fontWeight: FontWeight.bold,
                          fontSize: 19),
                    ),
                  ]),
                ElevatedButton(
                  onPressed: () {
                    String tType = (booking['trip_type'] ?? '').toString();
                    bool isRoundTrip = tType.toLowerCase().contains('round');
                    bool isLocalOrOneWay = tType.toLowerCase().contains('taxi') ||
                        tType.toLowerCase().contains('local') ||
                        tType.toLowerCase().contains('one-way') ||
                        tType.toLowerCase().contains('one way');
                    if (isRoundTrip && !_isEligibleForRoundTrip) {
                      _showLowWalletBalanceDialog(
                          "Insufficient wallet balance (₹${_walletBalance.toStringAsFixed(2)}). Minimum balance of ₹${_minWalletBalanceRoundTrip.toStringAsFixed(0)} is required to accept Round-Trip trips. Please recharge your wallet.");
                      return;
                    }
                    if (isLocalOrOneWay && !_isEligibleForLocalTaxi) {
                      _showLowWalletBalanceDialog(
                          "Insufficient wallet balance (₹${_walletBalance.toStringAsFixed(2)}). Minimum balance of ₹${_minWalletBalance.toStringAsFixed(0)} is required to accept trips. Please recharge your wallet.");
                      return;
                    }
                    _navigateTo(CarDriverSelectionScreen(
                        bookingId: booking['booking_id'].toString(),
                        bookingData: booking));
                  },
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
                  builder: (c) => VendorWalletPage(vendorPhone: widget.phoneNumber),
                ),
              ).then((_) => fetchBookings());
            },
            icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
            label: const Text("Recharge Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _carLabel(String? type, [String? distanceKm]) {
    return Column(children: [
      Image.asset('assets/sadan-1.webp',
          height: 40,
          errorBuilder: (_, __, ___) => const Icon(Icons.directions_car)),
      Text(type ?? "Sedan",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
      if (distanceKm != null && distanceKm.isNotEmpty) ...[
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
          ),
          child: Text(
            "$distanceKm km",
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 10,
              color: Color(0xFF1D4ED8),
            ),
          ),
        ),
      ],
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
              () => _navigateTo(VendorWalletPage(vendorPhone: widget.phoneNumber))),
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

  Widget _buildDateChip(String dateStr, String? timeStr) {
    final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final bool isToday = (dateStr.trim() == todayStr);

    String formattedTime = '';
    if (timeStr != null && timeStr.trim().isNotEmpty) {
      try {
        final parts = timeStr.trim().split(':');
        if (parts.length >= 2) {
          int hour = int.parse(parts[0]);
          int min = int.parse(parts[1]);
          final period = hour >= 12 ? 'PM' : 'AM';
          if (hour > 12) hour -= 12;
          if (hour == 0) hour = 12;
          formattedTime = " • $hour:${min.toString().padLeft(2, '0')} $period";
        }
      } catch (_) {}
    }

    String displayDate = dateStr;
    try {
      final parsed = DateTime.parse(dateStr);
      displayDate = DateFormat('dd MMM').format(parsed);
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isToday ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isToday ? const Color(0xFFBFDBFE) : const Color(0xFFA7F3D0),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isToday ? Icons.bolt_rounded : Icons.event_available_rounded,
            size: 13,
            color: isToday ? const Color(0xFF2563EB) : const Color(0xFF059669),
          ),
          const SizedBox(width: 4),
          Text(
            isToday ? "Today$formattedTime" : "$displayDate$formattedTime",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isToday ? const Color(0xFF1E40AF) : const Color(0xFF065F46),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketHeader() {
    final int activeCount = _activeFilterCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    "Marketplace Feed",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryAmber.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${bookings.length}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: darkCharcoal,
                      ),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _showFilterBottomSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: activeCount > 0 ? primaryAmber : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: activeCount > 0 ? primaryAmber : Colors.grey[300]!,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 15,
                        color: activeCount > 0 ? Colors.white : darkCharcoal,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        activeCount > 0 ? "Filter ($activeCount)" : "Filter",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: activeCount > 0 ? Colors.white : darkCharcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildQuickFilterChips(),
        ],
      ),
    );
  }

  Widget _buildQuickFilterChips() {
    final chips = [
      {'key': 'All', 'label': 'All Trips', 'icon': Icons.apps_rounded},
      {'key': 'Today', 'label': 'Today', 'icon': Icons.bolt_rounded},
      {'key': 'Advance', 'label': 'Advance', 'icon': Icons.calendar_month_rounded},
      {'key': 'Local-taxi', 'label': 'Local Taxi', 'icon': Icons.local_taxi_rounded},
      {'key': 'One-way', 'label': 'One-Way', 'icon': Icons.arrow_right_alt_rounded},
      {'key': 'Round-Trip', 'label': 'Round-Trip', 'icon': Icons.sync_alt_rounded},
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = chips[index];
          final String key = item['key'] as String;
          final String label = item['label'] as String;
          final IconData icon = item['icon'] as IconData;
          final bool isSelected = (selectedQuickFilter == key);
          final int count = _countForQuickFilter(key);

          return InkWell(
            onTap: () {
              setState(() {
                selectedQuickFilter = (isSelected && key != 'All') ? 'All' : key;
                bookings = _applyFilters(allBookings);
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? darkCharcoal : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? darkCharcoal : Colors.grey[300]!,
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isSelected ? primaryAmber : Colors.grey[700],
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : darkCharcoal,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryAmber : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "$count",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? darkCharcoal : Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFilterBottomSheet() {
    String tempDateFilter = selectedDateFilter;
    DateTime? tempCustomDate = customFilterDate;
    String tempTripType = selectedTripTypeFilter;
    String tempCarType = selectedCarTypeFilter;
    String tempSort = selectedSortFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Filter & Sort Rides",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                              ),
                            ),
                            if (_activeFilterCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: primaryAmber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "$_activeFilterCount Active",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: darkCharcoal,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempDateFilter = 'All';
                              tempCustomDate = null;
                              tempTripType = 'All';
                              tempCarType = 'All';
                              tempSort = 'Default';
                            });
                            _resetAllFilters();
                          },
                          child: const Text(
                            "Reset All",
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // SECTION 1: DATE SCHEDULE
                        _buildFilterSectionTitle("Date Schedule"),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChoiceChip(
                              label: "All Dates",
                              isSelected: tempDateFilter == 'All',
                              onTap: () => setModalState(() {
                                tempDateFilter = 'All';
                                tempCustomDate = null;
                              }),
                            ),
                            _buildChoiceChip(
                              label: "⚡ Today's Rides",
                              isSelected: tempDateFilter == 'Today',
                              onTap: () => setModalState(() {
                                tempDateFilter = 'Today';
                                tempCustomDate = null;
                              }),
                            ),
                            _buildChoiceChip(
                              label: "📅 Advance Bookings",
                              isSelected: tempDateFilter == 'Advance',
                              onTap: () => setModalState(() {
                                tempDateFilter = 'Advance';
                                tempCustomDate = null;
                              }),
                            ),
                            _buildChoiceChip(
                              label: tempCustomDate != null
                                  ? "📆 ${DateFormat('dd MMM').format(tempCustomDate!)}"
                                  : "📆 Pick Specific Date",
                              isSelected: tempDateFilter == 'Custom',
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: tempCustomDate ?? DateTime.now(),
                                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                  lastDate: DateTime.now().add(const Duration(days: 90)),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    tempDateFilter = 'Custom';
                                    tempCustomDate = picked;
                                  });
                                }
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // SECTION 2: TRIP CATEGORY
                        _buildFilterSectionTitle("Trip Category"),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChoiceChip(
                              label: "All Categories",
                              isSelected: tempTripType == 'All',
                              onTap: () => setModalState(() => tempTripType = 'All'),
                            ),
                            _buildChoiceChip(
                              label: "🚕 Local Taxi",
                              isSelected: tempTripType == 'Local-taxi',
                              onTap: () => setModalState(() => tempTripType = 'Local-taxi'),
                            ),
                            _buildChoiceChip(
                              label: "🛣️ One-Way",
                              isSelected: tempTripType == 'One-way',
                              onTap: () => setModalState(() => tempTripType = 'One-way'),
                            ),
                            _buildChoiceChip(
                              label: "🔄 Round-Trip",
                              isSelected: tempTripType == 'Round-Trip',
                              onTap: () => setModalState(() => tempTripType = 'Round-Trip'),
                            ),
                            _buildChoiceChip(
                              label: "⏱️ Hourly Rental",
                              isSelected: tempTripType == 'Local-duty',
                              onTap: () => setModalState(() => tempTripType = 'Local-duty'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // SECTION 3: CAR CATEGORY
                        _buildFilterSectionTitle("Car / Vehicle Type"),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChoiceChip(
                              label: "All Vehicles",
                              isSelected: tempCarType == 'All',
                              onTap: () => setModalState(() => tempCarType = 'All'),
                            ),
                            _buildChoiceChip(
                              label: "Sedan",
                              isSelected: tempCarType == 'Sedan',
                              onTap: () => setModalState(() => tempCarType = 'Sedan'),
                            ),
                            _buildChoiceChip(
                              label: "SUV",
                              isSelected: tempCarType == 'SUV',
                              onTap: () => setModalState(() => tempCarType = 'SUV'),
                            ),
                            _buildChoiceChip(
                              label: "Hatchback",
                              isSelected: tempCarType == 'Hatchback',
                              onTap: () => setModalState(() => tempCarType = 'Hatchback'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // SECTION 4: SORTING
                        _buildFilterSectionTitle("Sort Trips By"),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChoiceChip(
                              label: "Default",
                              isSelected: tempSort == 'Default',
                              onTap: () => setModalState(() => tempSort = 'Default'),
                            ),
                            _buildChoiceChip(
                              label: "💰 Highest Earnings",
                              isSelected: tempSort == 'PriceHighToLow',
                              onTap: () => setModalState(() => tempSort = 'PriceHighToLow'),
                            ),
                            _buildChoiceChip(
                              label: "📍 Nearest Distance",
                              isSelected: tempSort == 'DistanceNearest',
                              onTap: () => setModalState(() => tempSort = 'DistanceNearest'),
                            ),
                            _buildChoiceChip(
                              label: "⏰ Earliest Pickup",
                              isSelected: tempSort == 'PickupTime',
                              onTap: () => setModalState(() => tempSort = 'PickupTime'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          offset: const Offset(0, -4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  selectedDateFilter = tempDateFilter;
                                  customFilterDate = tempCustomDate;
                                  selectedTripTypeFilter = tempTripType;
                                  selectedCarTypeFilter = tempCarType;
                                  selectedSortFilter = tempSort;
                                  bookings = _applyFilters(allBookings);
                                });
                                Navigator.pop(ctx);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryAmber,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "Apply Filters",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFF111827),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? darkCharcoal : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? darkCharcoal : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
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

// ================= RADAR SCAN INDICATOR =================

class RadarScanWidget extends StatefulWidget {
  final bool isOnline;
  final Color activeColor;
  final Color inactiveColor;

  const RadarScanWidget({
    super.key,
    required this.isOnline,
    this.activeColor = const Color(0xFF10B981),
    this.inactiveColor = const Color(0xFF6B7280),
  });

  @override
  State<RadarScanWidget> createState() => _RadarScanWidgetState();
}

class _RadarScanWidgetState extends State<RadarScanWidget>
    with TickerProviderStateMixin {
  late AnimationController _sweepController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    if (widget.isOnline) {
      _sweepController.repeat();
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(RadarScanWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline) {
      if (!_sweepController.isAnimating) _sweepController.repeat();
      if (!_pulseController.isAnimating) _pulseController.repeat();
    } else {
      _sweepController.stop();
      _pulseController.stop();
      _sweepController.reset();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOnline) {
      return Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.inactiveColor,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Expanding radar pulse wave
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final double t = _pulseController.value;
              return Container(
                width: 14 + (t * 10),
                height: 14 + (t * 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.activeColor.withValues(alpha: (1.0 - t) * 0.7),
                    width: 1.5,
                  ),
                ),
              );
            },
          ),
          // 2. Rotating Radar Sweep Scope
          AnimatedBuilder(
            animation: _sweepController,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(20, 20),
                painter: RadarScanPainter(
                  angle: _sweepController.value * 2 * pi,
                  scanColor: widget.activeColor,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class RadarScanPainter extends CustomPainter {
  final double angle;
  final Color scanColor;

  RadarScanPainter({
    required this.angle,
    required this.scanColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Radar Scope Base (dark emerald tint)
    final bgPaint = Paint()
      ..color = scanColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 2. Concentric Radar Grid Rings
    final ringPaint = Paint()
      ..color = scanColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(center, radius * 0.55, ringPaint);

    // 3. Radar Crosshairs
    final crosshairPaint = Paint()
      ..color = scanColor.withValues(alpha: 0.25)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), crosshairPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), crosshairPaint);

    // 4. Rotating Sweep Beam with 90-degree gradient fan
    final sweepRect = Rect.fromCircle(center: center, radius: radius);
    final sweepGradient = SweepGradient(
      startAngle: 0.0,
      endAngle: pi / 2,
      colors: [
        scanColor.withValues(alpha: 0.0),
        scanColor.withValues(alpha: 0.55),
      ],
      transform: GradientRotation(angle - (pi / 2)),
    );

    final sweepPaint = Paint()
      ..shader = sweepGradient.createShader(sweepRect)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, sweepPaint);

    // 5. Leading Sweep Beam Needle (Bright scanning line)
    final needlePaint = Paint()
      ..color = scanColor
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final endX = center.dx + radius * cos(angle);
    final endY = center.dy + radius * sin(angle);
    canvas.drawLine(center, Offset(endX, endY), needlePaint);

    // 6. Glowing Center Beacon Core
    final corePaint = Paint()
      ..color = scanColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.5, corePaint);

    final glowPaint = Paint()
      ..color = scanColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4.0, glowPaint);
  }

  @override
  bool shouldRepaint(covariant RadarScanPainter oldDelegate) {
    return oldDelegate.angle != angle;
  }
}
