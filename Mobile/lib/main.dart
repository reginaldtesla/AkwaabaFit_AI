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
import 'package:mobile/shared/fitness/background_step_tracking_bootstrap.dart';
import 'package:mobile/shared/notifications/push_notification_service.dart';
import 'package:mobile/shared/nutrition/nutrition_repository.dart';
import 'package:mobile/shared/app_update/app_update_banner.dart';
import 'package:mobile/shared/app_update/app_update_provider.dart';
import 'package:mobile/shared/profile/profile_repository.dart';
import 'package:mobile/shared/payments/paystack_payment_launcher.dart';
import 'package:mobile/shared/fitness/step_goal_notification_listener.dart';
import 'package:mobile/shared/ui/app_scaffold_messenger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await BackgroundStepTrackingBootstrap.initializeOnAppStart();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'AkwaabaFit',
      theme: ThemeData(primarySwatch: Colors.green),
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return AppUpdateBannerHost(
          child: StepGoalNotificationListener(
            child: _PushAndProfileSyncListener(child: child),
          ),
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

class _PushAndProfileSyncListenerState extends ConsumerState<_PushAndProfileSyncListener>
    with WidgetsBindingObserver {
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final _push = PushNotificationService();

  // Simple debounce to avoid rapid re-sync calls.
  DateTime? _lastSyncAttempt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PaystackPaymentLauncher.instance.ensureInitialized();

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
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(BackgroundStepTrackingBootstrap.ensureRunningOnResume());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
