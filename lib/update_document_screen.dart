import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'booking_list.dart';

class UpdateDocumentPage extends StatefulWidget {
  final String docType;
  final String id;

  UpdateDocumentPage({required this.docType, required this.id});

  @override
  _UpdateDocumentPageState createState() => _UpdateDocumentPageState();
}

class _UpdateDocumentPageState extends State<UpdateDocumentPage> {
  TextEditingController doiController = TextEditingController();
  TextEditingController doeController = TextEditingController();

  bool get showDoi =>
      widget.docType.toLowerCase() != 'insurance' &&
      widget.docType.toLowerCase() != 'license';

  String get title => "${widget.docType} Expiry Update";

  // 🔹 Open a date picker and set the date into the controller
  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    DateTime initialDate = DateTime.now();
    DateTime firstDate = DateTime(2000);
    DateTime lastDate = DateTime(2100);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      controller.text = picked.toIso8601String().split('T')[0]; // yyyy-MM-dd
    }
  }

  void submitUpdate() async {
    final uri = Uri.parse(
        "https://agnicarrental.com/driver2025/change_document_expaired_date.php");

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'id': widget.id,
        'docType': widget.docType,
        'newDateDoi': doiController.text,
        'newDateDoe': doeController.text,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      String message = data['message'] ?? 'Update successful';

      // ✅ Show a dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Success'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog

                // ✅ Clear navigation stack and go to BookingListPage
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (context) => BookingListPage(phoneNumber: '')),
                  (Route<dynamic> route) => false,
                );
              },
              child: Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update document')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (showDoi) ...[
              TextField(
                controller: doiController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: '${widget.docType} DOI (yyyy-mm-dd)',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () => _selectDate(context, doiController),
              ),
              SizedBox(height: 10),
            ],
            TextField(
              controller: doeController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: '${widget.docType} DOE (yyyy-mm-dd)',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () => _selectDate(context, doeController),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: submitUpdate,
              child: Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
