import 'package:flutter/material.dart';
import 'package:mobile/shared/notifications/local_notification_service.dart';

/// UI helpers for consultation chat session timing (waiting → live → ended).
class ConsultationSessionUi {
  static String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  static Duration untilStart(DateTime? startsAt, DateTime serverNow) {
    if (startsAt == null) return Duration.zero;
    final d = startsAt.difference(serverNow);
    return d.isNegative ? Duration.zero : d;
  }

  static Duration remainingLive(DateTime? expiresAt, DateTime serverNow) {
    if (expiresAt == null) return Duration.zero;
    final d = expiresAt.difference(serverNow);
    return d.isNegative ? Duration.zero : d;
  }

  static ({
    String appBarSubtitle,
    String bannerText,
    Color bannerBg,
    Color bannerFg,
    bool canChat,
  })
      state({
    required String phase,
    required DateTime? startsAt,
    required DateTime? expiresAt,
    required DateTime serverNow,
    required bool active,
  }) {
    const liveBg = Color(0x140FBD74);
    const liveFg = Color(0xFF0FBD74);
    const waitBg = Color(0xFFEFF6FF);
    const waitFg = Color(0xFF1D4ED8);
    const endBg = Color(0xFFFEF2F2);
    const endFg = Color(0xFF991B1B);

    switch (phase) {
      case 'waiting':
        final until = untilStart(startsAt, serverNow);
        return (
          appBarSubtitle: 'Starts in ${formatDuration(until)}',
          bannerText: 'Session starts in: ${formatDuration(until)}',
          bannerBg: waitBg,
          bannerFg: waitFg,
          canChat: false,
        );
      case 'live':
        final rem = remainingLive(expiresAt, serverNow);
        return (
          appBarSubtitle: 'Time left: ${formatDuration(rem)}',
          bannerText: 'Time remaining: ${formatDuration(rem)}',
          bannerBg: liveBg,
          bannerFg: liveFg,
          canChat: active,
        );
      case 'ended':
        return (
          appBarSubtitle: 'Session ended',
          bannerText: 'Session ended. Pay to continue chatting.',
          bannerBg: endBg,
          bannerFg: endFg,
          canChat: false,
        );
      default:
        return (
          appBarSubtitle: 'Payment required',
          bannerText: 'Complete payment to start your advice session.',
          bannerBg: endBg,
          bannerFg: endFg,
          canChat: false,
        );
    }
  }

  static Future<void> notifySessionStarted({
    required String professionalName,
  }) async {
    const title = 'Nutrition session started';
    final body = professionalName.isNotEmpty
        ? 'Your session with $professionalName is live now. Open Advice to chat.'
        : 'Your scheduled session is live now. Open Advice to chat.';

    try {
      final local = LocalNotificationService();
      await local.showInstant(
        title: title,
        body: body,
        category: 'booking',
      );
    } catch (_) {}
  }
}
