import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Placeholder shown by a detail screen that was opened by id and is still
/// fetching its record — or could not find it.
///
/// Keeps the app bar so Back always works, including for a missing or invalid
/// id, instead of leaving the user on a blank or crashed screen.
class RecordLoadingScaffold extends StatelessWidget {
  final String title;

  /// When set, the message to show instead of the spinner.
  final String? error;

  const RecordLoadingScaffold({super.key, required this.title, this.error});

  @override
  Widget build(BuildContext context) {
    final message = error;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
      body: Center(
        child: message == null
            ? const CircularProgressIndicator(color: Color(0xFF00A884))
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off_rounded,
                        size: 48, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
