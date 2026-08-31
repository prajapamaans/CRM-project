import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/master_data_provider.dart';

/// Shared helpers for every screen that shows an MSP field.
///
/// MSP values come from `GET /api/msp-options` via [MasterDataProvider]
/// plus dynamically added custom options.
class MspFieldUtils {
  MspFieldUtils._();

  static const String addCustomMspValue = '__ADD_CUSTOM_MSP__';
  static const String addCustomMspLabel = '+ Add Custom MSP';

  /// Placeholder shown on an MSP dropdown, reflecting the current load state.
  static String placeholder(
    MasterDataProvider provider, {
    String idle = 'Select an MSP',
  }) {
    if (provider.isMspLoading && provider.mspNames.isEmpty) {
      return 'Loading MSPs...';
    }
    if (provider.mspError != null && provider.mspNames.isEmpty) {
      return 'Failed to load MSPs — tap to retry';
    }
    if (provider.mspNames.isEmpty) {
      return 'No MSP options available';
    }
    return idle;
  }

  /// Splits a record's stored MSP field into names. Records hold one or more
  /// MSPs as a comma-separated string (`'Magnit, Beeline'`).
  static List<String> namesFrom(String? stored) {
    final value = stored?.trim();
    if (value == null || value.isEmpty) return const [];
    return value
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// The API options, plus any value already stored on the record so an
  /// existing selection is never silently dropped from the field.
  static List<String> optionsWith(
    MasterDataProvider provider,
    String? currentValue,
  ) {
    final options = List<String>.from(provider.mspNames);
    final current = currentValue?.trim();
    if (current != null && current.isNotEmpty && current != addCustomMspValue && !options.contains(current)) {
      options.add(current);
    }
    return options;
  }

  /// Displays an interactive modal dialog allowing the user to enter a custom MSP name.
  /// Automatically registers the new MSP in [MasterDataProvider].
  static Future<String?> showAddCustomMspDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Add Custom MSP',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: GoogleFonts.poppins(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Enter MSP name',
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF94A3B8)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF00A884), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(ctx).pop(text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A884),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Add', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
    if (result != null && result.isNotEmpty && context.mounted) {
      context.read<MasterDataProvider>().addCustomMspOption(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'MSP $result added successfully',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          backgroundColor: const Color(0xFF00A884),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return result;
    }
    return null;
  }
}
