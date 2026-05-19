import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile/features/telehealth/data/tele_dietetics_api.dart';
import 'package:url_launcher/url_launcher.dart';

/// Result after user returns from Paystack checkout.
class PaystackPaymentResult {
  const PaystackPaymentResult({
    required this.paid,
    required this.reference,
    required this.consultationId,
  });

  final bool paid;
  final String reference;
  final int consultationId;
}

enum PaystackPaymentFlow {
  askNowOpenChat,
  scheduleWithReminders,
  renewExistingChat,
}

class _PendingPaystackPayment {
  _PendingPaystackPayment({
    required this.reference,
    required this.consultationId,
    required this.flow,
  });

  final String reference;
  final int consultationId;
  final PaystackPaymentFlow flow;
}

/// Opens Paystack in an in-app browser tab and completes when the user is
/// redirected back via `akwaabafit://payment-return?reference=...`.
class PaystackPaymentLauncher with WidgetsBindingObserver {
  PaystackPaymentLauncher._();

  static final PaystackPaymentLauncher instance = PaystackPaymentLauncher._();

  final AppLinks _appLinks = AppLinks();
  final TeleDieteticsApi _api = TeleDieteticsApi();

  StreamSubscription<Uri>? _linkSub;
  Completer<PaystackPaymentResult?>? _completer;
  _PendingPaystackPayment? _pending;
  bool _observingLifecycle = false;
  bool _handlingReturn = false;

  void ensureInitialized() {
    _linkSub ??= _appLinks.uriLinkStream.listen(_onDeepLink);
    unawaited(
      _appLinks.getInitialLink().then((uri) {
        if (uri != null) _onDeepLink(uri);
      }),
    );
    if (!_observingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    }
  }

  void dispose() {
    _linkSub?.cancel();
    _linkSub = null;
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_verifyPendingIfNeeded());
    }
  }

  /// Opens checkout and waits for deep-link return (or resume verify fallback).
  Future<PaystackPaymentResult?> launchAndWait({
    required String authorizationUrl,
    required String reference,
    required int consultationId,
    required PaystackPaymentFlow flow,
  }) async {
    ensureInitialized();

    if (_completer != null && !(_completer!.isCompleted)) {
      return null;
    }

    _pending = _PendingPaystackPayment(
      reference: reference,
      consultationId: consultationId,
      flow: flow,
    );
    _completer = Completer<PaystackPaymentResult?>();

    final opened = await launchUrl(
      Uri.parse(authorizationUrl),
      mode: LaunchMode.inAppBrowserView,
      webViewConfiguration: const WebViewConfiguration(
        enableJavaScript: true,
        enableDomStorage: true,
      ),
    );
    if (!opened) {
      _clearPending();
      return null;
    }

    try {
      return await _completer!.future.timeout(
        const Duration(minutes: 20),
        onTimeout: () => null,
      );
    } on TimeoutException {
      _clearPending();
      return null;
    }
  }

  void _onDeepLink(Uri uri) {
    if (uri.scheme != 'akwaabafit') return;
    if (uri.host != 'payment-return') return;
    final reference =
        uri.queryParameters['reference'] ?? uri.queryParameters['trxref'];
    if (reference == null || reference.isEmpty) return;
    unawaited(_completeWithReference(reference));
  }

  Future<void> _verifyPendingIfNeeded() async {
    final pending = _pending;
    if (pending == null || _handlingReturn) return;
    await _completeWithReference(pending.reference);
  }

  Future<void> _completeWithReference(String reference) async {
    if (_handlingReturn) return;
    _handlingReturn = true;
    try {
      final pending = _pending;
      if (pending == null) {
        // Cold start from deep link — still verify for UX.
        final paid = await _api.verifyPayment(reference: reference);
        if (paid && _completer != null && !_completer!.isCompleted) {
          _completer!.complete(
            PaystackPaymentResult(
              paid: true,
              reference: reference,
              consultationId: 0,
            ),
          );
        }
        return;
      }

      if (reference != pending.reference) return;

      var paid = false;
      for (var attempt = 0; attempt < 8; attempt++) {
        paid = await _api.verifyPayment(reference: reference);
        if (paid) break;
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }

      final result = PaystackPaymentResult(
        paid: paid,
        reference: reference,
        consultationId: pending.consultationId,
      );

      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete(result);
      }
      _clearPending();
    } finally {
      _handlingReturn = false;
    }
  }

  void _clearPending() {
    _pending = null;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(null);
    }
    _completer = null;
  }
}
