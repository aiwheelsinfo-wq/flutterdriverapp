import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

import 'checkAndRoot.dart';
import 'driver_add_form.dart';

// --- CUSTOM FORMATTER FOR FORCED UPPERCASE ---
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class CarFormPage extends StatefulWidget {
  const CarFormPage({super.key});

  @override
  _CarFormPageState createState() => _CarFormPageState();
}

class _CarFormPageState extends State<CarFormPage> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  final ScrollController _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();

  late Map<String, TextEditingController> _controllers;

  bool isLoading = true;
  bool isSubmitting = false;
  String? _selectedFuelItem;
  String? _selectedPlateColor;
  String? _selectedLicenseType;
  bool addNewBtn = false;
  bool nextStepBtn = false;
  bool addcabsuccess = false;
  bool carForm = true;
  bool _isAgree = false;
  bool nextBtn = false;
  String? phoneNumber;

  // Professional Amber Theme Palette
  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color accentAmber = Color(0xFFFF8F00);
  static const Color bgLight = Color(0xFFFFFBF0);
  static const Color charcoal = Color(0xFF2D2D2D);

  final List<String> fuelTypes = [
    'PETROL',
    'PETROL & CNG',
    'DIESEL',
    'EV',
    'HYBRID'
  ];
  final List<String> plateColors = [
    'YELLOW PLATE',
    'WHITE PLATE',
    'GREEN PLATE'
  ];

  // 4-Wheeler & Above Indian License Categories
  final List<String> indianLicenseTypes = [
    'LMV (LIGHT MOTOR VEHICLE - CARS/JEEPS)',
    'LMV-TR (TRANSPORT - COMMERCIAL TAXIS)',
    'LMV-GV (GOODS CARRIER - DELIVERY VANS)',
    'TRANS (TRANSPORT - COMPREHENSIVE)',
    'HPMV (HEAVY PASSENGER VEHICLE - BUS)',
    'HGMV (HEAVY GOODS VEHICLE - TRUCK)',
    'TRAILER (HEAVY VEHICLE WITH TRAILER)',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    fetchDriverDetails();
  }

  void _initializeControllers() {
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
  }

  Future<void> fetchDriverDetails() async {
    phoneNumber = await secureStorage.read(key: "phone_number");
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.registerDriver}?phone_number=$phoneNumber'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> driversData = data['driversdata'] ?? [];
        if (mounted && driversData.isNotEmpty) {
          setState(() => nextBtn = driversData[0]['status'] != 'not car');
        }
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _formatToBackend(String date) {
    if (date.isEmpty) return "";
    try {
      final parts = date.split('-');
      return '${parts[2]}-${parts[1]}-${parts[0]}';
    } catch (e) {
      return "";
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isAgree) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PLEASE AGREE TO THE TERMS")));
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final Map<String, dynamic> data = {
        'fuel_type': _selectedFuelItem,
        'plate_color': _selectedPlateColor,
        'phone_number': phoneNumber,
      };

      _controllers.forEach((key, controller) {
        if (key.contains('doe') ||
            key.contains('doi') ||
            key.contains('date')) {
          data[key] = _formatToBackend(controller.text);
        } else {
          data[key] = controller.text;
        }
      });

      final resp = await http.post(
        Uri.parse(ApiConfig.registerCar),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (resp.statusCode == 200) {
        setState(() {
          carForm = false;
          addcabsuccess = true;
          addNewBtn = true;
          nextStepBtn = true;
        });
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
      } else {
        throw "REGISTRATION FAILED. VEHICLE MAY ALREADY EXIST.";
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  // --- REUSABLE UI BUILDERS ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 30, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: accentAmber, size: 20),
          const SizedBox(width: 10),
          Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: charcoal)),
          const SizedBox(width: 10),
          const Expanded(child: Divider(thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String apiKey,
    String? hint,
    bool isDate = false,
    bool isRequired = true,
  }) {
    bool isOptionalForYellow = [
          'texi_permit_no',
          'texi_permit_doi',
          'texi_permit_doe',
          'fitness_certificate_no',
          'fitness_certificate_doi',
          'fitness_certificate_doe'
        ].contains(apiKey) &&
        _selectedPlateColor != 'YELLOW PLATE';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: _controllers[apiKey],
        readOnly: isDate,
        onTap: isDate ? () => _pickDate(apiKey) : null,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [UpperCaseTextFormatter()],
        style: const TextStyle(fontSize: 15, color: charcoal),
        decoration: InputDecoration(
          labelText: label.toUpperCase(),
          labelStyle: TextStyle(color: charcoal.withOpacity(0.6), fontSize: 12),
          hintText: hint?.toUpperCase(),
          hintStyle: TextStyle(color: charcoal.withOpacity(0.3), fontSize: 13),
          suffixIcon: isDate
              ? const Icon(Icons.calendar_month, size: 18, color: primaryAmber)
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryAmber, width: 2)),
        ),
        validator: (val) {
          if (isOptionalForYellow) return null;
          if (isRequired && (val == null || val.isEmpty)) return "REQUIRED";
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required List<String> items,
    required String? value,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label.toUpperCase(),
          labelStyle: TextStyle(color: charcoal.withOpacity(0.6), fontSize: 12),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
        items: items
            .map((e) => DropdownMenuItem(
                value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? "REQUIRED" : null,
      ),
    );
  }

  Future<void> _pickDate(String key) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: primaryAmber)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _controllers[key]!.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("VEHICLE ONBOARDING",
            style: TextStyle(
                color: charcoal, fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: charcoal),
            onPressed: () => Navigator.pop(context)),
        actions: [
          if (nextBtn)
            TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (c) => const checAbdRoot())),
                child: const Text("SKIP",
                    style: TextStyle(
                        color: accentAmber, fontWeight: FontWeight.bold))),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryAmber))
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    children: [
                      if (addcabsuccess) _buildSuccessBanner(),
                      if (carForm) _buildMainForm(),
                      if (addNewBtn) _buildFooterButtons(),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 25),
      decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.green.shade200)),
      child: const Row(children: [
        Icon(Icons.verified, color: Colors.green, size: 30),
        SizedBox(width: 15),
        Expanded(
            child: Text("VEHICLE ADDED SUCCESSFULLY!",
                style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16))),
      ]),
    );
  }

  Widget _buildMainForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Vehicle Basics", Icons.directions_car),
          _buildField(
              label: "Vehicle Reg Number",
              apiKey: "vehicle_id",
              hint: "Ex: MH 12 AB 1234"),
          Row(
            children: [
              Expanded(
                  child: _buildField(
                      label: "Vehicle Type",
                      apiKey: "vehicle_type",
                      hint: "Ex: SEDAN")),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildField(
                      label: "Model Name",
                      apiKey: "vehicle_name",
                      hint: "Ex: SWIFT DZIRE")),
            ],
          ),
          _buildDropdown(
              label: "Fuel Type",
              items: fuelTypes,
              value: _selectedFuelItem,
              onChanged: (v) => setState(() => _selectedFuelItem = v)),
          _buildDropdown(
              label: "Number Plate Color",
              items: plateColors,
              value: _selectedPlateColor,
              onChanged: (v) => setState(() => _selectedPlateColor = v)),

          _buildSectionHeader("License Information", Icons.badge),
          _buildField(
              label: "License Number",
              apiKey: "license_no",
              hint: "Ex: MH12 20100012345"),
          _buildDropdown(
              label: "License Category (4-Wheel & Above)",
              items: indianLicenseTypes,
              value: _selectedLicenseType,
              onChanged: (v) {
                setState(() {
                  _selectedLicenseType = v;
                  _controllers['license_type']!.text = v ?? '';
                });
              }),
          _buildField(
              label: "License Expiry (DOE)",
              apiKey: "license_doe",
              isDate: true),

          _buildSectionHeader("RC Details", Icons.assignment),
          _buildField(
              label: "RC Number", apiKey: "rc_no", hint: "Ex: ABC123456789"),
          _buildField(
              label: "Owner Name (As on RC)",
              apiKey: "rc_name",
              hint: "Ex: RAJESH KUMAR"),
          _buildField(
              label: "RC Expiry Date",
              apiKey: "rc_manufecture_date",
              isDate: true),

          _buildSectionHeader("Insurance & PUC", Icons.verified_user),
          _buildField(
              label: "Insurance Policy No",
              apiKey: "insurance_number",
              hint: "Ex: POL1234567"),
          _buildField(
              label: "Insurance Expiry", apiKey: "insurance_doe", isDate: true),
          Row(
            children: [
              Expanded(
                  child: _buildField(
                      label: "PUC DOI",
                      apiKey: "puc_doi",
                      isDate: true,
                      isRequired: false)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildField(
                      label: "PUC DOE",
                      apiKey: "puc_doe",
                      isDate: true,
                      isRequired: false)),
            ],
          ),

          // Conditional Yellow Plate Sections
          if (_selectedPlateColor == 'YELLOW PLATE') ...[
            _buildSectionHeader("Taxi Permit", Icons.business_center),
            _buildField(
                label: "Permit Number",
                apiKey: "texi_permit_no",
                isRequired: false,
                hint: "Ex: PMT998877"),
            Row(
              children: [
                Expanded(
                    child: _buildField(
                        label: "Permit DOI",
                        apiKey: "texi_permit_doi",
                        isDate: true,
                        isRequired: false)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildField(
                        label: "Permit DOE",
                        apiKey: "texi_permit_doe",
                        isDate: true,
                        isRequired: false)),
              ],
            ),
            _buildSectionHeader("Fitness Certificate", Icons.health_and_safety),
            _buildField(
                label: "Fitness Cert Number",
                apiKey: "fitness_certificate_no",
                isRequired: false,
                hint: "Ex: FIT112233"),
            Row(
              children: [
                Expanded(
                    child: _buildField(
                        label: "Fitness DOI",
                        apiKey: "fitness_certificate_doi",
                        isDate: true,
                        isRequired: false)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildField(
                        label: "Fitness DOE",
                        apiKey: "fitness_certificate_doe",
                        isDate: true,
                        isRequired: false)),
              ],
            ),
          ],

          const SizedBox(height: 30),
          _buildAgreementSection(),
          const SizedBox(height: 25),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildAgreementSection() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: CheckboxListTile(
        activeColor: primaryAmber,
        title: const Text(
            "I HEREBY DECLARE THAT ALL PROVIDED DOCUMENTS ARE AUTHENTIC AND VALID.",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        value: _isAgree,
        onChanged: (v) => setState(() => _isAgree = v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: charcoal,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15))),
        onPressed: isSubmitting ? null : _submitForm,
        child: isSubmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("REGISTER VEHICLE",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
      ),
    );
  }

  Widget _buildFooterButtons() {
    return Column(
      children: [
        const SizedBox(height: 15),
        OutlinedButton(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                side: const BorderSide(color: accentAmber)),
            onPressed: () {
              setState(() {
                carForm = true;
                addcabsuccess = false;
                addNewBtn = false;
                _initializeControllers();
                _selectedFuelItem = null;
                _selectedPlateColor = null;
                _selectedLicenseType = null;
                _isAgree = false;
              });
            },
            child: const Text("ADD ANOTHER VEHICLE",
                style: TextStyle(
                    color: accentAmber, fontWeight: FontWeight.bold))),
        const SizedBox(height: 15),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 55),
              backgroundColor: primaryAmber),
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (c) => DriverFormPage())),
          child: const Text("GO TO NEXT STEP",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controllers.forEach((k, v) => v.dispose());
    super.dispose();
  }
}
