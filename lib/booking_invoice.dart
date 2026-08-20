import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';

class InvoicePage extends StatefulWidget {
  final String bookingId;

  InvoicePage({required this.bookingId});

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();
  String? userType;
  final Map<String, String> invoiceData = {
    'invoieceDate': 'Not Generated',
    'invoiceNumber': 'Not Generated',
    'business_name': 'Not Generated',
    'business_address': 'Not Generated',
    'gst_number': 'Not Generated',
    'business_pincode': 'Not Generated',
    'trip_type': 'Not Generated',
    'cus_name': 'Not Generated',
    'car_type': 'Not Generated',
    'from': 'Not Generated',
    'to': 'Not Generated',
    'trip_date': 'Not Generated',
    'starting_km': '00',
    'closing_km': '00',
    'starting_date': '0000-00-00',
    'closing_date': '0000-00-00',
    'starting_time': '00:00:00',
    'closing_time': '00:00:00',
    'packageKm': '00',
    'packageHours': '00',
    'packageBaseFare': '00',
    'extra_km_price': '00',
    'extra_hours_price': '00',
    'package_price': 'Not Generated',
    'extra_hours': 'Not Generated',
    'parking_charge': '00',
    'toll_charge': '00',
    'gstPercent': '00',
    'driver_allowance': '00',
    'trip_total_fair': 'Not Generated',
    'user_id': 'Not Generated',
    'id': 'Not Generated',
    'next_invoice_no': 'Not Generated',
    'daily_limit': '0',
    'kmRate': '0',
    'distance': '0',
    'total_amount': '0',
    'agent_commission': '0',
    'permit_charge': '0',
    'discount_type': '',
    'discount_value': '0',
    'discount_name': '',
    'base_charge': '0',
    'paid_amount': '0',
  };

  @override
  void initState() {
    super.initState();
    fetchInvoiceData("123");
  }

  Future<void> fetchInvoiceData(String invoiceId) async {
    userType = await secureStorage.read(key: "userType");
    final url = Uri.parse(
        "${ApiConfig.getInvoiceData}?bookingId=${widget.bookingId}");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['error'] == null) {
          setState(() {
            invoiceData['invoiceNumber'] =
                data['invoice_no'] ?? 'Not Generated';
            invoiceData['invoieceDate'] =
                data['invoice_date'] ?? 'Not Generated';
            invoiceData['gst_number'] = data['gst_number'] ?? 'Not Generated';
            invoiceData['business_name'] =
                data['business_name'] ?? 'Not Generated';
            invoiceData['business_address'] =
                data['business_address'] ?? 'Not Generated';
            invoiceData['business_pincode'] =
                data['business_pincode'] ?? 'Not Generated';
            invoiceData['cus_name'] = data['name'] ?? 'Not Generated';
            invoiceData['car_type'] =
                '${data['car_type'] ?? 'Not Generated'} - ${data['vehicle_id'] ?? ''}';
            invoiceData['from'] = data['from_address'] ?? 'Not Generated';
            invoiceData['to'] = data['to_address'] ?? 'Not Generated';
            invoiceData['starting_date'] =
                data['starting_date'] ?? '0000-00-00';
            invoiceData['closing_date'] = data['closing_date'] ?? '0000-00-00';
            invoiceData['starting_km'] =
                (data['starting_km'] ?? '0').toString();
            invoiceData['closing_km'] = (data['closing_km'] ?? '0').toString();
            invoiceData['packageKm'] = (data['packageKm'] ?? '0').toString();
            invoiceData['packageHours'] =
                (data['packageHours'] ?? '0').toString();
            invoiceData['packageBaseFare'] =
                (data['baseAmount'] ?? '0').toString();
            invoiceData['extra_km_price'] =
                (data['extraKMAmount'] ?? '0').toString();
            invoiceData['extra_hours_price'] =
                (data['extraHoursAmount'] ?? '0').toString();
            invoiceData['starting_time'] =
                (data['starting_time'] ?? '00:00:00').toString();
            invoiceData['closing_time'] =
                (data['closing_time'] ?? '00:00:00').toString();
            invoiceData['parking_charge'] =
                (data['parking_charge'] ?? '0').toString();
            invoiceData['toll_charge'] =
                (data['toll_charge'] ?? '0').toString();
            invoiceData['gstPercent'] = (data['gstPercent'] ?? '0').toString();
            invoiceData['driver_allowance'] =
                (data['driver_allowance'] ?? '0').toString();
            invoiceData['trip_type'] =
                (data['trip_type'] ?? 'Not Generated').toString();
            invoiceData['daily_limit'] =
                (data['daily_limit'] ?? '0').toString();
            invoiceData['kmRate'] = (data['kmRate'] ?? '0').toString();
            invoiceData['distance'] = (data['distance'] ?? '0').toString();
            invoiceData['total_amount'] =
                (data['total_amount'] ?? '0').toString();
            invoiceData['agent_commission'] =
                (data['agent_commission'] ?? '0').toString();
            invoiceData['permit_charge'] =
                (data['permit_charge'] ?? '0').toString();
            invoiceData['discount_type'] =
                (data['discount_type'] ?? '').toString();
            invoiceData['discount_value'] =
                (data['discount_value'] ?? '0').toString();
            invoiceData['discount_name'] =
                (data['discount_name'] ?? '').toString();
            invoiceData['base_charge'] =
                (data['base_charge'] ?? '0').toString();
            invoiceData['paid_amount'] =
                (data['paid_amount'] ?? '0').toString();
            invoiceData['agent_agency_name'] =
                data['agent_agency_name'] ?? data['agency_name'] ?? '';
            invoiceData['agent_name'] = data['agent_name'] ?? '';
            invoiceData['agent_email'] = data['agent_email'] ?? '';
            invoiceData['agent_city'] = data['agent_city'] ?? '';
            invoiceData['agent_phone'] = data['agent_phone'] ?? '';
            invoiceData['agent_accountType'] =
                data['agent_accountType'] ?? data['accountType'] ?? '';
            invoiceData['booked_start_date'] =
                (data['date'] ?? '0000-00-00').toString();
            invoiceData['booked_return_date'] =
                (data['return_date'] ?? '0000-00-00').toString();
          });
        } else {
          print(data['error']);
        }
      } else {
        print('Failed to load data');
      }
    } catch (e) {
      print('Exception: $e');
    }
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '₹0';
    double? numVal;
    if (value is num) {
      numVal = value.toDouble();
    } else if (value is String) {
      String cleanStr = value
          .replaceAll('₹', '')
          .replaceAll('Rs', '')
          .replaceAll(',', '')
          .trim();
      numVal = double.tryParse(cleanStr);
    }
    if (numVal == null) return value.toString();

    if (numVal % 1 == 0) {
      final f = NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 0,
      );
      return f.format(numVal.toInt());
    } else {
      final f = NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 2,
      );
      String res = f.format(numVal);
      if (res.endsWith('.00')) {
        return res.substring(0, res.length - 3);
      }
      return res;
    }
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    double? numVal;
    if (value is num) {
      numVal = value.toDouble();
    } else if (value is String) {
      String cleanStr = value.replaceAll(',', '').trim();
      numVal = double.tryParse(cleanStr);
    }
    if (numVal == null) return value.toString();

    if (numVal % 1 == 0) {
      final f = NumberFormat.decimalPattern('en_IN');
      return f.format(numVal.toInt());
    } else {
      final f = NumberFormat.currency(
        locale: 'en_IN',
        symbol: '',
        decimalDigits: 2,
      );
      String res = f.format(numVal).trim();
      if (res.endsWith('.00')) {
        return res.substring(0, res.length - 3);
      }
      return res;
    }
  }

  bool get _isAgentInvoice {
    if (userType == 'agent') return true;
    if (invoiceData['agent_accountType'] == 'agent') return true;
    final bName = invoiceData['business_name'];
    if (bName != null && bName != 'Not Generated' && bName.trim().isNotEmpty) {
      return true;
    }
    return false;
  }

  String get _agentHeaderName {
    final bName = invoiceData['business_name'];
    if (bName != null && bName != 'Not Generated' && bName.trim().isNotEmpty) {
      return bName;
    }
    final aName = invoiceData['agent_agency_name'];
    if (aName != null && aName != 'Not Filled' && aName.trim().isNotEmpty) {
      return aName;
    }
    final agName = invoiceData['agent_name'];
    if (agName != null && agName != 'Not Filled' && agName.trim().isNotEmpty) {
      return agName;
    }
    return 'AGENT CAR RENTAL';
  }

  String get _agentHeaderAddress {
    final bAddr = invoiceData['business_address'];
    if (bAddr != null && bAddr != 'Not Generated' && bAddr.trim().isNotEmpty) {
      return bAddr;
    }
    final aCity = invoiceData['agent_city'];
    if (aCity != null && aCity != 'Not Filled' && aCity.trim().isNotEmpty) {
      return aCity;
    }
    return '';
  }

  String get _agentHeaderContact {
    String contact = '';
    final phone = invoiceData['agent_phone'];
    if (phone != null && phone.isNotEmpty && phone != 'Not Filled') {
      contact += "Tel: $phone";
    }
    final email = invoiceData['agent_email'];
    if (email != null && email.isNotEmpty && email != 'Not Filled') {
      if (contact.isNotEmpty) contact += " | ";
      contact += "Email: $email";
    }
    return contact;
  }

  String get _agentHeaderGst {
    final gst = invoiceData['gst_number'];
    if (gst != null && gst != 'Not Generated' && gst.trim().isNotEmpty) {
      return gst;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Invoice #${invoiceData['invoiceNumber']}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: _buildInvoiceContent(),
      ),
    );
  }

  Widget _buildInvoiceContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modern Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Text(
                      "CAR RENTAL INVOICE",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "Bill #${invoiceData['invoiceNumber']}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isAgentInvoice) ...[
                Text(
                  _agentHeaderName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (_agentHeaderAddress.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_agentHeaderAddress,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF475569))),
                ],
                if (_agentHeaderContact.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_agentHeaderContact,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF475569))),
                ],
                if (_agentHeaderGst.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text("GSTIN: $_agentHeaderGst",
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A8A))),
                ],
              ] else ...[
                const Text(
                  "RENTOX CAR",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                    "7, Jalaram Niwas, Ganesh Gawde Road, Mulund (W), Mumbai - 400080",
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                const SizedBox(height: 2),
                const Text(
                    "Tel: 9619936999 | Email: agnicarrental@gmail.com | Web: www.agnicarrental.com",
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                const SizedBox(height: 2),
                const Text("GSTIN: 27AABPG5706A3ZB",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A8A))),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Date: ${invoiceData['invoieceDate']}",
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B))),
                  Text("Trip: ${invoiceData['trip_type']}",
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A8A))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Customer & Trip Info Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "PASSENGER & ROUTE DETAILS",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                  letterSpacing: 0.5,
                ),
              ),
              const Divider(height: 16, color: Color(0xFFE2E8F0)),
              _buildInfoRow(
                  Icons.person_outline, "Passenger", invoiceData['cus_name']!),
              if (!_isAgentInvoice &&
                  invoiceData['gst_number'] != 'Not Generated' &&
                  invoiceData['gst_number'] != '') ...[
                _buildInfoRow(Icons.business_outlined, "Business Name",
                    invoiceData['business_name']!),
                _buildInfoRow(Icons.location_city_outlined, "Address",
                    invoiceData['business_address']!),
                _buildInfoRow(Icons.receipt_long_outlined, "GSTIN",
                    invoiceData['gst_number']!),
              ],
              _buildInfoRow(Icons.directions_car_outlined, "Vehicle",
                  invoiceData['car_type']!),
              _buildInfoRow(Icons.trip_origin, "From", invoiceData['from']!),
              if (invoiceData['trip_type'] != 'Local-Duty') ...[
                _buildInfoRow(
                    Icons.location_on_outlined, "To", invoiceData['to']!),
              ],
              _buildInfoRow(Icons.calendar_today_outlined, "Trip Date",
                  invoiceData['starting_date']!),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Table & Fare Breakdown
        _buildTable(),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
          const Text(": ", style: TextStyle(color: Color(0xFF94A3B8))),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final dateFormat = DateFormat('yyyy-MM-dd hh:mm a');
    final totalKm = double.parse(invoiceData['closing_km']!) -
        double.parse(invoiceData['starting_km']!);
    final startingDate = invoiceData['starting_date'];
    final startingTime = invoiceData['starting_time'];
    final closingDate = invoiceData['closing_date'];
    final closingTime = invoiceData['closing_time'];
    final startDateTime =
        DateTime.tryParse('$startingDate $startingTime') ?? DateTime.now();
    var endDateTime =
        DateTime.tryParse('$closingDate $closingTime') ?? DateTime.now();
    if (endDateTime.isBefore(startDateTime)) {
      endDateTime = endDateTime.add(const Duration(days: 1));
    }
    final duration = endDateTime.difference(startDateTime);
    var hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    String? commission;
    double? packageBaseWithCommission;
    String commissionFormulaText = '';
    int? totalDays = 0;
    double? extraKm;
    double? extrakmAmount;
    num? extraHours;
    double? extraHoursAmount;
    double? gst;
    double? netTotal;
    String? driver_allowance;
    double? baceAmount;
    double baseKmCharge = 0.0;
    double agentCommissionAmount = 0.0;
    double commissionRate = 0.0;

    var maxKm;
    double kmRate =
        double.tryParse(invoiceData['kmRate']?.toString() ?? '') ?? 0.0;
    double gstPercent = double.parse(invoiceData['gstPercent'].toString());
    double? agent_commission =
        double.tryParse(invoiceData['agent_commission'].toString()) ?? 0.0;
    double? permit_charge =
        double.tryParse(invoiceData['permit_charge'].toString()) ?? 0.0;
    double? parking_charge =
        double.tryParse(invoiceData['parking_charge'].toString()) ?? 0.0;
    double? toll_charge =
        double.tryParse(invoiceData['toll_charge'].toString()) ?? 0.0;
    if (invoiceData['trip_type'] == 'Local-Duty') {
      final packageKm = double.tryParse(invoiceData['packageKm'] ?? '0') ?? 0;
      final packageHours =
          double.tryParse(invoiceData['packageHours'] ?? '0') ?? 0;
      final extraKmPrice =
          double.tryParse(invoiceData['extra_km_price'] ?? '0') ?? 0;
      final extraHoursPrice =
          double.tryParse(invoiceData['extra_hours_price'] ?? '0') ?? 0;
      final packageBaseFare =
          double.tryParse(invoiceData['packageBaseFare'] ?? '0') ?? 0;
      double driverAllowance = 0.0;

      extraKm = totalKm > packageKm ? totalKm - packageKm : 0;
      extrakmAmount = extraKm * extraKmPrice;

      if (minutes > 30) hours += 1;
      extraHours = hours > packageHours ? hours - packageHours : 0;
      extraHoursAmount = extraHours * extraHoursPrice;

      bool isStartBefore5AM = startDateTime.hour < 5;
      bool isEndAfter1130PM = endDateTime.hour > 23 ||
          (endDateTime.hour == 23 && endDateTime.minute > 30);
      if (isStartBefore5AM || isEndAfter1130PM) {
        driverAllowance =
            double.tryParse(invoiceData['driver_allowance'] ?? '0') ?? 0;
      }

      double totalBeforeGst =
          packageBaseFare + extrakmAmount + extraHoursAmount + agent_commission;

      gst = totalBeforeGst * gstPercent / 100;
      netTotal = totalBeforeGst +
          gst +
          parking_charge +
          toll_charge +
          permit_charge +
          driverAllowance;

      baceAmount = double.parse(packageBaseFare.toStringAsFixed(2));
      packageBaseWithCommission =
          double.parse((packageBaseFare + agent_commission).toStringAsFixed(2));
      extrakmAmount = double.parse(extrakmAmount.toStringAsFixed(2));
      extraHoursAmount = double.parse(extraHoursAmount.toStringAsFixed(2));
      driverAllowance = double.parse(driverAllowance.toStringAsFixed(2));
      totalBeforeGst = double.parse(totalBeforeGst.toStringAsFixed(2));
      gst = double.parse(gst.toStringAsFixed(2));
      netTotal = double.parse(netTotal.toStringAsFixed(2));
      driver_allowance = driverAllowance.toString();
    }

    if (invoiceData['trip_type'] == 'Round-Trip') {
      double? driver_allowanceXdays;
      driver_allowance = invoiceData['driver_allowance'].toString();
      double runningKm = double.parse(invoiceData['closing_km'] ?? '0') -
          double.parse(invoiceData['starting_km'] ?? '0');
      double daily_limit = double.parse(invoiceData['daily_limit'] ?? '0');
      commission = userType == 'agent' ? '+${agent_commission.toString()}' : '';

      int days = 1;
      try {
        final bStartStr = invoiceData['booked_start_date'] ?? '';
        final bReturnStr = invoiceData['booked_return_date'] ?? '';
        if (bStartStr.isNotEmpty &&
            bReturnStr.isNotEmpty &&
            bStartStr != '0000-00-00' &&
            bReturnStr != '0000-00-00') {
          try {
            final bStart = DateFormat('dd MMM yyyy').parse(bStartStr);
            final bReturn = DateFormat('dd MMM yyyy').parse(bReturnStr);
            days = bReturn.difference(bStart).inDays + 1;
          } catch (_) {
            final bStart = DateTime.parse(bStartStr);
            final bReturn = DateTime.parse(bReturnStr);
            days = bReturn.difference(bStart).inDays + 1;
          }
        }
      } catch (e) {
        debugPrint("Error parsing booked dates: $e");
      }
      if (days <= 0) days = 1;
      maxKm = max(runningKm, (daily_limit * days));
      double dailyAllowance = double.tryParse(driver_allowance) ?? 400.0;
      bool isEarlyMorning = _isEarlyMorningTime(startingTime ?? '') ||
          ((startDateTime.hour >= 1 && startDateTime.hour < 6) ||
              (startDateTime.hour == 6 && startDateTime.minute == 0));
      double earlyMorningAllowance = isEarlyMorning ? 300.0 : 0.0;
      driver_allowanceXdays = (dailyAllowance * days) + earlyMorningAllowance;
      driver_allowance = driver_allowanceXdays.toStringAsFixed(2);
      totalDays = days;

      double commissionRateVal = 0.0;
      if (agent_commission > 0 && days > 0 && daily_limit > 0) {
        commissionRateVal =
            (agent_commission / (daily_limit * days)).roundToDouble();
      }
      commissionRate = commissionRateVal;
      baseKmCharge = (maxKm ?? 0) * kmRate;
      agentCommissionAmount = (maxKm ?? 0) * commissionRateVal;
      double effectiveKmRate = kmRate + commissionRateVal;
      baceAmount = baseKmCharge + agentCommissionAmount;

      commissionFormulaText = effectiveKmRate % 1 == 0
          ? effectiveKmRate.toInt().toString()
          : (effectiveKmRate.toStringAsFixed(2).endsWith('.00')
              ? effectiveKmRate.toInt().toString()
              : effectiveKmRate.toStringAsFixed(1));

      gst = baceAmount! * gstPercent / 100;

      netTotal = baceAmount +
          gst +
          parking_charge +
          toll_charge +
          permit_charge +
          driver_allowanceXdays;
    }

    double base_charge = 0.0;
    if (invoiceData['trip_type'] == 'One-way') {
      double distance = double.parse(invoiceData['distance'].toString());
      double driver_allowance;

      driver_allowance = (distance < 200) ? 300 : 400;

      baceAmount = invoiceData['total_amount'] != '0'
          ? double.parse(invoiceData['total_amount'].toString())
          : (distance * kmRate) + driver_allowance;

      double totalbeforeGst = (distance * kmRate) + agent_commission;

      gst = baceAmount * gstPercent / 100;
      netTotal = baceAmount + gst + parking_charge;

      base_charge =
          double.tryParse(invoiceData['base_charge']?.toString() ?? '') ?? 0.0;
      if (base_charge == 0.0) {
        base_charge = baceAmount - agent_commission;
      }

      baceAmount = double.parse(baceAmount.toStringAsFixed(2));
      totalbeforeGst = double.parse(totalbeforeGst.toStringAsFixed(2));
      gst = double.parse(gst.toStringAsFixed(2));
      netTotal = double.parse(netTotal.toStringAsFixed(2));
    }

    if (invoiceData['trip_type'] == 'Local-taxi') {
      netTotal = double.parse(invoiceData['total_amount'].toString());
    }

    final double advancedAmount =
        double.tryParse(invoiceData['paid_amount']?.toString() ?? '') ?? 0.0;
    final double balanceAmount = (netTotal ?? 0.0) - advancedAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meter & Timeline Strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("STARTING",
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B))),
                      Text(dateFormat.format(startDateTime),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A))),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("ENDING",
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B))),
                      Text(dateFormat.format(endDateTime),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A))),
                    ],
                  ),
                ],
              ),
              if (invoiceData['trip_type'] == 'Local-Duty' ||
                  invoiceData['trip_type'] == 'Round-Trip') ...[
                const Divider(height: 14, color: Color(0xFFE2E8F0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMeterCell("START KM", _formatNumber(invoiceData['starting_km']!)),
                    _buildMeterCell("END KM", _formatNumber(invoiceData['closing_km']!)),
                    _buildMeterCell(
                        "TOTAL KM", "${_formatNumber(totalKm)} KM",
                        isHighlight: true),
                    if (invoiceData['trip_type'] == 'Round-Trip')
                      _buildMeterCell("DAYS", "$totalDays Days"),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Modern Fare Breakdown Table
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(5),
                1: FlexColumnWidth(3),
                2: FlexColumnWidth(2),
              },
              children: [
                _buildModernTableRow(
                    'DESCRIPTION', 'RATE / DETAILS', 'AMOUNT',
                    isHeader: true),
                if (invoiceData['trip_type'] == 'Local-Duty') ...[
                  _buildModernTableRow(
                    'Package',
                    '${invoiceData['packageHours']} Hours - ${_formatNumber(invoiceData['packageKm'])} Km',
                    '$packageBaseWithCommission',
                  ),
                  _buildModernTableRow(
                    'Extra Km',
                    'Rs ${_formatNumber(invoiceData['extra_km_price'])} * ${_formatNumber(extraKm)} Km',
                    '$extrakmAmount',
                    isAlt: true,
                  ),
                  _buildModernTableRow(
                    'Extra Hrs',
                    'Rs ${_formatNumber(invoiceData['extra_hours_price'])} * ${_formatNumber(extraHours)} Hrs',
                    '$extraHoursAmount',
                  ),
                ],
                if (invoiceData['trip_type'] == 'Round-Trip') ...[
                  _buildModernTableRow(
                    'Total Km charge',
                    '${_formatNumber(maxKm)} x $commissionFormulaText',
                    '$baceAmount',
                  ),
                  _buildModernTableRow('Total Days', '$totalDays Days', '',
                      isAlt: true),
                ],
                _buildModernTableRow('Parking', '', '$parking_charge'),
                _buildModernTableRow('Toll', '', '$toll_charge', isAlt: true),
                _buildModernTableRow('Permit Charge', '', '$permit_charge'),
                _buildModernTableRow(
                    'Driver Allowance', '', '${driver_allowance ?? ""} ',
                    isAlt: true),
                if (invoiceData['trip_type'] == 'One-way') ...[
                  _buildModernTableRow(
                      'Base Amount', '', '$base_charge'),
                  _buildModernTableRow('Agent Commission', '',
                      '$agent_commission',
                      isAlt: true),
                  _buildModernTableRow('Total Charge', '', '$baceAmount'),
                ],
                if (invoiceData['trip_type'] != 'Local-taxi') ...[
                  _buildModernTableRow('GST ${_formatNumber(gstPercent)}%', '', '$gst'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Total & Payment Summary Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "TOTAL FARE",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _formatCurrency(netTotal),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Advance Amount",
                      style:
                          TextStyle(fontSize: 13, color: Color(0xFF475569))),
                  Text(_formatCurrency(advancedAmount),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669))),
                ],
              ),
              const Divider(height: 16, color: Color(0xFFE2E8F0)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Balance Amount",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A))),
                  Text(_formatCurrency(balanceAmount),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: balanceAmount > 0
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF0F172A))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Agent Commission Note
        if (userType == 'agent') ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: Color(0xFF1E3A8A)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Agent Commission is included in the above amount",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Bank Details Card (if not agent)
        if (!_isAgentInvoice) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("BANK PAYMENT DETAILS",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Color(0xFF1E3A8A))),
                SizedBox(height: 4),
                Text("Bank: Federal Bank  |  A/c: RENTOX CAR",
                    style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                Text("A/c No: 15390200008421  |  IFSC: FDRL0001539",
                    style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Signatory & Footer note
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  !_isAgentInvoice
                      ? "Kindly issue a crossed cheque in favour of AGNI CAR RENTAL \"Subject To Mumbai Jurisdiction\""
                      : "Thank you for choosing $_agentHeaderName",
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Container(
                      width: 100, height: 1, color: const Color(0xFF94A3B8)),
                  const SizedBox(height: 4),
                  const Text("Authorized Sign.",
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMeterCell(String label, String value,
      {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B))),
        Text(value,
            style: TextStyle(
                fontSize: 11,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                color: isHighlight
                    ? const Color(0xFF1E3A8A)
                    : const Color(0xFF0F172A))),
      ],
    );
  }

  TableRow _buildModernTableRow(
    String col1,
    String col2,
    String col3, {
    bool isHeader = false,
    bool isAlt = false,
    bool isTotal = false,
  }) {
    final bgColor = isHeader
        ? const Color(0xFF1E3A8A)
        : isTotal
            ? const Color(0xFFF1F5F9)
            : isAlt
                ? const Color(0xFFF8FAFC)
                : Colors.white;

    final textColor = isHeader
        ? Colors.white
        : isTotal
            ? const Color(0xFF0F172A)
            : const Color(0xFF1E293B);

    final textWeight =
        (isHeader || isTotal) ? FontWeight.bold : FontWeight.normal;
    final fontSize = isHeader ? 11.5 : (isTotal ? 12.5 : 11.5);

    String displayCol3 = '';
    if (col3.isNotEmpty) {
      if (isHeader || col3 == 'TOTAL' || col3 == 'AMOUNT') {
        displayCol3 = col3;
      } else {
        displayCol3 = _formatCurrency(col3);
      }
    }

    return TableRow(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: isHeader
                ? const Color(0xFF1E3A8A)
                : const Color(0xFFE2E8F0),
            width: isTotal ? 1.5 : 0.8,
          ),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            col1,
            style: TextStyle(
              fontWeight: (col1 == 'TOTAL' || isHeader)
                  ? FontWeight.bold
                  : textWeight,
              fontSize: fontSize,
              color: textColor,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            col2,
            style: TextStyle(
              fontWeight: textWeight,
              fontSize: fontSize,
              color: isHeader ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              displayCol3,
              style: TextStyle(
                fontWeight: (col1 == 'TOTAL' || isHeader)
                    ? FontWeight.bold
                    : (isTotal ? FontWeight.bold : FontWeight.w600),
                fontSize: fontSize,
                color: isHeader
                    ? Colors.white
                    : (col1 == 'TOTAL'
                        ? const Color(0xFF1E3A8A)
                        : textColor),
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _isEarlyMorningTime(String timeStr) {
    if (timeStr.isEmpty) return false;
    try {
      final clean = timeStr.trim().toUpperCase();
      int hour = -1;
      int minute = 0;
      if (clean.contains('AM') || clean.contains('PM')) {
        final parts =
            clean.replaceAll('AM', '').replaceAll('PM', '').trim().split(':');
        hour = int.parse(parts[0]);
        if (parts.length > 1) minute = int.parse(parts[1]);
        if (clean.contains('AM')) {
          if (hour == 12) hour = 0;
        } else if (clean.contains('PM')) {
          if (hour != 12) hour += 12;
        }
      } else {
        final parts = clean.split(':');
        hour = int.parse(parts[0]);
        if (parts.length > 1) minute = int.parse(parts[1]);
      }
      return (hour >= 1 && hour < 6) || (hour == 6 && minute == 0);
    } catch (_) {
      return false;
    }
  }
}
