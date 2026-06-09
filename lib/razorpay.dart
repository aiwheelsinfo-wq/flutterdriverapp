import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:agnidriver2025/whatsapp_booking_list.dart';
import 'api_config.dart';

//import 'BookingCustomerMessagePage.dart';

class RazorpayPaymentPage extends StatefulWidget {
  final String senderId;
  final double amount;
  final String description; // 'yes' or 'no'

  const RazorpayPaymentPage({
    super.key,
    required this.senderId,
    required this.amount,
    required this.description,
  });

  @override
  _RazorpayPaymentPageState createState() => _RazorpayPaymentPageState();
}

class _RazorpayPaymentPageState extends State<RazorpayPaymentPage> {
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    print("RazorpayPaymentPage opened with:");
    print("senderId: ${widget.senderId}");
    print("amount: ${widget.amount}");
    print("description: ${widget.description}");
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _openCheckout();
  }

  void _openCheckout() {
    var options = {
      'key': 'rzp_live_q9eMvidQ7LrwVQ', // Replace with your actual key
      'amount': (widget.amount * 100).toInt(), //(1 * 100).toInt(),
      'name': 'Agni Car Rental',
      'description': widget.description,
      'prefill': {
        'email': '',
        'contact': '',
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print("Error opening Razorpay checkout: $e");
    }
  }

  Future<void> _handleSuccess(PaymentSuccessResponse response) async {
    print("Payment Successful:");
    print("paymentId: ${response.paymentId}");
    print("orderId: ${response.orderId}");
    print("signature: ${response.signature}");
    var url = Uri.parse(ApiConfig.payment);


    try {
      var updateRes = await http.post(
        url,
        headers: {
          "Content-Type": "application/json", // 👈 VERY important!
        },
        body: json.encode({
          "sender_Id": widget.senderId,
          "payment_Id": response.paymentId ?? "",
          "status": "success",
          "amount": widget.amount,
          "description": widget.description,
        }),
      );

      print("Server response: ${updateRes.body}");

      var resData = json.decode(updateRes.body);
      if (resData['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => NearbyTripsPage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Payment saved but booking update failed!")),
        );
      }
    } catch (e) {
      print("Error during booking update: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment was successful, but update failed.")),
      );
    }
  }

  void _handleError(PaymentFailureResponse response) {
    print("Payment Failed: ${response.message}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment failed! Try again.")),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
