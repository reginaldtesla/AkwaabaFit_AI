import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppTab { home, history, stats, safety, profile }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
  });

  final AppTab activeTab;
  final ValueChanged<AppTab> onTabSelected;

  static const Color primary = Color(0xFF1A5D1A);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.only(top: 12, bottom: 16, left: 20, right: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          border: Border(top: BorderSide(color: Colors.blueGrey.shade100)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navItem(
              icon: Icons.home_outlined,
              label: 'Home',
              isActive: activeTab == AppTab.home,
              onTap: () => onTabSelected(AppTab.home),
            ),
            _navItem(
              icon: Icons.calendar_month,
              label: 'History',
              isActive: activeTab == AppTab.history,
              onTap: () => onTabSelected(AppTab.history),
            ),
            _navItem(
              icon: Icons.directions_walk_outlined,
              label: 'Stride',
              isActive: activeTab == AppTab.stats,
              onTap: () => onTabSelected(AppTab.stats),
            ),
            _navItem(
              icon: Icons.health_and_safety_outlined,
              label: 'Safety',
              isActive: activeTab == AppTab.safety,
              onTap: () => onTabSelected(AppTab.safety),
            ),
            _navItem(
              icon: Icons.account_circle_outlined,
              label: 'Profile',
              isActive: activeTab == AppTab.profile,
              onTap: () => onTabSelected(AppTab.profile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final color = isActive ? primary : Colors.blueGrey.shade400;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
