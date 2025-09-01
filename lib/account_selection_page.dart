import 'package:flutter/material.dart';
import 'owner_reg_page.dart';
import 'sub_driver_page.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

//import 'driver_page.dart';

class DriverOwnerSelectionPage extends StatefulWidget {
  @override
  State<DriverOwnerSelectionPage> createState() =>
      _DriverOwnerSelectionPageState();
}

class _DriverOwnerSelectionPageState extends State<DriverOwnerSelectionPage> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
  }

  Future<void> statusChangeNotFill() async {
    await secureStorage.write(key: "userType", value: "Vender");
    String? storedNumber = await secureStorage.read(key: "phone_number");
    String apiUrl =
        "https://agnicarrental.com/driver2025/status_change_notFilled.php";

    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        body: {"stored_number": storedNumber},
      );

      var jsonResponse = jsonDecode(response.body);
      if (jsonResponse["success"] == true) {
        // Wait for 10 minutes before hiding the loader

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => OwnerRegPage()),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Your selection is granted",
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    } catch (e) {
      print("Error ending trip: $e");
    }
  }

  Future<void> statusChangeNotJoin() async {
    await secureStorage.write(key: "userType", value: "Driver");
    String? storedNumber = await secureStorage.read(key: "phone_number");
    String apiUrl =
        "https://agnicarrental.com/driver2025/status_change_not_join.php";

    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        body: {"stored_number": storedNumber},
      );

      var jsonResponse = jsonDecode(response.body);
      if (jsonResponse["success"] == true) {
        // Wait for 10 minutes before hiding the loader

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SubDriverPage()),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Your selection is granted",
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    } catch (e) {
      print("Error ending trip: $e");
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Are you\nDriver or\nCab Owner?",
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      statusChangeNotJoin();
                    },
                    child: Text(
                      "Driver",
                      style: TextStyle(fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          20,
                        ), // Corrected this line
                      ),
                    ),
                  ),
                  SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: () {
                      statusChangeNotFill();
                    },
                    child: Text(
                      "Owner",
                      style: TextStyle(fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          20,
                        ), // Corrected this line
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
