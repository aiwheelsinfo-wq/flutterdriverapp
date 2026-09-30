import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ParsedStop {
  final String label; // "Stop 1", "Stop 2", "Drop"
  final String address;
  final bool isFinalDrop;

  ParsedStop({
    required this.label,
    required this.address,
    this.isFinalDrop = false,
  });

  String get shortAddress {
    final parts = address.split(',');
    if (parts.isNotEmpty) {
      final first = parts.first.trim();
      if (first.isNotEmpty) return first;
    }
    return address;
  }
}

class ParsedRoute {
  final String raw;
  final bool isMultiStop;
  final List<ParsedStop> intermediateStops;
  final ParsedStop? finalDrop;
  final String displayFinalDrop;

  ParsedRoute({
    required this.raw,
    required this.isMultiStop,
    required this.intermediateStops,
    this.finalDrop,
    required this.displayFinalDrop,
  });

  int get totalStopsCount => intermediateStops.length + (finalDrop != null ? 1 : 0);

  String get stopsSummary {
    if (intermediateStops.isEmpty) return "";
    return intermediateStops.map((s) => s.shortAddress).join(" • ");
  }
}

class RouteHelper {
  /// Parses any drop_location / to_address string into structured stops.
  /// Handles:
  /// - Modern pipe format: "Stop 1: Place A | Stop 2: Place B | Drop: Place C"
  /// - Unicode arrow: "Stop 1: Place A ➔ Stop 2: Place B ➔ Drop: Place C"
  /// - Corrupted unicode: "Stop 1: Place A ? Stop 2: Place B ? Drop: Place C"
  /// - Single drop: "Calicut Airport, Kozhikode"
  /// - Empty or null: "Local Trip / Drop"
  static ParsedRoute parseRoute(String? rawAddress, {String defaultDrop = "Local Trip / Drop"}) {
    if (rawAddress == null || rawAddress.trim().isEmpty) {
      return ParsedRoute(
        raw: "",
        isMultiStop: false,
        intermediateStops: [],
        finalDrop: null,
        displayFinalDrop: defaultDrop,
      );
    }

    final String trimmed = rawAddress.trim();

    // Check if it contains multi-stop markers
    final bool hasMarker = trimmed.contains('|') ||
        trimmed.contains('➔') ||
        trimmed.contains('? Stop') ||
        trimmed.contains('? Drop') ||
        trimmed.contains(' ? ') ||
        trimmed.startsWith('Stop 1:') ||
        trimmed.startsWith('Stop 1 :');

    if (!hasMarker) {
      return ParsedRoute(
        raw: trimmed,
        isMultiStop: false,
        intermediateStops: [],
        finalDrop: ParsedStop(label: "Drop", address: trimmed, isFinalDrop: true),
        displayFinalDrop: trimmed,
      );
    }

    // Normalize delimiters to ' | '
    final String normalized = trimmed
        .replaceAll('➔', ' | ')
        .replaceAll(RegExp(r'\s*\?\s*(?=Stop|\bDrop:|\bFinal Drop:)'), ' | ')
        .replaceAll(RegExp(r'\s+\?\s+'), ' | ');

    final List<String> rawParts = normalized
        .split('|')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (rawParts.length <= 1) {
      final String part = rawParts.isNotEmpty ? rawParts.first : trimmed;
      final String cleaned = part.replaceFirst(
        RegExp(r'^(?:Stop \d+|Drop|Final Drop)\s*:\s*', caseSensitive: false),
        '',
      ).trim();
      final String finalAddr = cleaned.isNotEmpty ? cleaned : part;
      return ParsedRoute(
        raw: trimmed,
        isMultiStop: false,
        intermediateStops: [],
        finalDrop: ParsedStop(label: "Drop", address: finalAddr, isFinalDrop: true),
        displayFinalDrop: finalAddr,
      );
    }

    final List<ParsedStop> intermediateStops = [];
    ParsedStop? finalDrop;

    for (int i = 0; i < rawParts.length; i++) {
      final String part = rawParts[i];
      final stopMatch = RegExp(r'^Stop\s*(\d+)\s*:\s*(.+)$', caseSensitive: false).firstMatch(part);
      final dropMatch = RegExp(r'^(?:Drop|Final Drop)\s*:\s*(.+)$', caseSensitive: false).firstMatch(part);

      if (stopMatch != null) {
        final String stopNum = stopMatch.group(1) ?? "${i + 1}";
        final String stopAddr = stopMatch.group(2)?.trim() ?? "";
        // If this is the last element and no explicit Drop was added, treat as final drop
        if (i == rawParts.length - 1 && rawParts.length > 1) {
          finalDrop = ParsedStop(label: "Stop $stopNum", address: stopAddr, isFinalDrop: true);
        } else {
          intermediateStops.add(ParsedStop(label: "Stop $stopNum", address: stopAddr, isFinalDrop: false));
        }
      } else if (dropMatch != null) {
        final String dropAddr = dropMatch.group(1)?.trim() ?? "";
        finalDrop = ParsedStop(label: "Drop", address: dropAddr, isFinalDrop: true);
      } else {
        // Plain string without prefix
        if (i == rawParts.length - 1) {
          finalDrop = ParsedStop(label: "Drop", address: part, isFinalDrop: true);
        } else {
          intermediateStops.add(ParsedStop(label: "Stop ${i + 1}", address: part, isFinalDrop: false));
        }
      }
    }

    if (finalDrop == null && intermediateStops.isNotEmpty) {
      finalDrop = intermediateStops.removeLast();
    }

    final bool isMulti = intermediateStops.isNotEmpty;
    final String displayDrop = (finalDrop?.address.isNotEmpty == true)
        ? finalDrop!.address
        : (isMulti ? "Multi-Stop Route" : defaultDrop);

    return ParsedRoute(
      raw: trimmed,
      isMultiStop: isMulti,
      intermediateStops: intermediateStops,
      finalDrop: finalDrop,
      displayFinalDrop: displayDrop,
    );
  }

  /// Builds a vertical timeline route stepper for the Incoming Ride Dialog and Trip Accept Screen.
  static Widget buildRouteStepper({
    required BuildContext context,
    required String pickupLocation,
    required String dropLocation,
    String? distanceKm,
    bool isDialog = true,
  }) {
    final parsed = parseRoute(dropLocation);
    final hasDistance = distanceKm != null && distanceKm.isNotEmpty && distanceKm != "0";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parsed.isMultiStop) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.alt_route_rounded, size: 14, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 6),
                Text(
                  "Multi-Stop Route (${parsed.intermediateStops.length} intermediate stop${parsed.intermediateStops.length > 1 ? 's' : ''})",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E40AF),
                  ),
                ),
              ],
            ),
          ),
        ],
        // 🟢 1. PICKUP
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  width: 3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PICKUP',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF059669),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    pickupLocation.isNotEmpty ? pickupLocation : 'Customer pickup location',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Connecting Line after Pickup
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Container(
                  width: 2,
                  height: hasDistance ? 20 : 16,
                  color: Colors.grey.shade300,
                ),
              ),
              if (hasDistance) ...[
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.straighten_rounded, size: 11, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        '$distanceKm km trip',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // 🔵 2. INTERMEDIATE STOPS (If multi-stop)
        if (parsed.isMultiStop) ...[
          for (int i = 0; i < parsed.intermediateStops.length; i++) ...[
            _buildIntermediateStopRow(parsed.intermediateStops[i], i + 1),
            // Connecting line after intermediate stop
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(
                width: 2,
                height: 16,
                color: const Color(0xFF93C5FD),
              ),
            ),
          ],
        ],

        // 🔴 3. FINAL DROP / DESTINATION
        if (dropLocation.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    width: 3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          parsed.isMultiStop ? 'FINAL DROP' : 'DROP',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFDC2626),
                            letterSpacing: 0.6,
                          ),
                        ),
                        if (parsed.isMultiStop) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "DESTINATION",
                              style: GoogleFonts.poppins(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      parsed.displayFinalDrop,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static Widget _buildIntermediateStopRow(ParsedStop stop, int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF0284C7).withValues(alpha: 0.3),
              width: 3,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      stop.label.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0369A1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'INTERMEDIATE STOP',
                    style: GoogleFonts.poppins(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                stop.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds a multi-stop card route display for the Marketplace Feed in `booking_list.dart`.
  static Widget buildCardRouteSection({
    required String? pickupLocation,
    required String? dropLocation,
  }) {
    final parsed = parseRoute(dropLocation);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pickup
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Pickup",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              pickupLocation ?? "N/A",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),

        // Intermediate Stops Badge (if multi-stop)
        if (parsed.isMultiStop) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.alt_route_rounded, size: 13, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    "${parsed.intermediateStops.length} Stops: ${parsed.stopsSummary}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ] else ...[
          const SizedBox(height: 20),
        ],

        // Drop
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              parsed.isMultiStop ? "Final Drop" : "Drop",
              style: TextStyle(
                color: parsed.isMultiStop ? const Color(0xFFDC2626) : Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              parsed.displayFinalDrop,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds a multi-stop journey line indicator for the marketplace feed card.
  static Widget buildCardJourneyIndicator({
    required String? dropLocation,
    required Color primaryColor,
  }) {
    final parsed = parseRoute(dropLocation);

    if (!parsed.isMultiStop) {
      return Column(
        children: [
          Icon(Icons.radio_button_checked, color: primaryColor, size: 16),
          Container(width: 2, height: 35, color: Colors.grey[200]),
          const Icon(Icons.location_on, color: Colors.redAccent, size: 18),
        ],
      );
    }

    return Column(
      children: [
        Icon(Icons.radio_button_checked, color: primaryColor, size: 16),
        Container(width: 2, height: 12, color: Colors.grey[300]),
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF0284C7),
            shape: BoxShape.circle,
          ),
        ),
        Container(width: 2, height: 12, color: const Color(0xFF93C5FD)),
        const Icon(Icons.location_on, color: Colors.redAccent, size: 18),
      ],
    );
  }
}
