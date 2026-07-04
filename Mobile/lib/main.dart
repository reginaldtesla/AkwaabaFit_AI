import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/auth/presentation/splash_screen.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/fitness/presentation/activity_tracking_screen.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/shared/device/physical_device_guard.dart';
import 'package:mobile/shared/device/unsupported_device_screen.dart';
import 'package:mobile/shared/fitness/background_step_tracking_bootstrap.dart';
import 'package:mobile/shared/nutrition/nutrition_repository.dart';
import 'package:mobile/shared/app_update/app_update_banner.dart';
import 'package:mobile/shared/app_update/app_update_provider.dart';
import 'package:mobile/shared/profile/profile_repository.dart';
import 'package:mobile/shared/weather/device_weather_service.dart';
import 'package:mobile/shared/fitness/leaderboard_provider.dart';
import 'package:mobile/shared/fitness/leaderboard_refresh_bus.dart';
import 'package:mobile/shared/fitness/step_goal_notification_listener.dart';
import 'package:mobile/shared/ui/app_scaffold_messenger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final blockReason = await PhysicalDeviceGuard.blockReason();
  if (blockReason != null) {
    runApp(UnsupportedDeviceScreen(message: blockReason));
    return;
  }

  // Splash text should appear on the first Flutter frame (no blank flash after native splash).
  await GoogleFonts.pendingFonts([
    GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
    GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
    GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
    GoogleFonts.inter(),
  ]);
  runApp(const ProviderScope(child: MyApp()));

  // Start step tracking after the first frame so launch UI is not blocked.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(BackgroundStepTrackingBootstrap.initializeOnAppStart());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'AkwaabaFit',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return AppUpdateBannerHost(
          child: StepGoalNotificationListener(
            child: _OfflineSyncListener(child: child),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}

class _OfflineSyncListener extends ConsumerStatefulWidget {
  const _OfflineSyncListener({required this.child});

  final Widget child;

  @override
  ConsumerState<_OfflineSyncListener> createState() => _OfflineSyncListenerState();
}

class _OfflineSyncListenerState extends ConsumerState<_OfflineSyncListener>
    with WidgetsBindingObserver {
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  // Simple debounce to avoid rapid re-sync calls.
  DateTime? _lastSyncAttempt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    Future.microtask(() async {
      try {
        await ref.read(profileRepositoryProvider).syncPendingIfAny();
        await ref.read(nutritionRepositoryProvider).syncPendingIfAny();
      } catch (_) {}
      ref.invalidate(dashboardDataProvider);
      ref.invalidate(activityDataProvider);
      ref.invalidate(nutritionHistoryProvider);
      ref.invalidate(deviceWeatherProvider);
      ref.invalidate(appUpdateInfoProvider);
      ref.invalidate(leaderboardProvider);
    });

    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.ethernet);

      final now = DateTime.now();
      final last = _lastSyncAttempt;
      if (last != null && now.difference(last).inSeconds < 5) return;
      _lastSyncAttempt = now;

      // Offline: show SQLite-backed dashboard immediately (no API wait).
      ref.invalidate(dashboardDataProvider);
      ref.invalidate(activityDataProvider);
      ref.invalidate(nutritionHistoryProvider);
      ref.invalidate(deviceWeatherProvider);

      if (!isOnline) return;

      ref.read(profileRepositoryProvider).syncPendingIfAny();
      ref.read(nutritionRepositoryProvider).syncPendingIfAny();
      ref.invalidate(appUpdateInfoProvider);
      ref.invalidate(leaderboardProvider);
      LeaderboardRefreshBus.notify();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(BackgroundStepTrackingBootstrap.ensureRunningOnResume());
      ref.read(profileRepositoryProvider).syncPendingIfAny();
      ref.read(nutritionRepositoryProvider).syncPendingIfAny();
      ref.invalidate(deviceWeatherProvider);
      ref.invalidate(dashboardDataProvider);
      ref.invalidate(activityDataProvider);
      ref.invalidate(leaderboardProvider);
      LeaderboardRefreshBus.notify();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
