import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/ai_scanner/presentation/ai_scanner_screen.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/fitness/presentation/activity_tracking_screen.dart';
import 'package:mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:mobile/features/telehealth/presentation/tele_dietetics_screen.dart';
import 'package:mobile/shared/ui/network_error_view.dart';
import 'package:mobile/shared/ui/user_friendly_errors.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';
import 'package:mobile/shared/nutrition/meal_macro_row.dart';
import 'package:mobile/shared/nutrition/nutrition_repository.dart';

// =====================================================================
// 1. STATE MANAGEMENT & DATA MODELS
// =====================================================================

enum SafetyStatus { safe, watch, alert }

class MealLog {
  final String id;
  final String name;
  final String time;
  /// Raw ISO8601 from server/device for detail formatting.
  final String eatenAtIso;
  final String category;
  final int calories;
  final int? protein;
  final int? carbs;
  final int? fat;
  final SafetyStatus status;
  final String? insightMessage;
  final String? imageUrl;
  final String? imagePath;
  final String? source;
  final Map<String, dynamic>? meta;

  MealLog({
    required this.id,
    required this.name,
    required this.time,
    required this.eatenAtIso,
    required this.category,
    required this.calories,
    this.protein,
    this.carbs,
    this.fat,
    required this.status,
    this.insightMessage,
    this.imageUrl,
    this.imagePath,
    this.source,
    this.meta,
  });
}

class DailyNutrition {
  final String dayLabel;
  final int totalKcal;
  final List<MealLog> meals;

  DailyNutrition({
    required this.dayLabel,
    required this.totalKcal,
    required this.meals,
  });
}

final nutritionHistoryProvider = FutureProvider<List<DailyNutrition>>((ref) async {
  try {
    final repo = ref.read(nutritionRepositoryProvider);
    final now = DateTime.now();
    final from =
        DateTime(now.year, now.month, now.day).subtract(const Duration(days: 14));
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final data = await repo.fetchHistory(from: from, to: to);
    final rawDays = data['days'];
    final daysList = rawDays is List ? rawDays : const <dynamic>[];

    final result = <DailyNutrition>[];
    for (final rawDay in daysList) {
      if (rawDay is! Map) continue;
      final d = rawDay.map((k, dynamic v) => MapEntry(k.toString(), v));

      final dateStr = (d['date'] ?? '').toString();
      final mealsRaw = d['meals'];
      final mealsList = mealsRaw is List ? mealsRaw : const <dynamic>[];

      final meals = <MealLog>[];
      for (final rawMeal in mealsList) {
        if (rawMeal is! Map) continue;
        final m = rawMeal.map((k, dynamic v) => MapEntry(k.toString(), v));

        final eatenAt = (m['eatenAt'] ?? '').toString();
        Map<String, dynamic>? meta;
        final metaRaw = m['meta'];
        if (metaRaw is Map) {
          meta = metaRaw.map((k, dynamic v) => MapEntry(k.toString(), v));
        }
        final imagePath =
            (meta?['image_path'] ?? meta?['imagePath'])?.toString();

        final statusStr = (m['safetyStatus'] ?? 'safe').toString().toLowerCase();
        final status = switch (statusStr) {
          'alert' => SafetyStatus.alert,
          'watch' => SafetyStatus.watch,
          _ => SafetyStatus.safe,
        };

        final rawSrc = m['source']?.toString().trim();
        final source =
            (rawSrc == null || rawSrc.isEmpty) ? null : rawSrc;

        final imRaw = m['insightMessage'];
        final insightTrimmed = imRaw?.toString().trim();
        final insightStr =
            (insightTrimmed == null || insightTrimmed.isEmpty) ? null : insightTrimmed;

        final imgRaw = m['imageUrl'];
        final imageUrlStr = imgRaw == null
            ? null
            : imgRaw.toString().trim().isEmpty
                ? null
                : imgRaw.toString();

        meals.add(
          MealLog(
            id: (m['id'] ?? '').toString(),
            name: (m['name'] ?? '').toString(),
            time: _formatTimeFromIso(eatenAt),
            eatenAtIso: eatenAt,
            category: (m['mealType'] ?? 'Meal').toString(),
            calories: (m['calories'] as int?) ??
                int.tryParse((m['calories'] ?? '0').toString()) ??
                0,
            protein: _parseNullableInt(m['proteinG']),
            carbs: _parseNullableInt(m['carbsG']),
            fat: _parseNullableInt(m['fatG']),
            status: status,
            insightMessage: insightStr,
            imageUrl: imageUrlStr,
            imagePath: imagePath,
            source: source,
            meta: meta == null ? null : Map<String, dynamic>.from(meta),
          ),
        );
      }

      final computedTotalKcal =
          meals.fold<int>(0, (sum, m) => sum + m.calories);

      result.add(
        DailyNutrition(
          dayLabel: _prettyDayLabel(dateStr),
          totalKcal: computedTotalKcal,
          meals: meals,
        ),
      );
    }

    return result;
  } catch (_) {
    return [];
  }
});

String _formatTimeFromIso(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $ampm';
}

int? _parseNullableInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString());
}

String _capitalizeLabel(String s) {
  final t = s.trim();
  if (t.isEmpty) return s;
  return '${t[0].toUpperCase()}${t.substring(1).toLowerCase()}';
}

String _prettyDayLabel(String dateStr) {
  final dt = DateTime.tryParse(dateStr);
  if (dt == null) return dateStr;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(dt.year, dt.month, dt.day);
  if (d == today) return 'Today';
  if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return '${dt.day}/${dt.month}/${dt.year}';
}

// =====================================================================
// 2. THE UI SCREEN
// =====================================================================

class NutritionHistoryScreen extends ConsumerStatefulWidget {
  const NutritionHistoryScreen({super.key});

  @override
  ConsumerState<NutritionHistoryScreen> createState() =>
      _NutritionHistoryScreenState();
}

class _NutritionHistoryScreenState extends ConsumerState<NutritionHistoryScreen> {
  // Theme Colors
  final Color primary = const Color(0xFF5C5A30);
  final Color slate800 = const Color(0xFF1E293B);
  final Color dashboardGreen = const Color(0xFF1A5D1A);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(nutritionHistoryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: historyState.when(
                loading: () =>
                    Center(child: CircularProgressIndicator(color: primary)),
                error: (err, stack) => NetworkErrorView(
                  title: 'Meal history unavailable',
                  message: userFriendlyDataLoadMessage(err),
                  onRetry: () =>
                      ref.invalidate(nutritionHistoryProvider),
                ),
                data: (days) {
                  Future<void> refreshHistory() async {
                    ref.invalidate(nutritionHistoryProvider);
                    await ref.read(nutritionHistoryProvider.future);
                  }

                  final filtered = _applySearch(days);
                  if (filtered.isEmpty) {
                    final q = _searchQuery.trim();
                    return RefreshIndicator(
                      color: primary,
                      onRefresh: refreshHistory,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Center(
                                child: Text(
                                  q.isEmpty
                                      ? 'No meals yet.'
                                      : 'No meals found for "$q".',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blueGrey.shade400,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: primary,
                    onRefresh: refreshHistory,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(
                        left: 24,
                        right: 24,
                        bottom: 120,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return _buildDailySection(context, filtered[index]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'SCAN MEAL',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: dashboardGreen,
                ),
              ),
            ),
            FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiScannerScreen()),
                );
              },
              backgroundColor: dashboardGreen,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.photo_camera,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        activeTab: AppTab.history,
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
        return;
      case AppTab.stats:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ActivityTrackingScreen()),
        );
        return;
      case AppTab.safety:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TeleDieteticsScreen()),
        );
        return;
      case AppTab.profile:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
        );
        return;
    }
  }

  // --- UI Components ---

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MEDICAL WELLNESS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primary.withOpacity(0.6),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nutrition History',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: slate800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search history...',
                hintStyle:
                    GoogleFonts.plusJakartaSans(color: Colors.blueGrey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.blueGrey.shade400),
                suffixIcon: _searchQuery.trim().isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, color: Colors.blueGrey.shade400),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DailyNutrition> _applySearch(List<DailyNutrition> days) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return days;

    final out = <DailyNutrition>[];
    for (final day in days) {
      final meals = day.meals.where((m) {
        final name = m.name.toLowerCase();
        final cat = m.category.toLowerCase();
        return name.contains(q) || cat.contains(q);
      }).toList();
      if (meals.isEmpty) continue;

      final total = meals.fold<int>(0, (sum, m) => sum + m.calories);
      out.add(DailyNutrition(dayLabel: day.dayLabel, totalKcal: total, meals: meals));
    }
    return out;
  }

  Widget _buildDailySection(BuildContext context, DailyNutrition daily) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                daily.dayLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: slate800,
                ),
              ),
              Text(
                '${daily.totalKcal} kcal total',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.blueGrey.shade400,
                ),
              ),
            ],
          ),
        ),
        ...daily.meals.map((meal) => _buildMealItem(context, meal)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMealItem(BuildContext context, MealLog meal) {
    Color bgColor;
    Color textColor;
    String statusText;

    switch (meal.status) {
      case SafetyStatus.safe:
        bgColor = const Color(0xFFF0F9F4);
        textColor = const Color(0xFF4F8B6F);
        statusText = 'SAFE';
        break;
      case SafetyStatus.watch:
        bgColor = const Color(0xFFFFF9EB);
        textColor = const Color(0xFFB38B3E);
        statusText = 'WATCH';
        break;
      case SafetyStatus.alert:
        bgColor = const Color(0xFFFFF5F5);
        textColor = const Color(0xFFC16B6B);
        statusText = 'ALERT';
        break;
    }

    final showMacros =
        meal.protein != null || meal.carbs != null || meal.fat != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showMealDetail(context, meal),
        child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.blueGrey.shade50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: _mealImageProvider(meal),
                fit: BoxFit.cover,
              ),
            ),
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
                            meal.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: slate800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${meal.time} • ${meal.category}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: Colors.blueGrey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: textColor.withOpacity(0.1)),
                      ),
                      child: Text(
                        statusText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                if (showMacros) ...[
                  const SizedBox(height: 8),
                  MealMacroRow(
                    proteinG: meal.protein ?? 0,
                    carbsG: meal.carbs ?? 0,
                    fatG: meal.fat ?? 0,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  void _showMealDetail(BuildContext context, MealLog meal) {
    final loc = MaterialLocalizations.of(context);
    final eaten = DateTime.tryParse(meal.eatenAtIso);
    final dateLine = eaten != null
        ? '${loc.formatFullDate(eaten)} · ${meal.time}'
        : '${meal.time} · ${meal.category}';

    Color statusBg;
    Color statusFg;
    String statusLabel;
    switch (meal.status) {
      case SafetyStatus.safe:
        statusBg = const Color(0xFFF0F9F4);
        statusFg = const Color(0xFF4F8B6F);
        statusLabel = 'SAFE';
        break;
      case SafetyStatus.watch:
        statusBg = const Color(0xFFFFF9EB);
        statusFg = const Color(0xFFB38B3E);
        statusLabel = 'WATCH';
        break;
      case SafetyStatus.alert:
        statusBg = const Color(0xFFFFF5F5);
        statusFg = const Color(0xFFC16B6B);
        statusLabel = 'ALERT';
        break;
    }

    final iron = meal.meta?['iron_mg'];
    final folate = meal.meta?['folate_mcg'];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.paddingOf(ctx).bottom;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.42,
          maxChildSize: 0.94,
          builder: (_, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            'Meal details',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: slate800,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.blueGrey.shade600),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomInset),
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Image(
                            image: _mealImageProvider(meal),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        meal.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: slate800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dateLine,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.blueGrey.shade500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              meal.category.isEmpty ? 'Meal' : meal.category,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.blueGrey.shade50,
                          ),
                          if (meal.source != null)
                            Chip(
                              label: Text(
                                meal.source == 'scan'
                                    ? 'Scanned'
                                    : _capitalizeLabel(meal.source!),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.blueGrey.shade50,
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusFg.withOpacity(0.2)),
                            ),
                            child: Text(
                              statusLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusFg,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '${meal.calories} kcal',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Macros',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.blueGrey.shade600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _detailMacroCell(
                              'Protein',
                              meal.protein != null ? '${meal.protein} g' : '—',
                            ),
                          ),
                          Expanded(
                            child: _detailMacroCell(
                              'Carbs',
                              meal.carbs != null ? '${meal.carbs} g' : '—',
                            ),
                          ),
                          Expanded(
                            child: _detailMacroCell(
                              'Fat',
                              meal.fat != null ? '${meal.fat} g' : '—',
                            ),
                          ),
                        ],
                      ),
                      if (iron != null || folate != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Micronutrients (scan)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.blueGrey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (iron != null)
                          Text(
                            'Iron: $iron mg',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: slate800,
                            ),
                          ),
                        if (folate != null)
                          Text(
                            'Folate: $folate mcg',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: slate800,
                            ),
                          ),
                      ],
                      if (meal.id.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Log ID · ${meal.id}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: Colors.blueGrey.shade400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _detailMacroCell(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: slate800,
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider _mealImageProvider(MealLog meal) {
    final path = meal.imagePath;
    if (path != null && path.isNotEmpty) {
      final f = File(path);
      if (f.existsSync()) return FileImage(f);
    }

    final url = meal.imageUrl;
    if (url != null && url.isNotEmpty) return NetworkImage(url);

    return const NetworkImage(
      'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=200&fit=crop',
    );
  }

}

