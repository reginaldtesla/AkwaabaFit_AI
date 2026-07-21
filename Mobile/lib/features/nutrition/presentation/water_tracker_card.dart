import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/shared/hydration/hydration_service.dart';
import 'package:mobile/shared/hydration/water_goal_achievement_notifier.dart';

class WaterTrackerCard extends ConsumerStatefulWidget {
  const WaterTrackerCard({
    super.key,
    this.initialTotalMl = 0,
    this.initialGoalMl = 2000,
  });

  final int initialTotalMl;
  final int initialGoalMl;

  @override
  ConsumerState<WaterTrackerCard> createState() => _WaterTrackerCardState();
}

class _WaterTrackerCardState extends ConsumerState<WaterTrackerCard> {
  late int _totalMl;
  late int _goalMl;
  bool _busy = false;
  bool _fromCache = false;

  static const Color _ink = Color(0xFF0F172A);
  static const Color _forest = Color(0xFF1A5D1A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _water = Color(0xFF3B82A0);
  static const Color _waterSoft = Color(0xFFEEF6F8);

  @override
  void initState() {
    super.initState();
    _totalMl = widget.initialTotalMl;
    _goalMl = widget.initialGoalMl;
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    final today = await ref.read(hydrationServiceProvider).fetchToday(
          seedTotalMl: widget.initialTotalMl,
          seedGoalMl: widget.initialGoalMl,
        );
    if (today != null && mounted) {
      setState(() {
        _totalMl = today.totalMl;
        _goalMl = today.goalMl;
        _fromCache = today.fromCache;
      });
      unawaited(
        WaterGoalAchievementNotifier.evaluate(
          totalMl: today.totalMl,
          goalMl: today.goalMl,
        ),
      );
    }
  }

  Future<void> _addGlass() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await ref.read(hydrationServiceProvider).logGlass(
            goalMl: _goalMl,
          );
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _totalMl = result.totalMl;
          _fromCache = !result.syncedOnline;
        });
        unawaited(
          WaterGoalAchievementNotifier.evaluate(
            totalMl: result.totalMl,
            goalMl: _goalMl,
          ),
        );
        final hitGoal = _goalMl > 0 && result.totalMl >= _goalMl;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hitGoal
                  ? 'Daily water goal reached — nice work!'
                  : result.syncedOnline
                      ? 'Glass added (+250 ml)'
                      : 'Glass saved offline (+250 ml) — will sync when online',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save water. Please sign in and try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _goalMl > 0 ? (_totalMl / _goalMl).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _waterSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _water.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_outlined, size: 18, color: _water),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Water',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                  ),
                ),
              ),
              Text(
                (_totalMl / 1000).toStringAsFixed(1),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                ' / ${(_goalMl / 1000).toStringAsFixed(1)} L',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ],
          ),
          if (_fromCache) ...[
            const SizedBox(height: 6),
            Text(
              'Saved on this device — syncs when you\'re back online',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.9),
              color: _water,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _busy ? null : _addGlass,
              style: OutlinedButton.styleFrom(
                foregroundColor: _forest,
                side: BorderSide(color: _forest.withValues(alpha: 0.35)),
                backgroundColor: Colors.white.withValues(alpha: 0.7),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _busy ? 'Adding…' : '+ Add glass (250 ml)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
