import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'forgot_password_screen.dart';
import 'health_profile_screen.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/shared/auth/sanctum_token_storage.dart';
import 'package:mobile/shared/auth/sanctum_token_ready_provider.dart';
import 'package:mobile/shared/nutrition/nutrition_repository.dart';
import 'package:mobile/shared/hydration/hydration_service.dart';
import 'package:mobile/shared/profile/profile_repository.dart';
import 'package:mobile/shared/ui/app_scaffold_messenger.dart';
import 'package:mobile/shared/ui/app_brand_logo.dart';
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

      return await _finalizeAuthResponse(response.data);
    } on DioException catch (e) {
      return _handleAuthDioError(e);
    }
  }

  Future<AuthSuccess?> _finalizeAuthResponse(dynamic raw) async {
    if (raw is! Map) {
      state = AsyncValue.error(
        'Unexpected server response. Please try again.',
        StackTrace.current,
      );
      return null;
    }

    final token = raw['token'] ?? raw['access_token'];
    if (token == null || token.toString().isEmpty) {
      state = AsyncValue.error(
        'Authentication succeeded but no token was returned by the server.',
        StackTrace.current,
      );
      return null;
    }

    await _storage.write(key: sanctumTokenKey, value: token.toString());

    final persisted = await readSanctumToken(storage: _storage);
    if (persisted == null) {
      state = AsyncValue.error(
        'Signed in, but this device could not save your session. Try again.',
        StackTrace.current,
      );
      return null;
    }

    final userRaw = raw['user'];
    final newId = userRaw is Map ? userRaw['id']?.toString() : null;
    if (newId != null && newId.isNotEmpty) {
      await OfflineSessionCleanup.onAuthenticatedUserId(newId);
    } else {
      await OfflineSessionCleanup.wipeDeviceCachesForAccountSwitch();
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

    try {
      await ref.read(nutritionRepositoryProvider).rehydrateHistory();
    } catch (_) {}
    ref.invalidate(nutritionHistoryProvider);

    state = const AsyncValue.data(null);
    return AuthSuccess(profileCompleted: profileCompleted);
  }

  AuthSuccess? _handleAuthDioError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    String? message;
    if (data is Map) {
      final map = data.map((k, v) => MapEntry(k.toString(), v));
      final m = map['message'];
      if (m is String && m.trim().isNotEmpty) message = m.trim();

      final errors = map['errors'];
      if (message == null && errors is Map && errors.isNotEmpty) {
        final firstKey = errors.keys.first;
        final firstVal = errors[firstKey];
        if (firstVal is List && firstVal.isNotEmpty) {
          message = firstVal.first.toString();
        }
      }
    }

    message ??= switch (status) {
      401 => 'Incorrect username, phone number, or password.',
      404 => 'Account not found. Please sign up.',
      422 => 'Please check your details and try again.',
      _ => 'Connection error. Please try again.',
    };

    state = AsyncValue.error(message, StackTrace.current);
    return null;
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
    // Push pending meals (and other offline writes) while the token still works.
    // Local SQLite is wiped next — anything not on the server would be lost.
    try {
      await ref.read(nutritionRepositoryProvider).syncPendingIfAny();
    } catch (_) {}
    try {
      await ref.read(hydrationServiceProvider).syncPendingIfAny();
    } catch (_) {}
    try {
      await ref.read(profileRepositoryProvider).syncPendingIfAny();
    } catch (_) {}

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
  static const Color _primary = Color(0xFF1A5D1A);
  static const Color _accent = Color(0xFF0FBD74);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _background = Color(0xFFF4F7F5);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  bool _isLogin = true;
  bool _obscurePassword = true;
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
    await _handleAuthResult(result);
  }

  Future<void> _handleAuthResult(AuthSuccess? result) async {
    if (result != null) {
      ref.invalidate(sanctumTokenReadyProvider);
      ref.invalidate(dashboardDataProvider);
      ref.invalidate(nutritionHistoryProvider);

      final destination = result.profileCompleted
          ? const DashboardScreen()
          : const HealthProfileScreen();

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination),
        (_) => false,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final messenger = rootScaffoldMessengerKey.currentState;
        if (messenger == null) return;
        final message = result.profileCompleted
            ? 'Welcome back!'
            : (_isLogin
                ? 'Signed in — finish your health profile to continue.'
                : 'Account created. Let\'s set up your health profile.');
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      });
    } else {
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

    ref.listen<AsyncValue>(authProvider, (_, state) {
      if (!state.isLoading && state.hasError) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(state.error.toString()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildLoginBackground(context),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 40,
                      maxWidth: 420,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        _buildBrandHeader(),
                        const SizedBox(height: 28),
                        _buildAuthCard(authState),
                        const SizedBox(height: 20),
                        _buildModeSwitcher(),
                        const SizedBox(height: 16),
                        _buildLegalFooter(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginBackground(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: _background),
          Align(
            alignment: const Alignment(0, -0.35),
            child: AppBrandLogo(
              size: width * 0.88,
              opacity: 0.22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Text(
          'AkwaabaFit',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Fitness & nutrition tracking',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.4,
            color: _textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard(AsyncValue<void> authState) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSegmentedAuthToggle(),
            const SizedBox(height: 22),
            Text(
              _isLogin ? 'Welcome back' : 'Create your account',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isLogin
                  ? 'Sign in to continue tracking your health.'
                  : 'Join AkwaabaFit to track meals and reach your goals.',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.4,
                color: _textMuted,
              ),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _isLogin ? _buildLoginFields() : _buildSignUpFields(),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: authState.isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _primary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: authState.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isLogin ? 'Sign in' : 'Create account',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedAuthToggle() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _segmentTab(label: 'Sign in', selected: _isLogin, onTap: () {
            if (_isLogin) return;
            setState(() => _isLogin = true);
          }),
          _segmentTab(label: 'Sign up', selected: !_isLogin, onTap: () {
            if (!_isLogin) return;
            setState(() => _isLogin = false);
          }),
        ],
      ),
    );
  }

  Widget _segmentTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? _textPrimary : _textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginFields() {
    return Column(
      key: const ValueKey('login_fields'),
      children: [
        _buildInputField(
          label: 'Username or phone',
          hint: 'e.g. kofi or +233…',
          controller: _loginIdentifierController,
          icon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.next,
          validator: (value) {
            final v = value?.trim() ?? '';
            if (v.isEmpty) return 'Enter your username or phone';
            if (v.length < 2) return 'Too short';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _buildInputField(
          label: 'Password',
          hint: 'Your password',
          controller: _passwordController,
          isPassword: true,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          trailing: _passwordVisibilityToggle(),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Enter your password';
            return null;
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ForgotPasswordScreen(),
                ),
              );
            },
            child: Text(
              'Forgot password?',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpFields() {
    return Column(
      key: const ValueKey('signup_fields'),
      children: [
        _buildInputField(
          label: 'Full name',
          hint: 'Your name',
          controller: _nameController,
          icon: Icons.badge_outlined,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        _buildInputField(
          label: 'Email',
          hint: 'you@example.com',
          controller: _emailController,
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: (value) {
            final v = value?.trim() ?? '';
            if (v.isEmpty) return 'Email is required';
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
              return 'Enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        _buildInputField(
          label: 'Username',
          hint: 'Choose a username',
          controller: _usernameController,
          icon: Icons.alternate_email_rounded,
          textInputAction: TextInputAction.next,
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
        const SizedBox(height: 14),
        _buildInputField(
          label: 'Phone (optional)',
          hint: '+233 XX XXX XXXX',
          controller: _phoneController,
          icon: Icons.phone_android_rounded,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          validator: (value) {
            final raw = value?.trim() ?? '';
            if (raw.isEmpty) return null;
            final digits = raw.replaceAll(RegExp(r'\D'), '');
            if (digits.length < 8) return 'Enter a valid phone number';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _buildInputField(
          label: 'Password',
          hint: 'At least 8 characters',
          controller: _passwordController,
          isPassword: true,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          trailing: _passwordVisibilityToggle(),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Password is required';
            if (value.length < 8) return 'At least 8 characters';
            return null;
          },
        ),
      ],
    );
  }

  Widget _passwordVisibilityToggle() {
    return IconButton(
      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      icon: Icon(
        _obscurePassword
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        color: _textMuted,
        size: 22,
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return TextButton(
      onPressed: () => setState(() => _isLogin = !_isLogin),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.inter(fontSize: 14, color: _textMuted),
          children: [
            TextSpan(
              text: _isLogin
                  ? 'New to AkwaabaFit? '
                  : 'Already have an account? ',
            ),
            TextSpan(
              text: _isLogin ? 'Create account' : 'Sign in',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalFooter() {
    return Text(
      'By continuing, you agree to use AkwaabaFit for personal wellness tracking. Your password is stored securely.',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 11,
        height: 1.45,
        color: _textMuted.withValues(alpha: 0.9),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool isPassword = false,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    void Function(String)? onFieldSubmitted,
    Widget? trailing,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: isPassword && _obscurePassword,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator ?? ((v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          style: GoogleFonts.inter(
            fontSize: 15,
            color: _textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: _textMuted.withValues(alpha: 0.75)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: icon != null
                ? Icon(icon, color: _textMuted, size: 22)
                : null,
            suffixIcon: trailing,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _accent, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
        ),
      ],
    );
  }
}
