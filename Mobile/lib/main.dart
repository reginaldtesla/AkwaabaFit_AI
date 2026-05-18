import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mobile/features/auth/presentation/splash_screen.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/fitness/presentation/activity_tracking_screen.dart';
import 'package:mobile/features/nutrition/presentation/nutrition_history_screen.dart';
import 'package:mobile/shared/fitness/background_step_service.dart';
import 'package:mobile/shared/notifications/push_notification_service.dart';
import 'package:mobile/shared/nutrition/nutrition_repository.dart';
import 'package:mobile/shared/app_update/app_update_banner.dart';
import 'package:mobile/shared/app_update/app_update_provider.dart';
import 'package:mobile/shared/profile/profile_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await BackgroundStepService.ensureStarted();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AkwaabaFit',
      theme: ThemeData(primarySwatch: Colors.green),
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return AppUpdateBannerHost(
          child: _PushAndProfileSyncListener(child: child),
        );
      },
      home: const SplashScreen(),
    );
  }
}

class _PushAndProfileSyncListener extends ConsumerStatefulWidget {
  const _PushAndProfileSyncListener({required this.child});

  final Widget child;

  @override
  ConsumerState<_PushAndProfileSyncListener> createState() => _PushAndProfileSyncListenerState();
}

class _PushAndProfileSyncListenerState extends ConsumerState<_PushAndProfileSyncListener> {
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final _push = PushNotificationService();

  // Simple debounce to avoid rapid re-sync calls.
  DateTime? _lastSyncAttempt;

  @override
  void initState() {
    super.initState();

    // Attempt a sync on app start.
    Future.microtask(() async {
      await _push.syncTokenIfLoggedIn();
      await ref.read(profileRepositoryProvider).syncPendingIfAny();
      await ref.read(nutritionRepositoryProvider).syncPendingIfAny();
      ref.invalidate(dashboardDataProvider);
      ref.invalidate(activityDataProvider);
      ref.invalidate(nutritionHistoryProvider);
      ref.invalidate(appUpdateInfoProvider);
    });

    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.ethernet);
      if (!isOnline) return;

      final now = DateTime.now();
      final last = _lastSyncAttempt;
      if (last != null && now.difference(last).inSeconds < 5) return;
      _lastSyncAttempt = now;

      _push.syncTokenIfLoggedIn();
      ref.read(profileRepositoryProvider).syncPendingIfAny();
      ref.read(nutritionRepositoryProvider).syncPendingIfAny();
      ref.invalidate(dashboardDataProvider);
      ref.invalidate(activityDataProvider);
      ref.invalidate(nutritionHistoryProvider);
      ref.invalidate(appUpdateInfoProvider);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
