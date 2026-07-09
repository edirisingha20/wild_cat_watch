import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/sighting_thumbnail.dart';
import '../../core/widgets/status_views.dart';
import '../../services/admin_service.dart';
import '../../services/api_service.dart';
import '../../services/sightings_service.dart';
import '../sightings/models/alert_model.dart';
import 'models/admin_user.dart';

/// In-app admin panel: manage user accounts and moderate sightings.
/// Only reachable when the logged-in user's role is admin; the backend
/// enforces this on every call as well.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, required this.currentUserId});

  /// Used to hide self-destructive actions (delete/deactivate own account).
  final int currentUserId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(icon: Icon(Icons.people_outline), text: 'Users'),
              Tab(icon: Icon(Icons.pets_outlined), text: 'Sightings'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _UsersTab(currentUserId: currentUserId),
            const _SightingsTab(),
          ],
        ),
      ),
    );
  }
}

// ── Users tab ─────────────────────────────────────────────────────────────────

class _UsersTab extends StatefulWidget {
  const _UsersTab({required this.currentUserId});

  final int currentUserId;

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final AdminService _adminService = AdminService();
  late Future<List<AdminUser>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _adminService.fetchUsers();
  }

  Future<void> _refresh() async {
    final Future<List<AdminUser>> fresh = _adminService.fetchUsers();
    setState(() => _usersFuture = fresh);
    await fresh;
  }

  void _showError(Object error) {
    if (!mounted) return;
    final String message = error is DioException
        ? ApiService.buildErrorMessage(error, fallbackMessage: 'Action failed')
        : 'Action failed';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setRole(AdminUser user, String role) async {
    try {
      await _adminService.updateUser(user.id, role: role);
      await _refresh();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _setActive(AdminUser user, bool isActive) async {
    try {
      await _adminService.updateUser(user.id, isActive: isActive);
      await _refresh();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteUser(AdminUser user) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text(
          'This permanently deletes "${user.username}" and all of their '
          'reported sightings. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _adminService.deleteUser(user.id);
      await _refresh();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _renameUser(AdminUser user) async {
    final TextEditingController controller =
        TextEditingController(text: user.fullName);
    try {
      final String? newName = await showDialog<String>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Edit full name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Full name'),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (newName == null || newName.isEmpty || newName == user.fullName) {
        return;
      }
      await _adminService.updateUser(user.id, fullName: newName);
      await _refresh();
    } catch (e) {
      _showError(e);
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminUser>>(
      future: _usersFuture,
      builder: (BuildContext context, AsyncSnapshot<List<AdminUser>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snapshot.hasError) {
          return ErrorStateView(
            message: 'Failed to load users',
            onRetry: _refresh,
          );
        }

        final List<AdminUser> users = snapshot.data ?? <AdminUser>[];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (BuildContext context, int index) {
              final AdminUser user = users[index];
              return _userTile(user);
            },
          ),
        );
      },
    );
  }

  Widget _userTile(AdminUser user) {
    final bool isSelf = user.id == widget.currentUserId;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            user.isAdmin ? Colors.orange.shade100 : Colors.green.shade50,
        child: Icon(
          user.isAdmin ? Icons.shield_outlined : Icons.person_outline,
          color: user.isAdmin ? Colors.orange.shade800 : Colors.green,
        ),
      ),
      title: Text(user.fullName.isNotEmpty ? user.fullName : user.username),
      subtitle: Text(
        '${user.username} · ${user.email}'
        '${user.departmentName != null ? '\n${user.departmentName}'
            '${user.positionName != null ? ' — ${user.positionName}' : ''}' : ''}',
      ),
      isThreeLine: user.departmentName != null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (user.isAdmin)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.xs),
              child: AppBadge(label: 'Admin', color: AppColors.amber),
            ),
          if (!user.isActive)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.xs),
              child: AppBadge(label: 'Disabled', color: AppColors.danger),
            ),
          if (isSelf)
            const AppBadge(label: 'You', color: AppColors.textSecondary)
          else
            PopupMenuButton<String>(
              onSelected: (String action) {
                switch (action) {
                  case 'rename':
                    _renameUser(user);
                  case 'make_admin':
                    _setRole(user, 'admin');
                  case 'make_user':
                    _setRole(user, 'user');
                  case 'activate':
                    _setActive(user, true);
                  case 'deactivate':
                    _setActive(user, false);
                  case 'delete':
                    _deleteUser(user);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'rename',
                  child: Text('Edit name'),
                ),
                if (user.isAdmin)
                  const PopupMenuItem<String>(
                    value: 'make_user',
                    child: Text('Remove admin role'),
                  )
                else
                  const PopupMenuItem<String>(
                    value: 'make_admin',
                    child: Text('Make admin'),
                  ),
                if (user.isActive)
                  const PopupMenuItem<String>(
                    value: 'deactivate',
                    child: Text('Deactivate (block login)'),
                  )
                else
                  const PopupMenuItem<String>(
                    value: 'activate',
                    child: Text('Activate'),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text(
                    'Delete user',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Sightings tab ─────────────────────────────────────────────────────────────

class _SightingsTab extends StatefulWidget {
  const _SightingsTab();

  @override
  State<_SightingsTab> createState() => _SightingsTabState();
}

class _SightingsTabState extends State<_SightingsTab> {
  final SightingsService _sightingsService = SightingsService();
  final AdminService _adminService = AdminService();
  late Future<List<Alert>> _sightingsFuture;

  @override
  void initState() {
    super.initState();
    _sightingsFuture = _sightingsService.fetchSightings();
  }

  Future<void> _refresh() async {
    final Future<List<Alert>> fresh = _sightingsService.fetchSightings();
    setState(() => _sightingsFuture = fresh);
    await fresh;
  }

  Future<void> _deleteSighting(Alert alert) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete sighting?'),
        content: Text(
          'Permanently delete the report at "${alert.locationName}"? '
          'This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _adminService.deleteSighting(alert.id);
      await _refresh();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.buildErrorMessage(
              e,
              fallbackMessage: 'Failed to delete sighting',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Alert>>(
      future: _sightingsFuture,
      builder: (BuildContext context, AsyncSnapshot<List<Alert>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snapshot.hasError) {
          return ErrorStateView(
            message: 'Failed to load sightings',
            onRetry: _refresh,
          );
        }

        final List<Alert> sightings = snapshot.data ?? <Alert>[];
        if (sightings.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: const <Widget>[
                SizedBox(height: 120),
                EmptyStateView(
                  icon: Icons.pets_outlined,
                  title: 'No sightings reported yet',
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: sightings.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (BuildContext context, int index) {
              final Alert alert = sightings[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                leading: SightingThumbnail(
                  imageUrl: alert.image,
                  width: 48,
                  height: 48,
                ),
                title: Text(
                  alert.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${alert.locationName}\n'
                  '${alert.createdAt.toLocal().toString().split('.').first}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.danger),
                  tooltip: 'Delete sighting',
                  onPressed: () => _deleteSighting(alert),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

