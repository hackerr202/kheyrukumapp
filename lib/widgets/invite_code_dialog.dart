import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models/invitation_code.dart';
import '../core/services/supabase_service.dart';
import '../core/theme/app_colors.dart';

/// Modal dialog allowing Administrators to generate realtime invite codes
/// for Teachers and Parents, and view active codes in real time.
class InviteCodeDialog extends StatefulWidget {
  const InviteCodeDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const InviteCodeDialog(),
    );
  }

  @override
  State<InviteCodeDialog> createState() => _InviteCodeDialogState();
}

class _InviteCodeDialogState extends State<InviteCodeDialog> {
  String _selectedRole = 'teacher';
  final TextEditingController _targetEmailController = TextEditingController();
  bool _isGenerating = false;
  String? _newlyGeneratedCode;
  String? _errorMessage;

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
        content: Text('Copied "$code" to clipboard!'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.accentTeal,
        behavior: SnackBarBehavior.floating,
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

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: borderColor),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentTeal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.vpn_key_rounded, color: AppColors.accentTeal, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generate Invite Code',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Realtime Parent & Teacher Signups',
                          style: TextStyle(
                            fontSize: 11,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: subtextColor, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Role Selector: Teacher vs Parent
            Text(
              'Select Target Role',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtextColor),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedRole = 'teacher'),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedRole == 'teacher'
                            ? AppColors.accentTeal.withOpacity(0.18)
                            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedRole == 'teacher' ? AppColors.accentTeal : borderColor,
                          width: _selectedRole == 'teacher' ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.school_rounded,
                            size: 16,
                            color: _selectedRole == 'teacher' ? AppColors.accentTeal : subtextColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Teacher (حلقة)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _selectedRole == 'teacher' ? AppColors.accentTeal : textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedRole = 'parent'),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedRole == 'parent'
                            ? AppColors.accentAmber.withOpacity(0.18)
                            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedRole == 'parent' ? AppColors.accentAmber : borderColor,
                          width: _selectedRole == 'parent' ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.family_restroom_rounded,
                            size: 16,
                            color: _selectedRole == 'parent' ? AppColors.accentAmber : subtextColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Parent (ولي أمر)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _selectedRole == 'parent' ? AppColors.accentAmber : textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Optional Target Email
            TextField(
              controller: _targetEmailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: textColor, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Pre-assign to Email (Optional)',
                hintStyle: TextStyle(color: subtextColor, fontSize: 12),
                prefixIcon: Icon(Icons.email_outlined, color: subtextColor, size: 16),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accentTeal),
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFFFF4B72), fontSize: 11),
              ),
            ],

            const SizedBox(height: 12),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _handleGenerateCode,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.flash_on_rounded, size: 16, color: Colors.black),
                label: Text(
                  _isGenerating
                      ? 'Generating Realtime Code...'
                      : 'Generate ${_selectedRole == 'teacher' ? 'Teacher' : 'Parent'} Code',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedRole == 'teacher' ? AppColors.accentTeal : AppColors.accentAmber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            // Newly Generated Code Banner
            if (_newlyGeneratedCode != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentEmerald.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accentEmerald.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.accentEmerald, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active Realtime Code Ready:',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accentEmerald),
                          ),
                          SelectableText(
                            _newlyGeneratedCode!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              letterSpacing: 1.2,
                              color: AppColors.accentEmerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: AppColors.accentEmerald, size: 18),
                      onPressed: () => _copyToClipboard(_newlyGeneratedCode!),
                      tooltip: 'Copy Code',
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            Divider(height: 1, color: borderColor),
            const SizedBox(height: 12),

            // Real-Time Active Codes Feed Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Live Invitation Codes',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentTeal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.sync_rounded, color: AppColors.accentTeal, size: 10),
                      SizedBox(width: 4),
                      Text(
                        'REALTIME',
                        style: TextStyle(
                          color: AppColors.accentTeal,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Real-Time Stream List
            Expanded(
              child: StreamBuilder<List<InvitationCode>>(
                stream: SupabaseService.instance.streamInviteCodes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }

                  final codes = snapshot.data ?? [];
                  if (codes.isEmpty) {
                    return Center(
                      child: Text(
                        'No invitation codes generated yet.',
                        style: TextStyle(fontSize: 12, color: subtextColor),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: codes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = codes[index];
                      final isTeacher = item.role == 'teacher';

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: item.isUsed
                                ? borderColor.withOpacity(0.4)
                                : (isTeacher ? AppColors.accentTeal.withOpacity(0.3) : AppColors.accentAmber.withOpacity(0.3)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isTeacher ? AppColors.accentTeal : AppColors.accentAmber).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isTeacher ? 'TEACHER' : 'PARENT',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isTeacher ? AppColors.accentTeal : AppColors.accentAmber,
                                ),
                              ),
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
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: item.isUsed ? subtextColor : textColor,
                                      decoration: item.isUsed ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  if (item.targetEmail != null)
                                    Text(
                                      item.targetEmail!,
                                      style: TextStyle(fontSize: 10, color: subtextColor),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.isUsed
                                    ? Colors.grey.withOpacity(0.15)
                                    : AppColors.accentEmerald.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.isUsed ? 'USED' : 'ACTIVE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: item.isUsed ? Colors.grey : AppColors.accentEmerald,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              color: subtextColor,
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
}
