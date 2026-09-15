import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'api_config.dart';
import 'booking_list.dart';
import 'car_list.dart';
import 'driver_list.dart';
import 'owner_account.dart';

class VendorWalletPage extends StatefulWidget {
  final String? vendorPhone;

  const VendorWalletPage({super.key, this.vendorPhone});

  @override
  State<VendorWalletPage> createState() => _VendorWalletPageState();
}

class _VendorWalletPageState extends State<VendorWalletPage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late Razorpay _razorpay;

  // App Theme Colors (White & Orange Theme)
  static const Color accentAmber = Color(0xFFFF8F00);
  static const Color darkOrange = Color(0xFFE65100);
  static const Color charcoal = Color(0xFF263238);
  static const Color bgLight = Color(0xFFFFFBF0);
  static const Color cardBorder = Color(0xFFFFECB3);

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
        'color': '#FF8F00',
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
      backgroundColor: Colors.white,
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
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accentAmber.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_card_rounded, color: accentAmber, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Recharge Wallet",
                            style: TextStyle(
                              color: charcoal,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Recharge your prepaid wallet to accept Local Taxi bookings. Company commission ($_commissionRate%) is automatically deducted from this wallet after trips.",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Select Quick Amount",
                    style: TextStyle(color: charcoal, fontSize: 13, fontWeight: FontWeight.bold),
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
                              color: isSelected ? accentAmber : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? accentAmber : Colors.grey.shade300,
                                width: 1.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: accentAmber.withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "₹${amt.toInt()}",
                              style: TextStyle(
                                color: isSelected ? Colors.white : charcoal,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _customAmountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: charcoal, fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.currency_rupee, color: accentAmber),
                      labelText: "Or Enter Custom Amount",
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: bgLight,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: accentAmber, width: 1.8),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null && parsed > 0) {
                        setModalState(() => _selectedRechargeAmount = parsed);
                      }
                    },
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentAmber,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                        shadowColor: accentAmber.withValues(alpha: 0.4),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startRazorpayRecharge(_selectedRechargeAmount);
                      },
                      child: Text(
                        "Proceed to Pay ₹${_selectedRechargeAmount.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Colors.white,
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
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: charcoal,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          "Vendor Prepaid Wallet",
          style: TextStyle(
            color: charcoal,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
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
          ? const Center(child: CircularProgressIndicator(color: accentAmber))
          : RefreshIndicator(
              color: accentAmber,
              onRefresh: _fetchWalletDetails,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= Primary Balance Card (Orange Theme) =================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF9800), Color(0xFFFF6D00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6D00).withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "AVAILABLE BALANCE",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isEligible ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isEligible ? "Local Taxi Ready" : "Recharge Needed",
                                      style: const TextStyle(
                                        color: Colors.white,
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
                                ? "Your wallet has sufficient funds to accept Local Taxi bookings. Platform commission will be auto-deducted after trip completion."
                                : "Balance is ₹${_walletBalance.toStringAsFixed(2)}. Please recharge minimum ₹${_minWalletBalance.toStringAsFixed(0)} to accept Local Taxi bookings.",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
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
                                backgroundColor: Colors.white,
                                foregroundColor: darkOrange,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: _isRecharging ? null : _showRechargeBottomSheet,
                              icon: _isRecharging
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: darkOrange),
                                    )
                                  : const Icon(Icons.add_circle_rounded, color: darkOrange),
                              label: Text(
                                _isRecharging ? "Opening Gateway..." : "Recharge Wallet",
                                style: const TextStyle(
                                  color: darkOrange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ================= Quick Parameters Row =================
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cardBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Min. Balance",
                                  style: TextStyle(color: Colors.grey, fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "₹${_minWalletBalance.toStringAsFixed(0)}",
                                  style: const TextStyle(color: charcoal, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cardBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Trip Commission",
                                  style: TextStyle(color: Colors.grey, fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${_commissionRate.toStringAsFixed(0)}%",
                                  style: const TextStyle(color: accentAmber, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ================= Info Card =================
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accentAmber.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.info_outline_rounded, color: accentAmber, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "How Local Taxi Commission Works",
                                  style: TextStyle(color: charcoal, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "Passenger pays you 100% in Cash/UPI at trip completion. The company platform commission ($_commissionRate%) is deducted automatically from this wallet.",
                                  style: TextStyle(color: Colors.grey[700], fontSize: 11.5, height: 1.35),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ================= Transaction History Header =================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Wallet Ledger",
                          style: TextStyle(
                            color: charcoal,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentAmber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "${_transactions.length} entries",
                            style: const TextStyle(color: accentAmber, fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_transactions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 42, color: Colors.grey[400]),
                            const SizedBox(height: 10),
                            Text(
                              "No transactions yet",
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.025),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isCredit
                                        ? Colors.green.shade50
                                        : const Color(0xFFFFF3E0),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                    color: isCredit ? Colors.green.shade700 : darkOrange,
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
                                          color: charcoal,
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
                                    color: isCredit ? Colors.green.shade700 : darkOrange,
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
      bottomNavigationBar: _buildModernBottomNav(),
    );
  }

  Widget _buildModernBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navIcon(0, Icons.dashboard_rounded, () {
            if (_phone.isNotEmpty) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => BookingListPage(phoneNumber: _phone)),
                (route) => false,
              );
            } else {
              Navigator.popUntil(context, (route) => route.isFirst);
            }
          }),
          _navIcon(1, Icons.directions_car_filled_rounded, () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CarListPage()),
            );
          }),
          _navIcon(2, Icons.person_add_rounded, () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriverListPage()),
            );
          }),
          _navIcon(3, Icons.account_balance_wallet_rounded, () {}),
          _navIcon(4, Icons.account_circle_rounded, () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const OwnerProfileScreen()),
            );
          }),
        ],
      ),
    );
  }

  Widget _navIcon(int index, IconData icon, VoidCallback onTap) {
    bool isSel = index == 3; // Index 3 is Wallet Page (Selected!)
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: isSel ? const Color(0xFFFFB300) : Colors.transparent,
            shape: BoxShape.circle),
        child: Icon(icon, color: isSel ? Colors.black : Colors.white38, size: 26),
      ),
    );
  }
}
