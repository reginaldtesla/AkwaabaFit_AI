import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'forgot_password_screen.dart';
import 'health_profile_screen.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/shared/auth/sanctum_token_storage.dart';
import 'package:mobile/shared/auth/sanctum_token_ready_provider.dart';
import 'package:mobile/shared/ui/app_scaffold_messenger.dart';
import 'package:mobile/shared/config/app_config.dart';
import 'package:mobile/shared/offline/offline_prefs.dart';
import 'package:mobile/shared/offline/offline_session_cleanup.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =====================================================================
// 1. STATE MANAGEMENT & API LOGIC (RIVERPOD + DIO)
// =====================================================================

/// Result of a successful login or registration.
class AuthSuccess {
  const AuthSuccess({required this.profileCompleted});

  final bool profileCompleted;
}

final authProvider = AsyncNotifierProvider<AuthNotifier, void>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<void> {
  final _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 10),
    ),
  );
  final _storage = const FlutterSecureStorage();

  @override
  Future<void> build() async {}

  Future<AuthSuccess?> authenticate({
    required bool isLogin,
    required String password,
    /// Sign in: username or phone number (any formatting for phone).
    String? login,
    /// Sign up fields.
    String? name,
    String? email,
    String? username,
    String? phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      final endpoint = isLogin ? '/login' : '/register';
      final Map<String, dynamic> data = isLogin
          ? {
              'login': login!.trim(),
              'password': password,
              'device_name': 'AkwaabaFit Flutter (${Platform.operatingSystem})',
            }
          : {
              'name': name,
              'username': username!.trim(),
              'email': email!.trim(),
              'password': password,
              'password_confirmation': password,
              if (phone != null && phone.trim().isNotEmpty)
                'phone': phone.trim(),
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
        return null;
      }

      await _storage.write(key: sanctumTokenKey, value: token.toString());

      // Confirm token is readable before the UI navigates (avoids dashboard → login flash).
      final persisted = await readSanctumToken(storage: _storage);
      if (persisted == null) {
        state = AsyncValue.error(
          'Signed in, but this device could not save your session. Try again.',
          StackTrace.current,
        );
        return null;
      }

      final userRaw = response.data['user'];
      final newId = userRaw is Map ? userRaw['id']?.toString() : null;
      if (newId != null && newId.isNotEmpty) {
        await OfflineSessionCleanup.onAuthenticatedUserId(newId);
      }

      var profileCompleted = false;
      if (userRaw is Map) {
        profileCompleted = userRaw['profile_completed'] == true;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(
            OfflinePrefsKeys.profileCompleteCached,
            profileCompleted,
          );
        } catch (_) {}
      }

      state = const AsyncValue.data(null);
      return AuthSuccess(profileCompleted: profileCompleted);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      String? message;
      if (data is Map) {
        final map = data.map((k, v) => MapEntry(k.toString(), v));
        final m = map['message'];
        if (m is String && m.trim().isNotEmpty) message = m.trim();

        // Laravel validation errors: { errors: { field: [..] } }
        final errors = map['errors'];
        if (message == null && errors is Map && errors.isNotEmpty) {
          final firstKey = errors.keys.first;
          final firstVal = errors[firstKey];
          if (firstVal is List && firstVal.isNotEmpty) {
            message = firstVal.first.toString();
          }
        }
      }

      // Friendly fallbacks for common auth failures
      message ??= switch (status) {
        401 => 'Incorrect username, phone number, or password.',
        404 => 'Account not found. Please sign up.',
        422 => 'Please check your details and try again.',
        _ => 'Connection error. Please try again.',
      };

      state = AsyncValue.error(message, StackTrace.current);
      return null;
    }
  }

  Future<bool> checkProfileCompleted() async {
    try {
      final token = await readSanctumToken(storage: _storage);
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

  /// Revokes Sanctum tokens on the server (best-effort) and clears local storage.
  Future<void> signOut() async {
    final token = await readSanctumToken(storage: _storage);
    if (token != null && token.toString().trim().isNotEmpty) {
      try {
        await _dio.post<void>(
          '/logout',
          options: Options(
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ),
        );
      } on DioException {
        // Offline or expired token — still clear locally.
      }
    }
    await OfflineSessionCleanup.markSignedOut();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(OfflinePrefsKeys.profileCompleteCached);
    } catch (_) {}
    await _storage.delete(key: sanctumTokenKey);
    state = const AsyncValue.data(null);
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
  final _loginIdentifierController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _loginIdentifierController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Dismiss keyboard + clear any prior SnackBars.
    FocusManager.instance.primaryFocus?.unfocus();
    ScaffoldMessenger.of(context).clearSnackBars();

    final result = await ref.read(authProvider.notifier).authenticate(
          isLogin: _isLogin,
          password: _passwordController.text,
          login: _isLogin ? _loginIdentifierController.text.trim() : null,
          name: _isLogin ? null : _nameController.text.trim(),
          email: _isLogin ? null : _emailController.text.trim(),
          username: _isLogin ? null : _usernameController.text.trim(),
          phone: _isLogin ? null : _phoneController.text.trim(),
        );

    if (!mounted) return;

    if (result != null) {
      ref.invalidate(sanctumTokenReadyProvider);
      ref.invalidate(dashboardDataProvider);

      final destination = result.profileCompleted
          ? const DashboardScreen()
          : const HealthProfileScreen();

      // Navigate first — snackbar on the auth screen context often never appears
      // on the dashboard after the route is replaced.
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
        (_) => false,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final messenger = rootScaffoldMessengerKey.currentState;
        if (messenger == null) return;
        if (_isLogin) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                result.profileCompleted
                    ? 'Welcome back!'
                    : 'Signed in — finish your health profile to continue.',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Account created. Let\'s set up your health profile.',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    } else {
      // AuthNotifier already sets a user-friendly error message; keep a simple fallback too.
      final err = ref.read(authProvider).error?.toString();
      if (err != null && err.isNotEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login failed. Please try again.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
                              _buildInputField(
                                label: 'Email',
                                hint: 'name@example.com',
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  final v = value?.trim() ?? '';
                                  if (v.isEmpty) return 'Required';
                                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(v)) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              _buildInputField(
                                label: 'Username',
                                hint: 'your_username',
                                controller: _usernameController,
                                icon: Icons.alternate_email,
                                validator: (value) {
                                  final v = value?.trim() ?? '';
                                  if (v.isEmpty) return 'Username is required';
                                  if (v.length < 3) return 'At least 3 characters';
                                  if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(v)) {
                                    return 'Letters, numbers, . _ - only';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              _buildInputField(
                                label: 'Mobile (optional)',
                                hint: '+233 XX XXX XXXX',
                                controller: _phoneController,
                                icon: Icons.phone_android_outlined,
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  final raw = value?.trim() ?? '';
                                  if (raw.isEmpty) return null;
                                  final digits =
                                      raw.replaceAll(RegExp(r'\D'), '');
                                  if (digits.length < 8) {
                                    return 'Enter a valid phone number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                            ],
                            if (_isLogin) ...[
                              _buildInputField(
                                label: 'Username or mobile number',
                                hint: 'username or +233…',
                                controller: _loginIdentifierController,
                                keyboardType: TextInputType.text,
                                validator: (value) {
                                  final v = value?.trim() ?? '';
                                  if (v.isEmpty) return 'Required';
                                  if (v.length < 2) return 'Too short';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                            ],
                            _buildInputField(
                              label: 'Password',
                              hint: '••••••••',
                              controller: _passwordController,
                              isPassword: true,
                              showForgot: _isLogin,
                              onForgotPressed: _isLogin
                                  ? () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const ForgotPasswordScreen(),
                                        ),
                                      );
                                    }
                                  : null,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                if (!_isLogin && value.length < 8) {
                                  return 'At least 8 characters';
                                }
                                return null;
                              },
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
          'AkwaabaFIT_AI',
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
    bool showForgot = false,
    VoidCallback? onForgotPressed,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
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
            if (showForgot && onForgotPressed != null)
              Padding(
                padding: const EdgeInsets.only(right: 4, bottom: 6),
                child: TextButton(
                  onPressed: onForgotPressed,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Forgot?',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primary.withOpacity(0.8),
                    ),
                  ),
                ),
              ),
          ],
        ),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          validator:
              validator ?? ((value) => value!.isEmpty ? 'Required' : null),
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

  Widget _buildFooter() {
    return Text(
      'Your data is protected by end-to-end encryption. By logging in, you agree to our Terms of Care.',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 11,
        height: 1.5,
        color: Colors.blueGrey.shade400,
      ),
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
