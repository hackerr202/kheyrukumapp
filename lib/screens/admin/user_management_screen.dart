import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/connectivity_service.dart';
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
        final offlineErr = AppLocalizations.of(context)
            .translate('unableToConnectCenterServerMsg');
        setState(() {
          _teachers = [];
          _parents = [];
          _admins = [];
          _inviteCodes = [];
          _loadError = offlineErr;
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
    final loc = AppLocalizations.of(context);
    final bool currentStatus = user['is_suspended'] == true;
    final bool newStatus = !currentStatus;
    final String actionWord = newStatus
        ? loc.translate('suspendWord')
        : loc.translate('activateWord');
    final userName = (user['full_name'] ?? '').toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.tr('suspendActivateConfirmTitle', {
          'action': actionWord,
          'name': userName,
        })),
        content: Text(
          newStatus
              ? loc.translate('suspendWarningMsg')
              : loc.translate('activateRestoredMsg'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.cancel)),
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

    if (!ConnectivityService.instance.isOnline &&
        !await ConnectivityService.instance.checkNow()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.internetRequiredAction),
            backgroundColor: p.danger,
          ),
        );
      }
      return;
    }

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
            content: Text(loc.translate('unableToConnectServer')),
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
              loc.tr('failedUpdateUserStatusMsg', {
                'error': SupabaseService.cleanErrorMessage(e),
              }),
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
            newStatus
                ? loc.tr('userSuspendedMsg', {'name': userName})
                : loc.tr('userReactivatedMsg', {'name': userName}),
          ),
          backgroundColor: newStatus ? p.danger : p.success,
        ),
      );
    }
  }

  Future<void> _removeUser(Map<String, dynamic> user, String listType) async {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final userName = (user['full_name'] ?? '').toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: p.danger, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(loc.translate('removeUserAccountTitle'))),
          ],
        ),
        content: Text(
          loc.tr('removeUserAccountBody', {'name': userName}),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: p.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(loc.translate('removePermanentlyAction')),
          ),
        ],
      ),
    );

    if (!mounted || confirm != true) return;

    if (!ConnectivityService.instance.isOnline &&
        !await ConnectivityService.instance.checkNow()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.internetRequiredAction),
            backgroundColor: p.danger,
          ),
        );
      }
      return;
    }

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
            content: Text(loc.translate('unableToConnectServer')),
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
          rpcRes['message']?.toString() ?? loc.translate('failedRemoveUserSimple'),
        );
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
                  loc.tr('failedRemoveUserMsg', {
                    'error': SupabaseService.cleanErrorMessage(fallbackErr),
                  }),
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
                loc.tr('failedRemoveUserMsg', {
                  'error': SupabaseService.cleanErrorMessage(e),
                }),
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
          content: Text(loc.tr('removedUserFromCenterMsg', {'name': userName})),
          backgroundColor: p.danger,
        ),
      );
    }
  }

  Future<void> _showAssignHalaqahDialog(Map<String, dynamic> teacher) async {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final teacherName = (teacher['full_name'] ?? '').toString();
    final halaqahs = HalaqahService.instance.halaqahs;
    if (halaqahs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.translate('createCircleFirstMsg')),
          ),
        );
      }
      return;
    }

    String selectedId = '';
    String selectedName = loc.translate('unassignedCircleLabel');
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
          title: Text(loc.tr('assignTeacherTitle', {'name': teacherName})),
          content: DropdownButtonFormField<String>(
            value: selectedId,
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(loc.translate('unassignedRemoveFromCircle')),
              ),
              ...halaqahs
                  .map((h) => DropdownMenuItem(value: h.id, child: Text(h.name))),
            ],
            onChanged: (val) {
              if (val == null) return;
              if (val.isEmpty) {
                setDialogState(() {
                  selectedId = '';
                  selectedName = loc.translate('unassignedCircleLabel');
                });
              } else {
                final h = halaqahs.firstWhere((e) => e.id == val);
                setDialogState(() {
                  selectedId = h.id;
                  selectedName = h.name;
                });
              }
            },
            decoration: InputDecoration(
              labelText: loc.translate('studyCircleHalaqahLabel'),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(loc.cancel)),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(loc.save),
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
          teacherName: teacher['full_name']?.toString() ?? loc.roleTeacher,
        );
      }
      await _loadAllUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selectedId.isEmpty
                  ? loc.tr('teacherUnassignedCircleMsg', {'name': teacherName})
                  : loc.tr('teacherAssignedCircleMsg', {
                      'name': teacherName,
                      'circle': selectedName,
                    }),
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
              loc.tr('failedUpdateAssignmentMsg', {
                'error': SupabaseService.cleanErrorMessage(e),
              }),
            ),
            backgroundColor: p.danger,
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadUserAvatar(Map<String, dynamic> user) async {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final userName = (user['full_name'] ?? '').toString();
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
        throw Exception(loc.translate('failedUploadImageToStorageMsg'));
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
            content: Text(loc.tr('profilePhotoUpdatedUserMsg', {'name': userName})),
            backgroundColor: p.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.tr('couldNotUpdatePhotoMsg', {
                'error': SupabaseService.cleanErrorMessage(e),
              }),
            ),
            backgroundColor: p.danger,
          ),
        );
      }
    }
  }

  Future<void> _showChangeRoleDialog(Map<String, dynamic> user) async {
    if (!AuthSessionService.instance.isSuperAdmin) return;
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final userName = (user['full_name'] ?? '').toString();
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
                  loc.tr('changeRoleForTitle', {'name': userName}),
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
                loc.translate('selectPermissionsPrompt'),
                style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
              ),
              const SizedBox(height: 14),
              RadioListTile<String>(
                title: Text(loc.translate('superadminFullControlTitle'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: Text(loc.translate('superadminFullControlDesc'),
                    style: const TextStyle(fontSize: 11)),
                value: 'superadmin',
                groupValue: selectedRole,
                activeColor: p.gold,
                onChanged: (v) => setDialogState(() => selectedRole = v!),
              ),
              RadioListTile<String>(
                title: Text(loc.translate('adminRoleDescTitle'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: Text(loc.translate('adminRoleDescSubtitle'),
                    style: const TextStyle(fontSize: 11)),
                value: 'admin',
                groupValue: selectedRole,
                activeColor: p.primary,
                onChanged: isSelfSuperadmin
                    ? null
                    : (v) => setDialogState(() => selectedRole = v!),
              ),
              RadioListTile<String>(
                title: Text(loc.translate('teacherRoleDescTitle'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: Text(loc.translate('teacherRoleDescSubtitle'),
                    style: const TextStyle(fontSize: 11)),
                value: 'teacher',
                groupValue: selectedRole,
                activeColor: p.primary,
                onChanged: isSelfSuperadmin
                    ? null
                    : (v) => setDialogState(() => selectedRole = v!),
              ),
              RadioListTile<String>(
                title: Text(loc.roleParent,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: Text(loc.translate('parentRoleDescSubtitle'),
                    style: const TextStyle(fontSize: 11)),
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
                    loc.translate('cannotDemoteSelfNote'),
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
              child: Text(loc.cancel),
            ),
            ElevatedButton(
              onPressed: selectedRole == currentRole
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final offlineMsg = loc.internetRequiredAction;
                      if (!ConnectivityService.instance.isOnline &&
                          !await ConnectivityService.instance.checkNow()) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(offlineMsg),
                            backgroundColor: p.danger,
                          ),
                        );
                        return;
                      }
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      try {
                        final client = SupabaseService.instance.client;
                        if (client == null) {
                          throw Exception(loc.translate('serverNotConnectedMsg'));
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
                                loc.tr('userPromotedRoleMsg', {
                                  'name': userName,
                                  'role': loc.localizedRoleBadge(selectedRole),
                                }),
                              ),
                              backgroundColor: p.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                loc.tr('failedUpdateRoleMsg', {
                                  'error': SupabaseService.cleanErrorMessage(e),
                                }),
                              ),
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
              child: Text(loc.translate('updateRoleAction')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);

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
          title: Text(loc.userManagement),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ProEmptyState(
              icon: Icons.lock_outline_rounded,
              title: loc.translate('accessRestrictedTitle'),
              message: loc.translate('onlyAdminsManageUsersMsg'),
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
              AppLocalizations.of(context).userManagement,
              style: TextStyle(
                color: p.ink,
                fontWeight: FontWeight.w700,
                fontSize: 17.5,
              ),
            ),
            Text(
              '${_teachers.length} ${AppLocalizations.of(context).teachersTab} • ${_parents.length} ${AppLocalizations.of(context).parentsTab} • ${_admins.length} ${AppLocalizations.of(context).adminsTab}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.inkSecondary, fontSize: 11.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_rounded, color: p.primary),
            tooltip: AppLocalizations.of(context).generateInviteCode,
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
                Tab(
                    text:
                        '${AppLocalizations.of(context).teachersTab} (${_teachers.length})'),
                Tab(
                    text:
                        '${AppLocalizations.of(context).parentsTab} (${_parents.length})'),
                Tab(
                    text:
                        '${AppLocalizations.of(context).adminsTab} (${_admins.length})'),
                Tab(
                    text:
                        '${AppLocalizations.of(context).invitesTab} (${_inviteCodes.length})'),
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
              hintText: AppLocalizations.of(context).search,
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
                          title: loc.translate('couldNotLoadUsersTitle'),
                          message: _loadError!,
                          accentColor: p.danger,
                          actionLabel: loc.retry,
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
    final loc = AppLocalizations.of(context);
    final filtered = users.where((u) {
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          phone.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      final emptyTitle = switch (listType) {
        'teacher' => loc.translate('noTeachersFoundTitle'),
        'admin' => loc.translate('noAdminsFoundTitle'),
        _ => loc.translate('noParentsFoundTitle'),
      };
      final emptyMsg = _searchQuery.isNotEmpty
          ? loc.translate('tryModifyingSearchMsg')
          : switch (listType) {
              'teacher' => loc.translate('registeredTeachersAppearMsg'),
              'admin' => loc.translate('registeredAdminsAppearMsg'),
              _ => loc.translate('registeredParentsAppearMsg'),
            };
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ProEmptyState(
            icon: Icons.person_off_outlined,
            title: emptyTitle,
            message: emptyMsg,
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
          final name =
              (user['full_name'] ?? loc.translate('userFallback')).toString();

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
                            ProStatusPill(
                              label: loc.translate('suspendedTag'),
                              color: p.danger,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        (user['phone'] != null &&
                                user['phone'].toString().isNotEmpty)
                            ? user['phone'].toString()
                            : (user['email']?.toString() ??
                                loc.translate('noContactInfo')),
                        style: TextStyle(fontSize: 12, color: p.inkSecondary),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          ProStatusPill(
                            label: loc.localizedRoleBadge(
                              (user['role'] ?? listType).toString(),
                            ),
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
                                        : loc.translate('unassignedCircleLabel'));
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
                              loc.translate('promoteChangeRoleAction'),
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
                              loc.translate('updatePhoto'),
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
                              loc.translate('assignHalaqahAction'),
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
                                ? loc.translate('reactivateAccountAction')
                                : loc.translate('suspendAccountAction'),
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
                            loc.translate('removeUser'),
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
    final loc = AppLocalizations.of(context);
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
                ? loc.translate('noMatchingInviteCodes')
                : loc.translate('noInviteCodesActive'),
            message: _searchQuery.isNotEmpty
                ? loc.translate('tryModifyingSearchMsg')
                : loc.translate('generateInviteTopRightHint'),
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
                            ? loc.translate('teacherRegistrationLabel')
                            : loc.translate('parentRegistrationLabel'),
                        style: TextStyle(fontSize: 11.5, color: p.inkSecondary),
                      ),
                    ],
                  ),
                ),
                ProStatusPill(
                  label: isUsed
                      ? loc.translate('usedTag')
                      : loc.translate('activeTag'),
                  color: isUsed ? p.inkMuted : p.success,
                ),
                if (!isUsed && codeStr.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.copy_rounded, size: 18, color: p.primary),
                    tooltip: loc.copyCodeTooltip,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: codeStr));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            loc.tr('copiedCodeMsg', {'code': codeStr}),
                          ),
                        ),
                      );
                    },
                  ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 19, color: p.danger),
                  tooltip: loc.translate('deleteInviteCodeTooltip'),
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
                          content:
                              Text(loc.translate('failedDeleteInviteCodeMsg')),
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
