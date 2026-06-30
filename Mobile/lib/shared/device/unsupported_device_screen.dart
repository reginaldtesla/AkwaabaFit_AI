import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shown when the app is opened on an emulator, simulator, or desktop.
class UnsupportedDeviceScreen extends StatelessWidget {
  const UnsupportedDeviceScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1A5D1A);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: green.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_android,
                    size: 48,
                    color: green,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Real phone required',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.blueGrey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Text(
                  'Connect your phone with USB, enable developer mode, then run:\n'
                  'flutter run --release',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.blueGrey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
