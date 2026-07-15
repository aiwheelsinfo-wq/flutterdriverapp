import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class SettlementsPage extends StatefulWidget {
  final String phoneNumber;
  const SettlementsPage({super.key, required this.phoneNumber});

  @override
  _SettlementsPageState createState() => _SettlementsPageState();
}

class _SettlementsPageState extends State<SettlementsPage> {
  bool isLoading = true;
  List<dynamic> settlements = [];
  List<dynamic> filteredSettlements = [];
  String searchQuery = "";
  String selectedStatus = "All"; // "All", "Pending", "Paid"
  double totalEarnings = 0.0;
  double totalPending = 0.0;
  String? errorMessage;

  // Theme Colors consistent with owner_account.dart
  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color accentAmber = Color(0xFFFF8F00);
  static const Color charcoal = Color(0xFF263238);
  static const Color bgLight = Color(0xFFFFFBF0);

  @override
  void initState() {
    super.initState();
    fetchSettlements();
  }

  void _calculateTotals() {
    double earnings = 0.0;
    double pending = 0.0;
    for (var s in settlements) {
      final double vendorAmt = double.tryParse(s["vendor_amount"]?.toString() ?? "0") ?? 0.0;
      final double eligibleAmt = double.tryParse(s["eligible_amount"]?.toString() ?? "0") ?? 0.0;
      final String status = (s["settlement_status"] ?? "Pending").toString().toLowerCase();

      earnings += (vendorAmt > 0 ? vendorAmt : eligibleAmt);

      if (status != 'paid') {
        pending += eligibleAmt;
      }
    }
    setState(() {
      totalEarnings = earnings;
      totalPending = pending;
    });
  }

  void _filterSettlements() {
    setState(() {
      filteredSettlements = settlements.where((s) {
        final bookingId = (s["booking_id"] ?? "").toString().toLowerCase();
        final tripType = (s["trip_type"] ?? "").toString().toLowerCase();
        final status = (s["settlement_status"] ?? "Pending").toString().toLowerCase();

        // Search filter
        final matchesSearch = bookingId.contains(searchQuery.toLowerCase()) ||
            tripType.contains(searchQuery.toLowerCase());

        // Status filter
        bool matchesStatus = true;
        if (selectedStatus == "Pending") {
          matchesStatus = status != 'paid';
        } else if (selectedStatus == "Paid") {
          matchesStatus = status == 'paid';
        }

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Future<void> fetchSettlements() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.getSettlements),
        body: {"phone_number": widget.phoneNumber},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          if (mounted) {
            setState(() {
              settlements = data["settlements"] ?? [];
              isLoading = false;
            });
            _calculateTotals();
            _filterSettlements();
          }
        } else {
          if (mounted) {
            setState(() {
              errorMessage = data["message"] ?? "Failed to fetch settlements";
              isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = "Server error: ${response.statusCode}";
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = "Connection error: $e";
          isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.amber[700]!;
      case 'approved':
        return Colors.green;
      case 'hold':
        return Colors.deepOrange;
      case 'processing':
        return Colors.blue;
      case 'paid':
        return Colors.green[700]!;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text(
          "Advance Settlements",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: charcoal,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchSettlements,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryAmber))
          : errorMessage != null
              ? _buildErrorState()
              : _buildMainContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              errorMessage ?? "Something went wrong",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: charcoal),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: fetchSettlements,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryAmber,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildStatsSummary(),
        _buildSearchAndFilters(),
        _buildInfoBanner(),
        Expanded(
          child: filteredSettlements.isEmpty
              ? _buildNoResultsState()
              : ListView.builder(
                  itemCount: filteredSettlements.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemBuilder: (context, index) {
                    final s = filteredSettlements[index];
                    return _buildSettlementCard(s);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatsSummary() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          // Total Earnings Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total Earnings",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      Icon(Icons.account_balance_wallet, color: Colors.green[600], size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "₹${totalEarnings.toStringAsFixed(0)}",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Total Pending Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total Pending",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const Icon(Icons.hourglass_empty, color: primaryAmber, size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "₹${totalPending.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: charcoal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Search Field
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: TextField(
              onChanged: (val) {
                searchQuery = val;
                _filterSettlements();
              },
              decoration: const InputDecoration(
                hintText: "Search by Booking ID or Trip Type...",
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filter Tabs
          Row(
            children: [
              _buildFilterChip("All"),
              const SizedBox(width: 8),
              _buildFilterChip("Pending"),
              const SizedBox(width: 8),
              _buildFilterChip("Paid"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String status) {
    final isSelected = selectedStatus == status;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedStatus = status;
        });
        _filterSettlements();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryAmber : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryAmber : Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : charcoal,
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    if (settlements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              "No Settlements Found",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                "Settlements are processed only for One-way trips with advances.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "No matching settlements found",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryAmber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryAmber.withOpacity(0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: accentAmber, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Your settlement will be processed by admin within 7 days after successful trip completion or booking cancellation (Vendor Protection).",
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: charcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementCard(dynamic s) {
    final bookingId = s["booking_id"] ?? "";
    final double advancePaid = double.tryParse(s["advance_paid"]?.toString() ?? "0") ?? 0.0;
    final double eligibleAmount = double.tryParse(s["eligible_amount"]?.toString() ?? "0") ?? 0.0;
    final status = s["settlement_status"] ?? "Pending";
    final expectedDate = s["expected_settlement_date"] ?? "";
    final settlementDate = s["settlement_date"];
    final txnRef = s["transaction_reference"];
    final tripStatus = s["trip_status"] ?? "";
    final bool isCancelled = tripStatus.toString().toLowerCase() == 'cancelled';
    final tripType = s["trip_type"] ?? "";
    final double vendorAmount = double.tryParse(s["vendor_amount"]?.toString() ?? "0") ?? 0.0;
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: statusColor, width: 6),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Booking #$bookingId",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: charcoal,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isCancelled) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade100, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 14, color: Colors.red[800]),
                        const SizedBox(width: 6),
                        Text(
                          "Cancelled Booking (Vendor Protection)",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 24, thickness: 1),

                // Amount Breakdown
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tripType.toString().toLowerCase() == 'round-trip'
                                ? "Cash Collected"
                                : "Customer Advance",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tripType.toString().toLowerCase() == 'round-trip'
                                ? "₹${(vendorAmount - eligibleAmount).toStringAsFixed(2)}"
                                : "₹${advancePaid.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: charcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCancelled
                                ? "Vendor Compensation"
                                : (tripType.toString().toLowerCase() == 'round-trip'
                                    ? "Due from Rentox"
                                    : "Your 60% Share"),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "₹${eligibleAmount.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (tripType.toString().toLowerCase() == 'round-trip') ...[
                  const SizedBox(height: 12),
                  const Divider(height: 16, thickness: 0.5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total Vendor Earnings:",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: charcoal,
                        ),
                      ),
                      Text(
                        "₹${vendorAmount.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[800],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // Dates & Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.calendar_month,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status.toString().toLowerCase() == 'paid'
                                ? "Settled On"
                                : "Expected Settlement Date",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            status.toString().toLowerCase() == 'paid' &&
                                    settlementDate != null
                                ? settlementDate.toString()
                                : expectedDate,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: charcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Transaction Reference (if paid)
                if (status.toString().toLowerCase() == 'paid' &&
                    txnRef != null &&
                    txnRef.toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.receipt_long,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Transaction Ref / UTR",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              txnRef.toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: "monospace",
                                fontWeight: FontWeight.w600,
                                color: charcoal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
