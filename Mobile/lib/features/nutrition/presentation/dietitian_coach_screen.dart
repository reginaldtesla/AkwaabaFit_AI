import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';
import 'package:mobile/shared/navigation/main_tab_shell.dart';
import 'package:mobile/shared/nutrition/dietitian_advice.dart';
import 'package:mobile/shared/nutrition/dietitian_ask_api.dart';
import 'package:mobile/shared/ui/network_error_view.dart';
import 'package:mobile/shared/ui/user_friendly_errors.dart';

class DietitianCoachScreen extends ConsumerWidget {
  const DietitianCoachScreen({
    super.key,
    this.advice,
    this.showBottomNav = true,
  });

  /// When null, advice is loaded from the dashboard provider (tab entry).
  final DietitianAdvice? advice;
  final bool showBottomNav;

  static const Color primary = Color(0xFF1A5D1A);
  static const Color slate800 = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = advice == null ? ref.watch(dashboardDataProvider) : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: slate800,
        elevation: 0,
        automaticallyImplyLeading: advice != null,
        title: _titleRow(
          isAi: advice?.isAiPowered == true ||
              (dashboardAsync?.valueOrNull?.resolveDietitianAdvice().isAiPowered ??
                  false),
        ),
      ),
      body: advice != null
          ? _DietitianBody(advice: advice!)
          : dashboardAsync!.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: primary)),
              error: (err, _) => NetworkErrorView(
                title: 'Dietitian unavailable',
                message: userFriendlyDataLoadMessage(err),
                onRetry: () => ref.invalidate(dashboardDataProvider),
              ),
              data: (data) => RefreshIndicator(
                color: primary,
                onRefresh: () async {
                  ref.invalidate(dashboardDataProvider);
                  await ref.read(dashboardDataProvider.future);
                },
                child: _DietitianBody(advice: data.resolveDietitianAdvice()),
              ),
            ),
      bottomNavigationBar: showBottomNav
          ? AppBottomNav(
              activeTab: AppTab.dietitian,
              onTabSelected: (tab) => _handleTab(context, tab),
            )
          : null,
    );
  }

  Widget _titleRow({required bool isAi}) {
    return Row(
      children: [
        Text(
          'Your Dietitian',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        if (isAi) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'AI',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _handleTab(BuildContext context, AppTab tab) {
    MainTabShell.open(context, tab: tab);
  }
}

class _DietitianBody extends StatelessWidget {
  const _DietitianBody({required this.advice});

  final DietitianAdvice advice;

  static const Color primary = DietitianCoachScreen.primary;
  static const Color slate800 = DietitianCoachScreen.slate800;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _heroCard(),
        const SizedBox(height: 16),
        const _AskAkwaabaFitCard(),
        if (advice.bodyMetrics != null) ...[
          const SizedBox(height: 16),
          _bodyMetricsCard(advice.bodyMetrics!),
        ],
        const SizedBox(height: 16),
        if (advice.nextMeal != null) ...[
          _sectionTitle('Suggested next meal'),
          _nextMealCard(advice.nextMeal!),
          const SizedBox(height: 16),
        ],
        _sectionTitle('Recommendations'),
        ...advice.recommendations.map(_recommendationCard),
        if (advice.hydrationTip != null) ...[
          const SizedBox(height: 8),
          _tipCard(
            icon: Icons.water_drop_outlined,
            title: 'Hydration',
            body: advice.hydrationTip!,
            color: Colors.blue,
          ),
        ],
        if (advice.portionTip != null) ...[
          const SizedBox(height: 8),
          _tipCard(
            icon: Icons.balance_outlined,
            title: 'Portion guide',
            body: advice.portionTip!,
            color: primary,
          ),
        ],
      ],
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF14532D), Color(0xFF1A5D1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.spa_outlined, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  advice.headline,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            advice.summary,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bodyMetricsCard(DietitianBodyMetrics metrics) {
    final bmiColor = _bmiColor(metrics.bmiCategory);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  label: 'BMI',
                  value: metrics.bmi?.toStringAsFixed(1) ?? '—',
                  sub: metrics.bmiCategory ?? 'Add height & weight',
                  accent: bmiColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricTile(
                  label: 'Weight',
                  value: metrics.weightKg != null
                      ? '${metrics.weightKg!.toStringAsFixed(0)} kg'
                      : '—',
                  sub: metrics.heightCm != null
                      ? '${metrics.heightCm!.toStringAsFixed(0)} cm tall'
                      : 'Profile',
                  accent: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  label: 'Steps',
                  value: _compactSteps(metrics.todaySteps),
                  sub: metrics.stepGoal > 0
                      ? 'Goal ${_compactSteps(metrics.stepGoal)}'
                      : 'Today',
                  accent: metrics.todaySteps >= metrics.stepGoal &&
                          metrics.stepGoal > 0
                      ? primary
                      : slate800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricTile(
                  label: 'Burned',
                  value: '${metrics.burnedKcal}',
                  sub: 'kcal from steps',
                  accent: const Color(0xFFEA580C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _kcalStat('Eaten', metrics.consumedKcal),
                ),
                Expanded(
                  child: _kcalStat('Net', metrics.netKcal),
                ),
                Expanded(
                  child: _kcalStat(
                    'Left',
                    metrics.netRemainingKcal,
                    emphasize: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile({
    required String label,
    required String value,
    required String sub,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kcalStat(String label, int? value, {bool emphasize = false}) {
    final text = value == null ? '—' : '$value';
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: emphasize && value != null && value < 0
                ? const Color(0xFFDC2626)
                : slate800,
          ),
        ),
      ],
    );
  }

  Color _bmiColor(String? category) {
    switch (category) {
      case 'Underweight':
        return const Color(0xFF0284C7);
      case 'Normal weight':
        return primary;
      case 'Overweight':
        return const Color(0xFFEA580C);
      case 'Obese':
        return const Color(0xFFDC2626);
      default:
        return slate800;
    }
  }

  String _compactSteps(int steps) {
    if (steps < 1000) return '$steps';
    final v = steps / 1000.0;
    if (steps < 10000) return '${v.toStringAsFixed(1)}k';
    return '${v.toStringAsFixed(0)}k';
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: slate800,
        ),
      ),
    );
  }

  Widget _nextMealCard(DietitianNextMeal meal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meal.suggestion,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: slate800,
            ),
          ),
          if ((meal.reason).trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              meal.reason,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.4,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _recommendationCard(DietitianRecommendation rec) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rec.title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: slate800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rec.detail,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipCard({
    required IconData icon,
    required String title,
    required String body,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: slate800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.4,
                    color: const Color(0xFF64748B),
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

class _AskAkwaabaFitCard extends StatefulWidget {
  const _AskAkwaabaFitCard();

  @override
  State<_AskAkwaabaFitCard> createState() => _AskAkwaabaFitCardState();
}

class _AskAkwaabaFitCardState extends State<_AskAkwaabaFitCard> {
  final _controller = TextEditingController();
  final _api = DietitianAskApi();
  bool _loading = false;
  String? _answer;
  String? _error;
  bool _aiSource = false;

  static const Color primary = DietitianCoachScreen.primary;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final question = _controller.text.trim();
    if (question.length < 5 || _loading) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _answer = null;
      _aiSource = false;
    });

    try {
      final result = await _api.ask(question);
      if (!mounted) return;
      setState(() {
        _answer = result.answer;
        _aiSource = result.isAiPowered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFriendlyDataLoadMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, color: primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ask AkwaabaFit AI',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: DietitianCoachScreen.slate800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Ask a diet or healthy-living question—Ghanaian meals, portions, hydration, and habits.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'e.g. Is kenkey okay for dinner if I want to lose weight?',
              hintStyle: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primary, width: 1.5),
              ),
            ),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: DietitianCoachScreen.slate800,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_loading ? 'Thinking…' : 'Ask'),
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: primary.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFFDC2626),
              ),
            ),
          ],
          if (_answer != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Answer',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                      if (_aiSource) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'AI',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _answer!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.45,
                      color: DietitianCoachScreen.slate800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
