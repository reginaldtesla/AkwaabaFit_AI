import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// =====================================================================
// 1. STATE MANAGEMENT & API LOGIC (RIVERPOD + DIO)
// =====================================================================

final healthProfileProvider =
    AsyncNotifierProvider<HealthProfileNotifier, void>(
      HealthProfileNotifier.new,
    );

class HealthProfileNotifier extends AsyncNotifier<void> {
  final _dio = Dio(
    BaseOptions(
      baseUrl: 'http://10.0.2.2:8000/api', // For Android emulator
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 10),
    ),
  );
  final _storage = const FlutterSecureStorage();

  @override
  Future<void> build() async {}

  Future<bool> updateProfile({
    required String name,
    required bool isPublicOnLeaderboard,
    int? age,
    String? gender,
    int? height,
    int? weight,
    String? activityLevel,
    String? goal,
  }) async {
    state = const AsyncValue.loading();
    try {
      final token = await _storage.read(key: 'sanctum_token');
      if (token == null) {
        state = AsyncValue.error(
          'No auth token found. Please login again.',
          StackTrace.current,
        );
        return false;
      }

      final data = {
        'name': name,
        'is_public_on_leaderboard': isPublicOnLeaderboard,
        if (age != null) 'age': age,
        if (gender != null) 'gender': gender,
        if (height != null) 'height': height,
        if (weight != null) 'weight': weight,
        if (activityLevel != null) 'activity_level': activityLevel,
        if (goal != null) 'goal': goal,
      };

      final response = await _dio.patch(
        '/profile',
        data: data,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      state = const AsyncValue.data(null);
      return true;
    } on DioException catch (e) {
      final message =
          e.response?.data['message'] ??
          'Failed to update profile. Please try again.';
      state = AsyncValue.error(message, StackTrace.current);
      return false;
    }
  }
}

// =====================================================================
// 2. THE UI SCREEN
// =====================================================================

class HealthProfileScreen extends ConsumerStatefulWidget {
  const HealthProfileScreen({super.key});

  @override
  ConsumerState<HealthProfileScreen> createState() =>
      _HealthProfileScreenState();
}

class _HealthProfileScreenState extends ConsumerState<HealthProfileScreen> {
  final Color primary = const Color(0xFF0D3B2E);
  final Color medicalBlue = const Color(0xFFF0F7F9);
  final Color slate800 = const Color(0xFF1E293B);

  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  // Form State
  String? _selectedGender;
  String? _selectedActivityLevel;
  String? _selectedGoal;
  bool _isPublicOnLeaderboard = true;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(healthProfileProvider.notifier)
        .updateProfile(
          name: _nameController.text.trim(),
          isPublicOnLeaderboard: _isPublicOnLeaderboard,
          age: int.tryParse(_ageController.text.trim()),
          gender: _selectedGender,
          height: int.tryParse(_heightController.text.trim()),
          weight: int.tryParse(_weightController.text.trim()),
          activityLevel: _selectedActivityLevel,
          goal: _selectedGoal,
        );

    if (!mounted) return;

    if (success) {
      // Navigate to main app
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AppScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(healthProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          // Background Elements
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
            bottom: -50,
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
                      _buildForm(),
                      const SizedBox(height: 32),
                      _buildSubmitButton(profileState),
                      const SizedBox(height: 48),
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
            Icons.health_and_safety_outlined,
            color: primary,
            size: 32,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Health Profile',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: slate800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tell us about yourself for personalized wellness',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.blueGrey.shade500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildInputField(
            label: 'FULL NAME',
            hint: 'John Doe',
            controller: _nameController,
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 20),
          _buildInputField(
            label: 'AGE',
            hint: '25',
            controller: _ageController,
            keyboardType: TextInputType.number,
            icon: Icons.calendar_today_outlined,
          ),
          const SizedBox(height: 20),
          _buildDropdownField(
            label: 'GENDER',
            hint: 'Select your gender',
            value: _selectedGender,
            items: ['Male', 'Female', 'Other', 'Prefer not to say'],
            onChanged: (value) => setState(() => _selectedGender = value),
            icon: Icons.wc_outlined,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'HEIGHT (CM)',
                  hint: '175',
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  icon: Icons.height_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputField(
                  label: 'WEIGHT (KG)',
                  hint: '70',
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  icon: Icons.monitor_weight_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDropdownField(
            label: 'ACTIVITY LEVEL',
            hint: 'How active are you?',
            value: _selectedActivityLevel,
            items: [
              'Sedentary',
              'Lightly active',
              'Moderately active',
              'Very active',
              'Extremely active',
            ],
            onChanged: (value) =>
                setState(() => _selectedActivityLevel = value),
            icon: Icons.directions_run_outlined,
          ),
          const SizedBox(height: 20),
          _buildDropdownField(
            label: 'PRIMARY GOAL',
            hint: 'What\'s your main goal?',
            value: _selectedGoal,
            items: [
              'Weight loss',
              'Muscle gain',
              'Maintain weight',
              'Improve fitness',
              'Health monitoring',
            ],
            onChanged: (value) => setState(() => _selectedGoal = value),
            icon: Icons.flag_outlined,
          ),
          const SizedBox(height: 20),
          _buildSwitchField(
            label: 'PUBLIC ON LEADERBOARD',
            subtitle:
                'Allow others to see your progress on public leaderboards',
            value: _isPublicOnLeaderboard,
            onChanged: (value) =>
                setState(() => _isPublicOnLeaderboard = value),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: Colors.blueGrey.shade400,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
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

  Widget _buildDropdownField({
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: Colors.blueGrey.shade400,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          value: value,
          hint: Text(
            hint,
            style: GoogleFonts.inter(color: Colors.blueGrey.shade400),
          ),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
          validator: (value) => value == null ? 'Required' : null,
          style: GoogleFonts.inter(color: slate800),
          decoration: InputDecoration(
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

  Widget _buildSwitchField({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: slate800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.blueGrey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: primary),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(AsyncValue<void> state) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: state.isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: state.isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Complete Profile',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBlurBlob(Color color, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(width / 2),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
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
      appBar: AppBar(title: const Text('AkwaabaFit AI')),
      body: const Center(child: Text('Welcome to the main app!')),
    );
  }
}
