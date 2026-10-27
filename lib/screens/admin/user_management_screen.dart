import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import '../../widgets/invite_code_dialog.dart';

/// Redesigned Modern User Management Screen with Telegram-grade clean aesthetics,
/// full search, role tabs, user suspension, and account removal.
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
  List<Map<String, dynamic>> _inviteCodes = [];
  bool _isLoading = true;
  String _searchQuery = '';

  static const Color _limeGreen = Color(0xFFC9F24A);
  static const Color _alertRed = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllUserData() async {
    setState(() => _isLoading = true);
    final client = SupabaseService.instance.client;

    if (client == null) {
      // Mock data for preview
      setState(() {
        _teachers = [
          {'id': 't-1', 'full_name': 'Ustaz Muhammad Yakubu', 'email': 'muhammad@kheyrukum.com', 'phone': '+251 91 123 4567', 'role': 'teacher', 'is_suspended': false},
          {'id': 't-2', 'full_name': 'Ustaz Bilal Al-Habashi', 'email': 'bilal@kheyrukum.com', 'phone': '+251 92 234 5678', 'role': 'teacher', 'is_suspended': false},
        ];
        _parents = [
          {'id': 'p-1', 'full_name': 'Aisha Rahman', 'email': 'aisha@parent.com', 'phone': '+251 94 456 7890', 'role': 'parent', 'is_suspended': false},
          {'id': 'p-2', 'full_name': 'Omar Farooq', 'email': 'omar@parent.com', 'phone': '+251 93 345 6789', 'role': 'parent', 'is_suspended': false},
        ];
        _isLoading = false;
      });
      return;
    }

    try {
      final teachersRes = await client
          .from('profiles')
          .select('id, full_name, email, phone, role, is_suspended, created_at')
          .eq('role', 'teacher')
          .order('created_at', ascending: false);

      final parentsRes = await client
          .from('profiles')
          .select('id, full_name, email, phone, role, is_suspended, created_at')
          .eq('role', 'parent')
          .order('created_at', ascending: false);

      final codesRes = await client
          .from('invitation_codes')
          .select('*')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _teachers = List<Map<String, dynamic>>.from(teachersRes ?? []);
          _parents = List<Map<String, dynamic>>.from(parentsRes ?? []);
          _inviteCodes = List<Map<String, dynamic>>.from(codesRes ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[UserManagement] Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSuspendUser(Map<String, dynamic> user) async {
    final bool currentStatus = user['is_suspended'] == true;
    final bool newStatus = !currentStatus;
    final String actionWord = newStatus ? 'Suspend' : 'Activate';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$actionWord ${user['full_name']}?'),
        content: Text(
          newStatus
              ? 'Suspended users will immediately be prevented from signing in and accessing center data.'
              : 'The user account will be restored and allowed to log in.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? _alertRed : _limeGreen,
              foregroundColor: newStatus ? Colors.white : Colors.black,
            ),
            child: Text(actionWord),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      user['is_suspended'] = newStatus;
    });

    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        await client.from('profiles').update({'is_suspended': newStatus}).eq('id', user['id']);
      } catch (e) {
        debugPrint('[UserManagement] Suspend error: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user['full_name']} has been ${newStatus ? 'suspended' : 'reactivated'}.'),
          backgroundColor: newStatus ? _alertRed : _limeGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeUser(Map<String, dynamic> user, String listType) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: _alertRed, size: 24),
            SizedBox(width: 8),
            Text('Remove User Account?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently remove "${user['full_name']}"? This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _alertRed, foregroundColor: Colors.white),
            child: const Text('Remove Permanently'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      if (listType == 'teacher') {
        _teachers.removeWhere((t) => t['id'] == user['id']);
      } else {
        _parents.removeWhere((p) => p['id'] == user['id']);
      }
    });

    final client = SupabaseService.instance.client;
    if (client != null) {
      try {
        await client.from('profiles').delete().eq('id', user['id']);
      } catch (e) {
        debugPrint('[UserManagement] Delete error: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed ${user['full_name']} from center.'),
          backgroundColor: _alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final subtleBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: cardBg,
      appBar: AppBar(
        backgroundColor: surfaceBg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User Management', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
            Text('${_teachers.length} Teachers • ${_parents.length} Parents', style: TextStyle(color: subtextColor, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: _limeGreen),
            tooltip: 'Generate Invite Code',
            onPressed: () => InviteCodeDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAllUserData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: surfaceBg,
            child: TabBar(
              controller: _tabController,
              indicatorColor: _limeGreen,
              indicatorWeight: 3,
              labelColor: _limeGreen,
              unselectedLabelColor: subtextColor,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(text: 'Teachers (${_teachers.length})'),
                Tab(text: 'Parents (${_parents.length})'),
                Tab(text: 'Invites (${_inviteCodes.length})'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              style: TextStyle(fontSize: 13.5, color: textColor),
              decoration: InputDecoration(
                hintText: 'Search by name, email, or phone...',
                hintStyle: TextStyle(color: subtextColor.withOpacity(0.6), fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: subtextColor),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: surfaceBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: subtleBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: subtleBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _limeGreen, width: 1.5)),
              ),
            ),
          ),

          // Tab Views
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _limeGreen))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUserList(_teachers, 'teacher', surfaceBg, textColor, subtextColor, subtleBorder),
                      _buildUserList(_parents, 'parent', surfaceBg, textColor, subtextColor, subtleBorder),
                      _buildInviteCodesList(surfaceBg, textColor, subtextColor, subtleBorder),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(
    List<Map<String, dynamic>> users,
    String listType,
    Color surfaceBg,
    Color textColor,
    Color subtextColor,
    Color subtleBorder,
  ) {
    final filtered = users.where((u) {
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || email.contains(_searchQuery) || phone.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_rounded, size: 48, color: subtextColor),
            const SizedBox(height: 10),
            Text('No ${listType}s found', style: TextStyle(color: subtextColor, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final user = filtered[index];
        final bool isSuspended = user['is_suspended'] == true;
        final name = user['full_name'] ?? 'User';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSuspended ? _alertRed.withOpacity(0.5) : subtleBorder),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSuspended ? _alertRed.withOpacity(0.15) : _limeGreen.withOpacity(0.15),
                  border: Border.all(color: isSuspended ? _alertRed : _limeGreen, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSuspended ? _alertRed : _limeGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Details
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
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              decoration: isSuspended ? TextDecoration.lineThrough : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSuspended) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _alertRed.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('SUSPENDED', style: TextStyle(color: _alertRed, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user['phone'] ?? user['email'] ?? 'No contact info',
                      style: TextStyle(fontSize: 11.5, color: subtextColor),
                    ),
                  ],
                ),
              ),

              // Popup Actions Menu: Suspend / Reactivate & Remove
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: subtextColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                color: surfaceBg,
                onSelected: (val) {
                  if (val == 'suspend') {
                    _toggleSuspendUser(user);
                  } else if (val == 'remove') {
                    _removeUser(user, listType);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'suspend',
                    child: Row(
                      children: [
                        Icon(
                          isSuspended ? Icons.play_arrow_rounded : Icons.block_rounded,
                          size: 18,
                          color: isSuspended ? _limeGreen : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isSuspended ? 'Reactivate Account' : 'Suspend Account',
                          style: TextStyle(
                            fontSize: 13,
                            color: isSuspended ? _limeGreen : const Color(0xFFF59E0B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: _alertRed),
                        SizedBox(width: 10),
                        Text('Remove User', style: TextStyle(fontSize: 13, color: _alertRed, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInviteCodesList(
    Color surfaceBg,
    Color textColor,
    Color subtextColor,
    Color subtleBorder,
  ) {
    if (_inviteCodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.vpn_key_off_rounded, size: 48, color: subtextColor),
            const SizedBox(height: 10),
            Text('No invitation codes active', style: TextStyle(color: subtextColor, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _inviteCodes.length,
      itemBuilder: (context, index) {
        final code = _inviteCodes[index];
        final isTeacher = code['role'] == 'teacher';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: surfaceBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: subtleBorder),
          ),
          child: Row(
            children: [
              Icon(isTeacher ? Icons.school_rounded : Icons.family_restroom_rounded, size: 20, color: _limeGreen),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(code['code'] ?? '', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                  Text(isTeacher ? 'Teacher Registration' : 'Parent Registration', style: TextStyle(fontSize: 11, color: subtextColor)),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _alertRed),
                onPressed: () async {
                  final id = code['id'];
                  setState(() => _inviteCodes.removeAt(index));
                  await SupabaseService.instance.deleteInviteCode(id);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
