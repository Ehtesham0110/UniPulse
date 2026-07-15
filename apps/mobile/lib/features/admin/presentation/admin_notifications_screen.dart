import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_formatting.dart';
import '../../notifications/application/notification_providers.dart';
import '../../notifications/data/notification_api.dart';
import '../../notifications/domain/app_notification.dart';

const _audienceTypes = [
  'College',
  'Branch',
  'Year',
  'Club',
  'Event Participants',
  'Individual Student',
];

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Send'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_SendNotificationTab(), _NotificationHistoryTab()],
      ),
    );
  }
}

class _SendNotificationTab extends ConsumerStatefulWidget {
  const _SendNotificationTab();

  @override
  ConsumerState<_SendNotificationTab> createState() => _SendNotificationTabState();
}

class _SendNotificationTabState extends ConsumerState<_SendNotificationTab> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _branchController = TextEditingController();
  final _yearController = TextEditingController();
  final _clubIdController = TextEditingController();
  final _eventIdController = TextEditingController();
  final _userIdController = TextEditingController();

  String _audienceType = _audienceTypes.first;
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _branchController.dispose();
    _yearController.dispose();
    _clubIdController.dispose();
    _eventIdController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  void _toast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFD32F2F) : const Color(0xFF22A33A),
      ),
    );
  }

  NotificationAudience? _buildAudience() {
    switch (_audienceType) {
      case 'Branch':
        if (_branchController.text.trim().isEmpty) return null;
        return NotificationAudience(type: 'Branch', branch: _branchController.text.trim());
      case 'Year':
        final year = int.tryParse(_yearController.text.trim());
        if (year == null) return null;
        return NotificationAudience(type: 'Year', year: year);
      case 'Club':
        if (_clubIdController.text.trim().isEmpty) return null;
        return NotificationAudience(type: 'Club', clubId: _clubIdController.text.trim());
      case 'Event Participants':
        if (_eventIdController.text.trim().isEmpty) return null;
        return NotificationAudience(type: 'Event Participants', eventId: _eventIdController.text.trim());
      case 'Individual Student':
        if (_userIdController.text.trim().isEmpty) return null;
        return NotificationAudience(type: 'Individual Student', userId: _userIdController.text.trim());
      case 'College':
      default:
        return const NotificationAudience(type: 'College');
    }
  }

  Future<void> _send() async {
    if (_titleController.text.trim().isEmpty || _bodyController.text.trim().isEmpty) {
      _toast('Please fill in both the title and message', isError: true);
      return;
    }
    final audience = _buildAudience();
    if (audience == null) {
      _toast('Please fill in the required field for this audience', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send this notification?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_titleController.text.trim(), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(_bodyController.text.trim()),
            const SizedBox(height: 12),
            Text('Audience: $_audienceType', style: const TextStyle(color: Color(0xFF696C7E))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSending = true);
    try {
      final result = await ref.read(notificationApiProvider).send(
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            audience: audience,
          );
      _toast(
        'Sent to ${result.recipientCount} student${result.recipientCount == 1 ? '' : 's'}'
        '${result.pushMocked ? ' (push mocked — Development Mode)' : ''}',
      );
      _titleController.clear();
      _bodyController.clear();
    } on NotificationApiException catch (error) {
      _toast(error.message, isError: true);
    } catch (_) {
      _toast('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _audienceField() {
    switch (_audienceType) {
      case 'Branch':
        return TextField(
          controller: _branchController,
          decoration: const InputDecoration(labelText: 'Branch (e.g. CS)', border: OutlineInputBorder()),
        );
      case 'Year':
        return TextField(
          controller: _yearController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Year (1-4)', border: OutlineInputBorder()),
        );
      case 'Club':
        return TextField(
          controller: _clubIdController,
          decoration: const InputDecoration(labelText: 'Club ID', border: OutlineInputBorder()),
        );
      case 'Event Participants':
        return TextField(
          controller: _eventIdController,
          decoration: const InputDecoration(labelText: 'Event ID', border: OutlineInputBorder()),
        );
      case 'Individual Student':
        return TextField(
          controller: _userIdController,
          decoration: const InputDecoration(labelText: 'Student User ID', border: OutlineInputBorder()),
        );
      case 'College':
      default:
        return const Text(
          'Sends to every active student in the college.',
          style: TextStyle(color: Color(0xFF696C7E)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _bodyController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 18),
        const Text('Audience', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _audienceType,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: _audienceTypes
              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
              .toList(),
          onChanged: (value) => setState(() => _audienceType = value ?? _audienceTypes.first),
        ),
        const SizedBox(height: 12),
        _audienceField(),
        const SizedBox(height: 20),
        if (_titleController.text.trim().isNotEmpty || _bodyController.text.trim().isNotEmpty) ...[
          const Text('Preview', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6EE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD9B8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleController.text.trim().isEmpty ? 'Notification title' : _titleController.text.trim(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(_bodyController.text.trim().isEmpty ? 'Notification message' : _bodyController.text.trim()),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        FilledButton.icon(
          onPressed: _isSending ? null : _send,
          icon: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send_rounded),
          label: Text(_isSending ? 'Sending…' : 'Send Notification'),
        ),
      ],
    );
  }
}

class _NotificationHistoryTab extends ConsumerStatefulWidget {
  const _NotificationHistoryTab();

  @override
  ConsumerState<_NotificationHistoryTab> createState() => _NotificationHistoryTabState();
}

class _NotificationHistoryTabState extends ConsumerState<_NotificationHistoryTab> {
  late Future<List<SentNotification>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = ref.read(notificationApiProvider).fetchHistory();
  }

  void _reload() {
    setState(() => _historyFuture = ref.read(notificationApiProvider).fetchHistory());
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<SentNotification>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 60),
                const Icon(Icons.error_outline, size: 48, color: Color(0xFF9295A4)),
                const SizedBox(height: 12),
                Text(
                  snapshot.error is NotificationApiException
                      ? (snapshot.error as NotificationApiException).message
                      : 'Could not load notification history.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF696C7E)),
                ),
              ],
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 60),
                Icon(Icons.history_rounded, size: 48, color: Color(0xFF9295A4)),
                SizedBox(height: 12),
                Center(child: Text('No notifications sent yet', style: TextStyle(color: Color(0xFF696C7E)))),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEDEDF2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        Text(
                          item.status,
                          style: const TextStyle(color: Color(0xFF22A33A), fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item.body, style: const TextStyle(color: Color(0xFF4C4F61))),
                    const SizedBox(height: 8),
                    Text(
                      '${item.audience.type} · ${item.recipientCount} recipient${item.recipientCount == 1 ? '' : 's'} · ${formatEventDate(item.sentAt)}',
                      style: const TextStyle(color: Color(0xFF9295A4), fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
