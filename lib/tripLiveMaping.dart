import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // Essential for flutter_map
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:location/location.dart' as loc;

import 'endingKmInputPage.dart';
import 'api_config.dart';


class TripLiveMapping extends StatefulWidget {
  final String bookingId;
  final String phoneNumber;

  const TripLiveMapping({
    super.key,
    required this.bookingId,
    required this.phoneNumber,
  });

  @override
  State<TripLiveMapping> createState() => _TripLiveMappingState();
}

class _TripLiveMappingState extends State<TripLiveMapping> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  final loc.Location location = loc.Location();
  final MapController _mapController = MapController();

  LatLng? fromLatLng;
  LatLng? toLatLng;
  LatLng? driverLatLng;

  List<LatLng> routePoints = [];
  bool isLoading = true;
  bool followDriver = true;
  double driverSpeed = 0.0;

  String fromAddress = "Loading...";
  String toAddress = "Loading...";

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _checkLocationPermission();
    await _loadRouteAndDriver();
    await _startLiveLocationUpdate();
  }

  Future<void> _checkLocationPermission() async {
    try {
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          debugPrint("Location services are disabled.");
          return;
        }
      }

      loc.PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) {
          debugPrint("Location permission denied.");
          return;
        }
      }
    } catch (e) {
      debugPrint("Location permission check error: $e");
    }
  }

  // Same logic as your provided code
  Future<void> _loadRouteAndDriver() async {
    try {
      final bookingRes = await http.post(
        Uri.parse(ApiConfig.tripLiveMappingBackend),
        body: {'action': 'get_booking_details', 'booking_id': widget.bookingId},
      );

      final bookingData = json.decode(bookingRes.body);
      if (!bookingData['success']) throw Exception("Booking fetch failed");

      fromAddress = bookingData['from_address'];
      toAddress = bookingData['to_address'];

      final fromLocs = await locationFromAddress(fromAddress);
      final toLocs = await locationFromAddress(toAddress);

      fromLatLng = LatLng(fromLocs[0].latitude, fromLocs[0].longitude);
      toLatLng = LatLng(toLocs[0].latitude, toLocs[0].longitude);

      final driverRes = await http.post(
        Uri.parse(ApiConfig.tripLiveMappingBackend),
        body: {
          'action': 'get_driver_location',
          'phone_number': widget.phoneNumber
        },
      );

      final driverData = json.decode(driverRes.body);
      driverLatLng = LatLng(driverData['latitude'], driverData['longitude']);

      await _fetchRouteOSRM(fromLatLng!, toLatLng!);

      setState(() => isLoading = false);
      _mapController.move(driverLatLng!, 15);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _fetchRouteOSRM(LatLng from, LatLng to) async {
    final url = Uri.parse(
        "http://router.project-osrm.org/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=geojson");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
      setState(() {
        routePoints =
            coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
      });
    }
  }

  Future<void> _startLiveLocationUpdate() async {
    try {
      loc.PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted != loc.PermissionStatus.granted) {
        debugPrint("Cannot start location updates: permission not granted.");
        return;
      }

      location.changeSettings(
          interval: 8000, accuracy: loc.LocationAccuracy.high);
      location.onLocationChanged.listen((loc.LocationData currentLocation) async {
        if (currentLocation.latitude != null &&
            currentLocation.longitude != null) {
          setState(() {
            driverSpeed = currentLocation.speed ?? 0.0;
            driverLatLng =
                LatLng(currentLocation.latitude!, currentLocation.longitude!);
          });

          if (followDriver)
            _mapController.move(driverLatLng!, _mapController.camera.zoom);

          await http.post(
            Uri.parse(ApiConfig.updateLocation),

            body: {
              'driver_id': widget.phoneNumber,
              'latitude': currentLocation.latitude.toString(),
              'longitude': currentLocation.longitude.toString(),
            },
          );
        }
      });
    } catch (e) {
      debugPrint("Live location update error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(color: Colors.amber.shade600))
          : Stack(
              children: [
                // 1. MAP
                FlutterMap(
                  mapController: _mapController,
                  options:
                      MapOptions(initialCenter: driverLatLng!, initialZoom: 15),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png", // Professional "Light" map style
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          strokeWidth: 5,
                          color: Colors.amber.withOpacity(0.7),
                        )
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        _buildMarker(
                            fromLatLng!, Icons.circle, Colors.green, 12),
                        _buildMarker(
                            toLatLng!, Icons.location_on, Colors.redAccent, 35),
                        Marker(
                          point: driverLatLng!,
                          width: 60,
                          height: 60,
                          child: _buildDriverMarker(),
                        ),
                      ],
                    ),
                  ],
                ),

                // 2. TOP BAR (Booking ID & Speed)
                Positioned(
                  top: 50,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeaderChip("ID: #${widget.bookingId}"),
                      _buildSpeedometer(),
                    ],
                  ),
                ),

                // 3. FLOATING CONTROLS
                // Positioned(
                //   right: 20,
                //   bottom: 320,
                //   child: Column(
                //     children: [
                //       _buildMapActionBtn(
                //         icon: followDriver
                //             ? Icons.gps_fixed
                //             : Icons.gps_not_fixed,
                //         onTap: () =>
                //             setState(() => followDriver = !followDriver),
                //       ),
                //       const SizedBox(height: 10),
                //       _buildMapActionBtn(
                //         icon: Icons.my_location,
                //         onTap: () => _mapController.move(driverLatLng!, 16),
                //       ),
                //     ],
                //   ),
                // ),

                // 4. MODERN TRIP CARD
                _buildTripDetailCard(),
              ],
            ),
    );
  }

  // ================= UI HELPER WIDGETS =================

  Marker _buildMarker(LatLng point, IconData icon, Color color, double size) {
    return Marker(
      point: point,
      width: 40,
      height: 40,
      child: Icon(icon, color: color, size: size),
    );
  }

  Widget _buildDriverMarker() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(8),
      child: const Icon(Icons.navigation, color: Colors.black, size: 30),
    );
  }

  Widget _buildHeaderChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSpeedometer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        "${(driverSpeed * 3.6).toStringAsFixed(0)} km/h",
        style:
            const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMapActionBtn(
      {required IconData icon, required VoidCallback onTap}) {
    return FloatingActionButton.small(
      heroTag: null,
      backgroundColor: Colors.white,
      onPressed: onTap,
      child: Icon(icon, color: Colors.black87),
    );
  }

  Widget _buildTripDetailCard() {
    return Positioned(
      bottom: 20,
      left: 15,
      right: 15,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timeline view for addresses
            Row(
              children: [
                Column(
                  children: [
                    const Icon(Icons.radio_button_checked,
                        color: Colors.green, size: 18),
                    Container(
                        width: 2, height: 30, color: Colors.grey.shade300),
                    const Icon(Icons.location_on,
                        color: Colors.redAccent, size: 18),
                  ],
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fromAddress,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 25),
                      Text(toAddress,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            // Action Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EndingKmInputPage(bookingId: widget.bookingId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade600,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("FINISH TRIP",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
