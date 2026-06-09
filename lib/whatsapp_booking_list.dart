import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:agnidriver2025/whatsApp_booking_recharge.dart';
import "package:agnidriver2025/trip_create.dart";
import 'api_config.dart';

class NearbyTripsPage extends StatefulWidget {
  const NearbyTripsPage({super.key});

  @override
  State<NearbyTripsPage> createState() => _NearbyTripsPageState();
}

class _NearbyTripsPageState extends State<NearbyTripsPage> {
  Position? _currentPosition;
  List<Map<String, dynamic>> _trips = [];
  List<Map<String, dynamic>> _allTrips = [];
  bool _loading = true;
  bool _showBubble = false;
  bool _callButton = true;
  bool showAd = true; // 👈 controls ad visibility

  final secureStorage = const FlutterSecureStorage();

  Set<int> _calledTrips = {};
  final Set<int> _loadingTrips = {};

  bool _showAlert = false;
  List<Map<String, dynamic>> _alerts = [];
  bool _alertLoading = false;

  int _alertCount = 0;

  String _searchText = "";

  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _call_on_off().then((_) {
      _fetchTrips();
      _loadCalledTrips();
      _callDriverAlertUpdateOnInit();
      _fetchAlertsCount();
    });
  }

  Future<void> _call_on_off() async {
    String? phoneNumber = await secureStorage.read(key: "phone_number");
    try {
      final res = await http.get(Uri.parse(
          "${ApiConfig.driverWhatsappCallOnOff}?phone_number=$phoneNumber"));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is Map && data['success'] == true && data['data'] != null) {
          if (data['data']['driver_WhatsAppCall_OnOfff'] == "On") {
            final successMsg = await http.get(Uri.parse(
                "${ApiConfig.balanceCheck}?sender_Id=$phoneNumber"));
            if (successMsg.statusCode == 200 &&
                successMsg.body.contains("true")) {
              setState(() => _callButton = true);
            } else {
              setState(() => _callButton = false);
            }
          } else {
            setState(() => _callButton = false);
          }
        }
      }
    } catch (e) {
      print("Exception: $e");
    }
  }

  void _sendMessage() {
    String text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Navigate to the new page and pass the message
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessagePage(message: text),
      ),
    );

    _messageController.clear(); // clear input after sending
  }

  Future<void> _callDriverAlertUpdateOnInit() async {
    String? phoneNumber = await secureStorage.read(key: "phone_number");
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(
          "${ApiConfig.driverAlertMessageUpdate}?phone_number=$phoneNumber",
        ));
        print(res.body);
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data is Map && data['success'] == false) {
            setState(() => _showBubble = false);
          } else {
            setState(() => _showBubble = true);
          }
        }
      } catch (_) {
        setState(() {
          _alertCount = 0;
        });
      }
    } else {
      setState(() {
        _alertCount = 0;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _fetchTrips({String? city}) async {
    try {
      // 1️⃣ Get current location if needed
      if (_currentPosition == null) await _getCurrentLocation();

      // 2️⃣ Build API URL
      String url =
          ApiConfig.whatsappTrips;

      if (_searchText.isNotEmpty && city != null) {
        // Search trips by city
        url += "?city=${Uri.encodeComponent(city)}";
      } else if (_currentPosition != null) {
        // Nearby trips using lat/lng
        url +=
            "?lat=${_currentPosition!.latitude}&lng=${_currentPosition!.longitude}";
      }

      final response = await http.get(Uri.parse(url));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        List<dynamic> trips = jsonResponse['data'];

        // 3️⃣ Fill actualCity for all trips (reverse geocode if city is empty)
        List<Map<String, dynamic>> tripsWithCity = await Future.wait(
          trips.map((trip) async {
            String cityName = trip['city'] ?? '';

            // Use reverse geocoding if city is empty and lat/lng exists
            if (cityName.isEmpty &&
                trip['latitude'] != null &&
                trip['longitude'] != null) {
              try {
                List<Placemark> placemarks = await placemarkFromCoordinates(
                  double.parse(trip['latitude'].toString()),
                  double.parse(trip['longitude'].toString()),
                );
                if (placemarks.isNotEmpty) {
                  cityName = placemarks.first.locality ?? 'Unknown';
                }
              } catch (_) {
                cityName = 'Unknown';
              }
            }

            return {
              ...trip,
              'actualCity': cityName.isNotEmpty ? cityName : 'Unknown',
            };
          }),
        );

        // 4️⃣ Update state
        setState(() {
          _allTrips = tripsWithCity;

          if (_searchText.isNotEmpty && city != null) {
            // Filter trips by search city
            _trips = tripsWithCity
                .where((t) => t['actualCity']
                    .toString()
                    .toLowerCase()
                    .contains(city.toLowerCase()))
                .toList();
          } else if (_currentPosition != null) {
            // Nearby trips for initial load
            _trips = tripsWithCity;
          } else {
            // Fallback
            _trips = tripsWithCity;
          }

          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        print("API error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching trips: $e");
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

// Search handler
  void _onSearchChanged(String searchText) {
    setState(() {
      _searchText = searchText.trim();
      _loading = true;
    });

    if (_searchText.isEmpty) {
      // Fetch nearby trips
      _fetchTrips();
    } else {
      // Search trips by city
      _fetchTrips(city: _searchText);
    }
  }

// Search handler

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    double dLat = _deg2rad(lat2 - lat1);
    double dLon = _deg2rad(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  Future<void> _loadCalledTrips() async {
    String? userMobile = await secureStorage.read(key: "phone_number");
    if (userMobile == null) return;

    try {
      final res = await http.get(Uri.parse(
          "${ApiConfig.whatsappMsgClickCounter}?driver_id=$userMobile"));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          final List records = data['data'];

          final clickedTripIds = records
              .where((rec) => rec['driver_id'].toString() == userMobile)
              .map<int>((rec) => int.parse(rec['whatsapp_msg_id'].toString()))
              .toSet();

          setState(() {
            _calledTrips = clickedTripIds;
          });
        }
      }
    } catch (e) {
      print("Error loading called trips: $e");
    }
  }

  Future<void> _handleCall(Map<String, dynamic> trip) async {
    final driverNumber = trip['mobile_number'].toString();

    try {
      String? userMobile = await secureStorage.read(key: "phone_number");
      if (userMobile != null) {
        final res = await http.post(
          Uri.parse(
              ApiConfig.whatsappMsgClickCounter),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "whatsapp_msg_id": trip['id'],
            "driver_id": userMobile,
          }),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['success'] == true) {
            await http.post(
              Uri.parse(
                  "${ApiConfig.whatsappTrips}?action=increment_click"),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({"trip_id": trip['id']}),
            );
          }
        }

        final verifyRes = await http.get(Uri.parse(
            "${ApiConfig.whatsappMsgClickCounter}?driver_id=$userMobile"));
        if (verifyRes.statusCode == 200) {
          final data = jsonDecode(verifyRes.body);

          if (data['success'] == true && data['data'] != null) {
            final List records = data['data'];

            final clickedTripIds = records
                .where((rec) => rec['driver_id'].toString() == userMobile)
                .map<int>((rec) => int.parse(rec['whatsapp_msg_id'].toString()))
                .toSet();

            setState(() {
              _calledTrips.addAll(clickedTripIds);
            });
          }
        }
      }

      final Uri launchUri = Uri(scheme: 'tel', path: driverNumber);
      await launchUrl(launchUri);
    } catch (e) {
      print("Error on call: $e");
    }
  }

  Future<void> _fetchAlerts() async {
    setState(() {
      _alertLoading = true;
      _showAlert = true;
    });
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.alertMessage),
      );
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          setState(() {
            _alerts = List<Map<String, dynamic>>.from(jsonResponse['data']);
          });
        }
      }
    } catch (e) {}
    setState(() {
      _alertLoading = false;
    });
  }

  Future<void> _fetchAlertsCount() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.alertMessage),
      );
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          setState(() {
            _alertCount = (jsonResponse['data'] as List).length;
          });
        } else {
          setState(() {
            _alertCount = 0;
          });
        }
      }
    } catch (e) {
      setState(() {
        _alertCount = 0;
      });
    }
  }

  void _closeAlert() {
    setState(() {
      _showAlert = false;
    });
    _fetchAlertsCount();
  }

  @override
  Widget build(BuildContext context) {
    // Filtered trips based on search
    final filteredTrips = _searchText.isEmpty
        ? _trips
        : _allTrips.where((trip) {
            final msg = (trip['trip_message'] ?? '').toString().toLowerCase();
            final city = (trip['actualCity'] ?? '').toString().toLowerCase();
            return msg.contains(_searchText.toLowerCase()) ||
                city.contains(_searchText.toLowerCase());
          }).toList();

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text(
              "WhatsApp",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: const Color(0xFF3CAF49),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.message, color: Colors.white),
                    onPressed: () async {
                      setState(() {
                        _showAlert = true;
                        _alertLoading = true;
                        _showBubble = false;
                      });
                      await _fetchAlerts();
                    },
                  ),
                  if (_showBubble)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/chat_bg.webp"),
                fit: BoxFit.cover,
              ),
            ),
            child: Column(
              children: [
                // 🔍 Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search by city",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),

                // 🔽 Trip list (or loader / no trips)
                Expanded(
                  child: _loading
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Loader Card
                            Card(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              color: Colors.white.withOpacity(0.9),
                              elevation: 6,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(
                                        color: Colors.blue),
                                    const SizedBox(height: 20),
                                    const Text(
                                      "Please wait Trip is loading...",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Ad Card (only shows if showAd is true)
                            if (showAd)
                              Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                      ),
                                      child: Container(
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.2, // 30% of screen height
                                        child: Image.network(
                                          ApiConfig.trakonPng,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          const Text("Start your decision"),
                                          InkWell(
                                            onTap: () async {
                                              const phoneNumber =
                                                  "tel:+12345678";
                                              final uri =
                                                  Uri.parse(phoneNumber);
                                              if (await canLaunchUrl(uri)) {
                                                await launchUrl(uri);
                                              }
                                            },
                                            child: Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color.fromARGB(
                                                    255, 44, 174, 21),
                                                borderRadius: BorderRadius.all(
                                                    Radius.circular(20)),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                      horizontal: 16),
                                              child: const Row(
                                                children: [
                                                  // Text("Call"),
                                                  Icon(Icons.call,
                                                      color: Color.fromARGB(
                                                          255, 255, 255, 255),
                                                      size: 16)
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                          ],
                        )
                      : filteredTrips.isEmpty
                          ? const Center(
                              child: Text(
                                "No trips found",
                                style: TextStyle(color: Colors.black87),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              reverse: true,
                              itemCount: filteredTrips.length +
                                  (filteredTrips.length ~/ 10),
                              itemBuilder: (context, index) {
                                // Show ad every 10 trips
                                if ((index + 1) % 11 == 0) {
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 3,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () async {
                                        const url =
                                            'https://oluber.com'; // Replace with your URL
                                        if (await canLaunchUrl(
                                            Uri.parse(url))) {
                                          await launchUrl(Uri.parse(url),
                                              mode: LaunchMode
                                                  .externalApplication);
                                        } else {
                                          // handle error if URL can't be opened
                                          print('Could not launch $url');
                                        }
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          height: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.20, // 30% of screen height
                                          child: Image.network(
                                            ApiConfig.trakonPng,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                // Calculate correct trip index
                                final tripIndex = index - (index ~/ 11);
                                if (tripIndex >= filteredTrips.length) {
                                  return const SizedBox.shrink();
                                }

                                final trip = filteredTrips[tripIndex];
                                bool isCalled = _calledTrips.contains(
                                  int.parse(trip['id'].toString()),
                                );

                                // Trip card UI
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: isCalled
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                    children: [
                                      if (!isCalled)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 6),
                                          child: CircleAvatar(
                                            radius: 14,
                                            backgroundColor:
                                                const Color(0xFFEC3635),
                                            child: Text(
                                              ((trip['actualCity'] ?? 'U')
                                                      .toString()
                                                      .trim()
                                                      .isNotEmpty)
                                                  ? trip['actualCity']
                                                      .toString()
                                                      .trim()[0]
                                                      .toUpperCase()
                                                  : 'U',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      Flexible(
                                        child: Container(
                                          constraints: BoxConstraints(
                                              maxWidth: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.75),
                                          decoration: BoxDecoration(
                                            color: isCalled
                                                ? const Color(0xFFDCF8C6)
                                                : const Color(0xFFFFFDE7),
                                            borderRadius: BorderRadius.only(
                                              topLeft:
                                                  const Radius.circular(12),
                                              topRight:
                                                  const Radius.circular(12),
                                              bottomLeft: isCalled
                                                  ? const Radius.circular(12)
                                                  : Radius.zero,
                                              bottomRight: isCalled
                                                  ? Radius.zero
                                                  : const Radius.circular(12),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey
                                                    .withOpacity(0.2),
                                                blurRadius: 2,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          padding: const EdgeInsets.all(10),
                                          child: Column(
                                            crossAxisAlignment: isCalled
                                                ? CrossAxisAlignment.end
                                                : CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      (trip['actualCity'] ??
                                                              'Unknown')
                                                          .toString()
                                                          .toUpperCase(),
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    trip['created_at'] ?? '',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                trip['trip_message'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                  height: 1.4,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(
                                                  trip['time'] ?? '',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical:
                                                                        6),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: const Color(
                                                                  0xFF3CAF49),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          20),
                                                            ),
                                                            child: Text(
                                                              "Total Driver Clicked: ${trip['drivers_click_counter']}",
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style:
                                                                  const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        ElevatedButton(
                                                          onPressed: () async {
                                                            if (_callButton) {
                                                              setState(() {
                                                                _loadingTrips
                                                                    .add(
                                                                  int.parse(trip[
                                                                          'id']
                                                                      .toString()),
                                                                );
                                                              });

                                                              await _handleCall(
                                                                  trip);

                                                              Future.delayed(
                                                                const Duration(
                                                                    milliseconds:
                                                                        1500),
                                                                () {
                                                                  setState(() {
                                                                    _loadingTrips
                                                                        .remove(
                                                                      int.parse(
                                                                          trip['id']
                                                                              .toString()),
                                                                    );
                                                                  });
                                                                },
                                                              );
                                                            } else {
                                                              // your recharge popup logic here
                                                            }
                                                          },
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                            backgroundColor:
                                                                const Color(
                                                                    0xFFEC3635),
                                                            shape:
                                                                const CircleBorder(),
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(10),
                                                            elevation: 0,
                                                          ),
                                                          child: _loadingTrips.contains(
                                                                  int.parse(trip[
                                                                          'id']
                                                                      .toString()))
                                                              ? const SizedBox(
                                                                  width: 16,
                                                                  height: 16,
                                                                  child:
                                                                      CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                    valueColor: AlwaysStoppedAnimation<
                                                                            Color>(
                                                                        Colors
                                                                            .white),
                                                                  ),
                                                                )
                                                              : const Icon(
                                                                  Icons.phone,
                                                                  size: 18,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isCalled)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 6),
                                          child: CircleAvatar(
                                            radius: 14,
                                            backgroundColor:
                                                const Color(0xFFEC3635),
                                            child: Text(
                                              (trip['actualCity'] ?? 'U')
                                                  .toString()
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),

                if (!_loading) // 🔽 WhatsApp-style Input field at bottom
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              keyboardType: TextInputType.multiline,
                              maxLines: null,
                              minLines: 1,
                              decoration: InputDecoration(
                                hintText: "Type a message",
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.green,
                            child: IconButton(
                              icon: const Icon(Icons.send, color: Colors.white),
                              onPressed: _sendMessage,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
              ],
            ),
          ),
        ),
        if (_showAlert)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.yellow[100],
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _alertLoading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: Colors.amber, size: 28),
                                const SizedBox(width: 8),
                                const Text(
                                  "Alert",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.amber,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.black54),
                                  onPressed: _closeAlert,
                                ),
                              ],
                            ),
                            const Divider(),
                            ..._alerts.isEmpty
                                ? [
                                    const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        "No instructions available.",
                                        style: TextStyle(
                                            color: Colors.black54,
                                            fontSize: 15),
                                      ),
                                    )
                                  ]
                                : _alerts
                                    .map(
                                      (alert) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6.0),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.circle,
                                                size: 10, color: Colors.amber),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                alert['message'] ?? '',
                                                style: const TextStyle(
                                                    fontSize: 15,
                                                    color: Colors.black87),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ],
                        ),
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 70,
          right: 10,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _loading = true;
                _trips.clear();
              });
              _fetchTrips();
              _loadCalledTrips();
              _fetchAlertsCount();
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF3CAF49), // WhatsApp green
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 28),
            ),
          ),
        ),
      ],
    );
  }
}
