import 'package:flutter/material.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/fitness/presentation/activity_tracking_screen.dart';
import 'package:mobile/features/nutrition/presentation/dietitian_coach_screen.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/features/profile/presentation/profile_settings_screen.dart';
import 'package:mobile/shared/navigation/app_bottom_nav.dart';

/// Root shell that keeps tab bodies alive with [IndexedStack].
class MainTabShell extends StatefulWidget {
  const MainTabShell({super.key, this.initialTab = AppTab.home});

  final AppTab initialTab;

  /// Replace the entire nav stack with the shell (post-login / sign-out recovery).
  static void open(BuildContext context, {AppTab tab = AppTab.home}) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => MainTabShell(initialTab: tab)),
      (_) => false,
    );
  }

  static int indexOf(AppTab tab) {
    switch (tab) {
      case AppTab.home:
        return 0;
      case AppTab.history:
        return 1;
      case AppTab.stats:
        return 2;
      case AppTab.dietitian:
        return 3;
      case AppTab.profile:
        return 4;
    }
  }

  static AppTab tabAt(int index) {
    switch (index) {
      case 1:
        return AppTab.history;
      case 2:
        return AppTab.stats;
      case 3:
        return AppTab.dietitian;
      case 4:
        return AppTab.profile;
      default:
        return AppTab.home;
    }
  }

  @override
  State<MainTabShell> createState() => _MainTabShellState();
}

class _MainTabShellState extends State<MainTabShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = MainTabShell.indexOf(widget.initialTab);
  }

  @override
  Widget build(BuildContext context) {
    final active = MainTabShell.tabAt(_index);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(showBottomNav: false),
          NutritionHistoryScreen(showBottomNav: false),
          ActivityTrackingScreen(showBottomNav: false),
          DietitianCoachScreen(showBottomNav: false),
          ProfileSettingsScreen(showBottomNav: false),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        activeTab: active,
        onTabSelected: (tab) {
          final next = MainTabShell.indexOf(tab);
          if (next == _index) return;
          setState(() => _index = next);
        },
      ),
    );
  }
}
