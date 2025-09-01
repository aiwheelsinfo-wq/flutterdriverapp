import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'driver_reg_success.dart';

class DriverFormPage extends StatefulWidget {
  final String? phoneNumber; // Accept phone number for editing

  DriverFormPage({this.phoneNumber});

  @override
  _DriverFormPageState createState() => _DriverFormPageState();
}

class _DriverFormPageState extends State<DriverFormPage> {
  final ScrollController _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();
  late Map<String, TextEditingController> _controllers;
  TextEditingController _fuelTypeController = TextEditingController();
  final Set<String> _uniqueValues = {};
  bool isLoading = true;
  bool _isDropdownOpen = false;
  String? _selectedItem;

  @override
  void initState() {
    super.initState();
    _controllers = {
      'phone_number': TextEditingController(
        text: widget.phoneNumber ?? '1234567890',
      ),
      'full_name': TextEditingController(),
      'email': TextEditingController(),
      'vehicle_id': TextEditingController(),
      'vehicle_type': TextEditingController(),
      'vehicle_name': TextEditingController(),
      'driver_address': TextEditingController(),
      'date_of_birth': TextEditingController(),
      'pin_code': TextEditingController(),
      'license_no': TextEditingController(),
      'license_doe': TextEditingController(),
      'license_type': TextEditingController(),
      'adhaar_card_no': TextEditingController(),
      'pan_card_no': TextEditingController(),
      'rc_no': TextEditingController(),
      'rc_name': TextEditingController(),
      'rc_manufecture_date': TextEditingController(),
      'insurnce_number': TextEditingController(),
      'insurnce_doe': TextEditingController(),
      'puc_doi': TextEditingController(),
      'puc_doe': TextEditingController(),
      'texi_permit_no': TextEditingController(),
      'texi_permit_doi': TextEditingController(),
      'texi_permit_doe': TextEditingController(),
      'fitness_certificate_no': TextEditingController(),
      'fitness_certificate_doi': TextEditingController(),
      'fitness_certificate_doe': TextEditingController(),
    };

    if (widget.phoneNumber != null) {
      fetchDriverDetails();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchDriverDetails() async {
    try {
      final response = await http.get(
        Uri.parse('https://agnicarrental.com/driver2025/register_driver.php'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final driver = (data['driversdata'] as List).firstWhere(
          (d) => d['phone_number'] == widget.phoneNumber,
          orElse: () => null,
        );
        if (driver != null) {
          setState(() {
            _controllers['full_name']!.text = driver['full_name'] ?? '';
            _controllers['email']!.text = driver['email'] ?? '';
            _controllers['vehicle_id']!.text = driver['vehicle_id'] ?? '';
            _controllers['vehicle_type']!.text = driver['vehicle_type'] ?? '';
            _controllers['vehicle_name']!.text = driver['vehicle_name'] ?? '';
            _controllers['driver_address']!.text =
                driver['driver_address'] ?? '';
            _controllers['date_of_birth']!.text = driver['date_of_birth'] ?? '';
            _controllers['pin_code']!.text = driver['pin_code'] ?? '';
            _controllers['license_no']!.text = driver['license_no'] ?? '';
            _controllers['license_doe']!.text = driver['license_doe'] ?? '';
            _controllers['license_type']!.text = driver['license_type'] ?? '';
            _controllers['adhaar_card_no']!.text =
                driver['adhaar_card_no'] ?? '';
            _controllers['pan_card_no']!.text = driver['pan_card_no'] ?? '';
            _controllers['rc_no']!.text = driver['rc_no'] ?? '';
            _controllers['rc_name']!.text = driver['rc_name'] ?? '';
            _controllers['rc_manufecture_date']!.text =
                driver['rc_manufecture_date'] ?? '';
            _controllers['insurnce_number']!.text =
                driver['insurnce_number'] ?? '';
            _controllers['insurnce_doe']!.text = driver['insurnce_doe'] ?? '';
            _controllers['puc_doi']!.text = driver['puc_doi'] ?? '';
            _controllers['puc_doe']!.text = driver['puc_doe'] ?? '';
            _controllers['texi_permit_no']!.text =
                driver['texi_permit_no'] ?? '';
            _controllers['texi_permit_doi']!.text =
                driver['texi_permit_doi'] ?? '';
            _controllers['texi_permit_doe']!.text =
                driver['texi_permit_doe'] ?? '';
            _controllers['fitness_certificate_no']!.text =
                driver['fitness_certificate_no'] ?? '';
            _controllers['fitness_certificate_doi']!.text =
                driver['fitness_certificate_doi'] ?? '';
            _controllers['fitness_certificate_doe']!.text =
                driver['fitness_certificate_doe'] ?? '';
            isLoading = false;
          });
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(
              content: Text(
            'Driver not found',
            overflow: TextOverflow.ellipsis,
          )));
          setState(() {
            isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load driver details');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context);
    }
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

    // Validate DD-MM-YYYY format
    final RegExp dateRegExp = RegExp(r'^\d{2}-\d{2}-\d{4}$');
    if (!dateRegExp.hasMatch(value)) {
      return 'Enter date in DD-MM-YYYY format';
    }

    try {
      final parts = value.split('-');
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      // Validate date ranges
      if (month < 1 || month > 12) return 'Month must be between 01 and 12';
      if (day < 1 || day > 31) return 'Day must be between 01 and 31';
      if (year < 1900 || year > 2100)
        return 'Year must be between 1900 and 2100';

      // Check if the date is valid
      final date = DateTime(year, month, day);
      if (date.day != day || date.month != month || date.year != year) {
        return 'Invalid date';
      }
      return null; // Valid date
    } catch (e) {
      return 'Invalid date';
    }
  }

  void _scrollToTop() {
    // Scroll the form to the top
    _scrollController.animateTo(0,
        duration: Duration(milliseconds: 5000), curve: Curves.easeInOut);
  }

// Convert DD-MM-YYYY to YYYY-MM-DD for Backend
  String convertDateToBackend(String date) {
    final parts = date.split('-');
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  Future<void> _submitForm() async {
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
          'vehicle_id': _controllers['vehicle_id']!.text.isEmpty
              ? null
              : _controllers['vehicle_id']!.text,
          'vehicle_type': _controllers['vehicle_type']!.text.isEmpty
              ? null
              : _controllers['vehicle_type']!.text,
          'vehicle_name': _controllers['vehicle_name']!.text.isEmpty
              ? null
              : _controllers['vehicle_name']!.text,
          'driver_address': _controllers['driver_address']!.text.isEmpty
              ? null
              : _controllers['driver_address']!.text,
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
          'rc_no': _controllers['rc_no']!.text.isEmpty
              ? null
              : _controllers['rc_no']!.text,
          'rc_name': _controllers['rc_name']!.text.isEmpty
              ? null
              : _controllers['rc_name']!.text,
          'rc_manufecture_date': _controllers['rc_manufecture_date']!
                  .text
                  .isEmpty
              ? null
              : convertDateToBackend(_controllers['rc_manufecture_date']!.text),
          'insurnce_number': _controllers['insurnce_number']!.text.isEmpty
              ? null
              : _controllers['insurnce_number']!.text,
          'insurnce_doe': _controllers['insurnce_doe']!.text.isEmpty
              ? null
              : convertDateToBackend(_controllers['insurnce_doe']!.text),
          'puc_doi': _controllers['puc_doi']!.text.isEmpty
              ? null
              : convertDateToBackend(_controllers['puc_doi']!.text),
          'puc_doe': _controllers['puc_doe']!.text.isEmpty
              ? null
              : convertDateToBackend(_controllers['puc_doe']!.text),
          'texi_permit_no': _controllers['texi_permit_no']!.text.isEmpty
              ? null
              : _controllers['texi_permit_no']!.text,
          'texi_permit_doi': _controllers['texi_permit_doi']!.text.isEmpty
              ? null
              : convertDateToBackend(_controllers['texi_permit_doi']!.text),
          'texi_permit_doe': _controllers['texi_permit_doe']!.text.isEmpty
              ? null
              : convertDateToBackend(_controllers['texi_permit_doe']!.text),
          'fitness_certificate_no':
              _controllers['fitness_certificate_no']!.text.isEmpty
                  ? null
                  : _controllers['fitness_certificate_no']!.text,
          'fitness_certificate_doi':
              _controllers['fitness_certificate_doi']!.text.isEmpty
                  ? null
                  : convertDateToBackend(
                      _controllers['fitness_certificate_doi']!.text),
          'fitness_certificate_doe':
              _controllers['fitness_certificate_doe']!.text.isEmpty
                  ? null
                  : convertDateToBackend(
                      _controllers['fitness_certificate_doe']!.text),
          'fuel_type': _fuelTypeController.text,
        };

        // Update driver details instead of adding new
        final url = Uri.parse(
          'https://agnicarrental.com/driver2025/register_driver.php',
        );
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        );

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ?? 'Driver updated successfully',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (context) => SubmitSuccessPage(
                    message: "Driver updated successfully!",
                    phoneNumber: widget.phoneNumber!)), // New screen
            (Route<dynamic> route) => false, // Remove all previous routes
          );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.phoneNumber != null ? 'Driver Registration' : 'Edit Driver'),
        elevation: 0,
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scrollController,
              child: Container(
                color: Colors.grey[100],
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Personal Information'),
                        _buildTextField('Phone Number', 'phone_number'),
                        _buildTextField('Full Name', 'full_name'),
                        _buildTextField('Email', 'email'),
                        _buildTextField('Address', 'driver_address'),
                        _buildDateField('Date of Birth', 'date_of_birth'),
                        _buildTextField('Pin Code', 'pin_code',
                            keyboardType: TextInputType.number),
                        _buildSectionTitle('Identification'),
                        _buildTextField('Aadhaar Card No', 'adhaar_card_no',
                            isUnique: true, keyboardType: TextInputType.number),
                        _buildTextField('PAN Card No', 'pan_card_no',
                            isUnique: true, keyboardType: TextInputType.number),
                        _buildSectionTitle('Vehicle Information'),
                        _buildTextField(
                          'Vehicle Number',
                          'vehicle_id',
                          isUnique: true,
                        ),
                        _buildTextField(
                            'Vehicle Type (e.g: Sedan, SUV)', 'vehicle_type'),
                        _buildTextField('Vehicle Name (e.g: Etios, Innova)',
                            'vehicle_name'),

                        // Show the dropdown list when the dropdown is open

                        // Display the value from the controller
                        _buildDropdown('Select Fuel'),
                        _isDropdownOpen ? _dropDown() : SizedBox(),
                        _buildSectionTitle('License Details'),
                        _buildTextField(
                          'License No',
                          'license_no',
                          isUnique: true,
                        ),
                        _buildDateField('License DOE', 'license_doe'),
                        _buildTextField('License Type', 'license_type'),
                        _buildSectionTitle('Registration Details'),
                        _buildTextField('RC No', 'rc_no', isUnique: true),
                        _buildTextField('RC Owner Name', 'rc_name'),
                        _buildDateField(
                          'Manufacture Date',
                          'rc_manufecture_date',
                        ),
                        _buildSectionTitle('Insurance & Permits'),
                        _buildTextField(
                          'Insurance Number',
                          'insurnce_number',
                          isUnique: true,
                        ),
                        _buildDateField('Insurance DOE', 'insurnce_doe'),
                        _buildDateField('PUC DOI', 'puc_doi'),
                        _buildDateField('PUC DOE', 'puc_doe'),
                        _buildTextField(
                          'Taxi Permit No',
                          'texi_permit_no',
                          isUnique: true,
                        ),
                        _buildDateField('Taxi Permit DOI', 'texi_permit_doi'),
                        _buildDateField('Taxi Permit DOE', 'texi_permit_doe'),
                        _buildTextField(
                          'Fitness Certificate No',
                          'fitness_certificate_no',
                          isUnique: true,
                        ),
                        _buildDateField(
                          'Fitness Certificate DOI',
                          'fitness_certificate_doi',
                        ),
                        _buildDateField(
                          'Fitness Certificate DOE',
                          'fitness_certificate_doe',
                        ),
                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: Size(double.infinity, 50),
                          ),
                          child: Text('Update',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 16)),
                        ),
                      ],
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
                    : null,
        controller: _controllers[controllerKey],
        decoration: _buildInputDecoration(label).copyWith(
          fillColor: controllerKey == 'phone_number' ? Colors.grey[200] : null,
          enabledBorder: controllerKey == 'phone_number'
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[400]!),
                )
              : null,
        ),
        keyboardType: keyboardType,
        readOnly: controllerKey == 'phone_number',
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'This field is required'; // Required validation
          }
          if (controllerKey == 'adhaar_card_no') {
            if (!RegExp(r'^\d{12}$').hasMatch(value)) {
              return 'Aadhaar Number must be exactly 12 digits'; // Aadhaar validation
            }
          }
          if (controllerKey == 'pan_card_no') {
            if (!RegExp(r'^\d{10}$').hasMatch(value)) {
              return 'Pan card Number must be exactly 10 digits'; // Aadhaar validation
            }
          }

          if (isUnique && _uniqueValues.contains(value)) {
            return 'This $label is already used'; // Unique validation
          }
          if (isUnique) {
            _uniqueValues.add(value); // Add to the set if unique
          }
          return null; // Valid input
        },
      ),
    );
  }

  Widget _buildDropdown(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: _fuelTypeController,
        decoration: _buildInputDecoration(label).copyWith(
          hintText: 'Select Fuel',
          hintStyle: TextStyle(color: Colors.grey[400]),
          labelText: label, // Add labelText if needed
          // Set the text based on selected item
          labelStyle: TextStyle(
            color: _selectedItem == '' ? Colors.grey : Colors.black,
          ),
        ),
        readOnly: true,
        onTap: () {
          setState(() {
            _isDropdownOpen = !_isDropdownOpen;
          });
        },
      ),
    );
  }

  Widget _dropDown() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8),
      margin: EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      child: Column(
        children: [
          ...fuelTypes.map((item) {
            return Column(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedItem = item;
                      _isDropdownOpen = false;

                      _fuelTypeController.text = _selectedItem!;

                      // Close dropdown after selection
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      item,
                      style: TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Divider between each item
                Divider(
                  color: Colors.grey[300],
                  thickness: 1,
                ),
              ],
            );
          }).toList(),
        ],
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
        readOnly: true, // Prevent manual typing
        onTap: () async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime(2100),
          );

          if (pickedDate != null) {
            String formattedDate = DateFormat('dd-MM-yyyy').format(pickedDate);
            _controllers[controllerKey]!.text =
                formattedDate; // Set the selected date
          }
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'This field is required'; // Check for empty values
          }
          return _dateValidator(value); // Validate the date format
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
