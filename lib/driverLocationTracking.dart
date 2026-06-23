import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:location/location.dart' as loc;
import 'api_config.dart';


class Driverlocationtracking extends StatefulWidget {
  final String bookingId;
  final String phoneNumber;

  const Driverlocationtracking(
      {super.key, required this.bookingId, required this.phoneNumber});

  @override
  _TripLiveMappingState createState() => _TripLiveMappingState();
}

class _TripLiveMappingState extends State<Driverlocationtracking> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  final loc.Location location = loc.Location();

  GoogleMapController? _mapController;
  LatLng? fromLatLng;
  LatLng? toLatLng;
  LatLng? driverLatLng;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _loadRouteAndDriver();
    _startLiveLocationUpdate();
  }

  Future<void> _loadRouteAndDriver() async {
    try {
      // 1. Fetch from_address and to_address
      final bookingRes = await http.post(
        Uri.parse(ApiConfig.tripLiveMappingBackend),

        body: {
          'action': 'get_booking_details',
          'booking_id': widget.bookingId,
        },
      );

      final bookingData = json.decode(bookingRes.body);
      if (!bookingData['success']) throw Exception("Booking fetch failed.");

      final fromAddress = bookingData['from_address'] ?? "";
      final toAddress = bookingData['to_address'] ?? "";

      // 2. Convert address to LatLng
      try {
        if (fromAddress.isNotEmpty) {
          fromLatLng = await _geocodeAddress(fromAddress);
        }
      } catch (e) {
        debugPrint("Geocoding failed for pickup address: $e");
      }

      // 4. Get driver location
      try {
        final driverRes = await http.post(
          Uri.parse(ApiConfig.tripLiveMappingBackend),

          body: {
            'action': 'get_driver_location',
            'phone_number': widget.phoneNumber,
          },
        );

        final driverData = json.decode(driverRes.body);
        if (driverData['success'] == true && driverData['latitude'] != null && driverData['longitude'] != null) {
          driverLatLng = LatLng(driverData['latitude'], driverData['longitude']);
        }
      } catch (e) {
        debugPrint("Driver location fetch failed: $e");
      }

      // 5. Handle route drawing only if toAddress is provided
      if (toAddress.isNotEmpty &&
          toAddress != "Local Trip / Drop" &&
          toAddress != "Local Duty" &&
          toAddress != "N/A") {
        try {
          toLatLng = await _geocodeAddress(toAddress);
          if (toLatLng != null) {
            if (fromLatLng != null) {
              await _fetchRouteFromGoogleDirectionsAPI(fromLatLng!, toLatLng!);
            }

            _markers.add(Marker(markerId: const MarkerId("to"), position: toLatLng!));
          }
        } catch (e) {
          debugPrint("Geocoding/routing failed for drop address: $e");
        }
      }
    } catch (e) {
      print("Error loading map: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load trip data.")),
      );
    } finally {
      setState(() {
        if (fromLatLng == null) {
          fromLatLng = const LatLng(20.5937, 78.9629);
        }
        if (driverLatLng == null) {
          driverLatLng = const LatLng(20.5937, 78.9629);
        }
        _markers.add(Marker(markerId: const MarkerId("from"), position: fromLatLng!));
        _markers.add(Marker(markerId: const MarkerId("driver"), position: driverLatLng!));
      });

      _mapController
          ?.animateCamera(CameraUpdate.newLatLngZoom(driverLatLng!, 14));
    }
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    const String googleAPIKey = "AIzaSyC41U3p08LqY8G15ruxDCEfTvBLkG_OrsM";
    final url =
        "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$googleAPIKey";
    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final lat = data['results'][0]['geometry']['location']['lat'];
        final lng = data['results'][0]['geometry']['location']['lng'];
        return LatLng(lat, lng);
      } else {
        debugPrint("Google Geocoding failed: ${data['status']}");
      }
    } catch (e) {
      debugPrint("Google Geocoding exception: $e");
    }
    return null;
  }

  Future<void> _fetchRouteFromGoogleDirectionsAPI(
      LatLng from, LatLng to) async {
    final apiKey =
        "AIzaSyC41U3p08LqY8G15ruxDCEfTvBLkG_OrsM"; // Replace with your actual API key
    final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/directions/json?origin=${from.latitude},${from.longitude}&destination=${to.latitude},${to.longitude}&key=$apiKey",
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final routes = data['routes'];
        if (routes.isNotEmpty) {
          final overviewPolyline = routes[0]['overview_polyline']['points'];
          final List<LatLng> polylineCoordinates =
              _decodePolyline(overviewPolyline);
          setState(() {
            _polylines.add(Polyline(
              polylineId: PolylineId("route"),
              points: polylineCoordinates,
              color: Colors.blue,
              width: 5,
            ));
          });
        }
      }
    } else {
      throw Exception('Failed to load directions');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polylineCoordinates = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polylineCoordinates.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polylineCoordinates;
  }

  Future<void> _startLiveLocationUpdate() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    loc.PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) return;
    }

    location.changeSettings(interval: 10000); // 10 seconds

    location.onLocationChanged.listen((loc.LocationData currentLocation) async {
      final phoneNumber = await secureStorage.read(key: "phone_number");

      if (phoneNumber != null &&
          currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        await http.post(
          Uri.parse(ApiConfig.updateLocation),

          body: {
            'driver_id': phoneNumber,
            'latitude': currentLocation.latitude.toString(),
            'longitude': currentLocation.longitude.toString(),
          },
        );

        setState(() {
          driverLatLng =
              LatLng(currentLocation.latitude!, currentLocation.longitude!);
          _markers.removeWhere((m) => m.markerId.value == "driver");
          _markers.add(
              Marker(markerId: MarkerId("driver"), position: driverLatLng!));
        });

        _mapController?.animateCamera(CameraUpdate.newLatLng(driverLatLng!));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Live Trip Mapping")),
      body: Column(
        children: [
          // Map view
          Expanded(
            child: fromLatLng == null || driverLatLng == null
                ? Center(child: CircularProgressIndicator())
                : GoogleMap(
                    onMapCreated: (controller) => _mapController = controller,
                    markers: _markers,
                    polylines: _polylines,
                    initialCameraPosition: CameraPosition(
                      target: driverLatLng!,
                      zoom: 14,
                    ),
                  ),
          ),

          // Trip End Button
        ],
      ),
    );
  }
}
