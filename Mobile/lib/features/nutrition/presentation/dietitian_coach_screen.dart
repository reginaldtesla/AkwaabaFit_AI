import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/shared/nutrition/dietitian_advice.dart';

class DietitianCoachScreen extends StatelessWidget {
  const DietitianCoachScreen({super.key, required this.advice});

  final DietitianAdvice advice;

  static const Color primary = Color(0xFF1A5D1A);
  static const Color slate800 = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: slate800,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'Your Dietitian',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            if (advice.isAiPowered) ...[
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
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _heroCard(),
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
      ),
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
                    fontSize: 17,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            advice.summary,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 13,
              height: 1.55,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Your snapshot',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: slate800,
                ),
              ),
              const Spacer(),
              if (metrics.goal != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    metrics.goal!,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
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
              const SizedBox(width: 8),
              Expanded(
                child: _metricTile(
                  label: 'Weight',
                  value: metrics.weightKg != null
                      ? '${metrics.weightKg!.toStringAsFixed(0)} kg'
                      : '—',
                  sub: metrics.heightCm != null
                      ? '${metrics.heightCm!.toStringAsFixed(0)} cm tall'
                      : 'Profile',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  label: 'Steps',
                  value: _formatSteps(metrics.todaySteps),
                  sub: metrics.stepGoal > 0
                      ? 'Goal ${_formatSteps(metrics.stepGoal)}'
                      : 'Today',
                  accent: metrics.todaySteps >= metrics.stepGoal &&
                          metrics.stepGoal > 0
                      ? primary
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricTile(
                  label: 'Burned',
                  value: '${metrics.burnedKcal}',
                  sub: 'kcal from steps',
                  accent: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _miniStat('Eaten', '${metrics.consumedKcal} kcal'),
                ),
                Expanded(
                  child: _miniStat('Net', '${metrics.netKcal} kcal'),
                ),
                Expanded(
                  child: _miniStat(
                    'Left',
                    metrics.netRemainingKcal != null
                        ? '${metrics.netRemainingKcal} kcal'
                        : '—',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _bmiColor(String? category) {
    return switch (category) {
      'Underweight' => Colors.blue,
      'Normal weight' => primary,
      'Overweight' => Colors.orange.shade700,
      'Obese' => Colors.red.shade700,
      _ => slate800,
    };
  }

  String _formatSteps(int steps) {
    if (steps < 1000) return '$steps';
    if (steps < 10000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return '${(steps / 1000).round()}k';
  }

  Widget _metricTile({
    required String label,
    required String value,
    required String sub,
    Color? accent,
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
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.blueGrey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: accent ?? slate800,
            ),
          ),
          Text(
            sub,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.blueGrey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.blueGrey.shade500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: slate800,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: slate800,
        ),
      ),
    );
  }

  Widget _nextMealCard(DietitianNextMeal meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meal.suggestion,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            meal.reason,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.blueGrey.shade600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recommendationCard(DietitianRecommendation rec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: slate800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rec.detail,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.blueGrey.shade600,
              height: 1.5,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: slate800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.blueGrey.shade700,
                    height: 1.45,
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
