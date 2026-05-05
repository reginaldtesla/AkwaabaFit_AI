import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'health_profile_screen.dart';

// =====================================================================
// 1. STATE MANAGEMENT & API LOGIC (RIVERPOD + DIO)
// =====================================================================

final authProvider = AsyncNotifierProvider<AuthNotifier, void>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<void> {
  final _dio = Dio(
    BaseOptions(
      baseUrl: 'http://10.0.2.2:8000/api', // For Android emulator
      // baseUrl: 'http://127.0.0.1:8000/api', // For iOS simulator
      // baseUrl: 'http://192.168.88.243:8000/api', // For physical device (use your PC's IP)
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 10),
    ),
  );
  final _storage = const FlutterSecureStorage();

  @override
  Future<void> build() async {}

  Future<bool> authenticate({
    required bool isLogin,
    required String email,
    required String password,
    String? name,
  }) async {
    state = const AsyncValue.loading();
    try {
      final endpoint = isLogin ? '/login' : '/register';
      final data = isLogin
          ? {
              'email': email,
              'password': password,
              'device_name': 'AkwaabaFit Flutter (${Platform.operatingSystem})',
            }
          : {
              'name': name,
              'email': email,
              'password': password,
              'password_confirmation': password,
            };

      // Ensure headers accept JSON so Laravel doesn't return HTML errors
      final response = await _dio.post(
        endpoint,
        data: data,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      // Save the Sanctum token securely
      final token = response.data['token'] ?? response.data['access_token'];
      if (token == null || token.toString().isEmpty) {
        state = AsyncValue.error(
          'Authentication succeeded but no token was returned by the server.',
          StackTrace.current,
        );
        return false;
      }

      await _storage.write(key: 'sanctum_token', value: token.toString());

      state = const AsyncValue.data(null);
      return true; // Success
    } on DioException catch (e) {
      // Extract error message from Laravel
      final message =
          e.response?.data['message'] ?? 'Connection error. Please try again.';
      state = AsyncValue.error(message, StackTrace.current);
      return false; // Failed
    }
  }

  Future<bool> checkProfileCompleted() async {
    try {
      final token = await _storage.read(key: 'sanctum_token');
      if (token == null) return false;

      final response = await _dio.get(
        '/user',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final user = response.data;
      return user['profile_completed'] == true;
    } catch (e) {
      return false;
    }
  }
}

// =====================================================================
// 2. THE UI SCREEN
// =====================================================================

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  // Brand Colors
  final Color primary = const Color(0xFF0D3B2E);
  final Color medicalBlue = const Color(0xFFF0F7F9);
  final Color slate800 = const Color(0xFF1E293B);

  // Form State
  bool _isLogin = true;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authProvider.notifier)
        .authenticate(
          isLogin: _isLogin,
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _isLogin ? null : _nameController.text.trim(),
        );

    if (!mounted) return;

    if (success) {
      if (_isLogin) {
        // After login, check if profile is completed
        final profileCompleted = await ref
            .read(authProvider.notifier)
            .checkProfileCompleted();
        if (profileCompleted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AppScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HealthProfileScreen()),
          );
        }
      } else {
        // After signup, go to health profile setup
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created successfully. Let\'s set up your health profile.',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HealthProfileScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen for errors and show a SnackBar
    ref.listen<AsyncValue>(authProvider, (_, state) {
      if (!state.isLoading && state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error.toString()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          // Background Blur Elements
          Positioned(
            top: -50,
            right: -50,
            child: _buildBlurBlob(
              Colors.blue.shade50.withOpacity(0.5),
              300,
              100,
            ),
          ),
          Positioned(
            top: 150,
            left: -50,
            child: _buildBlurBlob(
              Colors.green.shade50.withOpacity(0.4),
              250,
              80,
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20.0,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildTabToggle(),
                      const SizedBox(height: 32),

                      // The Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            if (!_isLogin) ...[
                              _buildInputField(
                                label: 'Full Name',
                                hint: 'John Doe',
                                controller: _nameController,
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 20),
                            ],
                            _buildInputField(
                              label: 'Email Address',
                              hint: 'name@medical.com',
                              controller: _emailController,
                              isEmail: true,
                            ),
                            const SizedBox(height: 20),
                            _buildInputField(
                              label: 'Password',
                              hint: '••••••••',
                              controller: _passwordController,
                              isPassword: true,
                              showForgot: _isLogin,
                            ),
                            const SizedBox(height: 32),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: authState.isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: authState.isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.lock_outline,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Secure Access',
                                            style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      _buildDivider(),
                      const SizedBox(height: 24),
                      _buildFaceIdButton(),
                      const SizedBox(height: 48),
                      _buildFooter(),
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

  // --- UI Components ---

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: medicalBlue,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade50),
          ),
          child: Icon(
            Icons.medical_services_outlined,
            color: primary,
            size: 32,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'AkwaabaFit AI',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: slate800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Medical Wellness & Nutrition Safety',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.blueGrey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildTabToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLogin = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isLogin ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _isLogin
                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Sign In',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: _isLogin ? FontWeight.w600 : FontWeight.w500,
                    color: _isLogin ? slate800 : Colors.blueGrey.shade500,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLogin = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isLogin ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: !_isLogin
                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Sign Up',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: !_isLogin ? FontWeight.w600 : FontWeight.w500,
                    color: !_isLogin ? slate800 : Colors.blueGrey.shade500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool isPassword = false,
    bool isEmail = false,
    bool showForgot = false,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.blueGrey.shade400,
                ),
              ),
            ),
            if (showForgot)
              Padding(
                padding: const EdgeInsets.only(right: 4, bottom: 6),
                child: Text(
                  'Forgot?',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primary.withOpacity(0.8),
                  ),
                ),
              ),
          ],
        ),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: isEmail
              ? TextInputType.emailAddress
              : TextInputType.text,
          validator: (value) => value!.isEmpty ? 'Required' : null,
          style: GoogleFonts.inter(color: slate800),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.blueGrey.shade400),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: icon != null
                ? Icon(icon, color: Colors.blueGrey.shade400)
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blueGrey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blueGrey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primary.withOpacity(0.5), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.blueGrey.shade200)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'SAFETY FIRST',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              color: Colors.blueGrey.shade300,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.blueGrey.shade200)),
      ],
    );
  }

  Widget _buildFaceIdButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {}, // Future FaceID Implementation
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.face, color: primary.withOpacity(0.7)),
              const SizedBox(width: 12),
              Text(
                'Sign in with FaceID',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.blueGrey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.green.shade100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user, color: Colors.green.shade600, size: 14),
              const SizedBox(width: 8),
              Text(
                'HIPAA COMPLIANT PROTOCOL',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Your data is protected by end-to-end encryption. By logging in, you agree to our Terms of Care.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            height: 1.5,
            color: Colors.blueGrey.shade400,
          ),
        ),
      ],
    );
  }

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
}
