import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import '../widgets/ride_request_dialog.dart';

class OverlayService {
  OverlayService._();
  static final OverlayService instance = OverlayService._();

  static const MethodChannel _channel = MethodChannel('com.rentox.driver/overlay');

  /// Checks if the driver has granted the 'Display Over Other Apps' permission
  Future<bool> hasPermission() async {
    try {
      return await Permission.systemAlertWindow.isGranted;
    } catch (e) {
      debugPrint('⚠️ OverlayService hasPermission error: $e');
      return false;
    }
  }

  /// Opens the system settings to let the driver toggle 'Display Over Other Apps'
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.systemAlertWindow.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('⚠️ OverlayService requestPermission error: $e');
      return false;
    }
  }

  /// Brings the Rentox Driver app directly to the foreground over other active apps
  Future<bool> bringToFront() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('bringToFront');
      return result ?? false;
    } catch (e) {
      debugPrint('⚠️ OverlayService bringToFront error: $e');
      return false;
    }
  }

  /// Handles incoming ride request floating display over other apps
  Future<void> handleIncomingRideAlert(Map<String, dynamic> data) async {
    try {
      final bool isAdvance = (data['is_advance_booking'] == 'true');
      if (isAdvance) {
        debugPrint('📅 Advance Booking notification received. Skipping floating overlay/urgent countdown.');
        final bool canDraw = await hasPermission();
        if (canDraw) {
          await bringToFront();
        }
        return;
      }

      final bool canDraw = await hasPermission();
      if (canDraw) {
        // Bring app above Google Maps / Home Screen
        await bringToFront();
      }

      // Small delay to ensure activity is focused before showing dialog
      await Future.delayed(const Duration(milliseconds: 250));

      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        final bookingId = data['booking_id']?.toString() ?? '';
        if (bookingId.isNotEmpty) {
          final int countdownSec = int.tryParse(data['countdown_seconds']?.toString() ?? '') ?? 45;
          RideRequestDialog.show(
            context,
            bookingId: bookingId,
            tripType: data['booking_type']?.toString() ?? 'Taxi Ride',
            pickupLocation: data['pickup_location']?.toString() ?? '',
            dropLocation: data['drop_location']?.toString() ?? '',
            vendorAmount: data['vendor_amount']?.toString() ?? '0',
            countdownSeconds: countdownSec,
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error handling incoming overlay ride alert: $e');
    }
  }

  /// Shows an Uber/Ola style permission prompt modal to the driver
  Future<void> showPermissionPromptIfNeeded(BuildContext context) async {
    try {
      final bool isGranted = await hasPermission();
      if (isGranted) return;
      if (!context.mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.layers, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Floating Ride Alerts",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
            content: const Text(
              "Enable 'Display Over Other Apps' so you never miss trip requests while using Google Maps or navigation .\n\nTrip requests will automatically pop up with a countdown timer on top of any active screen.",
              style: TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  "Later",
                  style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await requestPermission();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text(
                  "Enable Now",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint("⚠️ Overlay permission prompt error: $e");
    }
  }
}
