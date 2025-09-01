import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // To handle JSON responses
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'car_reg_form.dart';

class OwnerRegPage extends StatefulWidget {
  @override
  _OwnerPageState createState() => _OwnerPageState();
}

class _OwnerPageState extends State<OwnerRegPage> {
  final _formKey = GlobalKey<FormState>();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  TextEditingController agencyNameController = TextEditingController();
  TextEditingController ownerNameController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController secondNumberController = TextEditingController();
  TextEditingController cityController = TextEditingController();
  TextEditingController pinCodeController = TextEditingController();
  bool _isAgree = false; // Variable to track if the user agrees to the terms

  // Function to send POST request with form data
  Future<void> _submitForm() async {
    String? phoneNumber = await secureStorage.read(key: "phone_number");
    if (_formKey.currentState!.validate() && _isAgree) {
      // Collecting the data from form fields
      String agencyName = agencyNameController.text;
      String ownerName = ownerNameController.text;
      String address = addressController.text;
      String email = emailController.text;
      String secondNumber = secondNumberController.text;
      String city = cityController.text;
      String pinCode = pinCodeController.text;

      // Prepare data to send in JSON format
      var data = {
        'agency_name': agencyName,
        'full_name': ownerName,
        'driver_address': address,
        'email': email,
        'second_number': secondNumber,
        'driver_city': city,
        'pin_code': pinCode,
        'phone_number': phoneNumber,
        'status': 'not car'
      };

      // Send POST request
      try {
        var response = await http.post(
          Uri.parse('https://agnicarrental.com/driver2025/register_driver.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        );

        // Handle response
        if (response.statusCode == 200) {
          // Successfully submitted the data
          print('Form Submitted Successfully');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
              "Registration Successful!",
              overflow: TextOverflow.ellipsis,
            )),
          );

          // Reset the form fields
          _formKey.currentState!.reset();
          agencyNameController.clear();
          ownerNameController.clear();
          addressController.clear();
          emailController.clear();
          secondNumberController.clear();
          pinCodeController.clear();
          cityController.clear();
          setState(() {
            _isAgree = false; // Reset the agreement checkbox after submission
          });

          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CarFormPage()),
          );
        } else {
          // If the server didn't return a successful response
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
              "Error: ${response.statusCode}",
            )),
          );
        }
      } catch (e) {
        // If there's an error (e.g., no internet connection)
        print('Error occurred: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error submitting the form. Please try again.")),
        );
      }
    } else {
      // If the user hasn't agreed to the terms
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please agree to the terms and conditions")),
      );
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
          title: Text(
            "Registration",
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.blueGrey,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome!",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                    height:
                        1.5, // Makes the text more readable by increasing line height
                  ),
                ),
                Text(
                  "Welcome! to Agni Car Rental - Register Your Agency and Join Our Growing Network of Trusted Cab Owners. Empowering Your Business with Seamless Integration and Support for a Bright Future!",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                    height:
                        1.5, // Makes the text more readable by increasing line height
                  ),
                ),
                SizedBox(height: 20),
                _buildTextField(agencyNameController, "Agency Name"),
                _buildTextField(ownerNameController, "Owner Name"),
                _buildTextField(addressController, "Address"),
                _buildTextField(
                  emailController,
                  "Email ID",
                  keyboardType: TextInputType.emailAddress,
                  isEmail: true,
                ),
                _buildTextField(
                  secondNumberController,
                  "Second Number",
                  keyboardType: TextInputType.phone,
                  isPhoneNumber: true,
                ),
                _buildTextField(cityController, "City"),
                _buildTextField(
                  pinCodeController,
                  "Pin Code",
                  keyboardType: TextInputType.number,
                  isPinCode: true,
                ),
                // Declaration Checkbox
                SizedBox(height: 20),
                CheckboxListTile(
                  title: Text(
                    "I agree to the Terms and Conditions. My data will be used for future updates and contact.",
                    style: TextStyle(color: Colors.grey),
                  ),
                  value: _isAgree,
                  onChanged: (bool? value) {
                    setState(() {
                      _isAgree = value!;
                    });
                  },
                  controlAffinity: ListTileControlAffinity
                      .leading, // To position the checkbox on the left
                ),
                SizedBox(height: 30),
                Center(
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: Colors.blueGrey,
                    ),
                    child: Text(
                      "Submit",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    bool isEmail = false,
    bool isPhoneNumber = false,
    bool isPinCode = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: isPhoneNumber
            ? 10
            : isPinCode
                ? 6
                : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey),
          ),
          filled: true,
          fillColor: Colors.white,
          counterText: "",
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return "Enter $label";
          if (isEmail &&
              !RegExp(
                r'^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]+$',
              ).hasMatch(value)) {
            return "Enter a valid Email";
          }
          if (isPhoneNumber && !RegExp(r'^\d{10}$').hasMatch(value)) {
            return "Enter a valid 10-digit phone number";
          }
          if (isPinCode && !RegExp(r'^\d{6}$').hasMatch(value)) {
            return "Enter a valid 6-digit Pin Code";
          }

          return null;
        },
      ),
    );
  }
}
