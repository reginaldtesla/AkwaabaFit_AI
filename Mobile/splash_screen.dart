import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// --- Placeholder for your actual Auth logic ---
// In a real app, this provider checks secure storage for the Sanctum token.
final authInitializationProvider = FutureProvider<bool>((ref) async {
  // Simulating the time it takes to check the local database/secure storage
  await Future.delayed(const Duration(seconds: 3));
  // Return true if token exists, false if they need to login
  return false; 
});

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  // Define our brand colors from the design
  final Color forest = const Color(0xFF1B5E20);
  final Color medicalBlue = const Color(0xFFE3F2FD);
  final Color softWhite = const Color(0xFFF8FAFC);
  final Color slate800 = const Color(0xFF1E293B);
  final Color slate500 = const Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    // Listen to the auth check. Once it finishes, navigate.
    ref.listen<AsyncValue<bool>>(authInitializationProvider, (previous, next) {
      next.whenData((isAuthenticated) {
        if (isAuthenticated) {
          // context.go('/dashboard'); // Use GoRouter in production
          debugPrint("Token found. Go to Dashboard.");
        } else {
          // context.go('/login');
          debugPrint("No token. Go to Login.");
        }
      });
    });

    return Scaffold(
      backgroundColor: softWhite,
      body: Stack(
        children: [
          // 1. Background Blur Effects (The glowing orbs)
          Positioned(
            top: -80,
            left: -80,
            child: _buildBlurBlob(forest.withOpacity(0.05), 250, 80),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: _buildBlurBlob(medicalBlue.withOpacity(0.4), 300, 100),
          ),

          // 2. Main Content
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top spacing to push content down slightly
                const SizedBox(height: 20),

                // Center Logo & Title Area
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo Box
                      _buildLogo(),
                      const SizedBox(height: 48),

                      // Title
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: slate800,
                            letterSpacing: -0.5,
                          ),
                          children: [
                            const TextSpan(text: 'AkwaabaFit '),
                            TextSpan(
                              text: 'AI',
                              style: TextStyle(color: forest),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        'NUTRITION & HEALTH SAFETY',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: slate500,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Loading Indicator & Badge
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    children: [
                      // Medical Grade Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: forest.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: forest.withOpacity(0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user, color: forest, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'MEDICAL GRADE AI',
                              style: GoogleFonts.plusJakartaSans(
                                color: forest,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Custom Progress Bar
                      Container(
                        width: 64,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 24, // Represents a loading state
                          height: 4,
                          decoration: BoxDecoration(
                            color: forest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Bottom Text
                      Text(
                        'Your Health, Secured by Intelligence',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.blueGrey.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets to keep the build method clean ---

  Widget _buildBlurBlob(Color color, double size, double blurRadius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurRadius, sigmaY: blurRadius),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 192,
      height: 192,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [forest.withOpacity(0.05), Colors.transparent],
          stops: const [0.0, 0.7],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer subtle ring
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: forest.withOpacity(0.05)),
            ),
          ),
          // The main white square box
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: forest.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: forest.withOpacity(0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.health_and_safety, // closely matches shield_with_heart
                  size: 56,
                  color: forest.withOpacity(0.9),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.eco,
                      size: 18,
                      color: forest.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}