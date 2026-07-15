import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_formatting.dart';
import '../application/notification_providers.dart';
import '../data/notification_api.dart';
import '../domain/app_notification.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxAsync = ref.watch(myNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          inboxAsync.maybeWhen(
            data: (page) => page.unreadCount > 0
                ? TextButton(
                    onPressed: () => ref.read(myNotificationsProvider.notifier).markAllRead(),
                    child: const Text('Mark all read'),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myNotificationsProvider.notifier).refresh(),
        child: inboxAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 80),
              const Icon(Icons.error_outline, size: 56, color: Color(0xFF9295A4)),
              const SizedBox(height: 12),
              const Text(
                'Could not load your notifications',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                error is NotificationApiException ? error.message : 'Pull down to try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF696C7E)),
              ),
            ],
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.notifications_none_rounded, size: 56, color: Color(0xFF9295A4)),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'No notifications yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Announcements about your events and college will show up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF696C7E)),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: page.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _NotificationTile(notification: page.items[index]),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (!notification.isRead) {
      await ref.read(myNotificationsProvider.notifier).markRead(notification.recipientId);
    }
    final eventId = notification.relatedEventId;
    if (eventId != null && context.mounted) {
      context.push('/event/$eventId');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sentLabel = formatEventDate(notification.sentAt);

    return Dismissible(
      key: ValueKey(notification.recipientId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEAEA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Color(0xFFD32F2F)),
      ),
      onDismissed: (_) => ref.read(myNotificationsProvider.notifier).delete(notification.recipientId),
      child: InkWell(
        onTap: () => _open(context, ref),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead ? Colors.white : const Color(0xFFFFF6EE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead ? const Color(0xFFEDEDF2) : const Color(0xFFFFD9B8),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!notification.isRead)
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B1A),
                    shape: BoxShape.circle,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(notification.body, style: const TextStyle(color: Color(0xFF4C4F61))),
                    const SizedBox(height: 8),
                    Text(
                      sentLabel,
                      style: const TextStyle(color: Color(0xFF9295A4), fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (notification.relatedEventId != null)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.chevron_right, color: Color(0xFF9295A4)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
