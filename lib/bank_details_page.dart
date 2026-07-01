import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

class BankDetailsPage extends StatefulWidget {
  final String phoneNumber;
  final String currentHolder;
  final String currentAccNo;
  final String currentIfsc;
  final String currentUpi;

  const BankDetailsPage({
    super.key,
    required this.phoneNumber,
    required this.currentHolder,
    required this.currentAccNo,
    required this.currentIfsc,
    required this.currentUpi,
  });

  @override
  State<BankDetailsPage> createState() => _BankDetailsPageState();
}

class _BankDetailsPageState extends State<BankDetailsPage> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _holderController;
  late TextEditingController _accNoController;
  late TextEditingController _confirmAccNoController;
  late TextEditingController _ifscController;
  late TextEditingController _upiController;

  bool _isLoading = false;
  bool _isFetching = true;

  // Theme Colors
  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color accentAmber = Color(0xFFFF8F00);
  static const Color charcoal = Color(0xFF263238);
  static const Color bgLight = Color(0xFFFFFBF0);

  @override
  void initState() {
    super.initState();
    _holderController = TextEditingController(text: widget.currentHolder);
    _accNoController = TextEditingController(text: widget.currentAccNo);
    _confirmAccNoController = TextEditingController(text: widget.currentAccNo);
    _ifscController = TextEditingController(text: widget.currentIfsc);
    _upiController = TextEditingController(text: widget.currentUpi);
    _fetchLatestBankDetails();
  }

  @override
  void dispose() {
    _holderController.dispose();
    _accNoController.dispose();
    _confirmAccNoController.dispose();
    _ifscController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _fetchLatestBankDetails() async {
    try {
      final url = Uri.parse("${ApiConfig.getBankDetails}?phone_number=${widget.phoneNumber}");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == "success" && data["data"] != null) {
          final bank = data["data"];
          setState(() {
            _holderController.text = bank["bank_holder_name"] ?? "";
            _accNoController.text = bank["bank_account_no"] ?? "";
            _confirmAccNoController.text = bank["bank_account_no"] ?? "";
            _ifscController.text = bank["bank_ifsc"] ?? "";
            _upiController.text = bank["upi_id"] ?? "";
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching bank details: $e");
    } finally {
      setState(() => _isFetching = false);
    }
  }

  Future<void> _saveBankDetails() async {
    if (!_formKey.currentState!.validate()) return;

    final accNo = _accNoController.text.trim();
    final ifsc = _ifscController.text.trim().toUpperCase();
    final holder = _holderController.text.trim();
    final upi = _upiController.text.trim();

    if (accNo.isEmpty && upi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in either your Bank Account details OR a UPI ID."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (accNo.isNotEmpty && ifsc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter the bank IFSC code."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(ApiConfig.updateBankDetails);
      final response = await http.post(
        url,
        body: {
          "phone_number": widget.phoneNumber,
          "bank_account_no": accNo,
          "bank_ifsc": ifsc,
          "bank_holder_name": holder,
          "upi_id": upi,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == "success") {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Bank details saved successfully!"),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          }
        } else {
          throw Exception(data["message"] ?? "Server failed to save bank details.");
        }
      } else {
        throw Exception("Server returned status code: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text("Bank Account Details",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: charcoal,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isFetching
          ? const Center(child: CircularProgressIndicator(color: primaryAmber))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          _buildCard([
                            const Text(
                              "Payout Preferences",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: charcoal),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Configure where you want to receive your trip advance settlements. You can enter bank account info, a UPI ID, or both.",
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ]),
                          const SizedBox(height: 20),
                          _buildCard([
                            Row(
                              children: const [
                                Icon(Icons.account_balance, color: primaryAmber, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  "Option A: Bank Account Details",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: charcoal),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _holderController,
                              decoration: _inputDecoration("Account Holder Name", Icons.person_outline),
                              style: const TextStyle(fontSize: 14, color: charcoal),
                              validator: (val) {
                                if (_accNoController.text.trim().isNotEmpty && (val == null || val.trim().isEmpty)) {
                                  return "Please enter the account holder's name.";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _accNoController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration("Account Number", Icons.credit_card_outlined),
                              style: const TextStyle(fontSize: 14, color: charcoal),
                              validator: (val) {
                                if (_confirmAccNoController.text.trim().isNotEmpty && (val == null || val.trim().isEmpty)) {
                                  return "Please enter the account number.";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmAccNoController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration("Confirm Account Number", Icons.check_circle_outline),
                              style: const TextStyle(fontSize: 14, color: charcoal),
                              validator: (val) {
                                if (_accNoController.text.trim().isNotEmpty && val != _accNoController.text.trim()) {
                                  return "Account numbers do not match.";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _ifscController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: _inputDecoration("IFSC Code", Icons.pin_outlined),
                              style: const TextStyle(fontSize: 14, color: charcoal, fontFamily: "monospace"),
                              validator: (val) {
                                if (_accNoController.text.trim().isNotEmpty) {
                                  if (val == null || val.trim().isEmpty) {
                                    return "Please enter the bank IFSC code.";
                                  }
                                  if (val.trim().length != 11) {
                                    return "IFSC code must be exactly 11 characters.";
                                  }
                                }
                                return null;
                              },
                            ),
                          ]),
                          const SizedBox(height: 20),
                          _buildCard([
                            Row(
                              children: const [
                                Icon(Icons.alternate_email, color: primaryAmber, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  "Option B: UPI Address",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: charcoal),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _upiController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration("UPI ID (e.g. name@upi)", Icons.mobile_screen_share),
                              style: const TextStyle(fontSize: 14, color: charcoal),
                            ),
                          ]),
                          const SizedBox(height: 40),
                          _buildSaveButton(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      prefixIcon: Icon(icon, color: primaryAmber, size: 20),
      filled: true,
      fillColor: bgLight.withOpacity(0.5),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryAmber, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveBankDetails,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAmber,
          foregroundColor: charcoal,
          disabledBackgroundColor: primaryAmber.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: charcoal,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                "SAVE BANK DETAILS",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1),
              ),
      ),
    );
  }
}
