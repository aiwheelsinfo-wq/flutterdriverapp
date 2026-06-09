import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';


// ---------------- Date Parsing ----------------
DateTime? parseNumericDate(String? dateStr) {
  if (dateStr == null) return null;
  final regex = RegExp(r'(\d{1,2})[-\/](\d{1,2})[-\/](\d{2,4})');
  final match = regex.firstMatch(dateStr);
  if (match == null) return null;

  int d = int.parse(match.group(1)!);
  int mo = int.parse(match.group(2)!);
  int y = int.parse(match.group(3)!);

  if (y < 100) y += 2000;
  if (mo > 12 && d <= 12) {
    final temp = d;
    d = mo;
    mo = temp;
  }

  try {
    return DateTime(y, mo, d);
  } catch (_) {
    return null;
  }
}

// ---------------- Mobile Parsing ----------------
String? extractMobile(String raw) {
  final regex = RegExp(r'(\+?91[-\s()]?\d{3,5}[-\s()]?\d{5,7}|\b\d{10}\b)');
  final match = regex.firstMatch(raw);
  if (match == null) return null;

  return match.group(1)!.replaceAll(RegExp(r'[-\s()]'), "");
}

class BookingForm extends StatefulWidget {
  const BookingForm({super.key});

  @override
  State<BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends State<BookingForm> {
  final TextEditingController messageCtrl = TextEditingController();
  final TextEditingController mobileCtrl = TextEditingController();
  final TextEditingController dateCtrl = TextEditingController();
  final TextEditingController tripMsgCtrl = TextEditingController();

  bool extracted = false;
  Map<String, dynamic>? apiResponse;

  // ---------------- Extraction ----------------
  void extractDetails() {
    final raw = messageCtrl.text;

    // Date
    String? date;
    final numericDateMatch =
        RegExp(r'\d{1,2}[-\/]\d{1,2}[-\/]\d{2,4}').firstMatch(raw);
    if (numericDateMatch != null) {
      final parsed = parseNumericDate(numericDateMatch.group(0));
      if (parsed != null) {
        date = parsed.toIso8601String().split("T")[0];
      }
    }

    // Mobile
    final mobile = extractMobile(raw);

    // Populate controllers
    tripMsgCtrl.text = raw;
    mobileCtrl.text = mobile ?? "";
    dateCtrl.text = date ?? "";

    setState(() {
      extracted = true;
    });
  }

  // ---------------- Submit ----------------
  Future<void> submit() async {
    final payload = {
      "trip_message": tripMsgCtrl.text,
      "mobile_number": mobileCtrl.text.isNotEmpty
          ? mobileCtrl.text.substring(mobileCtrl.text.length - 10)
          : "",
      "pickup_date": dateCtrl.text,
      "status": "active",
    };

    try {
      final res = await http.post(
        Uri.parse(ApiConfig.whatsappTrips),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      setState(() {
        apiResponse = jsonDecode(res.body);
      });
    } catch (e) {
      setState(() {
        apiResponse = {"success": false, "message": e.toString()};
      });
    }
  }

  // ---------------- Reset ----------------
  void resetForm() {
    messageCtrl.clear();
    mobileCtrl.clear();
    dateCtrl.clear();
    tripMsgCtrl.clear();
    setState(() {
      extracted = false;
      apiResponse = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("WhatsApp Booking Form")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (!extracted) ...[
                TextField(
                  controller: messageCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Paste WhatsApp booking message here...",
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: extractDetails,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent),
                  child: const Text("Extract Date & Mobile"),
                ),
              ] else ...[
                TextField(
                  controller: tripMsgCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Trip Message",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dateCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "Date",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: mobileCtrl,
                  decoration: const InputDecoration(
                    labelText: "Mobile Number",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: submit,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      child: const Text("Submit"),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: resetForm,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey),
                      child: const Text("Reset"),
                    ),
                  ],
                ),
              ],
              if (apiResponse != null) ...[
                const SizedBox(height: 20),
                const Text(
                  "API Response:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  color: Colors.grey[200],
                  child: Text(
                    const JsonEncoder.withIndent("  ").convert(apiResponse),
                    style: const TextStyle(fontFamily: "monospace"),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
