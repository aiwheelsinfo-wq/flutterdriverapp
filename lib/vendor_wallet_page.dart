import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'api_config.dart';

class VendorWalletPage extends StatefulWidget {
  final String? vendorPhone;

  const VendorWalletPage({super.key, this.vendorPhone});

  @override
  State<VendorWalletPage> createState() => _VendorWalletPageState();
}

class _VendorWalletPageState extends State<VendorWalletPage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late Razorpay _razorpay;

  String _phone = '';
  double _walletBalance = 0.0;
  double _minWalletBalance = 0.0;
  double _commissionRate = 10.0;
  bool _isEligible = false;
  bool _isLoading = true;
  bool _isRecharging = false;
  String? _razorpayKey;
  List<dynamic> _transactions = [];

  final TextEditingController _customAmountController = TextEditingController();
  double _selectedRechargeAmount = 200.0;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _initWallet();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _customAmountController.dispose();
    super.dispose();
  }

  Future<void> _initWallet() async {
    String? phone = widget.vendorPhone;
    if (phone == null || phone.isEmpty) {
      phone = await _storage.read(key: 'phone');
    }
    _phone = phone ?? '';
    await Future.wait([
      _fetchRazorpayConfig(),
      _fetchWalletDetails(),
    ]);
  }

  Future<void> _fetchRazorpayConfig() async {
    try {
      final res = await http.get(Uri.parse("${ApiConfig.legacyPath}/get_razorpay_config.php"));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true && data['razorpay_key'] != null) {
          _razorpayKey = data['razorpay_key'];
        }
      }
    } catch (e) {
      debugPrint("Error fetching Razorpay key: $e");
    }
  }

  Future<void> _fetchWalletDetails() async {
    if (_phone.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final uri = Uri.parse("${ApiConfig.vendorWallet}?action=get_wallet&phone_number=$_phone");
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'success') {
          setState(() {
            _walletBalance = (data['wallet_balance'] as num?)?.toDouble() ?? 0.0;
            _minWalletBalance = (data['min_wallet_balance'] as num?)?.toDouble() ?? 0.0;
            _commissionRate = (data['commission_rate'] as num?)?.toDouble() ?? 10.0;
            _isEligible = data['is_eligible_for_local_taxi'] == true;
            _transactions = data['transactions'] ?? [];
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("Error fetching wallet details: $e");
    }

    setState(() => _isLoading = false);
  }

  void _startRazorpayRecharge(double amount) {
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select or enter a valid amount")),
      );
      return;
    }

    if (_razorpayKey == null || _razorpayKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Payment gateway is temporarily unavailable. Try again shortly.")),
      );
      return;
    }

    setState(() => _isRecharging = true);

    var options = {
      'key': _razorpayKey,
      'amount': (amount * 100).toInt(),
      'name': 'Rentox Transport Partner',
      'description': 'Vendor Wallet Recharge',
      'prefill': {
        'contact': _phone,
      },
      'theme': {
        'color': '#10B981',
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() => _isRecharging = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not open payment gateway: $e")),
      );
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isRecharging = true);
    final paymentId = response.paymentId ?? '';

    try {
      final res = await http.post(
        Uri.parse(ApiConfig.vendorWallet),
        body: {
          'action': 'recharge_wallet',
          'phone_number': _phone,
          'amount': _selectedRechargeAmount.toString(),
          'payment_id': paymentId,
          'description': 'Recharge via Razorpay ($paymentId)',
        },
      );

      final data = json.decode(res.body);
      if (!mounted) return;
      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green[800],
            content: Text("Recharge of ₹${_selectedRechargeAmount.toStringAsFixed(0)} successful!"),
          ),
        );
        await _fetchWalletDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red[800],
            content: Text(data['message'] ?? "Failed to credit recharge"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating wallet: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRecharging = false);
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isRecharging = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red[800],
        content: Text("Payment failed: ${response.message ?? 'Cancelled by user'}"),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() => _isRecharging = false);
  }

  void _showRechargeBottomSheet() {
    _customAmountController.text = _selectedRechargeAmount.toStringAsFixed(0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final amounts = [100.0, 200.0, 500.0, 1000.0];

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Recharge Wallet",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Recharge your prepaid wallet to accept Local Taxi bookings. Company commission ($_commissionRate%) will be deducted automatically from this balance after trips are completed.",
                    style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Select Quick Amount",
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: amounts.map((amt) {
                      final isSelected = _selectedRechargeAmount == amt;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              _selectedRechargeAmount = amt;
                              _customAmountController.text = amt.toStringAsFixed(0);
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF10B981) : const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF34D399) : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "₹${amt.toInt()}",
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _customAmountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.currency_rupee, color: Color(0xFF10B981)),
                      labelText: "Or Enter Custom Amount",
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null && parsed > 0) {
                        setModalState(() => _selectedRechargeAmount = parsed);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startRazorpayRecharge(_selectedRechargeAmount);
                      },
                      child: Text(
                        "Proceed to Pay ₹${_selectedRechargeAmount.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          "Partner Wallet",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchWalletDetails();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : RefreshIndicator(
              color: const Color(0xFF10B981),
              onRefresh: _fetchWalletDetails,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= Balance Card =================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isEligible ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFEF4444).withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "AVAILABLE BALANCE",
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _isEligible
                                      ? const Color(0xFF10B981).withOpacity(0.15)
                                      : const Color(0xFFEF4444).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _isEligible ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isEligible ? Icons.check_circle : Icons.warning_amber_rounded,
                                      size: 13,
                                      color: _isEligible ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isEligible ? "Local Taxi Ready" : "Recharge Needed",
                                      style: TextStyle(
                                        color: _isEligible ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "₹${_walletBalance.toStringAsFixed(2)}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isEligible
                                ? "You can accept Local Taxi trips. 10% platform share will be deducted upon trip completion."
                                : "Balance is ₹${_walletBalance.toStringAsFixed(2)}. Please recharge to accept Local Taxi bookings.",
                            style: TextStyle(
                              color: _isEligible ? Colors.grey[400] : const Color(0xFFFCA5A5),
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: _isRecharging ? null : _showRechargeBottomSheet,
                              icon: _isRecharging
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                    )
                                  : const Icon(Icons.add_circle_outline, color: Colors.black),
                              label: Text(
                                _isRecharging ? "Opening Gateway..." : "Recharge Wallet",
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ================= Info Banner =================
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.info_outline, color: Color(0xFF60A5FA), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "How Local Taxi Commission Works",
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Passenger pays you 100% in Cash/UPI at trip end. The platform commission ($_commissionRate%) is automatically deducted from this wallet.",
                                  style: TextStyle(color: Colors.grey[400], fontSize: 11.5, height: 1.3),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ================= Transaction History =================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Wallet Ledger",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${_transactions.length} entries",
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_transactions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 42, color: Colors.grey[600]),
                            const SizedBox(height: 10),
                            Text(
                              "No transactions yet",
                              style: TextStyle(color: Colors.grey[400], fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _transactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, index) {
                          final tx = _transactions[index];
                          final isCredit = tx['transaction_type'] == 'wallet_recharge';
                          final amt = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                          final desc = tx['description'] ?? 'Wallet transaction';
                          final date = tx['created_at'] ?? '';

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isCredit
                                        ? const Color(0xFF10B981).withOpacity(0.15)
                                        : const Color(0xFFEF4444).withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        desc,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        date,
                                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  "${isCredit ? '+' : '-'}₹${amt.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    color: isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
