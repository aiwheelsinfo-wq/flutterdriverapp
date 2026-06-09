import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api_config.dart';


// Import your existing pages
import 'whatsapp_booking_list.dart';
import 'car_reg_form.dart';

class OwnerRegPage extends StatefulWidget {
  const OwnerRegPage({super.key});

  @override
  _OwnerPageState createState() => _OwnerPageState();
}

class _OwnerPageState extends State<OwnerRegPage> {
  final _formKey = GlobalKey<FormState>();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  final TextEditingController agencyNameController = TextEditingController();
  final TextEditingController ownerNameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController secondNumberController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController pinCodeController = TextEditingController();

  bool _isAgree = false;
  bool _isLoading = false;

  Future<void> _submitForm() async {
    if (!_isAgree) {
      _showToast("Please agree to the terms", Colors.orange);
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      String? phoneNumber = await secureStorage.read(key: "phone_number");

      var data = {
        'agency_name': agencyNameController.text.trim(),
        'full_name': ownerNameController.text.trim(),
        'driver_address': addressController.text.trim(),
        'email': emailController.text.trim(),
        'second_number': secondNumberController.text.trim(),
        'driver_city': cityController.text.trim(),
        'pin_code': pinCodeController.text.trim(),
        'phone_number': phoneNumber,
        'status': 'not car'
      };

      try {
        var response = await http
            .post(
              Uri.parse(ApiConfig.registerDriver),

              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(data),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          _showToast("Registration Successful!", Colors.green);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CarFormPage()),
          );
        } else {
          _showToast("Error: ${response.statusCode}", Colors.red);
        }
      } catch (e) {
        _showToast("Network Error. Please try again.", Colors.red);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showToast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFD), // Soft designer white
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.black, size: 20),
            onPressed: () => SystemNavigator.pop(),
          ),
          title: Text(
            "VENDOR PORTAL",
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: 500), // tablet/web optimization
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 25),
                    _buildWhatsAppCard(),
                    const SizedBox(height: 35),
                    Text(
                      "Business Registration",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildFormFields(),
                    _buildTermsSection(),
                    const SizedBox(height: 30),
                    _buildSubmitButton(),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Welcome to Agni",
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Register your agency to start receiving bookings from our premium network.",
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey[600],
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildWhatsAppCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (context) => NearbyTripsPage())),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  height: 60,
                  width: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Image.asset('assets/WhatsApp_icon.png', scale: 12),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Live Marketplace",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        "View bookings from 500+ groups",
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const CircleAvatar(
                  backgroundColor: Colors.amber,
                  radius: 18,
                  child:
                      Icon(Icons.chevron_right, color: Colors.black, size: 20),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        _buildTextField(agencyNameController, "Agency Name",
            Icons.business_center_outlined),
        _buildTextField(
            ownerNameController, "Full Name", Icons.person_outline_rounded),
        _buildTextField(
            addressController, "Office Address", Icons.map_outlined),
        _buildTextField(
            emailController, "Email Address", Icons.alternate_email_rounded,
            keyboard: TextInputType.emailAddress, isEmail: true),
        _buildTextField(secondNumberController, "Emergency Number",
            Icons.phone_android_rounded,
            keyboard: TextInputType.phone, isPhone: true, isOptional: true),
        Row(
          children: [
            Expanded(
                child: _buildTextField(
                    cityController, "City", Icons.location_city_rounded)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildTextField(
                    pinCodeController, "Pin Code", Icons.pin_drop_outlined,
                    keyboard: TextInputType.number, isPin: true)),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    bool isEmail = false,
    bool isPhone = false,
    bool isPin = false,
    bool isOptional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLength: isPhone
            ? 10
            : isPin
                ? 6
                : null,
        style:
            const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
        decoration: InputDecoration(
          counterText: "",
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.amber[700], size: 20),
          filled: true,
          fillColor: Colors.grey[100],
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.amber, width: 1.5),
          ),
          errorStyle: const TextStyle(fontSize: 10),
        ),
        validator: (value) {
          if (!isOptional && (value == null || value.isEmpty))
            return "Required field";
          if (value != null && value.isNotEmpty) {
            if (isEmail &&
                !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value))
              return "Invalid Email";
            if (isPhone && value.length != 10) return "10 digits required";
            if (isPin && value.length != 6) return "6 digits required";
          }
          return null;
        },
      ),
    );
  }

  Widget _buildTermsSection() {
    return CheckboxListTile(
      value: _isAgree,
      activeColor: Colors.amber,
      onChanged: (val) => setState(() => _isAgree = val!),
      title: Text(
        "I agree to the Terms & Conditions and allow Agni to store my business data.",
        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
      ),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.black)
            : Text(
                "VERIFY & REGISTER",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 1),
              ),
      ),
    );
  }
}
