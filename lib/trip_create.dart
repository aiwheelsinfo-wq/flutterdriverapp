import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';


class MessagePage extends StatefulWidget {
  final String message;
  const MessagePage({super.key, required this.message});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  List<Map<String, dynamic>> _locationSuggestions = [];

  String? driverId;
  LatLng? selectedLocation;
  GoogleMapController? _mapController;
  String? cityName;

  @override
  void initState() {
    super.initState();
    _messageController.text = widget.message;
    _loadDriverId();

    // Automatically extract details when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _extractDetails();
    });
  }

  Future<void> searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() => _locationSuggestions = []);
      return;
    }

    try {
      List<Location> locations = await locationFromAddress(query);
      List<Map<String, dynamic>> suggestions = [];

      for (var loc in locations) {
        List<Placemark> placemarks =
            await placemarkFromCoordinates(loc.latitude, loc.longitude);

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;

          String fullAddress =
              "${place.name ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, "
              "${place.administrativeArea ?? ''}, ${place.postalCode ?? ''}, ${place.country ?? ''}";

          fullAddress = fullAddress.replaceAll(RegExp(r'(, )+'), ', ').trim();
          fullAddress = fullAddress.replaceAll(RegExp(r'^, |, $'), '');

          suggestions.add({
            "address": fullAddress,
            "lat": loc.latitude,
            "lng": loc.longitude,
          });
        }
      }

      setState(() => _locationSuggestions = suggestions);
    } catch (e) {
      setState(() => _locationSuggestions = []);
    }
  }

  void selectSuggestion(Map<String, dynamic> suggestion) async {
    setState(() {
      selectedLocation = LatLng(suggestion["lat"], suggestion["lng"]);
      _pickupController.text = suggestion["address"];
      _locationSuggestions = [];
    });

    // Extract city from coordinates
    List<Placemark> placemarks =
        await placemarkFromCoordinates(suggestion["lat"], suggestion["lng"]);
    if (placemarks.isNotEmpty) {
      setState(() {
        cityName = placemarks.first.locality ?? "";
      });
    }
  }

  Future<void> _loadDriverId() async {
    String? storedValue = await _secureStorage.read(key: "phone_number");
    setState(() {
      driverId = storedValue;
    });
  }

  /// ---------------- Pattern Recognition ----------------
  String _parseMobile(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
  }

  String? _parseDate(String text) {
    final regex = RegExp(r'(\d{1,2})[-/\.](\d{1,2})[-/\.](\d{2,4})');
    final match = regex.firstMatch(text);
    if (match != null) {
      int d = int.parse(match.group(1)!);
      int m = int.parse(match.group(2)!);
      int y = int.parse(match.group(3)!);
      if (y < 100) y += 2000;
      return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
    }
    return null;
  }

  String _parsePickupLocation(String text) {
    final regex = RegExp(r'Pickup[:\-]?\s*(.+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    if (match != null) return match.group(1)!.trim();
    // fallback: take first line as pickup
    return text.split('\n').first.trim();
  }

  void _extractDetails() {
    final msg = _messageController.text;
    _mobileController.text = _parseMobile(msg);
    _dateController.text = _parseDate(msg) ?? '';
    _pickupController.text = _parsePickupLocation(msg);

    // Optionally trigger location search for extracted pickup location
    if (_pickupController.text.isNotEmpty) {
      searchLocation(_pickupController.text);
    }
  }

  /// ---------------- Text Selection ----------------
  void _showSelectionMenu(String selectedText) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Assign Selected Text'),
        content: Text('"$selectedText" as:'),
        actions: [
          TextButton(
            onPressed: () {
              _mobileController.text = _parseMobile(selectedText);
              Navigator.pop(context);
            },
            child: const Text('Mobile Number'),
          ),
          TextButton(
            onPressed: () {
              _pickupController.text = selectedText;
              Navigator.pop(context);
            },
            child: const Text('Pickup Location'),
          ),
          TextButton(
            onPressed: () {
              final parsedDate = _parseDate(selectedText);
              if (parsedDate != null) _dateController.text = parsedDate;
              Navigator.pop(context);
            },
            child: const Text('Date'),
          ),
        ],
      ),
    );
  }

  /// ---------------- Location Selection ----------------
  void selectLocation(LatLng location, String address, String city) {
    setState(() {
      selectedLocation = location;
      _pickupController.text = address;
      cityName = city;
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 15));
  }

  Future<void> submitBooking() async {
    if (_mobileController.text.isEmpty ||
        _pickupController.text.isEmpty ||
        _dateController.text.isEmpty ||
        selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please fill all fields and select location")),
      );
      return;
    }

    final now = DateTime.now();
    final bookingData = {
      "trip_message": _messageController.text,
      "mobile_number": _mobileController.text,
      "pickup_date": _dateController.text,
      "latitude": selectedLocation!.latitude,
      "longitude": selectedLocation!.longitude,
      "status": "active",
      "drivers_click_counter": 0,
      "time": DateFormat('HH:mm:ss').format(now),
      "city": cityName ?? "",
      "driver_id": driverId,
    };

    final url = Uri.parse(ApiConfig.vendorTrips);

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(bookingData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Booking submitted successfully!")),
        );
        _resetForm();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _resetForm() {
    _messageController.clear();
    _mobileController.clear();
    _pickupController.clear();
    _dateController.clear();
    setState(() {
      selectedLocation = null;
      cityName = null;
      _locationSuggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                // IconButton(
                //   icon: const Icon(Icons.message, color: Colors.white),
                //   onPressed: () async {
                //     setState(() {
                //       _showAlert = true;
                //       _alertLoading = true;
                //       _showBubble = false;
                //     });
                //     await _fetchAlerts();
                //   },
                // ),
                // if (_showBubble)
                //   Positioned(
                //     right: 8,
                //     top: 8,
                //     child: Container(
                //       padding: const EdgeInsets.all(2),
                //       decoration: BoxDecoration(
                //         color: Colors.red,
                //         borderRadius: BorderRadius.circular(10),
                //       ),
                //       constraints: const BoxConstraints(
                //         minWidth: 12,
                //         minHeight: 12,
                //       ),
                //     ),
                //   ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            // Background image
            SizedBox.expand(
              child: Image.asset(
                'assets/chat_bg.webp',
                fit: BoxFit.cover,
              ),
            ),

            // Foreground scrollable content
            SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxWidth: 500), // optional for wide screens
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Booking Message
                      TextField(
                        controller: _messageController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: "Booking Message",
                          border: OutlineInputBorder(),
                          fillColor: Color.fromARGB(255, 255, 255, 255),
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Customer Mobile
                      TextField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: "Customer Mobile Number",
                          border: OutlineInputBorder(),
                          fillColor: Color.fromARGB(255, 255, 255, 255),
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Pickup Date
                      // Pickup Date
                      TextField(
                        controller: _dateController,
                        readOnly: true, // prevent manual input
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(), // no past dates
                            lastDate: DateTime(2100),
                          );

                          if (pickedDate != null) {
                            String formattedDate =
                                DateFormat('yyyy-MM-dd').format(pickedDate);
                            setState(() {
                              _dateController.text = formattedDate;
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: "Pickup Date",
                          border: OutlineInputBorder(),
                          fillColor: Color.fromARGB(255, 255, 255, 255),
                          filled: true,
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Pickup Location
                      TextField(
                        controller: _pickupController,
                        decoration: const InputDecoration(
                          labelText: "Pickup Location",
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.location_on),
                          fillColor: Color.fromARGB(255, 255, 255, 255),
                          filled: true,
                        ),
                        onChanged: searchLocation,
                      ),

                      // Location suggestions
                      ..._locationSuggestions.map((s) => ListTile(
                            title: Text(s["address"]),
                            leading: const Icon(Icons.location_on),
                            onTap: () => selectSuggestion(s),
                          )),

                      const SizedBox(height: 12),

                      // Google Map
                      if (selectedLocation != null)
                        SizedBox(
                          height: 250,
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                                target: selectedLocation!, zoom: 15),
                            markers: {
                              Marker(
                                markerId: const MarkerId("pickup"),
                                position: selectedLocation!,
                              )
                            },
                            onMapCreated: (controller) {
                              _mapController = controller;
                            },
                          ),
                        ),

                      const SizedBox(height: 12),

                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: submitBooking,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3CAF49)),
                              child: const Text(
                                "Submit Booking",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _resetForm,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                              child: const Text(
                                "Reset",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ));
  }
}
