import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/shared/notifications/notification_inbox.dart';

final notificationInboxServiceProvider =
    FutureProvider<NotificationInboxService>((ref) async {
  return NotificationInboxService.getInstance();
});

final notificationInboxItemsProvider =
    StreamProvider<List<AppNotificationItem>>((ref) async* {
  final inbox = await ref.watch(notificationInboxServiceProvider.future);
  yield inbox.items;
  await for (final _ in inbox.changes) {
    yield inbox.items;
  }
});

final notificationUnreadCountProvider = StreamProvider<int>((ref) async* {
  final inbox = await ref.watch(notificationInboxServiceProvider.future);
  yield inbox.unreadCount;
  await for (final _ in inbox.changes) {
    yield inbox.unreadCount;
  }
});
