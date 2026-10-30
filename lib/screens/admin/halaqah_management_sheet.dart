import 'package:flutter/material.dart';
import '../../core/models/halaqah.dart';
import '../../core/services/halaqah_service.dart';
import '../../core/services/student_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';

/// Interactive Halaqah Management Sheet for Admin:
/// Allows adding new halaqahs, assigning teachers, and managing circles.
class HalaqahManagementSheet extends StatefulWidget {
  const HalaqahManagementSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const HalaqahManagementSheet(),
    );
  }

  @override
  State<HalaqahManagementSheet> createState() => _HalaqahManagementSheetState();
}

class _HalaqahManagementSheetState extends State<HalaqahManagementSheet> {
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoadingTeachers = false;

  @override
  void initState() {
    super.initState();
    HalaqahService.instance.fetchHalaqahs();
    _fetchTeachers();
  }

  Future<void> _fetchTeachers() async {
    final client = SupabaseService.instance.client;
    if (client == null) return;

    setState(() => _isLoadingTeachers = true);
    try {
      final res = await client
          .from('profiles')
          .select('id, full_name, phone, email')
          .eq('role', 'teacher');
      if (mounted) {
        setState(() {
          _teachers = List<Map<String, dynamic>>.from(res ?? []);
          _isLoadingTeachers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTeachers = false);
    }
  }

  void _showAddHalaqahDialog() {
    final nameCtrl = TextEditingController();
    final scheduleCtrl = TextEditingController(text: 'Daily Recitation Session');
    final descCtrl = TextEditingController();
    String? selectedTeacherId;
    String? selectedTeacherName;
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.add_circle_outline_rounded, color: AppColors.accentEmerald),
                SizedBox(width: 8),
                Text('Create New Study Circle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Halaqah Name *',
                      hintText: 'e.g. Halaqah Bilal (حلقة بلال)',
                      prefixIcon: Icon(Icons.school_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: selectedTeacherId,
                    hint: const Text('Assign Teacher (Optional)'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Unassigned (Assign later)', style: TextStyle(fontSize: 12)),
                      ),
                      ..._teachers.map((t) {
                        return DropdownMenuItem<String>(
                          value: t['id']?.toString(),
                          child: Text(
                            '${t['full_name']} (${t['phone'] ?? ''})',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedTeacherId = val;
                        if (val != null) {
                          final match = _teachers.where((t) => t['id'] == val);
                          selectedTeacherName = match.isNotEmpty ? match.first['full_name'] : null;
                        } else {
                          selectedTeacherName = null;
                        }
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Assigned Ustaz',
                      prefixIcon: Icon(Icons.person_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: scheduleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Schedule',
                      hintText: 'e.g. Mon-Fri 4:00 PM - 6:00 PM',
                      prefixIcon: Icon(Icons.access_time_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Circle Notes / Curriculum Focus',
                      hintText: 'e.g. Juz Amma memorization and Makharij revision',
                      prefixIcon: Icon(Icons.menu_book_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isCreating ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: (isCreating || nameCtrl.text.trim().isEmpty)
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        setDialogState(() => isCreating = true);
                        try {
                          final halaqah = await HalaqahService.instance.createHalaqah(
                            name: name,
                            teacherId: selectedTeacherId,
                            teacherName: selectedTeacherName,
                            schedule: scheduleCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                          );

                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                          if (mounted) {
                            final isOfflineOnly = halaqah.id.startsWith('hal-');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isOfflineOnly
                                    ? 'Study Circle "$name" created in offline cache.'
                                    : 'Study Circle "$name" created successfully.'),
                                backgroundColor: isOfflineOnly ? const Color(0xFFF59E0B) : AppColors.accentEmerald,
                              ),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to create circle: ${SupabaseService.cleanErrorMessage(e)}'),
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
                          }
                        } finally {
                          if (ctx.mounted) {
                            setDialogState(() => isCreating = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentEmerald,
                  foregroundColor: Colors.black,
                ),
                child: isCreating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Create Circle'),
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
    final sheetBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtextColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentEmerald.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: AppColors.accentEmerald, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Memorization Circles',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddHalaqahDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('New Circle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentEmerald,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Create and configure active halaqahs, assign ustazs, and monitor enrollment.',
            style: TextStyle(fontSize: 12, color: subtextColor),
          ),
          const SizedBox(height: 14),

          Expanded(
            child: ValueListenableBuilder<List<Halaqah>>(
              valueListenable: HalaqahService.instance.halaqahsNotifier,
              builder: (context, halaqahs, _) {
                if (halaqahs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book_outlined, size: 48, color: subtextColor.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          Text(
                            'No Study Circles Created Yet',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap "New Circle" above to add your first Halaqah.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: subtextColor),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: halaqahs.length,
                  itemBuilder: (ctx, i) {
                    final h = halaqahs[i];
                    final studentCount = StudentService.instance.getStudentsForHalaqah(h.name).length;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  h.name,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                tooltip: 'Delete Circle',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Delete Circle?'),
                                      content: Text('Are you sure you want to remove "${h.name}"?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(c);
                                            HalaqahService.instance.deleteHalaqah(h.id);
                                          },
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.accentTeal.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Ustaz: ${h.teacherName}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentTeal),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.accentEmerald.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$studentCount Students',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentEmerald),
                                ),
                              ),
                            ],
                          ),
                          if (h.schedule.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Schedule: ${h.schedule}', style: TextStyle(fontSize: 11.5, color: subtextColor)),
                          ],
                          if (h.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(h.description, style: TextStyle(fontSize: 11, color: subtextColor.withOpacity(0.85))),
                          ],
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
