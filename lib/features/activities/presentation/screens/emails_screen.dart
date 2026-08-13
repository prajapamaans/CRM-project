import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmailsScreen extends StatelessWidget {
  const EmailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Emails',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
      body: Center(
        child: Text(
          'No emails found',
          style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 14),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF00A884),
        child: const Icon(Icons.edit_outlined, color: Colors.white),
      ),
    );
  }
}
