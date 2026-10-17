import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/halaqah.dart';
import '../../core/services/auth_session_service.dart';
import '../../core/services/halaqah_service.dart';
import '../../core/services/messaging_service.dart';
import '../../core/services/student_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/invite_code_dialog.dart';
import '../messages/chat_screen.dart';

/// Admin User Management Hub
/// Allows Center Director to monitor, inspect, and manage:
/// 1. Teachers (Assigned Halaqahs, Contact details, Joined date, Reassignment)
/// 2. Parents (Linked children, Contact details, Tuition verification)
/// 3. Pending Invitation Codes (Copy, Revoke, Generate)
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
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Fetch Teachers
      final teachersRes = await client
          .from('profiles')
          .select('id, full_name, email, phone, role, created_at')
          .eq('role', 'teacher')
          .order('created_at', ascending: false);

      // 2. Fetch Parents
      final parentsRes = await client
          .from('profiles')
          .select('id, full_name, email, phone, role, created_at')
          .eq('role', 'parent')
          .order('created_at', ascending: false);

      // 3. Fetch Pending Invitation Codes
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

  Future<void> _deleteInviteCode(String codeId) async {
    final client = SupabaseService.instance.client;
    if (client == null) return;

    try {
      await client.from('invitation_codes').delete().eq('id', codeId);
      setState(() {
        _inviteCodes.removeWhere((c) => c['id'] == codeId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation code revoked successfully.')),
        );
      }
    } catch (e) {
      debugPrint('[UserManagement] Error revoking code: $e');
    }
  }

  void _showAssignHalaqahDialog(Map<String, dynamic> teacher) {
    final halaqahs = HalaqahService.instance.halaqahs;
    String? selectedHalaqahId;

    // Find current assigned halaqah
    for (final h in halaqahs) {
      if (h.teacherId == teacher['id'] || h.teacherName == teacher['full_name']) {
        selectedHalaqahId = h.id;
        break;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.school_rounded, color: AppColors.accentTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Assign Circle to ${teacher['full_name']}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: halaqahs.isEmpty
                ? const Text('No Halaqahs created yet. Please create a circle in Halaqah Management first.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select the study circle this Ustaz will lead and take attendance for:',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedHalaqahId,
                        hint: const Text('Select a Halaqah'),
                        items: halaqahs.map((h) {
                          return DropdownMenuItem<String>(
                            value: h.id,
                            child: Text(h.name, style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) => setDialogState(() => selectedHalaqahId = val),
                        decoration: const InputDecoration(
                          labelText: 'Assigned Circle',
                          prefixIcon: Icon(Icons.menu_book_rounded),
                        ),
                      ),
                    ],
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              if (halaqahs.isNotEmpty)
                ElevatedButton(
                  onPressed: selectedHalaqahId == null
                      ? null
                      : () async {
                          Navigator.of(ctx).pop();
                          await HalaqahService.instance.assignTeacher(
                            halaqahId: selectedHalaqahId!,
                            teacherId: teacher['id'],
                            teacherName: teacher['full_name'] ?? 'Ustaz',
                          );
                          setState(() {});
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${teacher['full_name']} assigned to circle successfully.'),
                                backgroundColor: AppColors.accentTeal,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Save Assignment'),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('User Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadAllUserData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accentTeal,
          unselectedLabelColor: subtextColor,
          indicatorColor: AppColors.accentTeal,
          tabs: [
            Tab(text: 'Teachers (${_teachers.length})'),
            Tab(text: 'Parents (${_parents.length})'),
            Tab(text: 'Invites (${_inviteCodes.where((c) => c['is_used'] != true).length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, email, or phone...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTeachersTab(cardBg, textColor, subtextColor, borderColor, isDark),
                      _buildParentsTab(cardBg, textColor, subtextColor, borderColor, isDark),
                      _buildInvitesTab(cardBg, textColor, subtextColor, borderColor, isDark),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TEACHERS TAB
  // ---------------------------------------------------------------------------
  Widget _buildTeachersTab(Color cardBg, Color textColor, Color subtextColor, Color borderColor, bool isDark) {
    final filtered = _teachers.where((t) {
      final name = (t['full_name'] ?? '').toString().toLowerCase();
      final email = (t['email'] ?? '').toString().toLowerCase();
      final phone = (t['phone'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || email.contains(_searchQuery) || phone.contains(_searchQuery);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadAllUserData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          // Quick Invite Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withOpacity(isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accentTeal.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recruit New Teacher',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accentTeal),
                      ),
                      Text(
                        'Generate an invitation code for an Ustaz to register.',
                        style: TextStyle(fontSize: 11, color: subtextColor),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => InviteCodeDialog.show(context, initialRole: 'teacher'),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Invite', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            _buildEmptyState(
              icon: Icons.school_outlined,
              title: _searchQuery.isEmpty ? 'No Teachers Registered Yet' : 'No Teachers Found',
              subtitle: _searchQuery.isEmpty
                  ? 'Generate a teacher invite code to register the first teacher.'
                  : 'Try searching with a different name or phone number.',
              textColor: textColor,
              subtextColor: subtextColor,
            )
          else
            ...filtered.map((t) {
              // Check assigned halaqah
              final halaqahs = HalaqahService.instance.halaqahs;
              final assignedHalaqah = halaqahs.firstWhere(
                (h) => h.teacherId == t['id'] || h.teacherName == t['full_name'],
                orElse: () => const Halaqah(id: '', name: '', createdAt: null as dynamic),
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.accentTeal.withOpacity(0.15),
                          child: const Icon(Icons.person_rounded, color: AppColors.accentTeal, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t['full_name'] ?? 'Ustaz',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${t['email'] ?? ''} • ${t['phone'] ?? 'No phone'}',
                                style: TextStyle(fontSize: 11, color: subtextColor),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentTeal.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'TEACHER',
                            style: TextStyle(color: AppColors.accentTeal, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.school_outlined, size: 14, color: AppColors.accentTeal),
                            const SizedBox(width: 4),
                            Text(
                              assignedHalaqah.name.isNotEmpty
                                  ? 'Circle: ${assignedHalaqah.name}'
                                  : 'Circle: Unassigned',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: assignedHalaqah.name.isNotEmpty ? AppColors.accentTeal : subtextColor,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _showAssignHalaqahDialog(t),
                              icon: const Icon(Icons.edit_rounded, size: 14),
                              label: const Text('Assign Circle', style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.accentTeal,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                              color: AppColors.accentAmber,
                              tooltip: 'Message Teacher',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      conversationId: 'admin-teach-${t['id']}',
                                      conversationTitle: 'Ustaz ${t['full_name']}',
                                      targetRole: 'teacher',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. PARENTS TAB
  // ---------------------------------------------------------------------------
  Widget _buildParentsTab(Color cardBg, Color textColor, Color subtextColor, Color borderColor, bool isDark) {
    final filtered = _parents.where((p) {
      final name = (p['full_name'] ?? '').toString().toLowerCase();
      final email = (p['email'] ?? '').toString().toLowerCase();
      final phone = (p['phone'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || email.contains(_searchQuery) || phone.contains(_searchQuery);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadAllUserData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          // Quick Invite Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accentAmber.withOpacity(isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accentAmber.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Invite New Parent',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accentAmber),
                      ),
                      Text(
                        'Generate a parent code so they can sign up and link their children.',
                        style: TextStyle(fontSize: 11, color: subtextColor),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => InviteCodeDialog.show(context, initialRole: 'parent'),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Invite', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentAmber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            _buildEmptyState(
              icon: Icons.family_restroom_outlined,
              title: _searchQuery.isEmpty ? 'No Parents Registered Yet' : 'No Parents Found',
              subtitle: _searchQuery.isEmpty
                  ? 'Generate a parent invite code to allow parents to register.'
                  : 'Try searching with a different name or phone number.',
              textColor: textColor,
              subtextColor: subtextColor,
            )
          else
            ...filtered.map((p) {
              final pid = p['id']?.toString() ?? '';
              final linkedStudents = StudentService.instance.getStudentsForParent(pid, parentEmail: p['email']);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.accentAmber.withOpacity(0.15),
                          child: const Icon(Icons.family_restroom_rounded, color: AppColors.accentAmber, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['full_name'] ?? 'Parent',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${p['email'] ?? ''} • ${p['phone'] ?? 'No phone'}',
                                style: TextStyle(fontSize: 11, color: subtextColor),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentAmber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PARENT',
                            style: TextStyle(color: AppColors.accentAmber, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: linkedStudents.isEmpty
                                ? [
                                    Text(
                                      'No students linked yet',
                                      style: TextStyle(fontSize: 11, color: subtextColor, fontStyle: FontStyle.italic),
                                    ),
                                  ]
                                : linkedStudents.map((s) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentEmerald.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '👶 ${s.fullName} (${s.halaqahName})',
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.accentEmerald),
                                      ),
                                    );
                                  }).toList(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                          color: AppColors.accentAmber,
                          tooltip: 'Message Parent',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  conversationId: 'admin-parent-${p['id']}',
                                  conversationTitle: p['full_name'] ?? 'Parent',
                                  targetRole: 'parent',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. PENDING INVITATIONS TAB
  // ---------------------------------------------------------------------------
  Widget _buildInvitesTab(Color cardBg, Color textColor, Color subtextColor, Color borderColor, bool isDark) {
    final pendingCodes = _inviteCodes.where((c) => c['is_used'] != true).toList();

    return RefreshIndicator(
      onRefresh: _loadAllUserData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Invitation Codes (${pendingCodes.length})',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
              ),
              TextButton.icon(
                onPressed: () => InviteCodeDialog.show(context),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Generate Code', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (pendingCodes.isEmpty)
            _buildEmptyState(
              icon: Icons.vpn_key_outlined,
              title: 'No Pending Codes',
              subtitle: 'All generated invitation codes have been redeemed or none have been created yet.',
              textColor: textColor,
              subtextColor: subtextColor,
            )
          else
            ...pendingCodes.map((code) {
              final isTeacher = code['role'] == 'teacher';
              final roleColor = isTeacher ? AppColors.accentTeal : AppColors.accentAmber;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isTeacher ? Icons.school_rounded : Icons.family_restroom_rounded,
                        color: roleColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            code['code'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Role: ${code['role']?.toString().toUpperCase()} • Status: Pending activation',
                            style: TextStyle(fontSize: 10.5, color: subtextColor),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy Code',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code['code'] ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied code "${code['code']}" to clipboard.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                      tooltip: 'Revoke Code',
                      onPressed: () => _deleteInviteCode(code['id']),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: subtextColor.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: subtextColor)),
        ],
      ),
    );
  }
}
