import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/invitation_code.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/invite_code_dialog.dart';
import '../../widgets/pro_ui_kit.dart';

/// Bottom sheet to generate & view active Teacher and Parent invitation codes.
class InviteCodesBottomSheet extends StatefulWidget {
  const InviteCodesBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const InviteCodesBottomSheet(),
    );
  }

  @override
  State<InviteCodesBottomSheet> createState() => _InviteCodesBottomSheetState();
}

class _InviteCodesBottomSheetState extends State<InviteCodesBottomSheet> {
  late final Stream<List<InvitationCode>> _codesStream;

  @override
  void initState() {
    super.initState();
    _codesStream = SupabaseService.instance.streamInviteCodes();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    return ProBottomSheetShell(
      title: loc.inviteCodes,
      subtitle: loc.generateInviteCode,
      icon: Icons.vpn_key_rounded,
      iconColor: p.gold,
      heightFactor: 0.65,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final hostContext = Navigator.of(context).context;
                        Navigator.pop(context);
                        InviteCodeDialog.show(hostContext, initialRole: 'teacher');
                      },
                      icon: const Icon(Icons.school_rounded, size: 17),
                      label: Text(loc.teachersTab,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final hostContext = Navigator.of(context).context;
                        Navigator.pop(context);
                        InviteCodeDialog.show(hostContext, initialRole: 'parent');
                      },
                      icon: Icon(Icons.family_restroom_rounded,
                          size: 17, color: p.gold),
                      label: Text(
                        loc.parentsTab,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.gold, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: p.gold.withOpacity(0.6)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              loc.invitesTab.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: p.inkMuted,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<List<InvitationCode>>(
                stream: _codesStream,
                builder: (context, snapshot) {
                  final codes =
                      (snapshot.data ?? []).where((c) => !c.isUsed).toList();

                  if (codes.isEmpty) {
                    return const Center(
                      child: ProEmptyState(
                        icon: Icons.vpn_key_off_outlined,
                        title: 'No active codes',
                        message:
                            'Generate a Teacher or Parent invite code above to onboard new members.',
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: codes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = codes[index];
                      final isTeacher = item.role == 'teacher';
                      final tone = isTeacher ? p.primary : p.gold;

                      return ProCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        borderRadius: 14,
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: tone.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isTeacher
                                    ? Icons.school_rounded
                                    : Icons.family_restroom_rounded,
                                size: 18,
                                color: tone,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.code,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: p.ink,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    item.role.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: tone,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.copy_rounded,
                                  size: 18, color: p.primary),
                              tooltip: 'Copy Code',
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: item.code));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Copied "${item.code}" to clipboard.'),
                                  ),
                                );
                              },
                            ),
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
      ),
    );
  }
}
