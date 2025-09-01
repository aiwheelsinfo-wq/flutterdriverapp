import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'account_selection_page.dart';
import 'booking_list.dart';
import 'car_reg_form.dart';
import 'driver_add_form.dart';
import 'driver_reg_success.dart';
import 'join_sub_driver_page.dart';
import 'owner_reg_page.dart';
import 'sub_driver_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class checAbdRoot extends StatefulWidget {
  const checAbdRoot({super.key});

  @override
  State<checAbdRoot> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<checAbdRoot> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  String status = "";
  bool isLoading = true; // To control the loading state

  @override
  void initState() {
    super.initState();
    fetchDriverDetails();
  }

  Future<void> fetchDriverDetails() async {
    String? storedNumber = await secureStorage.read(key: "phone_number");

    try {
      final response = await http.get(
        Uri.parse(
          "https://agnicarrental.com/driver2025/driver_details_fetching.php?phone_number=$storedNumber",
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["status"] == "success") {
          setState(() {
            status = data["data"]['status'];
            isLoading = false; // Stop loading when response is received

            // Navigate based on the value of 'status'
            if (status == "filled") {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => SubDriverPage()),
              );
            } else if (status == "not filled") {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => OwnerRegPage()),
              );
            } else if (status == "join") {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => JoinSubDriverPage()),
              );
            } else if (status == "not Join") {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => SubDriverPage()),
              );
            } else if (status == "active" || status == "Notified") {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        BookingListPage(phoneNumber: storedNumber ?? '')),
              );
            } else if (status == "not car") {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => CarFormPage()),
              );
            } else if (status == "not driver") {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => DriverFormPage()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => DriverOwnerSelectionPage()),
              );
            }
          });
        } else {
          // Handle failure response if needed
          setState(() {
            isLoading = false;
          });
        }
      } else {
        // Handle server error or bad status code
        setState(() {
          isLoading = false;
        });
        // You might want to show an error message or retry option here
      }
    } catch (e) {
      // Handle network error or any other exception
      setState(() {
        isLoading = false;
      });
      // You might want to show an error message here
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set background color to white
      body: Center(
        child: isLoading
            ? CircularProgressIndicator() // Show loading indicator while waiting
            : Container(), // This will be empty when loading is done and navigation happens
      ),
    );
  }
}
