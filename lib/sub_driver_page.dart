import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'car_reg_form.dart';
import 'checkAndRoot.dart';
import 'driver_add_form.dart';
import 'owner_account.dart';

class SubDriverPage extends StatefulWidget {
  @override
  State<SubDriverPage> createState() => _SubDriverPageState();
}

class _SubDriverPageState extends State<SubDriverPage> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  String driverCode = ""; // Placeholder text
  String? storedNumber; // Your test phone number

  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  final List<String> imageUrls = [
    'https://agnicarrental.com/driver2025/add/add1.webp',
    'https://agnicarrental.com/driver2025/add/add2.webp',
    'https://agnicarrental.com/driver2025/add/add3.webp',
    'https://agnicarrental.com/driver2025/add/add4.webp',
  ];

  @override
  void initState() {
    super.initState();
    _fetchDriverCode(); // Fetch driver code when the page loads
  }

  Future<void> _fetchDriverCode() async {
    storedNumber = await secureStorage.read(key: "phone_number");
    final String apiUrl =
        "https://agnicarrental.com/driver2025/driver_code_fetching.php?phone_number=$storedNumber";

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData["status"] == "success") {
          setState(() {
            driverCode = responseData['driver_code'];
          });
        } else {
          setState(() {
            driverCode = "Error: ${responseData['message']}";
          });
        }
      } else {
        setState(() {
          driverCode = "Server Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        driverCode = "Network Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevents default navigation popping
      onPopInvokedWithResult: (didPop, result) async {
        // Added result parameter
        if (!didPop) {
          // Exit the app completely when back button is pressed
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Agni Driver",
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.blueGrey,
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Container(
                        child: CarouselSlider(
                          options: CarouselOptions(
                            height: 160.0,
                            autoPlay: true,
                            enlargeCenterPage: true,
                            aspectRatio: 16 / 9,
                            autoPlayInterval: Duration(seconds: 3),
                            autoPlayCurve: Curves.fastOutSlowIn,
                            enableInfiniteScroll: true,
                          ),
                          items: imageUrls.map((url) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                placeholder: (context, url) =>
                                    Center(child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) => Center(
                                  child: Icon(Icons.error, color: Colors.red),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(Icons.check_circle,
                            color: Colors.green, size: 80),
                      ),
                      Center(
                        child: Text(
                          "Your registration has been successfully saved. Please contact an Agni representative via WhatsApp by clicking the button below.",
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          String contactNumber = '8422001616';
                          if (Platform.isAndroid) {
                            String url =
                                'whatsapp://send?phone=$contactNumber&text=Hello, I am a driver for Agni Car Rental. I am unable to accept trips due to my account being inactive. Please assist in activating my account at the earliest. Thank you!';

                            // Launch the WhatsApp URL
                            await launchUrl(Uri.parse(url));

                            String? storedNumber =
                                await secureStorage.read(key: "phone_number");

                            // After launching WhatsApp, clear the navigation history and navigate to a new screen
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      checAbdRoot()), // Your new screen
                              (Route<dynamic> route) =>
                                  false, // Remove all previous routes
                            );
                          }
                        },
                        child: Text(
                          'WhatsApp Verification',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Center(
                        child: Card(
                          elevation: 4,
                          margin: EdgeInsets.all(20),
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Container(
                              width: double.infinity,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Welcome",
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 50),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    "Your Driver Code",
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.grey),
                                  ),
                                  Text(
                                    driverCode != null
                                        ? "$driverCode"
                                        : "Loading...",
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: driverCode != null
                                          ? 60
                                          : 10, // Adjust font size based on state
                                      color: Colors.blueGrey,
                                      letterSpacing: 10.0,
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2025, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15), // Round top-left corner
                topRight: Radius.circular(15), // Round top-right corner
              ),
              child: Container(
                width: double.infinity, // Ensures full width
                color: const Color.fromARGB(
                    255, 223, 245, 252), // Background color set to white
                padding: const EdgeInsets.symmetric(
                    vertical: 10), // Adjusted padding
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        //_scrollToTop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.transparent, // Remove background color
                        elevation: 0, // Remove shadow
                        padding: EdgeInsets
                            .zero, // Optional: Remove padding if needed
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.home,
                            color: Colors.blueGrey,
                          ),
                          Text(
                            "Home",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => CarFormPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.transparent, // Remove background color
                        elevation: 0, // Remove shadow
                        padding: EdgeInsets
                            .zero, // Optional: Remove padding if needed
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.directions_car,
                            color: Colors.blueGrey,
                          ),
                          Text(
                            "Add Cab",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => DriverFormPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.transparent, // Remove background color
                        elevation: 0, // Remove shadow
                        padding: EdgeInsets
                            .zero, // Optional: Remove padding if needed
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_add_alt_1_rounded,
                            color: Colors.blueGrey,
                          ),
                          Text(
                            "Add Driver",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => OwnerProfileScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.transparent, // Remove background color
                        elevation: 0, // Remove shadow
                        padding: EdgeInsets
                            .zero, // Optional: Remove padding if needed
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_add_alt_1_rounded,
                            color: Colors.blueGrey,
                          ),
                          Text(
                            "Account",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
