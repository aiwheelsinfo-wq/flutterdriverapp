import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

// --- CUSTOM FORMATTER FOR FORCED UPPERCASE ---
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class TestCarFormPage extends StatefulWidget {
  final Map<String, dynamic>? carData;
  const TestCarFormPage({super.key, this.carData});

  @override
  State<TestCarFormPage> createState() => _TestCarFormPageState();
}

class _TestCarFormPageState extends State<TestCarFormPage> {
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
  bool _isAgree = true; // Auto-checked for fast testing
  String? phoneNumber;

  // Mock RC verification state
  bool isVerifyingRc = false;
  bool isRcVerifiedSuccess = false;
  String? rcVerificationStatusMessage;
  Color rcVerificationStatusColor = Colors.grey;
  bool isOtpSent = false;
  String otpClientId = '';
  String otpMobileNumber = '';
  final TextEditingController _otpInputController = TextEditingController();
  bool isSubmittingOtp = false;
  String? otpErrorText;

  String _selectedPreset = 'SEDAN';
  List<String> _carCategories = [
    'SEDAN',
    'SUV',
    'ERTIGA',
    'INNOVA',
    'CRYSTA',
    'HATCHBACK',
    'TEMPO_TRAVELLER'
  ];
  String? _selectedCarCategory;

  // UI Colors
  static const Color purpleTest = Color(0xFF6A1B9A);
  static const Color purpleLight = Color(0xFFF3E5F5);
  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color accentAmber = Color(0xFFFF8F00);
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
      'license_no': TextEditingController(text: 'KL0720210009988'),
      'license_doe': TextEditingController(text: '15-08-2030'),
      'license_type': TextEditingController(),
      'rc_no': TextEditingController(text: 'KL72D5275'),
      'rc_name': TextEditingController(),
      'rc_manufecture_date': TextEditingController(),
      'insurance_number': TextEditingController(),
      'insurance_doe': TextEditingController(),
      'puc_doi': TextEditingController(),
      'puc_doe': TextEditingController(),
      'texi_permit_no': TextEditingController(),
      'texi_permit_doi': TextEditingController(),
      'texi_permit_doe': TextEditingController(),
      'fitness_certificate_no': TextEditingController(text: 'KL-FIT-2021-9988'),
      'fitness_certificate_doi': TextEditingController(text: '12-04-2021'),
      'fitness_certificate_doe': TextEditingController(),
    };

    if (widget.carData != null) {
      final c = widget.carData!;
      final plate = (c['vehicle_number'] ?? c['vehicle_id'] ?? c['rc_no'] ?? '').toString();
      if (plate.isNotEmpty) {
        _controllers['rc_no']!.text = plate;
        _controllers['vehicle_id']!.text = plate;
      }
      if (c['vehicle_name'] != null) _controllers['vehicle_name']!.text = c['vehicle_name'].toString();
      if (c['rc_name'] != null) _controllers['rc_name']!.text = c['rc_name'].toString();
      if (c['vehicle_type'] != null) {
        _selectedCarCategory = c['vehicle_type'].toString().toUpperCase();
        _controllers['vehicle_type']!.text = _selectedCarCategory!;
      }
      if (c['fuel_type'] != null) {
        _selectedFuelItem = c['fuel_type'].toString().toUpperCase();
      }
    }
  }

  Future<void> fetchDriverDetails() async {
    phoneNumber = await secureStorage.read(key: "phone_number");
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.registerDriver}?phone_number=$phoneNumber'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> driversData = data['driversdata'] ?? [];
        if (mounted && driversData.isNotEmpty) {
          setState(() => nextStepBtn = driversData[0]['status'] != 'not car');
        }
      }
    } catch (e) {
      debugPrint("Fetch Driver Details Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _formatToBackend(String date) {
    if (date.isEmpty) return "";
    try {
      final parts = date.split('-');
      if (parts.length == 3) {
        return '${parts[2]}-${parts[1]}-${parts[0]}';
      }
      return date;
    } catch (e) {
      return "";
    }
  }

  // Quick 1-Click Auto Fill
  Future<void> _quickAutoFillPreset(String preset) async {
    setState(() {
      _selectedPreset = preset;
      isVerifyingRc = true;
    });

    try {
      final rcNo = _controllers['rc_no']!.text.trim().replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
      final response = await http.post(
        Uri.parse(ApiConfig.testMockRc),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mode': 'get_mock',
          'rc_number': rcNo.isEmpty ? 'KL72D5275' : rcNo,
          'preset': preset
        }),
      );

      final resData = jsonDecode(response.body);
      if (response.statusCode == 200 && resData['success'] == true) {
        _applyRcDetails(resData['data'] ?? {}, rcNo);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Auto-fill error: $e"), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => isVerifyingRc = false);
    }
  }

  // Step 1: Send Mock OTP
  Future<void> _sendMockRcOtp() async {
    final rcNo = _controllers['rc_no']!.text.trim().replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
    if (rcNo.isEmpty || rcNo.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid RC Number"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() {
      isVerifyingRc = true;
      rcVerificationStatusMessage = "Connecting to Sandbox RC Service...";
      rcVerificationStatusColor = purpleTest;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.testMockRc),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mode': 'send_otp',
          'rc_number': rcNo,
          'preset': _selectedPreset,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          isVerifyingRc = false;
          isOtpSent = true;
          otpClientId = data['client_id'] ?? '';
          otpMobileNumber = data['mobile_number'] ?? '';
          _otpInputController.text = data['test_otp'] ?? '123456';
          rcVerificationStatusMessage = "📱 Sandbox OTP sent! Default test OTP: ${data['test_otp'] ?? '123456'}";
          rcVerificationStatusColor = purpleTest;
        });
      } else {
        setState(() {
          isVerifyingRc = false;
          rcVerificationStatusMessage = "❌ ${data['message'] ?? 'Mock RC failed'}";
          rcVerificationStatusColor = Colors.redAccent;
        });
      }
    } catch (e) {
      setState(() {
        isVerifyingRc = false;
        rcVerificationStatusMessage = "❌ Connection error: $e";
        rcVerificationStatusColor = Colors.redAccent;
      });
    }
  }

  // Step 2: Submit Mock OTP
  Future<void> _submitMockRcOtp() async {
    final rcNo = _controllers['rc_no']!.text.trim().replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
    final otp = _otpInputController.text.trim();

    setState(() {
      isSubmittingOtp = true;
      otpErrorText = null;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.testMockRc),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mode': 'verify_otp',
          'rc_number': rcNo,
          'otp': otp,
          'preset': _selectedPreset,
        }),
      );

      final resData = jsonDecode(response.body);
      if (response.statusCode == 200 && resData['success'] == true) {
        setState(() {
          isSubmittingOtp = false;
          isOtpSent = false;
        });
        _applyRcDetails(resData['data'] ?? {}, rcNo);
      } else {
        setState(() {
          isSubmittingOtp = false;
          otpErrorText = resData['message'] ?? "OTP Verification failed";
        });
      }
    } catch (e) {
      setState(() {
        isSubmittingOtp = false;
        otpErrorText = "Connection error: $e";
      });
    }
  }

  void _applyRcDetails(Map<String, dynamic> details, String rcNo) {
    setState(() {
      isRcVerifiedSuccess = true;
      rcVerificationStatusMessage = "✅ MOCK RC VERIFIED FOR ${details['owner_name'] ?? 'TEST OWNER'}";
      rcVerificationStatusColor = Colors.green;

      final ownerName = (details['owner_name'] ?? "").toString().trim();
      final makerModel = (details['maker_model'] ?? "").toString().trim();
      final makerDesc = (details['maker_description'] ?? "").toString().trim();
      final fuelType = (details['fuel_type'] ?? "").toString().toUpperCase().trim();
      final insNumber = (details['insurance_policy_number'] ?? "").toString().trim();
      final insUpto = (details['insurance_upto'] ?? "").toString().trim();
      final fitUpTo = (details['fit_up_to'] ?? "").toString().trim();
      final permitNo = (details['permit_number'] ?? "").toString().trim();
      final permitUpto = (details['permit_valid_upto'] ?? "").toString().trim();

      if (ownerName.isNotEmpty) _controllers['rc_name']!.text = ownerName;
      _controllers['rc_no']!.text = rcNo;
      _controllers['vehicle_id']!.text = rcNo;
      final fullModel = "$makerDesc $makerModel".trim();
      if (fullModel.isNotEmpty) _controllers['vehicle_name']!.text = fullModel;

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
      if (_selectedCarCategory == null && _carCategories.isNotEmpty) {
        _selectedCarCategory = _carCategories.first;
        _controllers['vehicle_type']!.text = _carCategories.first;
      }

      _selectedPlateColor = 'YELLOW PLATE';
      if (insNumber.isNotEmpty) _controllers['insurance_number']!.text = insNumber;
      if (insUpto.isNotEmpty) {
        try {
          final pDate = DateTime.parse(insUpto);
          _controllers['insurance_doe']!.text = DateFormat('dd-MM-yyyy').format(pDate);
        } catch (_) {
          _controllers['insurance_doe']!.text = insUpto;
        }
      }
      if (fitUpTo.isNotEmpty) {
        try {
          final pDate = DateTime.parse(fitUpTo);
          _controllers['fitness_certificate_doe']!.text = DateFormat('dd-MM-yyyy').format(pDate);
          _controllers['rc_manufecture_date']!.text = DateFormat('dd-MM-yyyy').format(pDate);
        } catch (_) {
          _controllers['fitness_certificate_doe']!.text = fitUpTo;
          _controllers['rc_manufecture_date']!.text = fitUpTo;
        }
      }
      if (permitNo.isNotEmpty) _controllers['texi_permit_no']!.text = permitNo;
      if (permitUpto.isNotEmpty) {
        try {
          final pDate = DateTime.parse(permitUpto);
          _controllers['texi_permit_doe']!.text = DateFormat('dd-MM-yyyy').format(pDate);
        } catch (_) {
          _controllers['texi_permit_doe']!.text = permitUpto;
        }
      }

      final pucNumber = (details['pucc_number'] ?? 'KL-PUC-554433').toString();
      final pucUpto = (details['pucc_upto'] ?? '2027-06-30').toString();
      _controllers['puc_doi']!.text = pucNumber;
      try {
        final pDate = DateTime.parse(pucUpto);
        _controllers['puc_doe']!.text = DateFormat('dd-MM-yyyy').format(pDate);
      } catch (_) {
        _controllers['puc_doe']!.text = pucUpto;
      }

      if (_selectedLicenseType == null && indianLicenseTypes.isNotEmpty) {
        _selectedLicenseType = indianLicenseTypes[1]; // LMV-TR
        _controllers['license_type']!.text = _selectedLicenseType!;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✅ Test Vehicle Data Auto-Filled for ${_controllers['vehicle_name']!.text}!"),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Submit to Real Database via register_car.php
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isAgree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PLEASE AGREE TO THE DECLARATION")),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final Map<String, dynamic> data = {
        'fuel_type': _selectedFuelItem ?? 'PETROL',
        'plate_color': _selectedPlateColor ?? 'YELLOW PLATE',
        'phone_number': phoneNumber,
      };

      if (widget.carData != null && widget.carData!['id'] != null) {
        data['id'] = widget.carData!['id'];
      }

      if (_controllers['vehicle_id']!.text.trim().isEmpty) {
        _controllers['vehicle_id']!.text = _controllers['rc_no']!.text.trim().replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
      }
      data['vehicle_id'] = _controllers['vehicle_id']!.text.trim();

      _controllers.forEach((key, controller) {
        if (key.contains('doe') || key.contains('doi') || key.contains('date')) {
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
        throw "REGISTRATION FAILED: ${resp.body}";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registration Error: $e"), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: purpleTest,
        foregroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 8),
            Icon(Icons.science_rounded, color: Colors.amberAccent, size: 20),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                "Sandbox Vehicle Form",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amberAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "TEST MODE",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: carForm ? _buildForm() : _buildSuccessCard(),
            ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── SANDBOX BANNER ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: purpleLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: purpleTest.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: purpleTest, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Mock Vehicle Testing Sandbox",
                      style: TextStyle(fontWeight: FontWeight.bold, color: purpleTest, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "This screen uses test data without calling Surepass API. Enter any RC number, or use 1-Click Quick Fill below:",
                  style: TextStyle(fontSize: 12, color: charcoal),
                ),
                const SizedBox(height: 12),

                // Preset selector buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPresetChip('SEDAN', '🚗 Dzire Sedan', 'KL72D5275'),
                    _buildPresetChip('SUV', '🚙 Brezza SUV', 'KL08BF1234'),
                    _buildPresetChip('ERTIGA', '🚐 Ertiga 7-Seater', 'KL07CG4455'),
                    _buildPresetChip('INNOVA', '🚙 Innova', 'KL01CA9999'),
                    _buildPresetChip('CRYSTA', '✨ Crysta', 'KL01CB8888'),
                    _buildPresetChip('HATCHBACK', '🚗 Hatchback', 'KL07AB1122'),
                    _buildPresetChip('TEMPO_TRAVELLER', '🚐 Tempo Traveller', 'KL07TT9999'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── SECTION 1: RC & REGISTRATION ──
          _buildSectionHeader("1. VEHICLE RC & IDENTIFICATION", Icons.directions_car_rounded),
          
          _buildField(
            label: "VEHICLE RC NUMBER *",
            apiKey: 'rc_no',
            hint: "e.g. KL72D5275",
            isRequired: true,
          ),

          // VERIFY RC BUTTON (MOCK)
          _buildVerifyRcButton(),

          _buildField(
            label: "VEHICLE MAKE & MODEL *",
            apiKey: 'vehicle_name',
            hint: "e.g. Maruti Suzuki Dzire",
            isRequired: true,
          ),

          _buildField(
            label: "REGISTERED OWNER NAME *",
            apiKey: 'rc_name',
            hint: "Owner name on RC",
            isRequired: true,
          ),

          _buildCategoryDropdown(),

          _buildDropdown(
            label: "FUEL TYPE *",
            items: fuelTypes,
            value: _selectedFuelItem,
            onChanged: (v) => setState(() => _selectedFuelItem = v),
          ),

          _buildDropdown(
            label: "NUMBER PLATE COLOR *",
            items: plateColors,
            value: _selectedPlateColor,
            onChanged: (v) => setState(() => _selectedPlateColor = v),
          ),

          // ── SECTION 2: INSURANCE & FITNESS ──
          _buildSectionHeader("2. INSURANCE & FITNESS VALIDITY", Icons.verified_user_rounded),

          _buildField(
            label: "INSURANCE POLICY NUMBER *",
            apiKey: 'insurance_number',
            hint: "Policy number",
            isRequired: true,
          ),

          _buildField(
            label: "INSURANCE EXPIRY DATE *",
            apiKey: 'insurance_doe',
            hint: "DD-MM-YYYY",
            isDate: true,
            isRequired: true,
          ),

          _buildField(
            label: "FITNESS CERTIFICATE EXPIRY *",
            apiKey: 'fitness_certificate_doe',
            hint: "DD-MM-YYYY",
            isDate: true,
            isRequired: true,
          ),

          // ── SECTION 3: PERMIT & PUC ──
          _buildSectionHeader("3. TAXI PERMIT & EMISSIONS (PUC)", Icons.description_rounded),

          _buildField(
            label: "TAXI PERMIT NUMBER",
            apiKey: 'texi_permit_no',
            hint: "Permit number",
            isRequired: false,
          ),

          _buildField(
            label: "PERMIT EXPIRY DATE",
            apiKey: 'texi_permit_doe',
            hint: "DD-MM-YYYY",
            isDate: true,
            isRequired: false,
          ),

          _buildField(
            label: "PUC EMISSION NUMBER",
            apiKey: 'puc_doi',
            hint: "PUC number",
            isRequired: false,
          ),

          _buildField(
            label: "PUC EXPIRY DATE",
            apiKey: 'puc_doe',
            hint: "DD-MM-YYYY",
            isDate: true,
            isRequired: false,
          ),

          const SizedBox(height: 16),

          // ── DECLARATION & SUBMIT ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: CheckboxListTile(
              activeColor: purpleTest,
              title: const Text(
                "I HEREBY DECLARE THAT THIS VEHICLE DATA IS AUTHENTIC.",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              value: _isAgree,
              onChanged: (v) => setState(() => _isAgree = v ?? true),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleTest,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: isSubmitting ? null : _submitForm,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, size: 20),
              label: Text(
                isSubmitting ? "SAVING TO DATABASE..." : "SAVE & REGISTER TEST VEHICLE",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String preset, String title, String defaultRc) {
    final isSelected = _selectedPreset == preset;
    return ActionChip(
      avatar: Icon(
        Icons.flash_on_rounded,
        size: 16,
        color: isSelected ? Colors.white : purpleTest,
      ),
      label: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : purpleTest,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      backgroundColor: isSelected ? purpleTest : Colors.white,
      side: const BorderSide(color: purpleTest),
      onPressed: () {
        _controllers['rc_no']!.text = defaultRc;
        _quickAutoFillPreset(preset);
      },
    );
  }

  Widget _buildVerifyRcButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isRcVerifiedSuccess ? Colors.green : purpleTest,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isVerifyingRc ? null : _sendMockRcOtp,
              icon: isVerifyingRc
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(isRcVerifiedSuccess ? Icons.verified : Icons.verified_user_outlined, size: 18),
              label: Text(
                isVerifyingRc
                    ? "VERIFYING VIA SANDBOX..."
                    : isRcVerifiedSuccess
                        ? "MOCK RC VERIFIED ✓"
                        : "VERIFY RC (SANDBOX MOCK)",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),

          // INLINE OTP CARD
          if (isOtpSent && !isRcVerifiedSuccess)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryAmber, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mark_email_unread_outlined, color: accentAmber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Test OTP Sent to ($otpMobileNumber)",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: charcoal),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Default Test OTP is 123456:",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _otpInputController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: "123456",
                      errorText: otpErrorText,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: charcoal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isSubmittingOtp ? null : _submitMockRcOtp,
                      child: Text(isSubmittingOtp ? "VERIFYING..." : "SUBMIT OTP & LOAD TEST DATA"),
                    ),
                  ),
                ],
              ),
            ),

          if (rcVerificationStatusMessage != null && !isOtpSent)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: rcVerificationStatusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: rcVerificationStatusColor.withOpacity(0.4)),
              ),
              child: Text(
                rcVerificationStatusMessage!,
                style: TextStyle(color: rcVerificationStatusColor, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: purpleTest, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: charcoal),
          ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: charcoal)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _controllers[apiKey],
            inputFormatters: [_UpperCaseTextFormatter()],
            validator: (v) {
              if (isRequired && (v == null || v.trim().isEmpty)) {
                return "This field is required";
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: purpleTest, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("VEHICLE CATEGORY *", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: charcoal)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedCarCategory,
            items: _carCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) {
              setState(() {
                _selectedCarCategory = v;
                _controllers['vehicle_type']!.text = v ?? '';
              });
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required List<String> items,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: charcoal)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: value,
            items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
          const SizedBox(height: 14),
          const Text(
            "TEST VEHICLE REGISTERED!",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: charcoal),
          ),
          const SizedBox(height: 8),
          Text(
            "Vehicle ${_controllers['rc_no']!.text} (${_controllers['vehicle_name']!.text}) has been successfully saved to your database in Sandbox mode.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: purpleTest, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context),
              child: const Text("BACK TO CAR LIST"),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                carForm = true;
                addcabsuccess = false;
                _initializeControllers();
                isRcVerifiedSuccess = false;
                isOtpSent = false;
              });
            },
            child: const Text("Add Another Test Vehicle"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controllers.forEach((k, v) => v.dispose());
    _otpInputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
