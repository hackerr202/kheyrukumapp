import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../core/services/halaqah_service.dart';
import '../../../core/services/messaging_service.dart';
import '../../../core/services/student_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/pro_ui_kit.dart';
import '../../messages/chat_screen.dart';

/// Flagship Messages Hub:
/// - Lazy CustomScrollView + SliverList rendering with loading, retryable error & empty states
/// - Real-time conversation list with role-aware display titles, badges & unread counts
/// - Role-scoped New Chat contact picker powered by get_messageable_contacts() RPC
class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (MessagingService.instance.allConversations.isEmpty) {
      MessagingService.instance.refreshAndSubscribe();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await MessagingService.instance.refreshAndSubscribe();
  }

  void _openConversation(BuildContext context, Conversation convo) {
    MessagingService.instance.markConversationRead(convo.id);
    final currentUserId = AuthSessionService.instance.userId;
    final currentRole = AuthSessionService.instance.currentRole;
    final displayTitle =
        MessagingService.instance.displayTitleFor(convo, currentUserId);

    final String resolvedTargetRole;
    if (convo.groupType == 'direct_teacher') {
      resolvedTargetRole = currentRole == 'parent' ? 'teacher' : 'parent';
    } else if (convo.groupType == 'direct_admin') {
      resolvedTargetRole =
          (currentRole == 'parent' || currentRole == 'teacher')
              ? 'admin'
              : 'parent';
    } else {
      resolvedTargetRole = convo.groupType;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: convo.id,
          conversationTitle: displayTitle,
          targetRole: resolvedTargetRole,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final messaging = MessagingService.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([
        AuthSessionService.instance.roleNotifier,
        messaging.isLoadingNotifier,
        messaging.errorNotifier,
      ]),
      builder: (context, _) {
        final currentRole = AuthSessionService.instance.currentRole;
        final isAdmin = currentRole == 'admin' || currentRole == 'superadmin';
        final isTeacher = currentRole == 'teacher';
        final isParent = currentRole == 'parent';
        final currentUserId = AuthSessionService.instance.userId;
        final isLoading = messaging.isLoadingNotifier.value;
        final errorMsg = messaging.errorNotifier.value;

        return StreamBuilder<List<Conversation>>(
          stream: messaging.conversationsStream,
          initialData: messaging.allConversations,
          builder: (context, _) {
            final allConvos = messaging.getConversationsForUser(
              currentUserId,
              role: currentRole,
            );

            final filteredConvos = _searchQuery.isEmpty
                ? allConvos
                : allConvos.where((c) {
                    final query = _searchQuery.toLowerCase();
                    final displayTitle =
                        messaging.displayTitleFor(c, currentUserId);
                    return displayTitle.toLowerCase().contains(query) ||
                        c.title.toLowerCase().contains(query) ||
                        c.lastMessage.toLowerCase().contains(query);
                  }).toList();

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: RefreshIndicator(
                color: p.primary,
                onRefresh: _handleRefresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTeacher
                                  ? loc.messagesSubtitleTeacher
                                  : (isParent
                                      ? loc.messagesSubtitleParent
                                      : loc.messagesSubtitleAdmin),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: p.inkSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Sculpted Search Field
                            ProSearchField(
                              controller: _searchCtrl,
                              hintText: loc.searchChatsHint,
                              query: _searchQuery,
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val.trim()),
                            ),
                            const SizedBox(height: 14),

                            // Role-specific Quick Actions
                            if (isParent) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildQuickActionButton(
                                      p: p,
                                      icon: Icons.menu_book_rounded,
                                      label: loc.ustazDirect,
                                      color: p.primary,
                                      onTap: () => _startParentDirectChat(
                                          context,
                                          role: 'teacher'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildQuickActionButton(
                                      p: p,
                                      icon: Icons.admin_panel_settings_outlined,
                                      label: loc.directorDirect,
                                      color: p.gold,
                                      onTap: () => _startParentDirectChat(
                                          context,
                                          role: 'admin'),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (isTeacher) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildQuickActionButton(
                                      p: p,
                                      icon: Icons.chat_bubble_outline_rounded,
                                      label: loc.classParents,
                                      color: p.primary,
                                      onTap: () =>
                                          _showTeacherMessageParentSheet(
                                              context),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildQuickActionButton(
                                      p: p,
                                      icon: Icons.people_outline_rounded,
                                      label: loc.allContacts,
                                      color: p.gold,
                                      onTap: () => _openNewChatSheet(context),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // Non-blocking sync warning banner if cached rows exist
                            if (errorMsg != null && filteredConvos.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildSyncErrorBanner(p, loc, errorMsg),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (isLoading && allConvos.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: p.primary),
                              const SizedBox(height: 12),
                              Text(
                                loc.loadingConversations,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: p.inkSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (errorMsg != null && allConvos.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
                        sliver: SliverToBoxAdapter(
                          child: ProEmptyState(
                            icon: Icons.cloud_off_rounded,
                            title: loc.couldNotLoadMessages,
                            message: errorMsg,
                            actionLabel: loc.retry,
                            onAction: _handleRefresh,
                          ),
                        ),
                      )
                    else if (filteredConvos.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
                        sliver: SliverToBoxAdapter(
                          child: ProEmptyState(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: _searchQuery.isNotEmpty
                                ? loc.noChatsMatching
                                : loc.noConversationsYet,
                            message: _searchQuery.isNotEmpty
                                ? loc.searchChatsHint
                                : (isTeacher
                                    ? loc.messagesSubtitleTeacher
                                    : (isParent
                                        ? loc.messagesSubtitleParent
                                        : loc.messagesSubtitleAdmin)),
                            actionLabel: _searchQuery.isNotEmpty
                                ? loc.clearSearch
                                : loc.startNewChat,
                            onAction: () {
                              if (_searchQuery.isNotEmpty) {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              } else {
                                _openNewChatSheet(context);
                              }
                            },
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
                        sliver: SliverList.builder(
                          itemCount: filteredConvos.length,
                          itemBuilder: (context, index) {
                            final convo = filteredConvos[index];
                            final isFirst = index == 0;
                            final isLast = index == filteredConvos.length - 1;
                            return Container(
                              decoration: BoxDecoration(
                                color: p.surface,
                                borderRadius: BorderRadius.vertical(
                                  top: isFirst
                                      ? const Radius.circular(20)
                                      : Radius.zero,
                                  bottom: isLast
                                      ? const Radius.circular(20)
                                      : Radius.zero,
                                ),
                                border: Border(
                                  top: isFirst
                                      ? BorderSide(color: p.border, width: 1)
                                      : BorderSide.none,
                                  left: BorderSide(color: p.border, width: 1),
                                  right: BorderSide(color: p.border, width: 1),
                                  bottom: BorderSide(
                                    color: isLast
                                        ? p.border
                                        : p.border.withOpacity(0.55),
                                    width: 1,
                                  ),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _buildChatTile(
                                  context, convo, currentUserId, p),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              floatingActionButton: Padding(
                padding: EdgeInsetsDirectional.only(
                  bottom: MediaQuery.of(context).padding.bottom + 84,
                ),
                child: FloatingActionButton.extended(
                  onPressed: () {
                    if (isAdmin) {
                      _showAdminActionSheet(context);
                    } else {
                      _openNewChatSheet(context);
                    }
                  },
                  backgroundColor: p.primary,
                  foregroundColor: p.onPrimary,
                  elevation: 4,
                  icon: const Icon(Icons.add_comment_rounded, size: 19),
                  label: Text(
                    loc.newChat,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSyncErrorBanner(
      AppPalette p, AppLocalizations loc, String errorMsg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.danger.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.danger.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          Icon(Icons.sync_problem_rounded, size: 18, color: p.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMsg,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: p.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _handleRefresh,
            child: Text(
              loc.retry,
              style: TextStyle(
                color: p.danger,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required AppPalette p,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ProCard(
      onTap: onTap,
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
      borderColor: color.withOpacity(0.32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(
    BuildContext context,
    Conversation convo,
    String currentUserId,
    AppPalette p,
  ) {
    final hasUnread = convo.unreadCount > 0;
    final isGroup = convo.isGroup;
    final badgeInfo = _resolveBadgeInfo(convo, p);
    final displayTitle =
        MessagingService.instance.displayTitleFor(convo, currentUserId);

    Widget lastMsgWidget;
    final preview = convo.lastMessage;
    if (preview.startsWith('🎤 Voice') || preview.contains('(0:')) {
      lastMsgWidget = _buildPreviewWithIcon(
          Icons.mic_rounded, p.primary, preview, hasUnread, p);
    } else if (preview.startsWith('📷 Photo')) {
      lastMsgWidget = _buildPreviewWithIcon(
          Icons.photo_rounded, p.info, preview, hasUnread, p);
    } else if (preview.startsWith('📎 Document')) {
      lastMsgWidget = _buildPreviewWithIcon(
          Icons.attach_file_rounded, p.gold, preview, hasUnread, p);
    } else {
      lastMsgWidget = Text(
        preview.isNotEmpty ? preview : 'Tap to open conversation',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          color: hasUnread ? p.ink : p.inkSecondary,
          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
        ),
      );
    }

    return InkWell(
      onTap: () => _openConversation(context, convo),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                ProAvatar(
                  name: displayTitle,
                  radius: 23,
                  color: badgeInfo.$2,
                  icon: isGroup ? Icons.groups_rounded : null,
                ),
                PositionedDirectional(
                  bottom: 0,
                  end: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: p.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: p.ink,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeInfo.$2.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeInfo.$1,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: badgeInfo.$2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(convo.lastMessageTime),
                        style: TextStyle(
                          fontSize: 11,
                          color: hasUnread ? p.primary : p.inkMuted,
                          fontWeight:
                              hasUnread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: lastMsgWidget),
                      if (convo.isPinned) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.push_pin_rounded,
                            size: 13, color: p.gold),
                      ],
                      if (hasUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          constraints: const BoxConstraints(
                              minWidth: 20, minHeight: 20),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: p.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            convo.unreadCount > 99
                                ? '99+'
                                : '${convo.unreadCount}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: p.onPrimary,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewWithIcon(
    IconData icon,
    Color iconColor,
    String text,
    bool hasUnread,
    AppPalette p,
  ) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: hasUnread ? p.ink : p.inkSecondary,
              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openNewChatSheet(BuildContext context) async {
    final p = AppColors.of(context);
    final selectedConvo = await showModalBottomSheet<Conversation>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ContactPickerSheet(palette: p),
    );
    if (selectedConvo != null && context.mounted) {
      _openConversation(context, selectedConvo);
    }
  }

  void _showTeacherMessageParentSheet(BuildContext context) {
    final p = AppColors.of(context);
    final assignedHalaqah = AuthSessionService.instance.assignedHalaqahName;
    final classStudents = StudentService.instance.getStudentsForHalaqah(
      assignedHalaqah,
      halaqahId: AuthSessionService.instance.assignedHalaqahId,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ProBottomSheetShell(
          title: 'Message Class Parent',
          subtitle: 'Select a parent from $assignedHalaqah',
          icon: Icons.chat_bubble_rounded,
          iconColor: p.primary,
          heightFactor: 0.65,
          child: classStudents.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: ProEmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No students in class',
                    message:
                        'No students are currently assigned to your study circle.',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: classStudents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, idx) {
                    final student = classStudents[idx];
                    return ProCard(
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        Navigator.pop(ctx);
                        if (student.parentId == null ||
                            student.parentId!.isEmpty) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                '${student.fullName} does not have a linked parent account yet.',
                              ),
                            ),
                          );
                          return;
                        }
                        try {
                          final convo = await MessagingService.instance
                              .startTeacherChatWithParent(
                            teacherId: AuthSessionService.instance.userId,
                            teacherName: AuthSessionService.instance.userName,
                            parentId: student.parentId!,
                            parentName: student.parentName,
                            studentName: student.fullName,
                            halaqahId: student.halaqahId,
                          );
                          final displayTitle = MessagingService.instance
                              .displayTitleFor(
                                  convo, AuthSessionService.instance.userId);
                          navigator.push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversationId: convo.id,
                                conversationTitle: displayTitle,
                                targetRole: 'parent',
                              ),
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not open chat: ${SupabaseService.cleanErrorMessage(e)}',
                              ),
                              backgroundColor: p.danger,
                            ),
                          );
                        }
                      },
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ProAvatar(
                            name: student.parentName,
                            radius: 20,
                            color: p.gold,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.parentName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: p.ink,
                                  ),
                                ),
                                Text(
                                  'Student: ${student.fullName} • ${student.parentPhone}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: p.inkSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: p.primary,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _startParentDirectChat(BuildContext context,
      {required String role}) async {
    final p = AppColors.of(context);
    final children = StudentService.instance.getStudentsForParent(
      AuthSessionService.instance.userId,
      parentEmail: AuthSessionService.instance.userEmail,
    );
    final child = children.isNotEmpty ? children.first : null;
    final childHalaqahId = child?.halaqahId;
    final childHalaqah = child?.halaqahName ?? 'Study Circle';
    final halaqahs = HalaqahService.instance.halaqahs;
    final hMatch = (childHalaqahId != null && childHalaqahId.isNotEmpty)
        ? halaqahs.where((h) => h.id == childHalaqahId)
        : halaqahs.where(
            (h) => h.name.toLowerCase() == childHalaqah.toLowerCase());
    final teacherName =
        (hMatch.isNotEmpty && hMatch.first.teacherName != 'Unassigned')
            ? hMatch.first.teacherName
            : 'Assigned Ustaz';
    final teacherId = hMatch.isNotEmpty ? hMatch.first.teacherId : null;

    try {
      final convo = await MessagingService.instance.startParentChat(
        parentId: AuthSessionService.instance.userId,
        parentName: AuthSessionService.instance.userName,
        targetRole: role,
        targetName: role == 'teacher' ? teacherName : 'Center Director',
        targetId: role == 'teacher' ? teacherId : null,
        halaqahId: childHalaqahId,
        halaqahName: childHalaqah,
      );

      if (context.mounted) {
        _openConversation(context, convo);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not start chat: ${SupabaseService.cleanErrorMessage(e)}',
            ),
            backgroundColor: p.danger,
          ),
        );
      }
    }
  }

  void _showAdminActionSheet(BuildContext context) {
    final p = AppColors.of(context);
    final registeredParents = StudentService.instance.getRegisteredParents();
    final halaqahs = HalaqahService.instance.halaqahs;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ProBottomSheetShell(
          title: 'Admin Messaging Hub',
          subtitle: 'Start a direct chat or circle group',
          icon: Icons.forum_rounded,
          iconColor: p.primary,
          heightFactor: 0.44,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ProCard(
                onTap: () {
                  Navigator.pop(ctx);
                  _openNewChatSheet(context);
                },
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: p.gold.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.person_search_rounded, color: p.gold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Message Teacher or Parent',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: p.ink,
                            ),
                          ),
                          Text(
                            'Browse all active staff and parent contacts',
                            style: TextStyle(
                              fontSize: 12,
                              color: p.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: p.inkMuted),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ProCard(
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  Navigator.pop(ctx);
                  final firstHalaqah =
                      halaqahs.isNotEmpty ? halaqahs.first : null;
                  final circleStudents = firstHalaqah != null
                      ? StudentService.instance.getStudentsForHalaqah(
                          firstHalaqah.name,
                          halaqahId: firstHalaqah.id,
                        )
                      : const [];
                  final parentIds = circleStudents.isNotEmpty
                      ? circleStudents
                          .map((s) => s.parentId ?? '')
                          .where((id) => id.isNotEmpty)
                          .toSet()
                          .toList()
                      : registeredParents.map((par) => par['id']!).toList();
                  final parentNames = circleStudents.isNotEmpty
                      ? parentIds.map((pid) {
                          final match = circleStudents
                              .where((s) => s.parentId == pid)
                              .toList();
                          return match.isNotEmpty
                              ? match.first.parentName
                              : 'Parent';
                        }).toList()
                      : registeredParents.map((par) => par['name']!).toList();

                  final groupName = firstHalaqah != null
                      ? '${firstHalaqah.name} Parents Group'
                      : 'Study Circle Parents Group';
                  try {
                    final convo = await MessagingService.instance.createGroup(
                      title: groupName,
                      parentIds: parentIds,
                      parentNames: parentNames,
                      halaqahId: firstHalaqah?.id,
                    );
                    navigator.push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: convo.id,
                          conversationTitle: convo.title,
                          targetRole: convo.groupType,
                        ),
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to create group: ${SupabaseService.cleanErrorMessage(e)}',
                        ),
                        backgroundColor: p.danger,
                      ),
                    );
                  }
                },
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: p.primary.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.groups_rounded, color: p.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Parent Halaqah Group',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: p.ink,
                            ),
                          ),
                          Text(
                            'Group discussion with circle parents',
                            style: TextStyle(
                              fontSize: 12,
                              color: p.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: p.inkMuted),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  (String, Color) _resolveBadgeInfo(Conversation convo, AppPalette p) {
    final lowerTitle = convo.title.toLowerCase();
    if (convo.groupType == 'direct_admin' ||
        lowerTitle.contains('director') ||
        lowerTitle.contains('admin')) {
      return ('Director', p.gold);
    } else if (convo.groupType == 'direct_teacher' ||
        lowerTitle.contains('ustaz') ||
        lowerTitle.contains('teacher')) {
      return ('Ustaz', p.primary);
    } else if (convo.isGroup) {
      return ('Group', p.info);
    } else {
      return ('Parent', p.gold);
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays == 0) {
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$min $ampm';
    }
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.month}/${dt.day}';
  }
}

class _ContactPickerSheet extends StatefulWidget {
  final AppPalette palette;

  const _ContactPickerSheet({required this.palette});

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  late Future<List<Map<String, dynamic>>> _contactsFuture;
  String _query = '';
  bool _isOpeningChat = false;

  @override
  void initState() {
    super.initState();
    _contactsFuture = MessagingService.instance.fetchMessageableContacts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _contactsFuture = MessagingService.instance.fetchMessageableContacts();
    });
  }

  (String, Color) _roleMeta(String role, AppPalette p) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return ('Superadmin', p.gold);
      case 'admin':
        return ('Director', p.gold);
      case 'teacher':
        return ('Ustaz', p.primary);
      default:
        return ('Parent', p.info);
    }
  }

  Future<void> _selectContact(Map<String, dynamic> contact) async {
    if (_isOpeningChat) return;
    final p = widget.palette;
    final id = contact['id']?.toString() ?? '';
    final name = contact['full_name']?.toString().trim() ?? '';
    final email = contact['email']?.toString().trim() ?? '';
    final role = contact['role']?.toString() ?? 'parent';
    final displayName = name.isNotEmpty ? name : (email.isNotEmpty ? email : 'User');

    setState(() => _isOpeningChat = true);
    try {
      final convo = await MessagingService.instance.startDirectChatWithContact(
        otherUserId: id,
        otherName: displayName,
        otherRole: role,
      );
      if (!mounted) return;
      Navigator.pop(context, convo);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOpeningChat = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not start chat: ${SupabaseService.cleanErrorMessage(e)}',
          ),
          backgroundColor: p.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final loc = AppLocalizations.of(context);
    return ProBottomSheetShell(
      title: loc.startNewChat,
      subtitle: loc.chooseContactSubtitle,
      icon: Icons.add_comment_rounded,
      iconColor: p.primary,
      heightFactor: 0.72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ProSearchField(
              controller: _searchCtrl,
              hintText: loc.filterContactsHint,
              query: _query,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          if (_isOpeningChat)
            LinearProgressIndicator(
              color: p.primary,
              backgroundColor: p.primarySoft,
              minHeight: 2,
            ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _contactsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: p.primary),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: ProEmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: loc.couldNotLoadMessages,
                      message: SupabaseService.cleanErrorMessage(
                          snapshot.error ?? 'Unknown error'),
                      actionLabel: loc.retry,
                      onAction: _reload,
                    ),
                  );
                }

                final contacts = snapshot.data ?? [];
                final filtered = _query.isEmpty
                    ? contacts
                    : contacts.where((c) {
                        final n = (c['full_name'] ?? '').toString().toLowerCase();
                        final e = (c['email'] ?? '').toString().toLowerCase();
                        final r = (c['role'] ?? '').toString().toLowerCase();
                        return n.contains(_query) ||
                            e.contains(_query) ||
                            r.contains(_query);
                      }).toList();

                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: ProEmptyState(
                      icon: Icons.people_outline_rounded,
                      title: loc.noContactsAvailable,
                      message: contacts.isEmpty
                          ? loc.chooseContactSubtitle
                          : loc.noChatsMatching,
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final contact = filtered[idx];
                    final name = (contact['full_name'] ?? '').toString().trim();
                    final email = (contact['email'] ?? '').toString().trim();
                    final role = (contact['role'] ?? 'parent').toString();
                    final avatarUrl = contact['avatar_url']?.toString();
                    final displayName = name.isNotEmpty
                        ? name
                        : (email.isNotEmpty ? email : 'User');
                    final roleMeta = _roleMeta(role, p);

                    return ProCard(
                      onTap: _isOpeningChat
                          ? null
                          : () => _selectContact(contact),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ProAvatar(
                            name: displayName,
                            imageUrl: avatarUrl,
                            radius: 20,
                            color: roleMeta.$2,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        displayName,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: p.ink,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    ProStatusPill(
                                      label: roleMeta.$1,
                                      color: roleMeta.$2,
                                    ),
                                  ],
                                ),
                                if (email.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: p.inkSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: p.inkMuted),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
