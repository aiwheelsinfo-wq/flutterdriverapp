import 'package:flutter/material.dart';
import 'package:agnidriver2025/razorpay.dart'; // import your RazorpayPaymentPage
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RechargePage extends StatelessWidget {
  const RechargePage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<_RechargeOption> options = [
      _RechargeOption(
        title: "Basic",
        price: 1,
        duration: "10 Days",
        subtitle: "Starter Pack",
        color: Colors.blueGrey[900]!,
        features: [
          _Feature(Icons.local_taxi, "Up to 20 Rides"),
          _Feature(Icons.access_time, "Standard Booking"),
          _Feature(Icons.support_agent, "Basic Support"),
        ],
      ),
      _RechargeOption(
        title: "Standard",
        price: 120,
        duration: "30 Days",
        subtitle: "Value Pack",
        color: Colors.blueGrey[800]!,
        features: [
          _Feature(Icons.local_taxi, "Up to 80 Rides"),
          _Feature(Icons.flash_on, "Priority Booking"),
          _Feature(Icons.support, "24/7 Support"),
        ],
      ),
      _RechargeOption(
        title: "Premium",
        price: 315,
        duration: "90 Days",
        subtitle: "Best Value",
        color: Colors.amber[800]!,
        features: [
          _Feature(Icons.local_taxi, "Unlimited Rides"),
          _Feature(Icons.verified, "Top Priority Booking"),
          _Feature(Icons.headset_mic, "Dedicated Support"),
          _Feature(Icons.card_giftcard, "Special Discounts"),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Recharge Plans"),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: options.length,
        itemBuilder: (context, index) {
          return _RechargeCard(option: options[index]);
        },
      ),
    );
  }
}

class _RechargeOption {
  final String title;
  final int price;
  final String duration;
  final String subtitle;
  final Color color;
  final List<_Feature> features;

  _RechargeOption({
    required this.title,
    required this.price,
    required this.duration,
    required this.subtitle,
    required this.color,
    required this.features,
  });
}

class _Feature {
  final IconData icon;
  final String text;

  _Feature(this.icon, this.text);
}

class _RechargeCard extends StatelessWidget {
  final _RechargeOption option;

  const _RechargeCard({required this.option});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: option.color,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(option.title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text(option.subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: option.features
                .map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(f.icon, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(f.text,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("₹${option.price} / ${option.duration}",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
                onPressed: () async {
                  final storage = FlutterSecureStorage();
                  String? phoneNumber = await storage.read(key: "phone_number");
                  if (phoneNumber == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Phone number not found!")),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RazorpayPaymentPage(
                        senderId: phoneNumber,
                        amount: option.price.toDouble(),
                        description: 'whatsApp Booking  Payment',
                      ),
                    ),
                  );
                },
                child: const Text("Recharge"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
