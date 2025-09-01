import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:location/location.dart' as loc;

import 'endingKmInputPage.dart';

class TripLiveMapping extends StatefulWidget {
  final String bookingId;
  final String phoneNumber;

  const TripLiveMapping(
      {Key? key, required this.bookingId, required this.phoneNumber})
      : super(key: key);

  @override
  _TripLiveMappingState createState() => _TripLiveMappingState();
}

class _TripLiveMappingState extends State<TripLiveMapping> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  final loc.Location location = loc.Location();

  GoogleMapController? _mapController;
  LatLng? fromLatLng;
  LatLng? toLatLng;
  LatLng? driverLatLng;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

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
        Uri.parse(
            "https://agnicarrental.com/driver2025/trip_live_mapping_backend.php"),
        body: {
          'action': 'get_booking_details',
          'booking_id': widget.bookingId,
        },
      );

      final bookingData = json.decode(bookingRes.body);
      if (!bookingData['success']) throw Exception("Booking fetch failed.");

      final fromAddress = bookingData['from_address'];
      final toAddress = bookingData['to_address'];

      // 2. Convert address to LatLng
      final fromLocations = await locationFromAddress(fromAddress);
      fromLatLng =
          LatLng(fromLocations[0].latitude, fromLocations[0].longitude);

      final toLocations = await locationFromAddress(toAddress);
      fromLatLng = LatLng(toLocations[0].latitude, toLocations[0].longitude);

      // 3. Get driver phone number

      // 4. Get driver location
      final driverRes = await http.post(
        Uri.parse(
            "https://agnicarrental.com/driver2025/trip_live_mapping_backend.php"),
        body: {
          'action': 'get_driver_location',
          'phone_number': widget.phoneNumber,
        },
      );

      final driverData = json.decode(driverRes.body);
      if (!driverData['success']) throw Exception("Driver location failed.");

      driverLatLng = LatLng(driverData['latitude'], driverData['longitude']);

      // 5. Handle route drawing only if toAddress is provided
      if (toAddress.isNotEmpty) {
        final toLocations = await locationFromAddress(toAddress);
        toLatLng = LatLng(toLocations[0].latitude, toLocations[0].longitude);

        await _fetchRouteFromGoogleDirectionsAPI(fromLatLng!, toLatLng!);

        _markers.add(Marker(markerId: MarkerId("to"), position: toLatLng!));
      }

      // 6. Update map with markers
      setState(() {
        _markers.add(Marker(markerId: MarkerId("from"), position: fromLatLng!));
        _markers
            .add(Marker(markerId: MarkerId("driver"), position: driverLatLng!));
      });

      _mapController
          ?.animateCamera(CameraUpdate.newLatLngZoom(driverLatLng!, 14));
    } catch (e) {}
  }

  Future<void> _fetchRouteFromGoogleDirectionsAPI(
      LatLng from, LatLng to) async {
    final apiKey =
        "AIzaSyCZkOB0WSoPjjdf8gRUj9GcXXJuWvpj5Mo"; // Replace with your actual API key
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
          Uri.parse("https://agnicarrental.com/driver2025/update_location.php"),
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
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 15),
            color: Colors.green,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 20),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EndingKmInputPage(
                      bookingId: widget.bookingId,
                    ),
                  ),
                );
              },
              child: Text(
                'End Trip',
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
