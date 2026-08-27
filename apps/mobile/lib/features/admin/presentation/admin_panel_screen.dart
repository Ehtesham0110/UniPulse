import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/user_role.dart';
import '../../../core/widgets/campus_tree_footer.dart';
import '../../auth/application/auth_controller.dart';
import '../../events/application/event_providers.dart';
import '../../events/data/event_api.dart';
import '../../events/domain/event_summary.dart';
import '../application/admin_providers.dart';
import '../domain/admin_member.dart';

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final isSuperAdmin = user?.role == UserRole.superAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -0.3),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFFFF5A1A),
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: const Color(0xFFFF5A1A),
          indicatorWeight: 3,
          tabs: [
            const Tab(text: 'Overview'),
            const Tab(text: 'Events'),
            if (isSuperAdmin) const Tab(text: 'Admin Team') else const Tab(text: 'Team'),
            const Tab(text: 'Announcements'),
            const Tab(text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DashboardTab(onNavigateTab: (index) => _tabController.animateTo(index)),
          const _AdminEventsTab(),
          _AdminTeamTab(isSuperAdmin: isSuperAdmin),
          const _AnnouncementsTab(),
          const _SettingsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/admin/events/new'),
              backgroundColor: const Color(0xFFFF5A1A),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Create Event', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 1: OVERVIEW / DASHBOARD
// -----------------------------------------------------------------------------
class _DashboardTab extends ConsumerWidget {
  const _DashboardTab({required this.onNavigateTab});

  final ValueChanged<int> onNavigateTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final isSuperAdmin = user?.role == UserRole.superAdmin;
    final eventsAsync = ref.watch(eventListProvider(const EventListQuery()));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AdminHeaderCard(user: user),
          const SizedBox(height: 24),
          const Text('System Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          eventsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const _StatsGridFallback(),
            data: (events) {
              final activeCount = events.where((e) => e.isRegistrationOpen).length;
              return Row(
                children: [
                  Expanded(child: _StatCard(label: 'Total Events', value: '${events.length}', icon: Icons.event_rounded, color: const Color(0xFFFF5A1A))),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(label: 'Active Open', value: '$activeCount', icon: Icons.how_to_reg_rounded, color: const Color(0xFF3B82F6))),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _QuickActionsGrid(
            isSuperAdmin: isSuperAdmin,
            onNavigateTab: onNavigateTab,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Events', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              TextButton(
                onPressed: () => onNavigateTab(1),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          eventsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Could not load events: $err'),
            data: (events) {
              if (events.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No events created yet.', textAlign: TextAlign.center),
                  ),
                );
              }
              final recent = events.take(4).toList();
              return Column(
                children: recent.map((event) => _AdminEventRow(event: event)).toList(),
              );
            },
          ),
          const SizedBox(height: 32),
          const CampusTreeFooter(),
        ],
      ),
    );
  }
}

class _AdminHeaderCard extends StatelessWidget {
  const _AdminHeaderCard({required this.user});

  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final roleName = user?.role == UserRole.superAdmin ? 'Super Admin' : 'Admin';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 32,
            backgroundColor: Color(0xFFFFF0EA),
            child: Icon(Icons.admin_panel_settings_rounded, size: 36, color: Color(0xFFFF5A1A)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.fullName ?? 'Welcome Admin',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A1A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFF5A1A)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGridFallback extends StatelessWidget {
  const _StatsGridFallback();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _StatCard(label: 'Total Events', value: '12', icon: Icons.event_rounded, color: Color(0xFFFF5A1A))),
        SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Active Open', value: '5', icon: Icons.how_to_reg_rounded, color: Color(0xFF3B82F6))),
      ],
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.isSuperAdmin, required this.onNavigateTab});

  final bool isSuperAdmin;
  final ValueChanged<int> onNavigateTab;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _ActionTile(
          label: 'Create Event',
          icon: Icons.add_circle_rounded,
          color: const Color(0xFFFF5A1A),
          onTap: () => context.push('/admin/events/new'),
        ),
        _ActionTile(
          label: 'Manage Events',
          icon: Icons.event_note_rounded,
          color: const Color(0xFF3B82F6),
          onTap: () => onNavigateTab(1),
        ),
        _ActionTile(
          label: 'Notifications',
          icon: Icons.campaign_rounded,
          color: const Color(0xFFEC4899),
          onTap: () => context.push('/admin/notifications'),
        ),
        if (isSuperAdmin)
          _ActionTile(
            label: 'Manage Admins',
            icon: Icons.group_add_rounded,
            color: const Color(0xFF7B61FF),
            onTap: () => onNavigateTab(2),
          ),
        _ActionTile(
          label: 'Certificates',
          icon: Icons.workspace_premium_rounded,
          color: const Color(0xFF10B981),
          onTap: () => context.push('/admin/certificates'),
        ),
        _ActionTile(
          label: 'Settings',
          icon: Icons.settings_rounded,
          color: const Color(0xFF6B7280),
          onTap: () => onNavigateTab(4),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.label, required this.icon, required this.color, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 2: EVENTS MANAGEMENT
// -----------------------------------------------------------------------------
class _AdminEventsTab extends ConsumerWidget {
  const _AdminEventsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventListProvider(const EventListQuery()));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(eventListProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('All Events', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ElevatedButton.icon(
                onPressed: () => context.push('/admin/events/new'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5A1A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Event'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          eventsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (err, _) => Center(child: Text('Error loading events: $err')),
            data: (events) {
              if (events.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No events found. Tap Add Event to create one.', textAlign: TextAlign.center),
                  ),
                );
              }
              return Column(
                children: events.map((event) => _AdminEventCard(event: event)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminEventCard extends ConsumerWidget {
  const _AdminEventCard({required this.event});

  final EventSummary event;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(eventApiProvider).deleteEvent(event.id);
        ref.invalidate(eventListProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted'), backgroundColor: Colors.red),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete event: $error'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(eventApiProvider).approveEvent(event.id);
      ref.invalidate(eventListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event published!'), backgroundColor: Color(0xFF22A33A)),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not publish: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              _StatusBadge(status: event.lifecycle),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${event.category} · ${event.venue}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (event.lifecycle != 'Registration Open' && event.lifecycle != 'Published')
                TextButton.icon(
                  onPressed: () => _publish(context, ref),
                  icon: const Icon(Icons.publish_rounded, size: 18, color: Color(0xFF22A33A)),
                  label: const Text('Publish', style: TextStyle(color: Color(0xFF22A33A))),
                ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Color(0xFF3B82F6)),
                onPressed: () => context.push('/admin/events/edit/${event.id}'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                onPressed: () => _delete(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 3: ADMIN & MULTI-ADMIN TEAM MANAGEMENT
// -----------------------------------------------------------------------------
class _AdminTeamTab extends ConsumerWidget {
  const _AdminTeamTab({required this.isSuperAdmin});

  final bool isSuperAdmin;

  void _showInviteDialog(BuildContext context, WidgetRef ref) {
    final phoneController = TextEditingController();
    final nameController = TextEditingController();
    String selectedRole = 'Admin';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Invite / Add Admin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile Number (+91...)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: const [
                  DropdownMenuItem(value: 'Admin', child: Text('Admin (Events & Notifications)')),
                  DropdownMenuItem(value: 'Super Admin', child: Text('Super Admin (Full Control)')),
                  DropdownMenuItem(value: 'Organizer', child: Text('Organizer (Attendance Only)')),
                ],
                onChanged: (val) => setDialogState(() => selectedRole = val!),
                decoration: const InputDecoration(labelText: 'Role Permission'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final phone = phoneController.text.trim();
                final name = nameController.text.trim();
                if (phone.isEmpty) return;

                try {
                  await ref.read(adminApiProvider).inviteAdmin(
                        phone: phone,
                        fullName: name.isNotEmpty ? name : null,
                        role: selectedRole,
                      );
                  ref.invalidate(adminListProvider);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Admin access granted to $phone'), backgroundColor: const Color(0xFF22A33A)),
                    );
                  }
                } catch (err) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error inviting admin: $err'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5A1A), foregroundColor: Colors.white),
              child: const Text('Grant Access'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminListAsync = ref.watch(adminListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Admin Team & Roles', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              if (isSuperAdmin)
                ElevatedButton.icon(
                  onPressed: () => _showInviteDialog(context, ref),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5A1A), foregroundColor: Colors.white),
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Add Admin'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          adminListAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Could not load team: $err')),
            data: (members) {
              if (members.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No admins found. Tap Add Admin to invite team members.'),
                  ),
                );
              }
              return Column(
                children: members.map((m) => _AdminMemberTile(member: m, isSuperAdmin: isSuperAdmin)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminMemberTile extends ConsumerWidget {
  const _AdminMemberTile({required this.member, required this.isSuperAdmin});

  final AdminMember member;
  final bool isSuperAdmin;

  Future<void> _changeRole(BuildContext context, WidgetRef ref, String newRole) async {
    try {
      await ref.read(adminApiProvider).updateRole(userId: member.id, role: newRole);
      ref.invalidate(adminListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated ${member.fullName}\'s role to $newRole')),
        );
      }
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update role: $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(adminApiProvider).removeAdmin(member.id);
      ref.invalidate(adminListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.fullName} removed from admin team')),
        );
      }
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove: $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: member.isSuperAdmin ? const Color(0xFFFF5A1A) : const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            child: Text(member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : 'A'),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text(member.phone, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
          if (isSuperAdmin)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'REMOVE') {
                  _remove(context, ref);
                } else {
                  _changeRole(context, ref, val);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'Admin', child: Text('Set as Admin')),
                const PopupMenuItem(value: 'Super Admin', child: Text('Set as Super Admin')),
                const PopupMenuItem(value: 'Organizer', child: Text('Set as Organizer')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'REMOVE', child: Text('Remove Admin Access', style: TextStyle(color: Colors.red))),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(member.role, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
              ),
            )
          else
            Chip(label: Text(member.role, style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 4: ANNOUNCEMENTS & NOTIFICATIONS
// -----------------------------------------------------------------------------
class _AnnouncementsTab extends StatelessWidget {
  const _AnnouncementsTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Announcements & Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.campaign_rounded, size: 48, color: Color(0xFFEC4899)),
                  const SizedBox(height: 12),
                  const Text(
                    'Campus Push Notifications & Broadcasts',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Send instant notifications to all students, specific branches, or event participants.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF696C7E)),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/admin/notifications'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC4899),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Open Notification Center', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 5: SETTINGS
// -----------------------------------------------------------------------------
class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('College & Admin Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: const Icon(Icons.school_rounded, color: Color(0xFFFF5A1A)),
          title: const Text('Campus Configuration', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Manage college code and permissions'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {},
        ),
        const SizedBox(height: 10),
        ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: const Icon(Icons.security_rounded, color: Color(0xFF3B82F6)),
          title: const Text('Role & Access Matrix', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Configure role permissions and access levels'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {},
        ),
      ],
    );
  }
}

// Helper row widgets
class _AdminEventRow extends StatelessWidget {
  const _AdminEventRow({required this.event});

  final EventSummary event;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            event.isTech ? Icons.laptop_mac_rounded : Icons.emoji_events_rounded,
            color: const Color(0xFFFF5A1A),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          _StatusBadge(status: event.lifecycle),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'Registration Open' || status == 'Published'
        ? const Color(0xFF22A33A)
        : status == 'Draft'
            ? const Color(0xFFF59E0B)
            : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}