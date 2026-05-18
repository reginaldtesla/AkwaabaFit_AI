import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:mobile/features/auth/presentation/auth_screen.dart';
import 'package:mobile/features/auth/presentation/health_profile_screen.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/offline/offline_prefs.dart';
import 'package:mobile/shared/offline/sqlite_offline_db.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Placeholder for your actual Auth logic ---
// This provider checks secure storage for the Sanctum token and profile completion.
final authInitializationProvider = FutureProvider<String>((ref) async {
  const storage = FlutterSecureStorage();
  String? token;
  try {
    token = await storage
        .read(key: 'sanctum_token')
        .timeout(const Duration(seconds: 8), onTimeout: () => null);
  } catch (_) {
    token = null;
  }

  if (token == null || token.isEmpty) {
    await Future.delayed(const Duration(seconds: 3));
    return 'not_authenticated';
  }

  // Check if profile is completed
  try {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: Duration(seconds: 5),
        receiveTimeout: Duration(seconds: 5),
      ),
    );

    final response = await dio.get(
      '/user',
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final user = response.data;
    final profileCompleted = user['profile_completed'] == true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(OfflinePrefsKeys.profileCompleteCached, profileCompleted);
    } catch (_) {}

    await Future.delayed(const Duration(seconds: 3));
    return profileCompleted
        ? 'authenticated_profile_complete'
        : 'authenticated_profile_incomplete';
  } catch (e) {
    await Future.delayed(const Duration(seconds: 3));
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(OfflinePrefsKeys.profileCompleteCached) == true) {
        return 'authenticated_profile_complete';
      }
      final local = await SqliteOfflineDb.getInstance().then((db) => db.getProfileCache());
      if (local != null) {
        final h = local['height'];
        final w = local['weight'];
        final hasBasics = (h != null && '$h'.trim().isNotEmpty) ||
            (w != null && '$w'.trim().isNotEmpty);
        if (hasBasics) return 'authenticated_profile_complete';
      }
    } catch (_) {}
    return 'authenticated_profile_incomplete';
  }
});

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Define our brand colors from the design
  final Color forest = const Color(0xFF1B5E20);
  final Color medicalBlue = const Color(0xFFE3F2FD);
  final Color softWhite = const Color(0xFFF8FAFC);
  final Color slate800 = const Color(0xFF1E293B);
  final Color slate500 = const Color(0xFF64748B);

  AnimationController? _progressController;
  bool _hasNavigated = false;

  /// First-install welcome sheet blocks routing until dismissed once.
  bool _welcomePrefsLoaded = false;
  bool _showFirstRunWelcome = false;
  String? _pendingAuthStatus;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _progressController?.repeat();

    // listen() in build only runs on *changes* after subscribe — if auth finishes
    // first we can miss navigation. listenManual + fireImmediately handles the
    // current AsyncValue and every later transition; error state still advances.
    ref.listenManual<AsyncValue<String>>(
      authInitializationProvider,
      (previous, next) {
        next.when(
          data: (status) {
            if (!mounted || _hasNavigated) return;
            _scheduleNavigation(status);
          },
          loading: () {},
          error: (Object _, StackTrace _) {
            if (!mounted || _hasNavigated) return;
            _scheduleNavigation('not_authenticated');
          },
        );
      },
      fireImmediately: true,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      var seenWelcome = true;
      try {
        final prefs = await SharedPreferences.getInstance().timeout(
          const Duration(seconds: 5),
        );
        seenWelcome = prefs.getBool('akwaaba_welcome_v1') ?? false;
      } catch (_) {
        seenWelcome = true;
      }
      if (!mounted) return;
      setState(() {
        _welcomePrefsLoaded = true;
        _showFirstRunWelcome = !seenWelcome;
      });
      if (seenWelcome && _pendingAuthStatus != null) {
        final status = _pendingAuthStatus!;
        _pendingAuthStatus = null;
        _navigateForAuthStatus(status);
      }
    });
  }

  Future<void> _dismissFirstRunWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('akwaaba_welcome_v1', true);
    if (!mounted) return;
    setState(() {
      _showFirstRunWelcome = false;
    });
    final pending = _pendingAuthStatus;
    if (pending != null) {
      _pendingAuthStatus = null;
      _navigateForAuthStatus(pending);
    }
  }

  void _scheduleNavigation(String status) {
    if (!_welcomePrefsLoaded) {
      _pendingAuthStatus = status;
      return;
    }
    if (_showFirstRunWelcome) {
      _pendingAuthStatus = status;
      return;
    }
    _navigateForAuthStatus(status);
  }

  void _navigateForAuthStatus(String status) {
    if (_hasNavigated) return;
    _hasNavigated = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (status) {
        case 'not_authenticated':
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AuthScreen()),
          );
          break;
        case 'authenticated_profile_incomplete':
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HealthProfileScreen()),
          );
          break;
        case 'authenticated_profile_complete':
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
          break;
      }
    });
  }

  @override
  void dispose() {
    _progressController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                Column(
                  children: [
                    // Medical Grade Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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

                    // Animated Progress Bar
                    if (_progressController != null)
                      AnimatedBuilder(
                        animation: _progressController!,
                        builder: (context, child) {
                          return Container(
                            width: 64,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade200,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 64 * _progressController!.value,
                              height: 4,
                              decoration: BoxDecoration(
                                color: forest.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        },
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
                    const SizedBox(height: 40),
                  ],
                ),
              ],
            ),
          ),

          if (_welcomePrefsLoaded && _showFirstRunWelcome)
            Positioned.fill(
              child: Material(
                color: softWhite.withValues(alpha: 0.97),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        Icon(Icons.travel_explore_rounded,
                            size: 48, color: forest),
                        const SizedBox(height: 20),
                        Text(
                          'Welcome',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: slate800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'AkwaabaFit works best when your phone can reach '
                          'your clinic server at least once—so you can sign in '
                          'and sync your profile.',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.5,
                            color: slate500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'After that, key screens remember your last data '
                          'when signal dips—your steps still update from your '
                          'phone.',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.5,
                            color: slate500,
                          ),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: _dismissFirstRunWelcome,
                          style: FilledButton.styleFrom(
                            backgroundColor: forest,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Continue',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
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
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
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

// Placeholder AppScreen - replace with your actual main app screen
class AppScreen extends StatelessWidget {
  const AppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AkwaabaFIT_AI')),
      body: const Center(child: Text('Welcome to the main app!')),
    );
  }
}
