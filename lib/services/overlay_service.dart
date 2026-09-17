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
            kmRate: data['km_rate']?.toString() ?? data['kmRate']?.toString(),
            carType: data['car_type']?.toString() ?? data['carType']?.toString(),
            distance: data['distance']?.toString(),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error handling incoming overlay ride alert: $e');
    }
  }

  /// Shows an Uber/Ola style permission prompt modal to the driver (Disabled per user request)
  Future<void> showPermissionPromptIfNeeded(BuildContext context) async {
    // Disabled: Floating overlay permission prompt removed per user request
    return;
  }
}
