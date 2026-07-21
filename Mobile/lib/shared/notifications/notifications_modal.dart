import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/shared/notifications/notification_inbox.dart';
import 'package:mobile/shared/notifications/notification_inbox_provider.dart';

Future<void> showNotificationsModal(BuildContext context, WidgetRef ref) async {
  final inbox = await ref.read(notificationInboxServiceProvider.future);
  await inbox.markAllRead();

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _NotificationsSheet(),
  );

}

class _NotificationsSheet extends ConsumerWidget {
  const _NotificationsSheet();

  static const Color primary = Color(0xFF1A5D1A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(notificationInboxItemsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final inbox =
                            await ref.read(notificationInboxServiceProvider.future);
                        await inbox.clearAll();
                      },
                      child: Text(
                        'Clear all',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: itemsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: primary),
                  ),
                  error: (_, _) => _emptyState('Could not load notifications'),
                  data: (items) {
                    if (items.isEmpty) {
                      return _emptyState('No notifications yet');
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _NotificationTile(item: items[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 48, color: Colors.blueGrey.shade300),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: Colors.blueGrey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Advice messages, reminders, and updates appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Colors.blueGrey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final AppNotificationItem item;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconBg;
    switch (item.category) {
      case 'push':
        icon = Icons.chat_bubble_outline;
        iconBg = const Color(0xFFE8F5E9);
        break;
      case 'booking':
        icon = Icons.event_available_outlined;
        iconBg = const Color(0xFFE3F2FD);
        break;
      case 'reminder':
        icon = Icons.alarm_outlined;
        iconBg = const Color(0xFFFFF8E1);
        break;
      default:
        icon = Icons.notifications_outlined;
        iconBg = const Color(0xFFF1F5F9);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.isRead ? Colors.white : const Color(0xFFF8FAF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF1A5D1A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: Colors.blueGrey.shade700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatWhen(item.createdAt),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.blueGrey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatWhen(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
