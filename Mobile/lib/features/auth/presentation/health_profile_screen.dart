import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/shared/profile/profile_repository.dart';
import 'package:mobile/shared/health/health_profile_options.dart';
import 'package:mobile/shared/offline/offline_prefs.dart';
import 'package:mobile/shared/notifications/local_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Matches backend default step bands from activity level before dashboard sync.
int defaultStepGoalFromActivityLevel(String? level) {
  switch (level) {
    case 'Sedentary':
      return 6000;
    case 'Lightly active':
      return 8000;
    case 'Moderately active':
      return 10000;
    case 'Very active':
      return 12000;
    case 'Extremely active':
      return 14000;
    default:
      return 10000;
  }
}

// =====================================================================
// 1. STATE MANAGEMENT & API LOGIC (RIVERPOD + DIO)
// =====================================================================

final healthProfileProvider =
    AsyncNotifierProvider<HealthProfileNotifier, void>(
      HealthProfileNotifier.new,
    );

class HealthProfileNotifier extends AsyncNotifier<void> {
  final _storage = const FlutterSecureStorage();

  @override
  Future<void> build() async {}

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    try {
      final token = await _storage.read(key: 'sanctum_token');
      if (token == null) {
        state = const AsyncValue.data(null);
      }

      await ref.read(profileRepositoryProvider).saveAndSync(data);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(OfflinePrefsKeys.profileCompleteCached, true);
      } catch (_) {}

      state = const AsyncValue.data(null);
      return true;
    } on DioException catch (e) {
      final message =
          e.response?.data['message'] ??
          'Failed to update profile. Please try again.';
      state = AsyncValue.error(message, StackTrace.current);
      return true;
    }
  }
}

// =====================================================================
// 2. THE UI SCREEN
// =====================================================================

class HealthProfileScreen extends ConsumerStatefulWidget {
  const HealthProfileScreen({super.key, this.isEditing = false});

  final bool isEditing;

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
  bool _isPublicOnLeaderboard = false;
  int _onboardingStep = 0;

  String? _selectedGoal;
  final Set<String> _selectedConditions = {'None'};
  String? _eatingPattern = 'Regular';
  String? _lifeStage = 'General adult';
  String? _mealSourcePreference = 'Mixed';
  String? _activityContext = 'Mixed';
  bool _mealRemindersEnabled = true;
  /// Blocks editing until cached/remote profile fields are applied.
  bool _isHydratingProfile = false;

  @override
  void initState() {
    super.initState();

    void refresh() {
      if (mounted) setState(() {});
    }

    _nameController.addListener(refresh);
    _ageController.addListener(refresh);
    _heightController.addListener(refresh);
    _weightController.addListener(refresh);

    if (widget.isEditing) {
      _isHydratingProfile = true;
    }

    Future.microtask(_hydrateProfile);
  }

  Future<void> _hydrateProfile() async {
    try {
      await ref.read(profileRepositoryProvider).syncPendingIfAny();

      // Show local cache first so edit mode can unlock quickly.
      var local = await ref.read(profileRepositoryProvider).readLocalProfile();
      if (!mounted) return;
      if (local != null) {
        _applyProfile(local, overwriteTypedFields: widget.isEditing);
        if (widget.isEditing && _isHydratingProfile) {
          setState(() => _isHydratingProfile = false);
        }
      }

      // Then refresh from server when online.
      await ref.read(profileRepositoryProvider).fetchRemoteAndCache();
      local = await ref.read(profileRepositoryProvider).readLocalProfile();
      if (!mounted || local == null) return;
      _applyProfile(local, overwriteTypedFields: widget.isEditing);
    } finally {
      if (mounted && _isHydratingProfile) {
        setState(() => _isHydratingProfile = false);
      }
    }
  }

  void _applyProfile(
    Map<String, dynamic> local, {
    required bool overwriteTypedFields,
  }) {
    void setText(TextEditingController c, Object? value) {
      if (value == null) return;
      final next = '$value';
      if (overwriteTypedFields || c.text.isEmpty) {
        c.text = next;
      }
    }

    setText(_nameController, local['name'] is String ? local['name'] : null);
    setText(_ageController, local['age']);
    setText(_heightController, local['height']);
    setText(_weightController, local['weight']);

    setState(() {
      if (overwriteTypedFields || _selectedGender == null) {
        _selectedGender = local['gender'] as String? ?? _selectedGender;
      }
      if (overwriteTypedFields || _selectedActivityLevel == null) {
        _selectedActivityLevel =
            local['activity_level'] as String? ?? _selectedActivityLevel;
      }
      if (overwriteTypedFields || _selectedGoal == null) {
        _selectedGoal = local['goal'] as String? ?? _selectedGoal;
      }
      _eatingPattern = local['eating_pattern'] as String? ?? _eatingPattern;
      _lifeStage = local['life_stage'] as String? ?? _lifeStage;
      _mealSourcePreference =
          local['meal_source_preference'] as String? ?? _mealSourcePreference;
      _activityContext =
          local['activity_context'] as String? ?? _activityContext;
      final conds = local['health_conditions'];
      if (conds is List) {
        _selectedConditions
          ..clear()
          ..addAll(conds.map((e) => e.toString()));
      }
      final reminders = local['meal_reminders_enabled'];
      if (reminders is bool) _mealRemindersEnabled = reminders;
      final pub = local['is_public_on_leaderboard'];
      if (pub is bool) _isPublicOnLeaderboard = pub;
    });
  }

  double get _formProgress {
    if (_onboardingStep == 1) {
      int done = 0;
      if (_selectedGoal != null) done++;
      if (_eatingPattern != null) done++;
      if (_lifeStage != null) done++;
      if (_mealSourcePreference != null) done++;
      if (_activityContext != null) done++;
      return (done / 5).clamp(0.0, 1.0);
    }
    int completed = 0;
    const int total = 6;

    bool hasText(TextEditingController c) => c.text.trim().isNotEmpty;

    if (hasText(_nameController)) completed++;
    if (hasText(_ageController)) completed++;
    if (_selectedGender != null) completed++;
    if (hasText(_heightController)) completed++;
    if (hasText(_weightController)) completed++;
    if (_selectedActivityLevel != null) completed++;

    return (completed / total).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_onboardingStep == 0) {
      if (!_formKey.currentState!.validate()) return;
      if (_selectedActivityLevel == null || _selectedGender == null) {
        setState(() {});
        return;
      }
      setState(() => _onboardingStep = 1);
      return;
    }

    if (_selectedGoal == null ||
        _eatingPattern == null ||
        _lifeStage == null ||
        _mealSourcePreference == null ||
        _activityContext == null) {
      setState(() {});
      return;
    }

    final weight = int.tryParse(_weightController.text.trim());
    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'is_public_on_leaderboard': _isPublicOnLeaderboard,
      'age': int.tryParse(_ageController.text.trim()),
      'gender': _selectedGender,
      'height': int.tryParse(_heightController.text.trim()),
      'weight': weight,
      'activity_level': _selectedActivityLevel,
      'goal': _selectedGoal,
      'health_conditions': _selectedConditions.toList(),
      'eating_pattern': _eatingPattern,
      'life_stage': _lifeStage,
      'meal_source_preference': _mealSourcePreference,
      'activity_context': _activityContext,
      'meal_reminders_enabled': _mealRemindersEnabled,
      'profile_completed': true,
      'water_goal_ml': HealthProfileOptions.defaultWaterGoalMl(weight),
      'step_goal': HealthProfileOptions.ghanaStepGoal(
        _activityContext!,
        _selectedActivityLevel!,
      ),
    };

    final success = await ref
        .read(healthProfileProvider.notifier)
        .updateProfile(payload);

    if (!mounted) return;

    if (success) {
      final stepGoal = payload['step_goal'] as int? ?? 10000;
      final notifications = ref.read(localNotificationServiceProvider);
      unawaited(notifications.scheduleDailyGoalReminder(stepGoal: stepGoal));
      if (_mealRemindersEnabled) {
        unawaited(notifications.scheduleGhanaMealReminders());
      }
      if (widget.isEditing) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
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
              Colors.blue.shade50.withValues(alpha: 0.5),
              300,
              100,
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _buildBlurBlob(
              Colors.green.shade50.withValues(alpha: 0.4),
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
                      if (_onboardingStep == 0) _buildForm() else _buildAssistantForm(),
                      const SizedBox(height: 32),
                      _buildSubmitButton(profileState),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Top progress line (moves as user completes the form)
          // Kept as the LAST stack child so nothing can paint over it.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: LinearProgressIndicator(
                value: _formProgress,
                minHeight: 6,
                backgroundColor: Colors.blueGrey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(primary),
              ),
            ),
          ),

          if (_isHydratingProfile) _buildProfileLoadingBarrier(),
        ],
      ),
    );
  }

  Widget _buildProfileLoadingBarrier() {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.35),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 280,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Loading your health profile',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: slate800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
          _onboardingStep == 0
              ? 'Tell us about yourself — height, weight, and how you move.'
              : 'Help your health assistant coach you — goals, conditions, and daily routine.',
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
              borderSide: BorderSide(color: primary.withValues(alpha: 0.5), width: 2),
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
          initialValue: value,
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
              borderSide: BorderSide(color: primary.withValues(alpha: 0.5), width: 2),
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
          Switch(value: value, onChanged: onChanged, activeThumbColor: primary),
        ],
      ),
    );
  }

  Widget _buildAssistantForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropdownField(
          label: 'WEIGHT GOAL',
          hint: 'What do you want to achieve?',
          value: _selectedGoal,
          items: HealthProfileOptions.goals,
          onChanged: (v) => setState(() => _selectedGoal = v),
          icon: Icons.flag_outlined,
        ),
        const SizedBox(height: 20),
        Text(
          'HEALTH CONDITIONS (select all that apply)',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.blueGrey.shade600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: HealthProfileOptions.healthConditions.map((c) {
            final selected = _selectedConditions.contains(c);
            return FilterChip(
              label: Text(c),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  if (c == 'None') {
                    _selectedConditions
                      ..clear()
                      ..add('None');
                  } else {
                    _selectedConditions.remove('None');
                    if (selected) {
                      _selectedConditions.remove(c);
                    } else {
                      _selectedConditions.add(c);
                    }
                    if (_selectedConditions.isEmpty) _selectedConditions.add('None');
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _buildDropdownField(
          label: 'EATING PATTERN',
          hint: 'Regular or fasting?',
          value: _eatingPattern,
          items: HealthProfileOptions.eatingPatterns,
          onChanged: (v) => setState(() => _eatingPattern = v),
          icon: Icons.restaurant_outlined,
        ),
        const SizedBox(height: 20),
        _buildDropdownField(
          label: 'LIFE STAGE',
          hint: 'Helps maternal & family tips',
          value: _lifeStage,
          items: HealthProfileOptions.lifeStages,
          onChanged: (v) => setState(() => _lifeStage = v),
          icon: Icons.family_restroom_outlined,
        ),
        const SizedBox(height: 20),
        _buildDropdownField(
          label: 'WHERE YOU EAT MOST',
          hint: 'Chop bar or home?',
          value: _mealSourcePreference,
          items: HealthProfileOptions.mealSourcePreferences,
          onChanged: (v) => setState(() => _mealSourcePreference = v),
          icon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 20),
        _buildDropdownField(
          label: 'DAILY ROUTINE',
          hint: 'How you move in Ghana',
          value: _activityContext,
          items: HealthProfileOptions.activityContexts,
          onChanged: (v) => setState(() => _activityContext = v),
          icon: Icons.directions_walk_outlined,
        ),
        const SizedBox(height: 20),
        _buildSwitchField(
          label: 'MEAL-TIME REMINDERS',
          subtitle: 'Waakye morning, lunch chop, lighter supper—timed for Ghana',
          value: _mealRemindersEnabled,
          onChanged: (v) => setState(() => _mealRemindersEnabled = v),
        ),
        if (_onboardingStep == 1 && !widget.isEditing)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextButton(
              onPressed: () => setState(() => _onboardingStep = 0),
              child: const Text('Back to basics'),
            ),
          ),
      ],
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
                    _onboardingStep == 0 ? 'Continue' : 'Complete Profile',
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
      appBar: AppBar(title: const Text('AkwaabaFIT_AI')),
      body: const Center(child: Text('Welcome to the main app!')),
    );
  }
}
