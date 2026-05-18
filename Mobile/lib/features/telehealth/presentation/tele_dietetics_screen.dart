import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/fitness/presentation/activity_tracking_screen.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:mobile/features/telehealth/data/tele_dietetics_api.dart';
import 'package:mobile/features/telehealth/presentation/nutrition_advice_chat_screen.dart';
import 'package:mobile/features/telehealth/presentation/dietitian_application_screen.dart';
import 'package:mobile/features/telehealth/presentation/nutrition_advice_inbox_screen.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';
import 'package:mobile/shared/notifications/local_notification_service.dart';
import 'dart:async' show unawaited;
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';

// =====================================================================
// 1. STATE MANAGEMENT & DATA MODELS
// =====================================================================

class Dietitian {
  final String id;
  final int advisorUserId;
  final String name;
  final String specialty;
  final String category;
  final double rating;
  final int hourlyRate;
  final String imageUrl;

  Dietitian({
    required this.id,
    required this.advisorUserId,
    required this.name,
    required this.specialty,
    required this.category,
    required this.rating,
    required this.hourlyRate,
    required this.imageUrl,
  });
}

final _teleApiProvider = Provider<TeleDieteticsApi>((ref) => TeleDieteticsApi());

final dietitiansProvider = FutureProvider<List<Dietitian>>((ref) async {
  final api = ref.read(_teleApiProvider);
  final dtos = await api.fetchDietitians();

  final all = dtos
      .where((d) => d.id.isNotEmpty && d.name.isNotEmpty && d.advisorUserId > 0)
      .map(
        (d) => Dietitian(
          id: d.id,
          advisorUserId: d.advisorUserId,
          name: d.name,
          specialty: d.specialty,
          category: d.category,
          rating: d.rating,
          hourlyRate: d.hourlyRate,
          imageUrl: d.imageUrl,
        ),
      )
      .toList();

  return all;
});

// =====================================================================
// 2. THE UI SCREEN
// =====================================================================

class TeleDieteticsScreen extends ConsumerWidget {
  const TeleDieteticsScreen({super.key});

  final Color primary = const Color(0xFF0FBD74);
  final Color bgLight = const Color(0xFFFDFBF7);
  final Color surface = const Color(0xFFFFFFFF);
  final Color textMain = const Color(0xFF1A1A1A);
  final Color muted = const Color(0xFF8C8C8C);
  final Color accent = const Color(0xFFD4AF37);

  /// Matches dashboard “Scan meal” FAB (forest green + pill label).
  static const Color _adviceFabGreen = Color(0xFF1A5D1A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Expanded(child: _buildDietitianList(context, ref)),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 8, right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'MY SESSIONS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _adviceFabGreen,
                ),
              ),
            ),
            FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NutritionAdviceInboxScreen(),
                  ),
                );
              },
              backgroundColor: _adviceFabGreen,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.question_answer_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        activeTab: AppTab.safety,
        onTabSelected: (tab) => _handleTab(context, tab),
      ),
    );
  }

  void _handleTab(BuildContext context, AppTab tab) {
    switch (tab) {
      case AppTab.home:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        return;
      case AppTab.history:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const NutritionHistoryScreen()),
        );
        return;
      case AppTab.stats:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ActivityTrackingScreen()),
        );
        return;
      case AppTab.safety:
        return;
      case AppTab.profile:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
        );
        return;
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: bgLight.withValues(alpha: 0.9),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: textMain),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Nutrition Advice',
        style: GoogleFonts.spaceGrotesk(
          color: textMain,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DietitianApplicationScreen()),
            );
          },
          icon: Icon(Icons.badge_outlined, size: 20, color: primary),
          label: Text(
            'Apply',
            style: GoogleFonts.spaceGrotesk(
              color: primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _refreshDietitians(WidgetRef ref) async {
    ref.invalidate(dietitiansProvider);
    await ref.read(dietitiansProvider.future);
  }

  Widget _scrollableAdviceBody({
    required BuildContext context,
    required Widget child,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildDietitianList(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(dietitiansProvider);

    return RefreshIndicator(
      color: primary,
      onRefresh: () => _refreshDietitians(ref),
      child: listState.when(
        loading: () => _scrollableAdviceBody(
          context: context,
          child: Center(child: CircularProgressIndicator(color: primary)),
        ),
        error: (err, stack) => _scrollableAdviceBody(
          context: context,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load professionals. Pull down to try again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(color: muted, fontSize: 15),
              ),
            ),
          ),
        ),
        data: (dietitians) {
          if (dietitians.isEmpty) {
            return _scrollableAdviceBody(
              context: context,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No verified nutrition professionals yet.\nPull down to refresh.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(color: muted, fontSize: 16),
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: dietitians.length,
            itemBuilder: (context, index) {
              return _buildProviderCard(context, ref, dietitians[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildProviderCard(BuildContext context, WidgetRef ref, Dietitian dietitian) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(10, 46, 31, 0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: dietitian.imageUrl.isNotEmpty
                ? NetworkImage(dietitian.imageUrl)
                : null,
            child: dietitian.imageUrl.isEmpty
                ? Icon(Icons.person, color: muted, size: 32)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dietitian.name,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textMain,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dietitian.specialty,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9E6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: accent, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            dietitian.rating.toStringAsFixed(1),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textMain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textMain,
                        ),
                        children: [
                          TextSpan(text: '₵${dietitian.hourlyRate}'),
                          TextSpan(
                            text: ' / hr',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _showBookingConfirmation(context, ref, dietitian);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'GET ADVICE',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingConfirmation(BuildContext context, WidgetRef ref, Dietitian dietitian) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Get food advice',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'with ${dietitian.name}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _bookNow(context, dietitian);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Ask now',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final when = await _pickDateTime(context);
                  if (!context.mounted) return;
                  if (when == null) return;
                  await _bookScheduled(context, ref, dietitian, when);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: textMain,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Schedule session',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<DateTime?> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null) return null;
    if (!context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _bookNow(BuildContext context, Dietitian dietitian) async {
    final messenger = ScaffoldMessenger.of(context);
    if (dietitian.advisorUserId <= 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'This professional is not linked to an advisor account yet. Approve their application in admin first.',
            style: GoogleFonts.spaceGrotesk(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      final api = TeleDieteticsApi();
      final init = await api.initiatePayment(
        dieticianName: dietitian.name,
        advisorUserId: dietitian.advisorUserId,
        type: 'ask_now',
      );
      if (init == null) throw Exception('Could not start payment.');

      final uri = Uri.parse(init.authorizationUrl);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('Could not open Paystack checkout.');

      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Complete payment'),
            content: const Text('After payment, tap “I’ve paid” to continue.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('I’ve paid'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;

      final paid = await api.verifyPayment(reference: init.reference);
      if (!paid) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Payment not confirmed yet. If you just paid, try again in a moment.',
              style: GoogleFonts.spaceGrotesk(),
            ),
            backgroundColor: textMain,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NutritionAdviceChatScreen(
            consultationId: init.consultationId,
            professionalName: dietitian.name,
            advisorUserId: dietitian.advisorUserId,
          ),
        ),
      );
    } catch (e) {
      final msg = (e is DioException)
          ? (e.response?.data is Map
              ? ((e.response!.data as Map)['message'] ?? e.message)?.toString()
              : e.message)
          : e.toString();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not start advice session. ${msg ?? 'Please try again.'}',
            style: GoogleFonts.spaceGrotesk(),
          ),
          backgroundColor: textMain,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _bookScheduled(
    BuildContext context,
    WidgetRef ref,
    Dietitian dietitian,
    DateTime when,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (dietitian.advisorUserId <= 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'This professional is not linked to an advisor account yet. Approve their application in admin first.',
            style: GoogleFonts.spaceGrotesk(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      final api = TeleDieteticsApi();
      final init = await api.initiatePayment(
        dieticianName: dietitian.name,
        advisorUserId: dietitian.advisorUserId,
        type: 'schedule',
        scheduledTime: when,
      );
      if (init == null) throw Exception('Could not start payment.');

      final uri = Uri.parse(init.authorizationUrl);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('Could not open Paystack checkout.');

      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Complete payment'),
            content: const Text('After payment, tap “I’ve paid” to schedule reminders.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('I’ve paid'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;

      final paid = await api.verifyPayment(reference: init.reference);
      if (!paid) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Payment not confirmed yet. If you just paid, try again in a moment.',
              style: GoogleFonts.spaceGrotesk(),
            ),
            backgroundColor: textMain,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      unawaited(
        ref.read(localNotificationServiceProvider).scheduleConsultationReminders(
              scheduledAt: when,
              professionalName: dietitian.name,
            ),
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Scheduled and reminders set.',
            style: GoogleFonts.spaceGrotesk(),
          ),
          backgroundColor: textMain,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Scheduling failed. Please try again.',
            style: GoogleFonts.spaceGrotesk(),
          ),
          backgroundColor: textMain,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
