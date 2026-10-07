import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/auth_session_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/invite_code_dialog.dart';

/// Settings & Profile Tab:
/// 1. Functional Light/Dark theme toggle
/// 2. Role Switcher Preview Hub (switch between Admin, Teacher, and Parent)
/// 3. Admin-only Invite Codes Generator (hidden for Teacher & Parent)
/// 4. User profile and sign out
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  Future<void> _handleSignOut() async {
    await SupabaseService.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;
        final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
        final subtextColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
        final cardBg = isDark ? AppColors.surfaceCard : AppColors.surfaceCardLight;
        final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

        return ValueListenableBuilder<String>(
          valueListenable: AuthSessionService.instance.roleNotifier,
          builder: (context, currentRole, _) {
            final isAdmin = currentRole == 'admin';
            final isTeacher = currentRole == 'teacher';
            final isParent = currentRole == 'parent';

            final fullName = AuthSessionService.instance.userName;
            final userRole = currentRole.toUpperCase();
            final userEmail = AuthSessionService.instance.userEmail;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                // User Account Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: isTeacher
                            ? AppColors.accentTeal
                            : (isParent ? AppColors.accentAmber : const Color(0xFFFF4B72)),
                        child: Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userEmail,
                              style: TextStyle(color: subtextColor, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isTeacher ? AppColors.accentTeal : AppColors.accentAmber).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                userRole,
                                style: TextStyle(
                                  color: isTeacher ? AppColors.accentTeal : AppColors.accentAmber,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // =============================================================
                // ROLE SWITCHER PREVIEW (For Testing & Verifying all 3 views)
                // =============================================================
                Text(
                  'Switch Active Interface (Testing Hub)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: subtextColor),
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select role to test separated Teacher, Parent, or Admin interfaces:',
                        style: TextStyle(fontSize: 11.5, color: subtextColor),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildRoleButton(
                            role: 'admin',
                            label: 'Admin',
                            icon: Icons.shield_rounded,
                            color: const Color(0xFFFF4B72),
                            isSelected: isAdmin,
                            onTap: () => AuthSessionService.instance.setRole('admin'),
                          ),
                          const SizedBox(width: 8),
                          _buildRoleButton(
                            role: 'teacher',
                            label: 'Teacher',
                            icon: Icons.school_rounded,
                            color: AppColors.accentTeal,
                            isSelected: isTeacher,
                            onTap: () => AuthSessionService.instance.setRole('teacher'),
                          ),
                          const SizedBox(width: 8),
                          _buildRoleButton(
                            role: 'parent',
                            label: 'Parent',
                            icon: Icons.family_restroom_rounded,
                            color: AppColors.accentAmber,
                            isSelected: isParent,
                            onTap: () => AuthSessionService.instance.setRole('parent'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Appearance & Theme Mode
                Text(
                  'Appearance & Display',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: subtextColor),
                ),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SwitchListTile(
                    value: !isDark,
                    onChanged: (val) {
                      AppTheme.setThemeMode(val ? ThemeMode.light : ThemeMode.dark);
                    },
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (!isDark ? const Color(0xFFD97706) : AppColors.accentAmber).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        !isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        color: !isDark ? const Color(0xFFD97706) : AppColors.accentAmber,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      'Light Theme Mode',
                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      !isDark ? 'Bright daylight mode active' : 'Midnight dark aesthetic active',
                      style: TextStyle(color: subtextColor, fontSize: 12),
                    ),
                    activeColor: const Color(0xFFD97706),
                  ),
                ),

                const SizedBox(height: 20),

                // =============================================================
                // ADMIN ONLY ACCESS: INVITATION CODES GENERATOR (HIDDEN FOR OTHERS)
                // =============================================================
                if (isAdmin) ...[
                  Text(
                    'Administration & Access Control (Admin Only)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: subtextColor),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invite Codes Generator',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                                  ),
                                  Text(
                                    'Generate realtime signup codes for Teachers and Parents',
                                    style: TextStyle(fontSize: 11.5, color: subtextColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => InviteCodeDialog.show(context),
                            icon: const Icon(Icons.add_rounded, size: 16, color: Colors.black),
                            label: const Text(
                              'Manage & Generate Invite Codes',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentTeal,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Sign Out Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _handleSignOut,
                    icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFFEF4444)),
                    label: const Text(
                      'Sign Out of Account',
                      style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRoleButton({
    required String role,
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: isSelected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.black : color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
