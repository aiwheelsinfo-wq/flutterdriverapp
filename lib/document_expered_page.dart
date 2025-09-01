import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'booking_list.dart';
import 'update_document_screen.dart';

class DocumentExperedPage extends StatefulWidget {
  @override
  State<DocumentExperedPage> createState() => _TestState();
}

class _TestState extends State<DocumentExperedPage> {
  @override
  Widget build(BuildContext context) {
    return VehicleListPage(); // no MaterialApp here
  }
}

class VehicleListPage extends StatefulWidget {
  @override
  _VehicleListPageState createState() => _VehicleListPageState();
}

class _VehicleListPageState extends State<VehicleListPage> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  List<Map<String, dynamic>> combinedList = [];
  String? storedNumber;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    storedNumber = await secureStorage.read(key: "phone_number");
    final vehicleResponse = await http.get(Uri.parse(
        'https://agnicarrental.com/driver2025/car_document_expaired_list.php?phone_number=$storedNumber'));

    final driverResponse = await http.get(Uri.parse(
        'https://agnicarrental.com/driver2025/drivers_document_expaired_list.php?phone_number=$storedNumber'));

    if (vehicleResponse.statusCode == 200 && driverResponse.statusCode == 200) {
      final vehicleData = json.decode(vehicleResponse.body);
      final driverData = json.decode(driverResponse.body);

      if (vehicleData['status'] == 'success') {
        List vehicleList = vehicleData['data'];
        vehicleList
            .where((v) =>
                (v['insurance_remaining_days'] != null &&
                    v['insurance_remaining_days'] <= 30) ||
                (v['puc_remaining_days'] != null &&
                    v['puc_remaining_days'] <= 30) ||
                (v['texi_permit_remaining_days'] != null &&
                    v['texi_permit_remaining_days'] <= 30) ||
                (v['fitness_certificate_remaining_days'] != null &&
                    v['fitness_certificate_remaining_days'] <= 30))
            .forEach((v) {
          // Optional: Skip if any important dates are empty
          if (v['insurance_doe'] != null &&
              v['insurance_doe'].toString().isNotEmpty &&
              v['puc_doe'] != null &&
              v['puc_doe'].toString().isNotEmpty &&
              v['texi_permit_doe'] != null &&
              v['texi_permit_doe'].toString().isNotEmpty &&
              v['fitness_certificate_doe'] != null &&
              v['fitness_certificate_doe'].toString().isNotEmpty) {
            combinedList.add({'type': 'vehicle', 'data': v});
          }
        });
      }

      if (driverData['status'] == 'success') {
        List driverList = driverData['data'];
        driverList.where((d) => d['license_remaining_days'] <= 30).forEach((d) {
          combinedList.add({'type': 'driver', 'data': d});
        });
      }

      setState(() {});
    } else {
      print('Failed to fetch data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey,
        title: Text(
          'Document List',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (context) => BookingListPage(phoneNumber: '')),
              (Route<dynamic> route) => true,
            );
          },
        ),
      ),
      body: combinedList.isEmpty
          ? Container(
              height: MediaQuery.of(context).size.height,
              width: double.infinity,
              color: Colors.blue[50],
              padding: EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 50, color: Colors.orange),
                        SizedBox(height: 20),
                        Text(
                          'Document Expiry Monitoring',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'We are actively checking all your documents to ensure they are valid. '
                          'If any document is set to expire within 30 days, we’ll notify you. '
                          'For documents expiring in less than 10 days, you’ll receive daily notifications. '
                          'Please note: once expired, you won’t be able to accept bookings using vehicles or drivers with expired documents.',
                          style: TextStyle(
                              fontSize: 16, color: Colors.black87, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : ListView.builder(
              itemCount: combinedList.length,
              itemBuilder: (context, index) {
                var item = combinedList[index];
                var type = item['type'];
                var data = item['data'];

                return Column(
                  children: [
                    if (index == 0)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 50, color: Colors.orange),
                                SizedBox(height: 20),
                                Text(
                                  'Document Expiry Monitoring',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'We are actively checking all your documents to ensure they are valid. '
                                  'If any document is set to expire within 30 days, we’ll notify you. '
                                  'For documents expiring in less than 10 days, you’ll receive daily notifications. '
                                  'Please note: once expired, you won’t be able to accept bookings using vehicles or drivers with expired documents.',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                      height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (type == 'vehicle') ...[
                      buildVehicleCard(data),
                    ] else if (type == 'driver') ...[
                      buildDriverCard(data),
                    ] else ...[
                      SizedBox.shrink(),
                    ]
                  ],
                );
              },
            ),
    );
  }

  Widget buildVehicleCard(dynamic vehicle) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${vehicle['vehicle_number']}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Divider(),
            Column(
              children: [
                buildExpiryRow(
                    'Insurance',
                    vehicle['insurance_doe'],
                    vehicle['insurance_remaining_days'],
                    vehicle['vehicle_number']),
                buildExpiryRow('PUC', vehicle['puc_doe'],
                    vehicle['puc_remaining_days'], vehicle['vehicle_number']),
                buildExpiryRow(
                    'Taxi Permit',
                    vehicle['texi_permit_doe'],
                    vehicle['texi_permit_remaining_days'],
                    vehicle['vehicle_number']),
                buildExpiryRow(
                    'Fitness',
                    vehicle['fitness_certificate_doe'],
                    vehicle['fitness_certificate_remaining_days'],
                    vehicle['vehicle_number']),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDriverCard(dynamic driver) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Driver: ${driver['full_name']} \nCall: ${driver['phone_number']} ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Divider(),
            SizedBox(height: 6),
            buildSimpleRow(
                'License', driver['license_doe'], driver['phone_number']),
            buildExpiryDays(driver['license_remaining_days']),
          ],
        ),
      ),
    );
  }

  Widget buildExpiryRow(
      String label, String date, int remainingDays, String id) {
    return Visibility(
      visible: remainingDays <= 30,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey, width: 1.0),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 35,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                Expanded(
                  flex: 40,
                  child: Text(
                    "$date  ",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                Expanded(
                    flex: 25,
                    child: IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  UpdateDocumentPage(docType: label, id: id)),
                        );
                        // Your function or action here
                        print('Icon pressed!');
                      },
                      icon: Icon(Icons
                          .edit), // or any other icon like Icons.delete, Icons.update, etc.
                      color: Colors.blue, // optional: change icon color
                      tooltip: 'Edit', // optional: shows tooltip on long press
                    )),
              ],
            ),
            buildExpiryDays(remainingDays),
          ],
        ),
      ),
    );
  }

  Widget buildExpiryDays(int remainingDays) {
    return Row(
      children: [
        Expanded(
          child: Container(
            color: remainingDays <= 5
                ? Colors.red
                : remainingDays <= 10
                    ? Colors.pink
                    : remainingDays <= 20
                        ? Colors.orange
                        : Colors.green,
            padding: EdgeInsets.all(2.0),
            child: Text(
              remainingDays <= 0
                  ? "Already Expired"
                  : "$remainingDays Days Remaining",
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildSimpleRow(String label, String date, String id) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 35,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ),
          Expanded(
            flex: 40,
            child: Text(
              date,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ),
          Expanded(
            flex: 25,
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          UpdateDocumentPage(docType: label, id: id)),
                );
                // Your function or action here
                print('Icon pressed!');
              },
              icon: Icon(Icons
                  .edit), // or any other icon like Icons.delete, Icons.update, etc.
              color: Colors.blue, // optional: change icon color
              tooltip: 'Edit', // optional: shows tooltip on long press
            ),
          ),
        ],
      ),
    );
  }
}
