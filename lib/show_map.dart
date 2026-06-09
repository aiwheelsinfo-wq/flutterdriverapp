import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as location;
import 'api_config.dart';


class ShowMap extends StatefulWidget {
  final String fromAddress;
  final String toAddress;
  final String phoneNumber;

  const ShowMap({
    super.key,
    required this.fromAddress,
    required this.toAddress,
    required this.phoneNumber,
  });

  @override
  State<ShowMap> createState() => _ShowMapState();
}

class _ShowMapState extends State<ShowMap> {
  GoogleMapController? mapController;

  LatLng _fromLocation = LatLng(0, 0);
  LatLng _toLocation = LatLng(0, 0);
  LatLng? _currentLocation;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<LatLng> _polylineCoordinates = [];

  final location.Location _location = location.Location();
  location.LocationData? _currentPosition;

  String googleAPIKey =
      "AIzaSyCZkOB0WSoPjjdf8gRUj9GcXXJuWvpj5Mo"; // Replace this

  @override
  void initState() {
    super.initState();
    _initMapData(); // handles geocoding and routing
    _requestLocationPermission(); // handles current location
  }

  Future<void> _initMapData() async {
    try {
      final fromLatLng = await getCoordinatesFromGoogle(widget.fromAddress);
      final toLatLng = await getCoordinatesFromGoogle(widget.toAddress);

      setState(() {
        _fromLocation = fromLatLng;
        _toLocation = toLatLng;
      });

      _setMarkers();
      _fetchRoute();
      _moveCameraToBounds();
    } catch (e) {
      print("Error initializing map data: $e");
    }
  }

  Future<LatLng> getCoordinatesFromGoogle(String address) async {
    final url =
        "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$googleAPIKey";

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data['status'] == 'OK') {
      final lat = data['results'][0]['geometry']['location']['lat'];
      final lng = data['results'][0]['geometry']['location']['lng'];
      return LatLng(lat, lng);
    } else {
      throw Exception('Failed to get coordinates: ${data['status']}');
    }
  }

  void _setMarkers() {
    _markers.clear();
    _markers.add(Marker(
      markerId: MarkerId("from"),
      position: _fromLocation,
      infoWindow: InfoWindow(title: "From Location"),
    ));

    _markers.add(Marker(
      markerId: MarkerId("to"),
      position: _toLocation,
      infoWindow: InfoWindow(title: "To Location"),
    ));
  }

  Future<void> _fetchRoute() async {
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${_fromLocation.latitude},${_fromLocation.longitude}&destination=${_toLocation.latitude},${_toLocation.longitude}&key=$googleAPIKey";

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if ((data["routes"] as List).isNotEmpty) {
        final encodedPolyline =
            data["routes"][0]["overview_polyline"]["points"];
        _polylineCoordinates = _decodePolyline(encodedPolyline);

        setState(() {
          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: PolylineId("route"),
            points: _polylineCoordinates,
            color: Colors.blue,
            width: 5,
          ));
        });
      }
    } else {
      print("Error fetching route: ${response.statusCode}");
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polylinePoints = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      polylinePoints.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polylinePoints;
  }

  Future<void> _moveCameraToBounds() async {
    if (_fromLocation.latitude == 0 || _toLocation.latitude == 0) return;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        min(_fromLocation.latitude, _toLocation.latitude),
        min(_fromLocation.longitude, _toLocation.longitude),
      ),
      northeast: LatLng(
        max(_fromLocation.latitude, _toLocation.latitude),
        max(_fromLocation.longitude, _toLocation.longitude),
      ),
    );

    mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    location.PermissionStatus permissionGranted =
        await _location.hasPermission();
    if (permissionGranted == location.PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != location.PermissionStatus.granted) return;
    }

    _location.onLocationChanged.listen((location.LocationData currentLocation) {
      _currentPosition = currentLocation;
      _currentLocation =
          LatLng(currentLocation.latitude!, currentLocation.longitude!);

      _updateLocationToServer(
        currentLocation.latitude!,
        currentLocation.longitude!,
      );

      // Optionally update marker or animate camera
    });
  }

  Future<void> _updateLocationToServer(
      double latitude, double longitude) async {
    final url = ApiConfig.updateLocation;


    await http.post(
      Uri.parse(url),
      body: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'driver_id': widget.phoneNumber,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Route & Current Location"),
      ),
      body: GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          mapController = controller;
        },
        initialCameraPosition: CameraPosition(
          target: _fromLocation,
          zoom: 10.0,
        ),
        markers: _markers,
        polylines: _polylines,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _requestLocationPermission,
        child: Icon(Icons.my_location),
      ),
    );
  }
}
