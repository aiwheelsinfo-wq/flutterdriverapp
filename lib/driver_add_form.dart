import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'checkAndRoot.dart';
import 'api_config.dart';
import 'booking_list.dart';


// --- CUSTOM FORMATTER FOR FORCED UPPERCASE ---
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class DriverFormPage extends StatefulWidget {
  const DriverFormPage({super.key});

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
  bool driverFrom = false;
  bool newDriverForm = false;
  bool driverCodeField = false;
  bool addDriverSuccess = false;
  bool driverForm = true;
  bool addNewBtn = false;
  bool nextStepBtn = false;
  bool nextBtn = false;
  bool _isAgree = false;
  final Set<String> _uniqueValues = {};
  bool isPhoneLocked = false;
  bool isDriverCodeLocked = false;
  String? searchStatusMessage;
  Color searchStatusColor = Colors.grey;

  bool isVerifyingDl = false;
  String? dlVerificationStatusMessage;
  Color dlVerificationStatusColor = Colors.grey;
  bool isDlVerifiedSuccess = false;

  // Real-time DL duplicate check
  bool isDlDuplicate = false;
  bool isDlUnique = false;
  bool isCheckingDl = false;
  String? dlDuplicateMessage;

  // Professional Amber Palette
  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color accentAmber = Color(0xFFFF8F00);
  static const Color charcoal = Color(0xFF263238);
  static const Color bgLight = Color(0xFFFFFBF0);

  final List<String> indianLicenseTypes = [
    'LMV (LIGHT MOTOR VEHICLE - CARS/JEEPS)',
    'LMV-TR (TRANSPORT - COMMERCIAL TAXIS)',
    'LMV-GV (GOODS CARRIER - DELIVERY VANS)',
    'TRANS (TRANSPORT - COMPREHENSIVE)',
    'HPMV (HEAVY PASSENGER VEHICLE - BUS)',
    'HGMV (HEAVY GOODS VEHICLE - TRUCK)',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    fetchDriverStatus();
    _showInitialHint();
  }

  void _initializeControllers() {
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
      'license_doi': TextEditingController(),
      'license_doe': TextEditingController(),
      'license_type': TextEditingController(),
      'adhaar_card_no': TextEditingController(),
      'pan_card_no': TextEditingController(),
    };
  }

  void _showInitialHint() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Enter Phone Number to start verification"),
          backgroundColor: charcoal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  // ------------------- API CALLS -------------------

  Future<void> fetchDriverStatus() async {
    storedNumber = await secureStorage.read(key: "phone_number");
    try {
      final response = await http.get(Uri.parse(
          '${ApiConfig.registerDriver}?phone_number=$storedNumber'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> driversData = data['driversdata'] ?? [];
        if (driversData.isNotEmpty &&
            driversData[0]['status'] != 'not driver') {
          setState(() => nextBtn = true);
        }
      }
    } catch (e) {
      debugPrint("Status Fetch Error: $e");
    }
  }

  Future<void> fetchDriverDetails(String phoneNumber) async {
    setState(() {
      searchStatusMessage = "Searching for driver details...";
      searchStatusColor = Colors.orange;
    });

    try {
      final response = await http.get(Uri.parse(
          "${ApiConfig.driverDetailsFetching}?phone_number=$phoneNumber"));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == "success") {
          final driverData = data["data"];
          setState(() {
            _controllers['full_name']?.text =
                (driverData["full_name"] ?? '').toUpperCase();
            _controllers['email']?.text =
                (driverData['email'] ?? '').toUpperCase();
            _controllers['driver_address']?.text =
                (driverData['driver_address'] ?? '').toUpperCase();
            _controllers['pin_code']?.text = driverData['pin_code'] ?? '';
            _controllers['driver_city']?.text =
                (driverData['driver_city'] ?? '').toUpperCase();
            _controllers['license_no']?.text =
                (driverData['license_no'] ?? '').toUpperCase();
            _controllers['license_doe']?.text = driverData['license_doe'] ?? '';
            _controllers['license_type']?.text =
                (driverData['license_type'] ?? '').toUpperCase();
            _controllers['adhaar_card_no']?.text =
                driverData['adhaar_card_no'] ?? '';
            _controllers['pan_card_no']?.text =
                (driverData['pan_card_no'] ?? '').toUpperCase();
            _controllers['date_of_birth']?.text =
                driverData['date_of_birth'] ?? '';

            if (driverCode != null) {
              _controllers['driver_code']?.text = driverCode!;
            }

            searchStatusMessage = "Existing driver found. Details loaded automatically.";
            searchStatusColor = Colors.green;
            isPhoneLocked = true;
            isDriverCodeLocked = true;
            newDriverForm = true;
          });
        } else {
          setState(() {
            searchStatusMessage = "No existing driver found. Please enter driver details.";
            searchStatusColor = Colors.blueGrey;
            isPhoneLocked = false;
            isDriverCodeLocked = false;
            driverCodeField = false;
            newDriverForm = true;
          });
        }
      } else {
        setState(() {
          searchStatusMessage = "No existing driver found. Please enter driver details.";
          searchStatusColor = Colors.blueGrey;
          isPhoneLocked = false;
          isDriverCodeLocked = false;
          driverCodeField = false;
          newDriverForm = true;
        });
      }
    } catch (e) {
      debugPrint("Details Fetch Error: $e");
      setState(() {
        searchStatusMessage = "No existing driver found. Please enter driver details.";
        searchStatusColor = Colors.blueGrey;
        isPhoneLocked = false;
        isDriverCodeLocked = false;
        driverCodeField = false;
        newDriverForm = true;
      });
    }
  }

  Future<void> fetchDriverCodeForPhone(String phoneNumber) async {
    setState(() {
      searchStatusMessage = "Checking phone number...";
      searchStatusColor = Colors.orange;
      driverCodeField = false;
      newDriverForm = false;
    });

    try {
      final response = await http.get(Uri.parse(
          "${ApiConfig.driverCodeFetching}?phone_number=$phoneNumber"));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            driverCode = data['driver_code'];
            driverCodeField = true;
            newDriverForm = false;
            searchStatusMessage = "Existing driver found. Please enter Driver Code to load details.";
            searchStatusColor = Colors.orange;
          });
        } else {
          setState(() {
            driverCode = null;
            driverCodeField = false;
            newDriverForm = true;
            searchStatusMessage = "No existing driver found. Please enter driver details.";
            searchStatusColor = Colors.blueGrey;
            isPhoneLocked = false;
            isDriverCodeLocked = false;
          });
        }
      } else {
        setState(() {
          driverCode = null;
          driverCodeField = false;
          newDriverForm = true;
          searchStatusMessage = "No existing driver found. Please enter driver details.";
          searchStatusColor = Colors.blueGrey;
          isPhoneLocked = false;
          isDriverCodeLocked = false;
        });
      }
    } catch (e) {
      debugPrint("Code Fetch Error: $e");
      setState(() {
        driverCode = null;
        driverCodeField = false;
        newDriverForm = true;
        searchStatusMessage = "No existing driver found. Please enter driver details.";
        searchStatusColor = Colors.blueGrey;
        isPhoneLocked = false;
        isDriverCodeLocked = false;
      });
    }
  }

  Future<void> statusChangeNotFill() async {
    storedNumber = await secureStorage.read(key: "phone_number");
    String? userType = await secureStorage.read(key: "userType");

    if (userType == "Vender" || userType == "Vendor") {
      if (storedNumber != null && storedNumber!.isNotEmpty) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => BookingListPage(phoneNumber: storedNumber!)),
          (route) => false,
        );
        return;
      }
    }

    try {
      var response = await http.post(
        Uri.parse(ApiConfig.statusChangeFilled),
        body: {"stored_number": storedNumber},
      );

      if (jsonDecode(response.body)["success"] == true) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const checAbdRoot()));
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => BookingListPage(phoneNumber: storedNumber ?? '')),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint("Status Change Error: $e");
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => BookingListPage(phoneNumber: storedNumber ?? '')),
        (route) => false,
      );
    }
  }

  // ------------------- FORM LOGIC -------------------

  void _onPhoneChanged(String value) async {
    if (value.length == 10) {
      storedNumber = await secureStorage.read(key: "phone_number");
      if (value == storedNumber) {
        setState(() {
          driverCodeField = false;
          newDriverForm = true;
        });
        fetchDriverDetails(value);
      } else {
        fetchDriverCodeForPhone(value);
      }
    } else {
      setState(() {
        newDriverForm = false;
        driverCodeField = false;
        searchStatusMessage = null;
        isPhoneLocked = false;
        isDriverCodeLocked = false;
      });
    }
  }

  void _onDriverCodeChanged(String value) {
    if (value.length == 4) {
      if (driverCode != null && value == driverCode) {
        fetchDriverDetails(_controllers['phone_number']!.text);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Invalid Driver Code")));
      }
    }
  }

  String _formatToBackend(String date) {
    if (date.isEmpty) return "";
    try {
      final parts = date.split('-');
      return '${parts[2]}-${parts[1]}-${parts[0]}';
    } catch (e) {
      return date;
    }
  }

  Future<void> _verifyDrivingLicense() async {
    final rawDl = _controllers['license_no']!.text.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase().trim();
    final dob = _controllers['date_of_birth']!.text.trim();

    if (rawDl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Driving License Number")),
      );
      return;
    }

    // 1. Client Format Regex Check (FREE)
    final dlRegex = RegExp(r'^[A-Z]{2}[0-9]{2}[0-9]{11}$');
    if (!dlRegex.hasMatch(rawDl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid DL format. Enter valid 15-character DL (e.g. KL7320220004599)")),
      );
      return;
    }

    if (dob.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select Date of Birth before verifying DL")),
      );
      return;
    }

    setState(() {
      isVerifyingDl = true;
      dlVerificationStatusMessage = "Verifying DL via Government API...";
      dlVerificationStatusColor = Colors.blue;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.verifyDl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'license_no': rawDl,
          'date_of_birth': _formatToBackend(dob),
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final details = data['data'] ?? {};
        final name = details['name'] ?? details['holder_name'] ?? "";
        final expiry = details['expiry_date'] ?? details['doe'] ?? "";
        final address = details['permanent_address'] ?? details['address'] ?? "";

        setState(() {
          isVerifyingDl = false;
          isDlVerifiedSuccess = true;
          dlVerificationStatusMessage = "✅ DL VERIFIED: $name (Valid till: $expiry)";
          dlVerificationStatusColor = Colors.green;

          if (name.isNotEmpty) {
            _controllers['full_name']!.text = name;
          }
          final issueDate = details['issue_date'] ?? details['doi'] ?? "";
          if (issueDate.isNotEmpty) {
            try {
              final parsedIssue = DateTime.parse(issueDate);
              _controllers['license_doi']!.text = DateFormat('dd-MM-yyyy').format(parsedIssue);
            } catch (e) {
              _controllers['license_doi']!.text = issueDate;
            }
          }
          if (expiry.isNotEmpty) {
            try {
              final parsedDate = DateTime.parse(expiry);
              _controllers['license_doe']!.text = DateFormat('dd-MM-yyyy').format(parsedDate);
            } catch (e) {
              _controllers['license_doe']!.text = expiry;
            }
          }
          if (address.isNotEmpty) {
            _controllers['driver_address']!.text = address;
          }
          _controllers['license_type']!.text = indianLicenseTypes.first;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("DL Verified! Holder: $name"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorMsg = data['message'] ?? "DL Verification failed or record not found";
        setState(() {
          isVerifyingDl = false;
          isDlVerifiedSuccess = false;
          dlVerificationStatusMessage = "❌ $errorMsg";
          dlVerificationStatusColor = Colors.red;
        });
      }
    } catch (e) {
      setState(() {
        isVerifyingDl = false;
        isDlVerifiedSuccess = false;
        dlVerificationStatusMessage = "⚠️ Network/Server error during DL verification";
        dlVerificationStatusColor = Colors.orange;
      });
    }
  }

  Future<void> _submitForm(String status) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isAgree) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please agree to terms")));
      return;
    }

    final data = {
      'phone_number': _controllers['phone_number']!.text,
      'full_name': _controllers['full_name']!.text,
      'email': _controllers['email']!.text,
      'driver_address': _controllers['driver_address']!.text,
      'driver_city': _controllers['driver_city']!.text,
      'date_of_birth': _formatToBackend(_controllers['date_of_birth']!.text),
      'pin_code': _controllers['pin_code']!.text,
      'license_no': _controllers['license_no']!.text,
      'license_doi': _formatToBackend(_controllers['license_doi']!.text),
      'license_doe': _formatToBackend(_controllers['license_doe']!.text),
      'license_type': _controllers['license_type']!.text,
      'adhaar_card_no': _controllers['adhaar_card_no']!.text,
      'pan_card_no': _controllers['pan_card_no']!.text,
      'status': status,
      'vendor_number': storedNumber,
    };

    try {
      final resp = await http.post(
        Uri.parse(ApiConfig.registerDriver),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));

      Map<String, dynamic> respData = {};
      try {
        if (resp.body.isNotEmpty) {
          respData = jsonDecode(resp.body);
        }
      } catch (_) {}

      if (resp.statusCode == 200 && respData['status'] == 'success') {
        setState(() {
          driverForm = false;
          addDriverSuccess = true;
          addNewBtn = true;
          nextStepBtn = true;
        });
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
      } else {
        final errMsg = respData['message'] ?? 'Registration failed. Please try again.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errMsg), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: Unable to connect to server. Please try again."), backgroundColor: Colors.red));
    }
  }

  // ------------------- REAL-TIME DL DUPLICATE CHECK -------------------

  Future<void> _checkDlExists(String value) async {
    final raw = value.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase().trim();
    if (raw.length < 15) {
      if (isDlDuplicate || isDlUnique) {
        setState(() {
          isDlDuplicate = false;
          isDlUnique = false;
          dlDuplicateMessage = null;
        });
      }
      return;
    }
    setState(() {
      isCheckingDl = true;
      isDlDuplicate = false;
      isDlUnique = false;
      dlDuplicateMessage = null;
    });
    try {
      final resp = await http.get(
        Uri.parse(ApiConfig.checkDlExists + '?license_no=' + Uri.encodeComponent(raw)),
      ).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      final data = jsonDecode(resp.body);
      setState(() {
        isCheckingDl = false;
        if (data['exists'] == true) {
          isDlDuplicate = true;
          isDlUnique = false;
          dlDuplicateMessage = 'This driving license number already exists. Please enter a different license number.';
        } else {
          isDlDuplicate = false;
          isDlUnique = true;
          dlDuplicateMessage = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => isCheckingDl = false);
    }
  }

  // ------------------- UI COMPONENTS -------------------

  Widget _buildField({
    required String label,
    required String apiKey,
    String? hint,
    IconData? icon,
    bool isDate = false,
    bool isRequired = true,
    bool isUnique = false,
    TextInputType? keyboard,
    Function(String)? onChanged,
    int? maxLength,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: _controllers[apiKey],
        readOnly: readOnly || isDate,
        enabled: !readOnly,
        onTap: isDate ? () => _pickDate(apiKey) : null,
        onChanged: onChanged,
        maxLength: maxLength,
        keyboardType: keyboard,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [UpperCaseTextFormatter()],
        decoration: InputDecoration(
          labelText: label.toUpperCase(),
          hintText: hint?.toUpperCase(),
          prefixIcon: Icon(icon ?? Icons.edit, color: readOnly ? Colors.grey.shade400 : primaryAmber, size: 20),
          counterText: "",
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
          if (isRequired && (val == null || val.isEmpty)) return "REQUIRED";
          return null;
        },
      ),
    );
  }

  Future<void> _pickDate(String key) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: primaryAmber)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() =>
          _controllers[key]!.text = DateFormat('dd-MM-yyyy').format(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: charcoal),
            onPressed: () => Navigator.pop(context)),
        title: const Text("DRIVER ONBOARDING",
            style: TextStyle(
                color: charcoal, fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          if (nextBtn)
            TextButton(
                onPressed: statusChangeNotFill,
                child: const Text("SKIP",
                    style: TextStyle(
                        color: accentAmber, fontWeight: FontWeight.bold))),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  if (addDriverSuccess) _buildSuccessCard(),
                  if (addNewBtn) _buildActionButtons(),
                  if (driverForm) _buildVerificationAndForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      padding: const EdgeInsets.all(
          16), // Slightly reduced padding for tighter screens
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.green.shade200)),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            // Essential: prevents text from pushing Row out of bounds
            child: Text(
              "DRIVER REGISTERED SUCCESSFULLY!",
              style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationAndForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildVerificationHeader(),
          _buildField(
            label: "Driver Phone Number",
            apiKey: "phone_number",
            icon: Icons.phone_android,
            maxLength: 10,
            keyboard: TextInputType.phone,
            onChanged: _onPhoneChanged,
            readOnly: isPhoneLocked,
          ),
          if (driverCodeField)
            _buildField(
              label: "Enter 4-Digit Driver Code",
              apiKey: "driver_code",
              icon: Icons.lock_outline,
              maxLength: 4,
              keyboard: TextInputType.number,
              onChanged: _onDriverCodeChanged,
              readOnly: isDriverCodeLocked,
            ),
          if (searchStatusMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: searchStatusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: searchStatusColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    searchStatusColor == Colors.green ? Icons.check_circle : Icons.info,
                    color: searchStatusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      searchStatusMessage!,
                      style: TextStyle(
                        color: searchStatusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (isPhoneLocked) ...[
                    const SizedBox(width: 10),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setState(() {
                          isPhoneLocked = false;
                          isDriverCodeLocked = false;
                          searchStatusMessage = null;
                          _controllers['phone_number']!.clear();
                          _controllers['driver_code']!.clear();
                          _controllers['full_name']!.clear();
                          _controllers['email']!.clear();
                          _controllers['driver_address']!.clear();
                          _controllers['pin_code']!.clear();
                          _controllers['driver_city']!.clear();
                          _controllers['license_no']!.clear();
                          _controllers['license_doe']!.clear();
                          _controllers['license_type']!.clear();
                          _controllers['adhaar_card_no']!.clear();
                          _controllers['pan_card_no']!.clear();
                          _controllers['date_of_birth']!.clear();
                          newDriverForm = false;
                          driverCodeField = false;
                        });
                      },
                      child: const Text(
                        "RESET",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: newDriverForm ? _buildMainForm() : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Verify Driver",
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: charcoal)),
          Text("Connect your fleet. Verify your driver's identity to continue.",
              style: TextStyle(color: charcoal.withOpacity(0.6))),
          const Divider(height: 30, thickness: 1),
        ],
      ),
    );
  }

  Widget _buildMainForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Personal Details", Icons.person_outline),
        _buildField(
            label: "Full Name",
            apiKey: "full_name",
            hint: "As per Adhaar",
            icon: Icons.person),
        _buildField(
            label: "Email Address",
            apiKey: "email",
            hint: "example@mail.com",
            icon: Icons.email,
            keyboard: TextInputType.emailAddress),
        _buildField(
            label: "Address", apiKey: "driver_address", icon: Icons.map),
        Row(
          children: [
            Expanded(child: _buildField(label: "City", apiKey: "driver_city")),
            const SizedBox(width: 10),
            Expanded(
                child: _buildField(
                    label: "Pin Code",
                    apiKey: "pin_code",
                    maxLength: 6,
                    keyboard: TextInputType.number)),
          ],
        ),
        _buildSectionTitle("Identification", Icons.badge_outlined),
        _buildField(
            label: "Adhaar Number",
            apiKey: "adhaar_card_no",
            maxLength: 12,
            keyboard: TextInputType.number,
            icon: Icons.fingerprint),
        _buildField(
            label: "PAN Card Number",
            apiKey: "pan_card_no",
            maxLength: 10,
            icon: Icons.credit_card),
        _buildSectionTitle("License Details", Icons.drive_eta_outlined),
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: primaryAmber.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primaryAmber.withOpacity(0.4)),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: accentAmber, size: 16),
              SizedBox(width: 8),
              Text(
                "STEP 1: SELECT DOB FIRST BEFORE GOVT VERIFICATION",
                style: TextStyle(
                    color: charcoal, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        _buildField(
            label: "Date of Birth (DOB)",
            apiKey: "date_of_birth",
            isDate: true,
            hint: "SELECT DOB FIRST (DD-MM-YYYY)",
            icon: Icons.cake),
        // --- License Number with real-time duplicate check ---
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _controllers['license_no'],
                onChanged: (val) {
                  if (val.length >= 15) _checkDlExists(val);
                  if (val.length < 15 && (isDlDuplicate || isDlUnique)) {
                    setState(() {
                      isDlDuplicate = false;
                      isDlUnique = false;
                      dlDuplicateMessage = null;
                    });
                  }
                },
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseTextFormatter()],
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'LICENSE NUMBER',
                  hintText: 'E.G. KL7320220004599',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: Icon(
                    Icons.assignment_ind,
                    color: isDlDuplicate
                        ? Colors.redAccent
                        : isDlUnique
                            ? Colors.green
                            : primaryAmber,
                    size: 20,
                  ),
                  suffixIcon: isCheckingDl
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : isDlDuplicate
                          ? const Icon(Icons.error, color: Colors.redAccent)
                          : isDlUnique
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: isDlDuplicate
                              ? Colors.redAccent
                              : isDlUnique
                                  ? Colors.green
                                  : Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: isDlDuplicate
                              ? Colors.redAccent
                              : isDlUnique
                                  ? Colors.green
                                  : Colors.grey.shade300,
                          width: (isDlDuplicate || isDlUnique) ? 2 : 1)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: isDlDuplicate
                              ? Colors.redAccent
                              : isDlUnique
                                  ? Colors.green
                                  : primaryAmber,
                          width: 2)),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'REQUIRED';
                  if (isDlDuplicate) return 'License number already exists';
                  return null;
                },
              ),
              if (isDlDuplicate && dlDuplicateMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dlDuplicateMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              if (isDlUnique)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'License number is unique ✓',
                        style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        _buildVerifyDlButton(),
        _buildLicenseDropdown(),
        _buildField(
            label: "License Issue Date", apiKey: "license_doi", isDate: true, icon: Icons.calendar_month),
        _buildField(
            label: "License Expiry Date", apiKey: "license_doe", isDate: true),
        const SizedBox(height: 20),
        _buildAgreementSection(),
        const SizedBox(height: 30),
        _buildSubmitButton(),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 25, bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: accentAmber, size: 20),
          const SizedBox(width: 8),
          Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: charcoal,
                  letterSpacing: 1)),
          const SizedBox(width: 10),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildVerifyDlButton() {
    return Column(
      children: [
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDlVerifiedSuccess ? Colors.green.shade700 : primaryAmber,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: isVerifyingDl ? null : _verifyDrivingLicense,
            icon: isVerifyingDl
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Icon(isDlVerifiedSuccess ? Icons.verified : Icons.security_rounded, color: Colors.white),
            label: Text(
              isVerifyingDl
                  ? "VERIFYING DL..."
                  : (isDlVerifiedSuccess ? "DL VERIFIED WITH GOVT API" : "VERIFY DL VIA GOVT API"),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
            ),
          ),
        ),
        if (dlVerificationStatusMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: dlVerificationStatusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: dlVerificationStatusColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  isDlVerifiedSuccess ? Icons.check_circle : Icons.info_outline,
                  color: dlVerificationStatusColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dlVerificationStatusMessage!,
                    style: TextStyle(
                      color: dlVerificationStatusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildLicenseDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        decoration: InputDecoration(
          labelText: "LICENSE CATEGORY",
          prefixIcon: const Icon(Icons.category, color: primaryAmber),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: indianLicenseTypes
            .map((e) => DropdownMenuItem(
                value: e, child: Text(e, style: const TextStyle(fontSize: 12))))
            .toList(),
        onChanged: (v) =>
            setState(() => _controllers['license_type']!.text = v ?? ""),
        validator: (v) => (v == null || v.isEmpty) ? "REQUIRED" : null,
      ),
    );
  }

  Widget _buildAgreementSection() {
    return CheckboxListTile(
      activeColor: primaryAmber,
      contentPadding: EdgeInsets.zero,
      title: const Text(
          "I declare that all driver details and documents provided are genuine.",
          style: TextStyle(fontSize: 12, color: charcoal)),
      value: _isAgree,
      onChanged: (v) => setState(() => _isAgree = v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildSubmitButton() {
    final bool canSubmit = !isDlDuplicate && !isCheckingDl;
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: canSubmit ? charcoal : Colors.grey.shade400,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15))),
        onPressed: canSubmit ? () => _submitForm(driverCodeField ? 'join' : 'filled') : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isCheckingDl)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            else
              const Icon(Icons.app_registration, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              isCheckingDl
                  ? "CHECKING LICENSE..."
                  : isDlDuplicate
                      ? "DUPLICATE DL — CANNOT REGISTER"
                      : "REGISTER & UPDATE DRIVER",
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use parent constraints instead of double.infinity
        double btnWidth = constraints.maxWidth;

        return Column(
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  minimumSize: Size(btnWidth, 50),
                  side: const BorderSide(color: accentAmber)),
              onPressed: () => setState(() {
                _initializeControllers();
                driverForm = true;
                addDriverSuccess = false;
                addNewBtn = false;
                newDriverForm = false;
              }),
              child: const Text("ADD ANOTHER DRIVER",
                  style: TextStyle(
                      color: accentAmber, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(btnWidth, 50),
                  backgroundColor: primaryAmber),
              onPressed: statusChangeNotFill,
              child: const Text("FINISH & GO TO HOME",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controllers.forEach((k, v) => v.dispose());
    super.dispose();
  }
}
