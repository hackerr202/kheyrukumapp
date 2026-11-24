import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models/invitation_code.dart';
import '../core/services/supabase_service.dart';
import '../core/theme/app_colors.dart';
import 'pro_ui_kit.dart';

/// Modal dialog allowing Administrators to generate realtime invite codes
/// for Teachers and Parents, and inspect active codes in real time.
class InviteCodeDialog extends StatefulWidget {
  final String initialRole;

  const InviteCodeDialog({super.key, this.initialRole = 'teacher'});

  static Future<void> show(BuildContext context,
      {String initialRole = 'teacher'}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => InviteCodeDialog(initialRole: initialRole),
    );
  }

  @override
  State<InviteCodeDialog> createState() => _InviteCodeDialogState();
}

class _InviteCodeDialogState extends State<InviteCodeDialog> {
  late String _selectedRole;
  late final Stream<List<InvitationCode>> _codesStream;
  final TextEditingController _targetEmailController = TextEditingController();
  bool _isGenerating = false;
  String? _newlyGeneratedCode;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
    _codesStream = SupabaseService.instance.streamInviteCodes();
  }

  @override
  void dispose() {
    _targetEmailController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerateCode() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    final email = _targetEmailController.text.trim();
    final res = await SupabaseService.instance.generateInviteCode(
      role: _selectedRole,
      targetEmail: email.isEmpty ? null : email,
    );

    if (mounted) {
      setState(() {
        _isGenerating = false;
        if (res['success'] == true) {
          _newlyGeneratedCode = res['code'];
          _targetEmailController.clear();
        } else {
          _errorMessage = res['message'] ?? 'Failed to generate code';
        }
      });
    }
  }

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied "$code" to clipboard.'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.of(context).primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);

    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: p.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: p.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          Icon(Icons.vpn_key_rounded, color: p.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generate Invite Code',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: p.ink,
                          ),
                        ),
                        Text(
                          'Realtime Parent & Teacher Signups',
                          style: TextStyle(fontSize: 11.5, color: p.inkSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: p.inkSecondary, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'Select Target Role',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: p.inkSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildRoleTile(
                    p: p,
                    role: 'teacher',
                    label: 'Teacher',
                    icon: Icons.school_rounded,
                    color: p.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildRoleTile(
                    p: p,
                    role: 'parent',
                    label: 'Parent',
                    icon: Icons.family_restroom_rounded,
                    color: p.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _targetEmailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: p.ink, fontSize: 13.5),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Pre-assign to Email (Optional)',
                prefixIcon: Icon(Icons.email_outlined, size: 18),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: p.danger, fontSize: 11.5),
              ),
            ],
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _handleGenerateCode,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.flash_on_rounded, size: 16),
                label: Text(
                  _isGenerating
                      ? 'Generating Code...'
                      : 'Generate ${_selectedRole == 'teacher' ? 'Teacher' : 'Parent'} Code',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _selectedRole == 'teacher' ? p.primary : p.gold,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            if (_newlyGeneratedCode != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.success.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.success.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: p.success, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Code Ready',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: p.success,
                            ),
                          ),
                          SelectableText(
                            _newlyGeneratedCode!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              letterSpacing: 1.2,
                              color: p.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy_rounded, color: p.success, size: 18),
                      onPressed: () => _copyToClipboard(_newlyGeneratedCode!),
                      tooltip: 'Copy Code',
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            Divider(height: 1, color: p.border),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Live Invitation Codes',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                ProStatusPill(
                  label: 'REALTIME',
                  icon: Icons.sync_rounded,
                  color: p.primary,
                ),
              ],
            ),
            const SizedBox(height: 10),

            Expanded(
              child: StreamBuilder<List<InvitationCode>>(
                stream: _codesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.primary,
                      ),
                    );
                  }

                  final codes = snapshot.data ?? [];
                  if (codes.isEmpty) {
                    return Center(
                      child: Text(
                        'No invitation codes generated yet.',
                        style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: codes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = codes[index];
                      final isTeacher = item.role == 'teacher';
                      final roleColor = isTeacher ? p.primary : p.gold;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: p.surfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: item.isUsed
                                ? p.border
                                : roleColor.withOpacity(0.32),
                          ),
                        ),
                        child: Row(
                          children: [
                            ProStatusPill(
                              label: isTeacher ? 'TEACHER' : 'PARENT',
                              color: roleColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.code,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: item.isUsed ? p.inkMuted : p.ink,
                                      decoration: item.isUsed
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  if (item.targetEmail != null)
                                    Text(
                                      item.targetEmail!,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: p.inkSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            ProStatusPill(
                              label: item.isUsed ? 'USED' : 'ACTIVE',
                              color: item.isUsed ? p.inkMuted : p.success,
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              color: p.inkSecondary,
                              onPressed: () => _copyToClipboard(item.code),
                              tooltip: 'Copy Code',
                              visualDensity: VisualDensity.compact,
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

  Widget _buildRoleTile({
    required AppPalette p,
    required String role,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedRole == role;
    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.14) : p.surfaceSubtle,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : p.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: isSelected ? color : p.inkSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? color : p.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
