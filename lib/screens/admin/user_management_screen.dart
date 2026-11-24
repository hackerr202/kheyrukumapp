import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/halaqah_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/invite_code_dialog.dart';
import '../../widgets/pro_ui_kit.dart';

/// Flagship User Management Screen for Center Administrators:
/// - Teachers, Parents, and Invites tabs
/// - Search across name, email, or phone
/// - Assign Study Circle (Halaqah), Suspend/Reactivate, Remove User, and Delete Invite Codes
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _parents = [];
  List<Map<String, dynamic>> _admins = [];
  List<Map<String, dynamic>> _inviteCodes = [];
  bool _isLoading = true;
  String? _loadError;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllUserData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final client = SupabaseService.instance.client;

    if (client == null) {
      if (mounted) {
        setState(() {
          _teachers = [];
          _parents = [];
          _admins = [];
          _inviteCodes = [];
          _loadError = 'Unable to connect to center server. Please try again.';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      await HalaqahService.instance.fetchHalaqahs();
      final teachersRes = await client
          .from('profiles')
          .select(
              'id, full_name, email, phone, role, is_suspended, halaqah_id, halaqah_name, avatar_url, created_at')
          .eq('role', 'teacher')
          .order('created_at', ascending: false);

      final parentsRes = await client
          .from('profiles')
          .select(
              'id, full_name, email, phone, role, is_suspended, avatar_url, created_at')
          .eq('role', 'parent')
          .order('created_at', ascending: false);

      final adminsRes = await client
          .from('profiles')
          .select(
              'id, full_name, email, phone, role, is_suspended, halaqah_id, halaqah_name, avatar_url, created_at')
          .inFilter('role', ['admin', 'superadmin'])
          .order('created_at', ascending: false);

      final codesRes = await client
          .from('invitation_codes')
          .select('*')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _teachers = List<Map<String, dynamic>>.from(teachersRes);
          _parents = List<Map<String, dynamic>>.from(parentsRes);
          _admins = List<Map<String, dynamic>>.from(adminsRes);
          _inviteCodes = List<Map<String, dynamic>>.from(codesRes);
          _loadError = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[UserManagement] Error loading data: $e');
      if (mounted) {
        setState(() {
          _loadError = SupabaseService.cleanErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleSuspendUser(Map<String, dynamic> user) async {
    final p = AppColors.of(context);
    final bool currentStatus = user['is_suspended'] == true;
    final bool newStatus = !currentStatus;
    final String actionWord = newStatus ? 'Suspend' : 'Activate';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionWord ${user['full_name']}?'),
        content: Text(
          newStatus
              ? 'Suspended users will immediately be prevented from signing in and accessing center data.'
              : 'The user account will be restored and allowed to log in.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? p.danger : p.success,
              foregroundColor: Colors.white,
            ),
            child: Text(actionWord),
          ),
        ],
      ),
    );

    if (!mounted || confirm != true) return;

    setState(() {
      user['is_suspended'] = newStatus;
    });

    final client = SupabaseService.instance.client;
    if (client == null) {
      if (mounted) {
        setState(() {
          user['is_suspended'] = currentStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to connect to server.'),
            backgroundColor: p.danger,
          ),
        );
      }
      return;
    }

    try {
      await client
          .from('profiles')
          .update({
            'is_suspended': newStatus,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user['id'])
          .select('id, is_suspended')
          .single();
    } catch (e) {
      if (mounted) {
        setState(() {
          user['is_suspended'] = currentStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update user status: ${SupabaseService.cleanErrorMessage(e)}',
            ),
            backgroundColor: p.danger,
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${user['full_name']} has been ${newStatus ? 'suspended' : 'reactivated'}.',
          ),
          backgroundColor: newStatus ? p.danger : p.success,
        ),
      );
    }
  }

  Future<void> _removeUser(Map<String, dynamic> user, String listType) async {
    final p = AppColors.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: p.danger, size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text('Remove User Account?')),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently remove "${user['full_name']}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: p.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove Permanently'),
          ),
        ],
      ),
    );

    if (!mounted || confirm != true) return;

    setState(() {
      if (listType == 'teacher') {
        _teachers.removeWhere((t) => t['id'] == user['id']);
      } else if (listType == 'admin') {
        _admins.removeWhere((a) => a['id'] == user['id']);
      } else {
        _parents.removeWhere((par) => par['id'] == user['id']);
      }
    });

    final client = SupabaseService.instance.client;
    if (client == null) {
      if (mounted) {
        setState(() {
          if (listType == 'teacher') {
            _teachers.add(user);
          } else if (listType == 'admin') {
            _admins.add(user);
          } else {
            _parents.add(user);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to connect to server.'),
            backgroundColor: p.danger,
          ),
        );
      }
      return;
    }

    try {
      final rpcRes = await client.rpc(
        'admin_delete_user',
        params: {'p_user_id': user['id']},
      );
      if (rpcRes is Map && rpcRes['success'] != true) {
        throw Exception(
            rpcRes['message']?.toString() ?? 'Failed to remove user.');
      }
    } catch (e) {
      final errMsg = e.toString().toLowerCase();
      final missingRpc = errMsg.contains('42883') ||
          errMsg.contains('pgrst202') ||
          errMsg.contains('could not find the function');
      if (missingRpc) {
        try {
          await client
              .from('profiles')
              .delete()
              .eq('id', user['id'])
              .select('id')
              .single();
        } catch (fallbackErr) {
          if (mounted) {
            setState(() {
              if (listType == 'teacher') {
                _teachers.add(user);
              } else if (listType == 'admin') {
                _admins.add(user);
              } else {
                _parents.add(user);
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to remove user: ${SupabaseService.cleanErrorMessage(fallbackErr)}',
                ),
                backgroundColor: p.danger,
              ),
            );
          }
          return;
        }
      } else {
        if (mounted) {
          setState(() {
            if (listType == 'teacher') {
              _teachers.add(user);
            } else if (listType == 'admin') {
              _admins.add(user);
            } else {
              _parents.add(user);
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to remove user: ${SupabaseService.cleanErrorMessage(e)}',
              ),
              backgroundColor: p.danger,
            ),
          );
        }
        return;
      }
    }

    if (mounted) {
      await _loadAllUserData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed ${user['full_name']} from center.'),
          backgroundColor: p.danger,
        ),
      );
    }
  }

  Future<void> _showAssignHalaqahDialog(Map<String, dynamic> teacher) async {
    final p = AppColors.of(context);
    final halaqahs = HalaqahService.instance.halaqahs;
    if (halaqahs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please create a Study Circle (Halaqah) first.'),
          ),
        );
      }
      return;
    }

    String selectedId = '';
    String selectedName = 'Unassigned';
    final currentId = teacher['halaqah_id']?.toString();
    if (currentId != null && currentId.isNotEmpty) {
      final match = halaqahs.where((h) => h.id == currentId);
      if (match.isNotEmpty) {
        selectedId = match.first.id;
        selectedName = match.first.name;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Assign ${teacher['full_name']}'),
          content: DropdownButtonFormField<String>(
            value: selectedId,
            isExpanded: true,
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Unassigned (Remove from Circle)'),
              ),
              ...halaqahs
                  .map((h) => DropdownMenuItem(value: h.id, child: Text(h.name))),
            ],
            onChanged: (val) {
              if (val == null) return;
              if (val.isEmpty) {
                setDialogState(() {
                  selectedId = '';
                  selectedName = 'Unassigned';
                });
              } else {
                final h = halaqahs.firstWhere((e) => e.id == val);
                setDialogState(() {
                  selectedId = h.id;
                  selectedName = h.name;
                });
              }
            },
            decoration:
                const InputDecoration(labelText: 'Study Circle (Halaqah)'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || confirm != true) return;

    try {
      final teacherId = teacher['id'].toString();
      if (selectedId.isEmpty) {
        await HalaqahService.instance.unassignTeacher(teacherId);
      } else {
        await HalaqahService.instance.assignTeacher(
          halaqahId: selectedId,
          teacherId: teacherId,
          teacherName: teacher['full_name']?.toString() ?? 'Teacher',
        );
      }
      await _loadAllUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selectedId.isEmpty
                  ? '${teacher['full_name']} unassigned from study circle.'
                  : '${teacher['full_name']} assigned to $selectedName.',
            ),
            backgroundColor: p.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update circle assignment: ${SupabaseService.cleanErrorMessage(e)}',
            ),
            backgroundColor: p.danger,
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadUserAvatar(Map<String, dynamic> user) async {
    final p = AppColors.of(context);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (!mounted || picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final ext = picked.name.split('.').last;
      final uploadedUrl = await StorageService.uploadAvatar(
        userIdOrName: user['id']?.toString() ?? 'user',
        bytes: bytes,
        extension: ext.isNotEmpty ? ext : 'jpg',
      );

      if (uploadedUrl == null) {
        throw Exception('Failed to upload image to storage.');
      }

      final client = SupabaseService.instance.client;
      if (client != null) {
        await client
            .from('profiles')
            .update({
              'avatar_url': uploadedUrl,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', user['id']);
      }

      await _loadAllUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user['full_name']} profile photo updated.'),
            backgroundColor: p.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Could not update photo: ${SupabaseService.cleanErrorMessage(e)}'),
            backgroundColor: p.danger,
          ),
        );
      }
    }
  }

  Future<void> _showChangeRoleDialog(Map<String, dynamic> user) async {
    if (!AuthSessionService.instance.isSuperAdmin) return;
    final p = AppColors.of(context);
    final String currentRole =
        (user['role'] ?? 'parent').toString().toLowerCase();
    String selectedRole = currentRole;
    final String targetUserId = user['id']?.toString() ?? '';
    final bool isSelfSuperadmin =
        currentRole == 'superadmin' &&
        targetUserId == AuthSessionService.instance.userId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: p.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.security, color: p.gold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Change Role for ${user['full_name']}',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: p.ink),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select permissions and access level for this user:',
                style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
              ),
              const SizedBox(height: 14),
              RadioListTile<String>(
                title: const Text('Superadmin (Full Control)',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text(
                    'Full access including payments, fees, and user role promotion',
                    style: TextStyle(fontSize: 11)),
                value: 'superadmin',
                groupValue: selectedRole,
                activeColor: p.gold,
                onChanged: (v) => setDialogState(() => selectedRole = v!),
              ),
              RadioListTile<String>(
                title: const Text('Admin (Center Administrator)',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text(
                    'Study circles, students, attendance, homework (No payment access)',
                    style: TextStyle(fontSize: 11)),
                value: 'admin',
                groupValue: selectedRole,
                activeColor: p.primary,
                onChanged: isSelfSuperadmin
                    ? null
                    : (v) => setDialogState(() => selectedRole = v!),
              ),
              RadioListTile<String>(
                title: const Text('Teacher (Ustaz)',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text(
                    'Assigned study circle, attendance, and recitation grading',
                    style: TextStyle(fontSize: 11)),
                value: 'teacher',
                groupValue: selectedRole,
                activeColor: p.primary,
                onChanged: isSelfSuperadmin
                    ? null
                    : (v) => setDialogState(() => selectedRole = v!),
              ),
              RadioListTile<String>(
                title: const Text('Parent',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: const Text(
                    'Linked children, weekly reports, and tuition payment',
                    style: TextStyle(fontSize: 11)),
                value: 'parent',
                groupValue: selectedRole,
                activeColor: p.info,
                onChanged: isSelfSuperadmin
                    ? null
                    : (v) => setDialogState(() => selectedRole = v!),
              ),
              if (isSelfSuperadmin)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Note: You cannot demote your own active Superadmin account.',
                    style: TextStyle(
                        fontSize: 11,
                        color: p.warning,
                        fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedRole == currentRole
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      try {
                        final client = SupabaseService.instance.client;
                        if (client == null) {
                          throw Exception('Server not connected.');
                        }
                        await client.rpc('admin_set_user_role', params: {
                          'p_user_id': user['id'],
                          'p_new_role': selectedRole,
                        });
                        await _loadAllUserData();
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${user['full_name']} promoted to $selectedRole successfully.'),
                              backgroundColor: p.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Failed to update role: ${SupabaseService.cleanErrorMessage(e)}'),
                              backgroundColor: p.danger,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: p.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Update Role'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);

    if (!AuthSessionService.instance.isAdmin) {
      return Scaffold(
        backgroundColor: p.canvas,
        appBar: AppBar(
          backgroundColor: p.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: p.ink),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('User Management'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: ProEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Access Restricted',
              message: 'Only center administrators can manage user accounts.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: p.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Management',
              style: TextStyle(
                color: p.ink,
                fontWeight: FontWeight.w700,
                fontSize: 17.5,
              ),
            ),
            Text(
              '${_teachers.length} Teachers • ${_parents.length} Parents • ${_admins.length} Admins',
              style: TextStyle(color: p.inkSecondary, fontSize: 11.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_rounded, color: p.primary),
            tooltip: 'Generate Invite Code',
            onPressed: () async {
              await InviteCodeDialog.show(context);
              if (mounted) await _loadAllUserData();
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: p.inkSecondary),
            onPressed: _loadAllUserData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(bottom: BorderSide(color: p.border)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: p.primary,
              indicatorWeight: 3,
              labelColor: p.primary,
              unselectedLabelColor: p.inkSecondary,
              isScrollable: true,
              tabs: [
                Tab(text: 'Teachers (${_teachers.length})'),
                Tab(text: 'Parents (${_parents.length})'),
                Tab(text: 'Admins (${_admins.length})'),
                Tab(text: 'Invites (${_inviteCodes.length})'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: ProSearchField(
              controller: _searchController,
              hintText: 'Search by name, email, or phone...',
              query: _searchQuery,
              onChanged: (v) =>
                  setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: p.primary))
                : (_loadError != null
                    ? Center(
                        child: ProEmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: 'Could not load users',
                          message: _loadError!,
                          accentColor: p.danger,
                          actionLabel: 'Retry',
                          onAction: _loadAllUserData,
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildUserList(_teachers, 'teacher', p),
                          _buildUserList(_parents, 'parent', p),
                          _buildUserList(_admins, 'admin', p),
                          _buildInviteCodesList(p),
                        ],
                      )),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(
    List<Map<String, dynamic>> users,
    String listType,
    AppPalette p,
  ) {
    final filtered = users.where((u) {
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          phone.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ProEmptyState(
            icon: Icons.person_off_outlined,
            title: 'No ${listType}s found',
            message: _searchQuery.isNotEmpty
                ? 'Try clearing or modifying your search query.'
                : 'Registered ${listType}s will appear here.',
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: p.primary,
      onRefresh: _loadAllUserData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final user = filtered[index];
          final bool isSuspended = user['is_suspended'] == true;
          final name = (user['full_name'] ?? 'User').toString();

          return ProCard(
            padding: const EdgeInsets.all(14),
            borderColor: isSuspended ? p.danger.withOpacity(0.5) : p.border,
            child: Row(
              children: [
                ProAvatar(
                  name: name,
                  imageUrl: user['avatar_url']?.toString(),
                  radius: 22,
                  color: isSuspended
                      ? p.danger
                      : (user['role'] == 'superadmin' || user['role'] == 'admin'
                          ? p.gold
                          : (listType == 'teacher' ? p.primary : p.gold)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: p.ink,
                                decoration: isSuspended
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSuspended) ...[
                            const SizedBox(width: 6),
                            ProStatusPill(label: 'SUSPENDED', color: p.danger),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        (user['phone'] != null &&
                                user['phone'].toString().isNotEmpty)
                            ? user['phone'].toString()
                            : (user['email']?.toString() ?? 'No contact info'),
                        style: TextStyle(fontSize: 12, color: p.inkSecondary),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          ProStatusPill(
                            label: (user['role'] ?? listType).toString().toUpperCase(),
                            color: (user['role'] == 'superadmin' || user['role'] == 'admin')
                                ? p.gold
                                : (listType == 'teacher' ? p.primary : p.info),
                          ),
                          if (listType == 'teacher')
                            Builder(
                              builder: (_) {
                                final matches = HalaqahService.instance.halaqahs
                                    .where((h) => h.teacherId == user['id']);
                                final profileHalaqah =
                                    user['halaqah_name']?.toString();
                                final assignedName = (profileHalaqah != null &&
                                        profileHalaqah.isNotEmpty)
                                    ? profileHalaqah
                                    : (matches.isNotEmpty
                                        ? matches.first.name
                                        : 'Unassigned Circle');
                                return Text(
                                  assignedName,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: p.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: p.inkSecondary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  color: p.surface,
                  onSelected: (val) {
                    if (val == 'promote') {
                      _showChangeRoleDialog(user);
                    } else if (val == 'avatar') {
                      _pickAndUploadUserAvatar(user);
                    } else if (val == 'assign_halaqah') {
                      _showAssignHalaqahDialog(user);
                    } else if (val == 'suspend') {
                      _toggleSuspendUser(user);
                    } else if (val == 'remove') {
                      _removeUser(user, listType);
                    }
                  },
                  itemBuilder: (context) {
                    final targetRoleStr =
                        (user['role'] ?? 'parent').toString().toLowerCase();
                    final isSelf = user['id']?.toString() ==
                        AuthSessionService.instance.userId;
                    final canManageTarget = !isSelf &&
                        targetRoleStr != 'superadmin' &&
                        (targetRoleStr != 'admin' ||
                            AuthSessionService.instance.isSuperAdmin);
                    return [
                    if (AuthSessionService.instance.isSuperAdmin) ...[
                      PopupMenuItem(
                        value: 'promote',
                        child: Row(
                          children: [
                            Icon(Icons.security,
                                size: 18, color: p.gold),
                            const SizedBox(width: 10),
                            Text(
                              'Promote / Change Role',
                              style: TextStyle(
                                fontSize: 13,
                                color: p.gold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'avatar',
                        child: Row(
                          children: [
                            Icon(Icons.photo_camera,
                                size: 18, color: p.primary),
                            const SizedBox(width: 10),
                            Text(
                              'Update Photo',
                              style: TextStyle(
                                fontSize: 13,
                                color: p.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (listType == 'teacher')
                      PopupMenuItem(
                        value: 'assign_halaqah',
                        child: Row(
                          children: [
                            Icon(Icons.school_outlined,
                                size: 18, color: p.primary),
                            const SizedBox(width: 10),
                            Text(
                              'Assign Halaqah',
                              style: TextStyle(
                                fontSize: 13,
                                color: p.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (canManageTarget) ...[
                    PopupMenuItem(
                      value: 'suspend',
                      child: Row(
                        children: [
                          Icon(
                            isSuspended
                                ? Icons.play_arrow_rounded
                                : Icons.block_rounded,
                            size: 18,
                            color: isSuspended ? p.success : p.warning,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isSuspended
                                ? 'Reactivate Account'
                                : 'Suspend Account',
                            style: TextStyle(
                              fontSize: 13,
                              color: isSuspended ? p.success : p.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 18, color: p.danger),
                          const SizedBox(width: 10),
                          Text(
                            'Remove User',
                            style: TextStyle(
                              fontSize: 13,
                              color: p.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ],
                  ];
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInviteCodesList(AppPalette p) {
    final filtered = _inviteCodes.where((code) {
      if (_searchQuery.isEmpty) return true;
      final codeStr = (code['code'] ?? '').toString().toLowerCase();
      final roleStr = (code['role'] ?? '').toString().toLowerCase();
      final emailStr = (code['target_email'] ?? '').toString().toLowerCase();
      return codeStr.contains(_searchQuery) ||
          roleStr.contains(_searchQuery) ||
          emailStr.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ProEmptyState(
            icon: Icons.vpn_key_off_outlined,
            title: _searchQuery.isNotEmpty
                ? 'No matching invite codes'
                : 'No invitation codes active',
            message: _searchQuery.isNotEmpty
                ? 'Try clearing or modifying your search query.'
                : 'Generate an invite code from the top right button.',
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: p.primary,
      onRefresh: _loadAllUserData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final code = filtered[index];
          final codeStr = (code['code'] ?? '').toString();
          final isTeacher = code['role'] == 'teacher';
          final isUsed = code['is_used'] == true;
          final tone = isTeacher ? p.primary : p.gold;

          return ProCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tone.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isTeacher
                        ? Icons.school_rounded
                        : Icons.family_restroom_rounded,
                    size: 19,
                    color: tone,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        codeStr,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isUsed ? p.inkMuted : p.ink,
                          decoration:
                              isUsed ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Text(
                        isTeacher
                            ? 'Teacher Registration'
                            : 'Parent Registration',
                        style: TextStyle(fontSize: 11.5, color: p.inkSecondary),
                      ),
                    ],
                  ),
                ),
                ProStatusPill(
                  label: isUsed ? 'USED' : 'ACTIVE',
                  color: isUsed ? p.inkMuted : p.success,
                ),
                if (!isUsed && codeStr.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.copy_rounded, size: 18, color: p.primary),
                    tooltip: 'Copy Code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: codeStr));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied "$codeStr" to clipboard.'),
                        ),
                      );
                    },
                  ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 19, color: p.danger),
                  tooltip: 'Delete Invite Code',
                  onPressed: () async {
                    final id = code['id'];
                    if (id == null) return;
                    final removedItem = code;
                    final origIdx =
                        _inviteCodes.indexWhere((item) => item['id'] == id);
                    setState(() =>
                        _inviteCodes.removeWhere((item) => item['id'] == id));
                    final ok = await SupabaseService.instance
                        .deleteInviteCode(id.toString());
                    if (!ok && mounted) {
                      setState(() {
                        if (origIdx >= 0 && origIdx <= _inviteCodes.length) {
                          _inviteCodes.insert(origIdx, removedItem);
                        } else {
                          _inviteCodes.add(removedItem);
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Failed to delete invite code.'),
                          backgroundColor: p.danger,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
