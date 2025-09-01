import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'checkAndRoot.dart';

class DriverFormPage extends StatefulWidget {
  // Phone number stored in variable

  @override
  _DriverFormPageState createState() => _DriverFormPageState();
}

class _DriverFormPageState extends State<DriverFormPage> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  final ScrollController _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();
  late Map<String, TextEditingController> _controllers;
  String? storedNumber;
  String? driverCode;
  String? inputNumber;

  String? driverFullName;
  String? driverEmail;
  String? driverAddress;
  String? pinCode;
  String? driverCity;
  String? agencyName;
  String? secondNumber;

  bool driverFrom = false;
  bool newdriverForm = false;
  bool driverCodeField = false;
  bool driverCodeNotCorrect = false;
  bool addDriverSuccess = false;
  bool driverForm = true;
  bool addNewBtn = false;
  bool nextStepBtn = false;
  bool _isAgree = false;
  bool nextBtn = false;

  final Set<String> _uniqueValues = {};

  @override
  void initState() {
    super.initState();
    _controllers = {
      'phone_number': TextEditingController(),
      'driver_code': TextEditingController(),
      'full_name': TextEditingController(),
      'email': TextEditingController(),
      'driver_address': TextEditingController(),
      'driver_city': TextEditingController(),
      'date_of_birth': TextEditingController(),
      'pin_code': TextEditingController(),
      'license_no': TextEditingController(),
      'license_doe': TextEditingController(),
      'license_type': TextEditingController(),
      'adhaar_card_no': TextEditingController(),
      'pan_card_no': TextEditingController(),
    };
    fetchDriverStatus();
    Future.delayed(Duration(seconds: 2), () {
      // Show SnackBar automatically after loading is complete
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Fill this page first, and go forward..",
            overflow: TextOverflow.ellipsis,
          ),
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  Future<void> fetchDriverStatus() async {
    storedNumber = await secureStorage.read(key: "phone_number");
    print("Fetching driver details...");
    try {
      final response = await http.get(
        Uri.parse(
          'https://agnicarrental.com/driver2025/register_driver.php?phone_number=$storedNumber',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Response data: $data");

        final List<dynamic> driversData = data['driversdata'];
        final driver = driversData.isNotEmpty ? driversData[0] : null;

        if (driver != null) {
          print("Driver Status: ${driver['status']}");

          // Correct condition to check driver status
          if (driver['status'] != 'not driver') {
            // Assuming 'active' is the required status
            setState(() {
              nextBtn = true;
              print("Button enabled");
            });
          } else {
            setState(() {
              nextBtn = false;
            });
            print("Driver is not active.");
          }
        } else {
          print("No driver data found.");
          setState(() {
            nextBtn = false;
          });
        }
      } else {
        throw Exception('Failed to load driver details');
      }
    } catch (e) {
      setState(() {
        nextBtn = false; // Disable the button on error
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      print("Error fetching driver details: $e");
    }
  }

  void clearAllControllers() {
    _controllers.forEach((key, controller) {
      controller.clear(); // Clear each TextEditingController
    });
  }

  void _agreeValidation() {
    if (_isAgree) {
      if (driverCodeField) {
        _submitForm('join');
      } else {
        _submitForm('filled');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please agree to the terms and conditions")),
      );
    }
  }

  Future<void> statusChangeNotFill() async {
    String? storedNumber = await secureStorage.read(key: "phone_number");
    String apiUrl =
        "https://agnicarrental.com/driver2025/status_change_filled.php";

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
          MaterialPageRoute(builder: (context) => checAbdRoot()),
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

  Future<void> checkPhoneNumber() async {
    inputNumber = _controllers['phone_number']?.text.trim() ?? "";
    storedNumber = await secureStorage.read(key: "phone_number");

    if (inputNumber == storedNumber) {
      setState(() {
        driverFrom = true;
        driverCodeField = false;
        newdriverForm = true;
        fetchDriverDetails(inputNumber);
      });
    } else {
      setState(() {
        driverCodeField = true;
        fetchDriverDetails(inputNumber);
        fetchDriverCode();
      });
    }
  }

  Future<void> fetchDriverDetails(phoneNumber) async {
    final response = await http.get(
      Uri.parse(
        "https://agnicarrental.com/driver2025/driver_details_fetching.php?phone_number=$phoneNumber",
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data["status"] == "success") {
        setState(() {
          // Update text controllers with data from the map
          _controllers['full_name']?.text = data["data"]["full_name"] ??
              ''; // Ensure text controller is set with data
          _controllers['email']?.text = data["data"]['email'] ?? '';
          _controllers['driver_address']?.text =
              data["data"]['driver_address'] ?? '';
          _controllers['pin_code']?.text =
              data["data"]['pin_code'] ?? ''; // Fixed empty key issue
          _controllers['driver_city']?.text = data["data"]['driver_city'] ?? '';
          _controllers['agency_name']?.text = data["data"]['agency_name'] ?? '';
          _controllers['license_no']?.text = data["data"]['license_no'] ?? '';
          _controllers['license_doe']?.text = convertDateToBackend(
            data["data"]['license_doe'] ?? '',
          );
          _controllers['license_type']?.text =
              data["data"]['license_type'] ?? '';
          _controllers['adhaar_card_no']?.text =
              data["data"]['adhaar_card_no'] ?? '';
          _controllers['pan_card_no']?.text = data["data"]['pan_card_no'] ?? '';
          _controllers['date_of_birth']?.text = convertDateToBackend(
            data["data"]['date_of_birth'] ?? '',
          );

          // Assuming driverCode is a variable you want to set
          // driverCode = data['driver_code']; // Safely set driverCode
        });
      } else {
        setState(() {});
      }
    } else {
      setState(() {});
    }
  }

  Future<void> fetchDriverCode() async {
    String inputNumber = _controllers['phone_number']?.text.trim() ?? '';

    final url = Uri.parse(
      "https://agnicarrental.com/driver2025/driver_code_fetching.php?phone_number=$inputNumber",
    );
    try {
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        setState(() {
          driverCode = data['driver_code'];

          print("objecttttt: ${data['driver_code']}");
        });
      } else {
        setState(() {});
      }
    } catch (e) {}
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[600]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  String? _dateValidator(String? value) {
    if (value == null || value.isEmpty) return 'This field is required';

    final RegExp dateRegExp = RegExp(r'^\d{2}-\d{2}-\d{4}$');
    if (!dateRegExp.hasMatch(value)) {
      return 'Enter date in DD-MM-YYYY format';
    }

    try {
      final parts = value.split('-');
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      if (month < 1 || month > 12) return 'Month must be between 01 and 12';
      if (day < 1 || day > 31) return 'Day must be between 01 and 31';
      if (year < 1900 || year > 2100)
        return 'Year must be between 1900 and 2100';

      final date = DateTime(year, month, day);
      if (date.day != day || date.month != month || date.year != year) {
        return 'Invalid date';
      }
      return null;
    } catch (e) {
      return 'Invalid date';
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: 5000),
      curve: Curves.easeInOut,
    );
  }

  String convertDateToBackend(String date) {
    final parts = date.split('-');
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  Future<void> _submitForm(String status) async {
    _scrollToTop();
    _uniqueValues.clear();
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        final data = {
          'phone_number': _controllers['phone_number']!.text.isEmpty
              ? null
              : _controllers['phone_number']!.text,
          'full_name': _controllers['full_name']!.text.isEmpty
              ? null
              : _controllers['full_name']!.text,
          'email': _controllers['email']!.text.isEmpty
              ? null
              : _controllers['email']!.text,
          'driver_address': _controllers['driver_address']!.text.isEmpty
              ? null
              : _controllers['driver_address']!.text,
          'driver_city': _controllers['driver_city']!.text.isEmpty
              ? null
              : _controllers['driver_city']!.text,
          'date_of_birth': _controllers['date_of_birth']!.text.isEmpty
              ? null
              : convertDateToBackend(_controllers['date_of_birth']!.text),
          'pin_code': _controllers['pin_code']!.text.isEmpty
              ? null
              : _controllers['pin_code']!.text,
          'license_no': _controllers['license_no']!.text.isEmpty
              ? null
              : _controllers['license_no']!.text,
          'license_doe': _controllers['license_doe']!.text.isEmpty
              ? null
              : convertDateToBackend(_controllers['license_doe']!.text),
          'license_type': _controllers['license_type']!.text.isEmpty
              ? null
              : _controllers['license_type']!.text,
          'adhaar_card_no': _controllers['adhaar_card_no']!.text.isEmpty
              ? null
              : _controllers['adhaar_card_no']!.text,
          'pan_card_no': _controllers['pan_card_no']!.text.isEmpty
              ? null
              : _controllers['pan_card_no']!.text,
          'status': status,
          'vendor_number': storedNumber,
        };

        final url = Uri.parse(
          'https://agnicarrental.com/driver2025/register_driver.php',
        );
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        );

        if (response.statusCode == 200) {
          clearAllControllers();
          final result = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ?? 'Driver updated successfully',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );

          setState(() {
            driverForm = false;
            newdriverForm = false;
            addNewBtn = true;
            nextStepBtn = true;
            addDriverSuccess = true;
            driverCodeField = false;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error: ${response.statusCode}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  final List<String> fuelTypes = [
    'Petrol',
    'Petrol & CNG',
    'Diesel',
    'EV',
    'Hybrid',
  ];

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
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Driver Registration", overflow: TextOverflow.ellipsis),
              nextBtn
                  ? TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => checAbdRoot()),
                        );
                      },
                      child: Text(
                        "Not Now",
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : SizedBox(),
            ],
          ),
          elevation: 0,
          backgroundColor: Colors.blueGrey[700],
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          controller: _scrollController,
          child: Container(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(30.0),
              child: Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Column(
                  children: [
                    if (addDriverSuccess)
                      Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(
                              30,
                            ), // Add padding for better spacing
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.green,
                                width: 2,
                              ), // Green border with 2px width
                              borderRadius: BorderRadius.circular(
                                8,
                              ), // Optional: Rounded corners
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check,
                                  color: Colors.green,
                                  size: 30.0,
                                ),
                                Text(
                                  "Your Driver is Added Successfully",
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 50),
                        ],
                      ),
                    if (addNewBtn && nextStepBtn)
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  driverForm = true;
                                  addNewBtn = false;
                                  nextStepBtn = false;
                                  addDriverSuccess = false;
                                  fetchDriverDetails('');
                                });
                                // Action you want to perform when the button is pressed
                              },
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width *
                                    0.3, // 50% of the screen width
                                child: Center(
                                  child: Text(
                                    "Add New",
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                statusChangeNotFill();
                                // Action you want to perform when the button is pressed
                              },
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width *
                                    0.3, // 50% of the screen width
                                child: Center(
                                  child: Text(
                                    "Finish",
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (driverForm)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Add Your Driver",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 40),
                            textAlign: TextAlign.start,
                          ),
                          Text(
                            "Let's Drive Your Business Forward,  Register Your Driver with Us and Get Ready to Hit the Road!",
                            overflow: TextOverflow.ellipsis,
                          ),
                          Divider(),
                          SizedBox(height: 30),
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(
                                  'Driver Phone Number',
                                  'phone_number',
                                  keyboardType: TextInputType.number,
                                ),
                                if (driverCodeField)
                                  _buildTextField(
                                    'Driver Code',
                                    'driver_code',
                                    keyboardType: TextInputType.number,
                                  ),
                                if (newdriverForm)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionTitle(
                                        'Personal Information',
                                      ),
                                      _buildTextField('Full Name', 'full_name'),
                                      _buildTextField('Email', 'email'),
                                      _buildTextField(
                                        'Address',
                                        'driver_address',
                                      ),
                                      _buildTextField('City', 'driver_city'),
                                      _buildTextField(
                                        'Pin Code',
                                        'pin_code',
                                        keyboardType: TextInputType.number,
                                      ),
                                      _buildDateField(
                                        'Date of Birth',
                                        'date_of_birth',
                                      ),
                                      _buildSectionTitle('Identification'),
                                      _buildTextField(
                                        'Aadhaar Card No',
                                        'adhaar_card_no',
                                        isUnique: true,
                                        keyboardType: TextInputType.number,
                                      ),
                                      _buildTextField(
                                        'PAN Card No',
                                        'pan_card_no',
                                        isUnique: true,
                                      ),
                                      _buildSectionTitle('License Details'),
                                      _buildTextField(
                                        'License No',
                                        'license_no',
                                        isUnique: true,
                                      ),
                                      _buildDateField(
                                        'License DOE',
                                        'license_doe',
                                      ),
                                      _buildTextField(
                                        'License Type',
                                        'license_type',
                                      ),
                                      SizedBox(height: 20),
                                      CheckboxListTile(
                                        title: Text(
                                          "I agree to the Terms and Conditions. "
                                          "My data will be used for future updates and contact.",
                                          overflow: TextOverflow.ellipsis,
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
                                      SizedBox(height: 24),
                                      ElevatedButton(
                                        onPressed: () {
                                          _agreeValidation();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue[700],
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          minimumSize: Size(
                                            double.infinity,
                                            50,
                                          ),
                                        ),
                                        child: Text(
                                          'Update',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ],
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
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue[700],
        ),
        textAlign: TextAlign.start,
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String controllerKey, {
    TextInputType? keyboardType,
    bool isUnique = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: TextFormField(
        maxLength: controllerKey == 'adhaar_card_no'
            ? 12
            : controllerKey == 'pan_card_no'
                ? 10
                : controllerKey == 'pin_code'
                    ? 6
                    : controllerKey == 'phone_number'
                        ? 10
                        : controllerKey == 'driver_code'
                            ? 4
                            : null,
        controller: _controllers[controllerKey],
        onChanged: controllerKey == 'phone_number'
            ? (value) {
                if (value.length == 10) {
                  checkPhoneNumber();
                } else {
                  setState(() {
                    driverFrom = false;
                    newdriverForm = false;
                    driverCodeField = false;
                    _controllers['driver_code']?.clear();
                  });
                }
              }
            : controllerKey == 'driver_code'
                ? (value) {
                    if (value.length == 4) {
                      String drivercodeinput =
                          _controllers['driver_code']?.text.trim() ?? '';
                      if (drivercodeinput == driverCode) {
                        setState(() {
                          newdriverForm = true;
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Please enter a valid driver code"),
                          ),
                        );
                      }
                    } else {
                      setState(() {
                        driverFrom = false;
                        newdriverForm = false;
                      });
                    }
                  }
                : null,
        decoration: _buildInputDecoration(label),
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'This field is required';
          }
          if (controllerKey == 'phone_number') {
            if (!RegExp(r'^\d{10}$').hasMatch(value)) {
              return 'Phone number must be exactly 10 digits';
            }
            // Check if matches stored number
          }
          if (controllerKey == 'pin_code') {
            if (!RegExp(r'^\d{6}$').hasMatch(value)) {
              return 'Phone number must be exactly 6 digits';
            }
          }
          if (controllerKey == 'adhaar_card_no') {
            if (!RegExp(r'^\d{12}$').hasMatch(value)) {
              return 'Aadhaar Number must be exactly 12 digits';
            }
          }
          if (controllerKey == 'pan_card_no') {
            if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(value)) {
              return 'It must be in format: ABCDE1234F';
            }
          }

          if (isUnique && _uniqueValues.contains(value)) {
            return 'This $label is already used';
          }
          if (isUnique) {
            _uniqueValues.add(value);
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDateField(String label, String controllerKey) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: _controllers[controllerKey],
        decoration: _buildInputDecoration(label).copyWith(
          hintText: 'DD-MM-YYYY (e.g., 28-03-2025)',
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
        readOnly: true,
        onTap: () async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime(2100),
          );

          if (pickedDate != null) {
            String formattedDate = DateFormat('dd-MM-yyyy').format(pickedDate);
            _controllers[controllerKey]!.text = formattedDate;
          }
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'This field is required';
          }
          return _dateValidator(value);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }
}
