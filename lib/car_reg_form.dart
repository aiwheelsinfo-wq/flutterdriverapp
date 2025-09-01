import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'checkAndRoot.dart';
import 'driver_add_form.dart';
// import 'driver_reg_success.dart';

class CarFormPage extends StatefulWidget {
  @override
  _CarFormPageState createState() => _CarFormPageState();
}

class _CarFormPageState extends State<CarFormPage> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  final ScrollController _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();
  late Map<String, TextEditingController> _controllers;
  TextEditingController _fuelTypeController = TextEditingController();
  TextEditingController _plateColorController = TextEditingController();
  final Set<String> _uniqueValues = {};
  bool isLoading = true;
  bool _isDropdownOpen = false;
  bool _isPlateColorDropdownOpen = false;
  String? _selectedFuelItem;
  String? _selectedPlateColor;
  bool addNewBtn = false;
  bool nextStepBtn = false;
  bool addcabsuccess = false;
  bool carForm = true;
  bool _isAgree = false;
  bool nextBtn = false;
  String? phoneNumber;

  @override
  void initState() {
    super.initState();
    _controllers = {
      'vehicle_id': TextEditingController(),
      'vehicle_type': TextEditingController(),
      'vehicle_name': TextEditingController(),
      'license_no': TextEditingController(),
      'license_doe': TextEditingController(),
      'license_type': TextEditingController(),
      'rc_no': TextEditingController(),
      'rc_name': TextEditingController(),
      'rc_manufecture_date': TextEditingController(),
      'insurance_number': TextEditingController(),
      'insurance_doe': TextEditingController(),
      'puc_doi': TextEditingController(),
      'puc_doe': TextEditingController(),
      'texi_permit_no': TextEditingController(),
      'texi_permit_doi': TextEditingController(),
      'texi_permit_doe': TextEditingController(),
      'fitness_certificate_no': TextEditingController(),
      'fitness_certificate_doi': TextEditingController(),
      'fitness_certificate_doe': TextEditingController(),
    };

    fetchDriverDetails();

    setState(() {
      isLoading = false;
    });
  }

  void clearAllControllers() {
    _controllers.forEach((key, controller) {
      controller.clear();
    });
    _fuelTypeController.clear();
    _plateColorController.clear();
  }

  Future<void> fetchDriverDetails() async {
    phoneNumber = await secureStorage.read(key: "phone_number");
    print("Fetching driver details...");
    try {
      final response = await http.get(
        Uri.parse(
          'https://agnicarrental.com/driver2025/register_driver.php?phone_number=$phoneNumber',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Response data: $data");

        final List<dynamic> driversData = data['driversdata'];
        final driver = driversData.isNotEmpty ? driversData[0] : null;

        if (driver != null) {
          print("Driver Status: ${driver['status']}");

          if (driver['status'] != 'not car') {
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
        isLoading = false;
        nextBtn = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
        ),
      );
      print("Error fetching driver details: $e");
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

  String? _dateValidator(String? value, {bool isRequired = false}) {
    if (isRequired && (value == null || value.isEmpty))
      return 'This field is required';

    if (value == null || value.isEmpty) {
      return null;
    }

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

  void _agreeValidation() {
    if (_isAgree) {
      _submitForm();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Please agree to the terms and conditions",
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    phoneNumber = await secureStorage.read(key: "phone_number");
    _scrollToTop();
    _uniqueValues.clear();

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        String? getFieldValue(String controllerKey) {
          return _controllers[controllerKey]!.text.isEmpty
              ? null
              : _controllers[controllerKey]!.text;
        }

        final data = {
          'vehicle_id': getFieldValue('vehicle_id'),
          'vehicle_type': getFieldValue('vehicle_type'),
          'vehicle_name': getFieldValue('vehicle_name'),
          'license_no': getFieldValue('license_no'),
          'license_doe': getFieldValue('license_doe') != null
              ? convertDateToBackend(_controllers['license_doe']!.text)
              : null,
          'license_type': getFieldValue('license_type'),
          'rc_no': getFieldValue('rc_no'),
          'rc_name': getFieldValue('rc_name'),
          'rc_manufecture_date': getFieldValue('rc_manufecture_date') != null
              ? convertDateToBackend(_controllers['rc_manufecture_date']!.text)
              : null,
          'insurance_number': getFieldValue('insurance_number'),
          'insurance_doe': getFieldValue('insurance_doe') != null
              ? convertDateToBackend(_controllers['insurance_doe']!.text)
              : null,
          'puc_doi': getFieldValue('puc_doi') != null
              ? convertDateToBackend(_controllers['puc_doi']!.text)
              : null,
          'puc_doe': getFieldValue('puc_doe') != null
              ? convertDateToBackend(_controllers['puc_doe']!.text)
              : null,
          'texi_permit_no': getFieldValue('texi_permit_no'),
          'texi_permit_doi': getFieldValue('texi_permit_doi') != null
              ? convertDateToBackend(_controllers['texi_permit_doi']!.text)
              : null,
          'texi_permit_doe': getFieldValue('texi_permit_doe') != null
              ? convertDateToBackend(_controllers['texi_permit_doe']!.text)
              : null,
          'fitness_certificate_no': getFieldValue('fitness_certificate_no'),
          'fitness_certificate_doi':
              getFieldValue('fitness_certificate_doi') != null
                  ? convertDateToBackend(
                      _controllers['fitness_certificate_doi']!.text)
                  : null,
          'fitness_certificate_doe':
              getFieldValue('fitness_certificate_doe') != null
                  ? convertDateToBackend(
                      _controllers['fitness_certificate_doe']!.text)
                  : null,
          'fuel_type': _fuelTypeController.text,
          'plate_color': _plateColorController.text,
          'phone_number': phoneNumber
        };

        final url =
            Uri.parse('https://agnicarrental.com/driver2025/register_car.php');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data),
        );

        print('Response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          Map<String, dynamic> responseBody = jsonDecode(response.body);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                responseBody['message'] ?? 'Driver updated successfully',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );

          setState(() {
            carForm = false;
            addNewBtn = true;
            nextStepBtn = true;
            addcabsuccess = true;
          });

          clearAllControllers();
        } else {
          Map<String, dynamic> errorResponse = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${errorResponse['message']} - This cab is already added!',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
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

  final List<String> plateColors = [
    'Yellow',
    'White',
    'Black',
    'Green',
    'Red',
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Cab Registration",
                overflow: TextOverflow.ellipsis,
              ),
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
                      ))
                  : SizedBox(),
            ],
          ),
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                controller: _scrollController,
                child: Container(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(30.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 40,
                          ),
                          if (addcabsuccess)
                            Column(
                              children: [
                                Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(30),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.green, width: 2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check,
                                            color: Colors.green, size: 30.0),
                                        Text(
                                          "Your Cab is Added Successfully",
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    )),
                                SizedBox(
                                  height: 50,
                                )
                              ],
                            ),
                          if (addNewBtn && nextStepBtn)
                            Padding(
                              padding: const EdgeInsets.only(top: 20.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                        carForm = true;
                                        addNewBtn = false;
                                        nextStepBtn = false;
                                        addcabsuccess = false;
                                        fetchDriverDetails();
                                      });
                                    },
                                    child: SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          0.3,
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
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                DriverFormPage()),
                                      );
                                    },
                                    child: SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          0.3,
                                      child: Center(
                                        child: Text(
                                          "Next Step",
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (carForm)
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Add Your Cab",
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 40,
                                  ),
                                  textAlign: TextAlign.start,
                                ),
                                Text(
                                  "Let's Drive Your Business Forward,  Register Your Car with Us and Get Ready to Hit the Road!",
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Divider(),
                                SizedBox(
                                  height: 30,
                                ),
                                _buildSectionTitle('Vehicle Information'),
                                _buildTextField(
                                  'Vehicle Number',
                                  'vehicle_id',
                                  isUnique: true,
                                ),
                                _buildTextField(
                                  'Vehicle Type (e.g: Sedan, SUV)',
                                  'vehicle_type',
                                ),
                                _buildTextField(
                                  'Vehicle Name (e.g: Etios, Innova)',
                                  'vehicle_name',
                                ),
                                _buildDropdown(
                                    'Select Fuel',
                                    _fuelTypeController,
                                    fuelTypes,
                                    _isDropdownOpen,
                                    _selectedFuelItem, (item) {
                                  setState(() {
                                    _selectedFuelItem = item;
                                    _isDropdownOpen = false;
                                    _fuelTypeController.text = item!;
                                  });
                                }),
                                _isDropdownOpen
                                    ? _dropDown(fuelTypes, _selectedFuelItem,
                                        (item) {
                                        setState(() {
                                          _selectedFuelItem = item;
                                          _isDropdownOpen = false;
                                          _fuelTypeController.text = item!;
                                        });
                                      })
                                    : SizedBox(),
                                _buildDropdown(
                                    'Number Plate Color',
                                    _plateColorController,
                                    plateColors,
                                    _isPlateColorDropdownOpen,
                                    _selectedPlateColor, (item) {
                                  setState(() {
                                    _selectedPlateColor = item;
                                    _isPlateColorDropdownOpen = false;
                                    _plateColorController.text = item!;
                                  });
                                }),
                                _isPlateColorDropdownOpen
                                    ? _dropDown(
                                        plateColors, _selectedPlateColor,
                                        (item) {
                                        setState(() {
                                          _selectedPlateColor = item;
                                          _isPlateColorDropdownOpen = false;
                                          _plateColorController.text = item!;
                                        });
                                      })
                                    : SizedBox(),
                                _buildSectionTitle('Registration Details'),
                                _buildTextField('RC No', 'rc_no',
                                    isUnique: true),
                                _buildTextField('RC Owner Name', 'rc_name'),
                                _buildDateField(
                                  'Manufacture Date',
                                  'rc_manufecture_date',
                                ),
                                _buildSectionTitle('Insurance'),
                                _buildTextField(
                                  'Insurance Number',
                                  'insurance_number',
                                  isUnique: true,
                                ),
                                _buildDateField(
                                    'Insurance DOE', 'insurance_doe'),
                                _buildSectionTitle('PUC'),
                                _buildDateField('PUC DOI', 'puc_doi',
                                    isRequired: false),
                                _buildDateField('PUC DOE', 'puc_doe',
                                    isRequired: false),
                                _buildSectionTitle('Taxi Permit'),
                                _buildTextField(
                                  'Taxi Permit No',
                                  'texi_permit_no',
                                  isUnique: true,
                                ),
                                _buildDateField(
                                    'Taxi Permit DOI', 'texi_permit_doi'),
                                _buildDateField(
                                    'Taxi Permit DOE', 'texi_permit_doe'),
                                _buildSectionTitle('Fitness'),
                                _buildTextField('Fitness Certificate No',
                                    'fitness_certificate_no',
                                    isUnique: true, isRequired: false),
                                _buildDateField('Fitness Certificate DOI',
                                    'fitness_certificate_doi',
                                    isRequired: false),
                                _buildDateField('Fitness Certificate DOE',
                                    'fitness_certificate_doe',
                                    isRequired: false),
                                SizedBox(height: 20),
                                CheckboxListTile(
                                  title: Text(
                                    "I agree to the Terms and Conditions. "
                                    "My data will be used for future updates and contact.",
                                    style: TextStyle(color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  value: _isAgree,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _isAgree = value!;
                                    });
                                  },
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                ),
                                SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _agreeValidation,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueGrey,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    minimumSize: Size(double.infinity, 50),
                                  ),
                                  child: Text(
                                    'Add',
                                    style: TextStyle(fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
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
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue[700],
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String controllerKey, {
    TextInputType? keyboardType,
    bool isUnique = false,
    bool isRequired = true,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: _controllers[controllerKey],
        decoration: _buildInputDecoration(label).copyWith(),
        keyboardType: keyboardType,
        readOnly: controllerKey == 'phone_number',
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'This field is required';
          }
          if (value == null || value.isEmpty) {
            return null;
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

  Widget _buildDropdown(
      String label,
      TextEditingController controller,
      List<String> items,
      bool isOpen,
      String? selectedItem,
      Function(String?) onSelect) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        decoration: _buildInputDecoration(label).copyWith(
          hintText: 'Select $label',
          hintStyle: TextStyle(color: Colors.grey[400]),
          labelStyle: TextStyle(
            color: selectedItem == null ? Colors.grey : Colors.black,
          ),
        ),
        readOnly: true,
        onTap: () {
          setState(() {
            if (label == 'Select Fuel') {
              _isDropdownOpen = !_isDropdownOpen;
              _isPlateColorDropdownOpen = false;
            } else {
              _isPlateColorDropdownOpen = !_isPlateColorDropdownOpen;
              _isDropdownOpen = false;
            }
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _dropDown(
      List<String> items, String? selectedItem, Function(String?) onSelect) {
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
          ...items.map((item) {
            return GestureDetector(
              onTap: () => onSelect(item),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item,
                            style: TextStyle(fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: Colors.grey[300], thickness: 1),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, String controllerKey,
      {bool isRequired = true}) {
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
        validator: (value) => _dateValidator(value, isRequired: isRequired),
      ),
    );
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    _fuelTypeController.dispose();
    _plateColorController.dispose();
    super.dispose();
  }
}
