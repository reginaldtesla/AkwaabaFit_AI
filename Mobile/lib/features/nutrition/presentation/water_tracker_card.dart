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
    setState(() => _busy = true);
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
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1A5D1A);
    final progress = _goalMl > 0 ? (_totalMl / _goalMl).clamp(0.0, 1.0) : 0.0;

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
              Icon(Icons.water_drop_outlined, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Text(
                'Water today',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                '${(_totalMl / 1000).toStringAsFixed(1)} / ${(_goalMl / 1000).toStringAsFixed(1)} L',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.blueGrey.shade600,
                ),
              ),
            ],
          ),
          if (_fromCache) ...[
            const SizedBox(height: 6),
            Text(
              'Saved on this device — syncs when you\'re back online',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.blueGrey.shade500,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.blue.shade50,
              color: Colors.blue.shade400,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _addGlass,
              icon: const Icon(Icons.add),
              label: const Text('Add glass (250 ml)'),
              style: OutlinedButton.styleFrom(foregroundColor: green),
            ),
          ),
        ],
      ),
    );
  }
}
