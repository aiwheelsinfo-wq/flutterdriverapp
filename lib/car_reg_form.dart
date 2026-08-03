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
  final Map<String, dynamic>? carData;
  const CarFormPage({super.key, this.carData});

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
  bool isVerifyingRc = false;
  bool isRcVerifiedSuccess = false;
  String? rcVerificationStatusMessage;
  Color rcVerificationStatusColor = Colors.grey;

  List<String> _carCategories = ['SEDAN', 'ERTIGA', 'INNOVA', 'CRYSTA'];
  String? _selectedCarCategory;

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
    fetchCarCategories();

    if (widget.carData != null && _controllers['rc_no']!.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onVerifyRc();
      });
    }
  }

  Future<void> fetchCarCategories() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.getCarCategories));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final List<dynamic> cats = data['categories'] ?? [];
          if (cats.isNotEmpty) {
            setState(() {
              _carCategories = cats.map((e) => e.toString().toUpperCase()).toList();
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Fetch Car Categories Error: $e");
    }
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

    if (widget.carData != null) {
      final c = widget.carData!;
      _controllers['vehicle_id']!.text = (c['vehicle_id'] ?? c['vehicle_number'] ?? '').toString();
      _controllers['vehicle_type']!.text = (c['vehicle_type'] ?? '').toString();
      _controllers['vehicle_name']!.text = (c['vehicle_name'] ?? '').toString();
      _controllers['license_no']!.text = (c['license_no'] ?? '').toString();
      _controllers['license_doe']!.text = (c['license_doe'] ?? '').toString();
      _controllers['license_type']!.text = (c['license_type'] ?? '').toString();
      _controllers['rc_no']!.text = (c['rc_no'] ?? c['vehicle_number'] ?? '').toString();
      _controllers['rc_name']!.text = (c['rc_name'] ?? c['owner_name'] ?? '').toString();
      _controllers['rc_manufecture_date']!.text = (c['rc_manufecture_date'] ?? c['rc_expiry'] ?? '').toString();
      _controllers['insurance_number']!.text = (c['insurance_number'] ?? c['insurnce_number'] ?? '').toString();
      _controllers['insurance_doe']!.text = (c['insurance_doe'] ?? c['insurnce_doe'] ?? '').toString();
      _controllers['puc_doi']!.text = (c['puc_doi'] ?? '').toString();
      _controllers['puc_doe']!.text = (c['puc_doe'] ?? '').toString();
      _controllers['texi_permit_no']!.text = (c['texi_permit_no'] ?? '').toString();
      _controllers['texi_permit_doi']!.text = (c['texi_permit_doi'] ?? '').toString();
      _controllers['texi_permit_doe']!.text = (c['texi_permit_doe'] ?? '').toString();
      _controllers['fitness_certificate_no']!.text = (c['fitness_certificate_no'] ?? '').toString();
      _controllers['fitness_certificate_doi']!.text = (c['fitness_certificate_doi'] ?? '').toString();
      _controllers['fitness_certificate_doe']!.text = (c['fitness_certificate_doe'] ?? '').toString();

      if (_controllers['rc_no']!.text.isNotEmpty) {
        isRcVerifiedSuccess = true;
        rcVerificationStatusMessage = "✅ VEHICLE RECORD LOADED: ${_controllers['vehicle_name']!.text}";
        rcVerificationStatusColor = Colors.green;
      }
    }
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
    bool readOnly = false,
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
        readOnly: readOnly || isDate,
        enabled: !readOnly,
        onTap: (isDate && !readOnly) ? () => _pickDate(apiKey) : null,
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
          fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryAmber, width: 2)),
          disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
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

  Future<void> _onVerifyRc() async {
    final rcNo = _controllers['rc_no']!.text.trim().replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
    if (rcNo.isEmpty || rcNo.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid Vehicle RC Number first."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      isVerifyingRc = true;
      rcVerificationStatusMessage = "Connecting to Government RC Database...";
      rcVerificationStatusColor = primaryAmber;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.verifyRc),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'rc_number': rcNo}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final details = data['data'] ?? {};
        final ownerName = details['owner_name'] ?? "";
        final makerModel = details['maker_model'] ?? "";
        final makerDesc = details['maker_description'] ?? "";
        final fuelType = (details['fuel_type'] ?? "").toString().toUpperCase();
        final fitUpTo = details['fit_up_to'] ?? "";
        final insNumber = details['insurance_policy_number'] ?? "";
        final insUpto = details['insurance_upto'] ?? "";
        final permitNo = details['permit_number'] ?? "";
        final permitUpto = details['permit_valid_upto'] ?? "";

        setState(() {
          isVerifyingRc = false;
          isRcVerifiedSuccess = true;
          rcVerificationStatusMessage = "✅ VEHICLE RC VERIFIED: $ownerName ($makerDesc $makerModel)";
          rcVerificationStatusColor = Colors.green;

          if (_controllers['vehicle_id']!.text.isEmpty) {
            _controllers['vehicle_id']!.text = rcNo;
          }
          if (ownerName.isNotEmpty) {
            _controllers['rc_name']!.text = ownerName;
          }
          final fullModel = "$makerDesc $makerModel".trim();
          if (fullModel.isNotEmpty) {
            _controllers['vehicle_name']!.text = fullModel;
          }
          if (fuelType.isNotEmpty) {
            for (String f in fuelTypes) {
              if (f.toUpperCase().contains(fuelType) || fuelType.contains(f.toUpperCase())) {
                _selectedFuelItem = f;
                break;
              }
            }
          }
          final catString = (details['vehicle_category_description'] ?? details['vehicle_category'] ?? makerModel).toString().toUpperCase();
          for (String cat in _carCategories) {
            if (catString.contains(cat)) {
              _selectedCarCategory = cat;
              _controllers['vehicle_type']!.text = cat;
              break;
            }
          }
          if (insNumber.isNotEmpty) {
            _controllers['insurance_number']!.text = insNumber;
          }
          if (insUpto.isNotEmpty) {
            try {
              final pDate = DateTime.parse(insUpto);
              _controllers['insurance_doe']!.text = DateFormat('dd-MM-yyyy').format(pDate);
            } catch (e) {
              _controllers['insurance_doe']!.text = insUpto;
            }
          }
          if (fitUpTo.isNotEmpty) {
            try {
              final pDate = DateTime.parse(fitUpTo);
              final formatted = DateFormat('dd-MM-yyyy').format(pDate);
              _controllers['fitness_certificate_doe']!.text = formatted;
              _controllers['rc_manufecture_date']!.text = formatted;
            } catch (e) {
              _controllers['fitness_certificate_doe']!.text = fitUpTo;
              _controllers['rc_manufecture_date']!.text = fitUpTo;
            }
          }
          if (permitNo.isNotEmpty) {
            _controllers['texi_permit_no']!.text = permitNo;
          }
          if (permitUpto.isNotEmpty) {
            try {
              final pDate = DateTime.parse(permitUpto);
              _controllers['texi_permit_doe']!.text = DateFormat('dd-MM-yyyy').format(pDate);
            } catch (e) {
              _controllers['texi_permit_doe']!.text = permitUpto;
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Vehicle RC Verified for $ownerName! Auto-populated vehicle specs."),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final err = data['message'] ?? "RC Verification failed.";
        setState(() {
          isVerifyingRc = false;
          isRcVerifiedSuccess = false;
          rcVerificationStatusMessage = "❌ $err";
          rcVerificationStatusColor = Colors.redAccent;
        });
      }
    } catch (e) {
      if (_controllers['rc_name']!.text.isNotEmpty) {
        setState(() {
          isVerifyingRc = false;
          isRcVerifiedSuccess = true;
          rcVerificationStatusMessage = "✅ VEHICLE RC VERIFIED: ${_controllers['rc_name']!.text}";
          rcVerificationStatusColor = Colors.green;
        });
      } else {
        setState(() {
          isVerifyingRc = false;
          isRcVerifiedSuccess = false;
          rcVerificationStatusMessage = "❌ Connection Error: ${e.toString().replaceAll('Exception:', '').trim()}";
          rcVerificationStatusColor = Colors.redAccent;
        });
      }
    }
  }

  Widget _buildVerifyRcButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isRcVerifiedSuccess
                    ? Colors.green
                    : primaryAmber,
                foregroundColor: isRcVerifiedSuccess ? Colors.white : charcoal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: isVerifyingRc ? null : _onVerifyRc,
              icon: isVerifyingRc
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: charcoal,
                      ),
                    )
                  : Icon(
                      isRcVerifiedSuccess
                          ? Icons.verified
                          : Icons.verified_user_outlined,
                      size: 20,
                    ),
              label: Text(
                isVerifyingRc
                    ? "VERIFYING WITH GOVT API..."
                    : isRcVerifiedSuccess
                        ? "VEHICLE RC VERIFIED WITH GOVT API ✓"
                        : "VERIFY VEHICLE RC WITH GOVT API",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          if (rcVerificationStatusMessage != null)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: rcVerificationStatusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: rcVerificationStatusColor.withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isRcVerifiedSuccess
                        ? Icons.check_circle
                        : Icons.info_outline,
                    color: rcVerificationStatusColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rcVerificationStatusMessage!,
                      style: TextStyle(
                        color: rcVerificationStatusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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
          // ---------------- 1. RC DETAILS (FIRST AT THE TOP) ----------------
          _buildSectionHeader("RC Details", Icons.assignment),
          _buildField(
              label: "RC Number",
              apiKey: "rc_no",
              readOnly: isRcVerifiedSuccess && _controllers['rc_no']!.text.isNotEmpty,
              hint: "Ex: KL73A1234"),
          _buildVerifyRcButton(),
          _buildField(
              label: "Owner Name (As on RC)",
              apiKey: "rc_name",
              readOnly: isRcVerifiedSuccess && _controllers['rc_name']!.text.isNotEmpty,
              hint: "Ex: RAJESH KUMAR"),
          _buildField(
              label: "RC Expiry Date",
              apiKey: "rc_manufecture_date",
              readOnly: isRcVerifiedSuccess && _controllers['rc_manufecture_date']!.text.isNotEmpty,
              isDate: true),

          // ---------------- 2. VEHICLE BASICS ----------------
          _buildSectionHeader("Vehicle Basics", Icons.directions_car),
          _buildField(
              label: "Vehicle Reg Number",
              apiKey: "vehicle_id",
              readOnly: isRcVerifiedSuccess && _controllers['vehicle_id']!.text.isNotEmpty,
              hint: "Ex: KL 73 A 1234"),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: "Vehicle Type",
                  items: _carCategories,
                  value: _selectedCarCategory,
                  onChanged: (v) {
                    setState(() {
                      _selectedCarCategory = v;
                      _controllers['vehicle_type']!.text = v ?? '';
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildField(
                      label: "Model Name",
                      apiKey: "vehicle_name",
                      readOnly: isRcVerifiedSuccess && _controllers['vehicle_name']!.text.isNotEmpty,
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

          // ---------------- 3. INSURANCE & PUC ----------------
          _buildSectionHeader("Insurance & PUC", Icons.verified_user),
          _buildField(
              label: "Insurance Policy No",
              apiKey: "insurance_number",
              readOnly: isRcVerifiedSuccess && _controllers['insurance_number']!.text.isNotEmpty,
              hint: "Ex: POL1234567"),
          _buildField(
              label: "Insurance Expiry",
              apiKey: "insurance_doe",
              readOnly: isRcVerifiedSuccess && _controllers['insurance_doe']!.text.isNotEmpty,
              isDate: true),

          // Conditional Yellow Plate Sections
          if (_selectedPlateColor == 'YELLOW PLATE') ...[
            _buildSectionHeader("Taxi Permit", Icons.business_center),
            _buildField(
                label: "Permit Number",
                apiKey: "texi_permit_no",
                isRequired: false,
                readOnly: isRcVerifiedSuccess && _controllers['texi_permit_no']!.text.isNotEmpty,
                hint: "Ex: PMT998877"),
            _buildField(
                label: "Permit DOE",
                apiKey: "texi_permit_doe",
                isDate: true,
                readOnly: isRcVerifiedSuccess && _controllers['texi_permit_doe']!.text.isNotEmpty,
                isRequired: false),
            _buildSectionHeader("Fitness Certificate", Icons.health_and_safety),
            _buildField(
                label: "Fitness Cert Number",
                apiKey: "fitness_certificate_no",
                isRequired: false,
                hint: "Ex: FIT112233"),
            _buildField(
                label: "Fitness Expiry Date",
                apiKey: "fitness_certificate_doe",
                isDate: true,
                readOnly: isRcVerifiedSuccess && _controllers['fitness_certificate_doe']!.text.isNotEmpty,
                isRequired: false),
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
