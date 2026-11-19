import 'package:flutter/material.dart';
import '../../core/models/halaqah.dart';
import '../../core/services/halaqah_service.dart';
import '../../core/services/student_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/pro_ui_kit.dart';

/// Flagship Halaqah Management Sheet for Administrators:
/// Create study circles, assign Ustazs, inspect enrollment, and remove circles.
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

  @override
  void initState() {
    super.initState();
    HalaqahService.instance.fetchHalaqahs();
    _fetchTeachers();
  }

  Future<void> _fetchTeachers() async {
    final client = SupabaseService.instance.client;
    if (client == null) return;

    try {
      final res = await client
          .from('profiles')
          .select('id, full_name, phone, email')
          .eq('role', 'teacher');
      if (mounted) {
        setState(() {
          _teachers = List<Map<String, dynamic>>.from(res ?? []);
        });
      }
    } catch (_) {}
  }

  void _showAddHalaqahDialog() {
    final p = AppColors.of(context);
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
            title: Row(
              children: [
                Icon(Icons.add_circle_outline_rounded, color: p.primary),
                const SizedBox(width: 8),
                const Expanded(child: Text('Create Study Circle')),
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
                        child: Text('Unassigned (Assign later)',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                      ..._teachers.map((t) {
                        return DropdownMenuItem<String>(
                          value: t['id']?.toString(),
                          child: Text(
                            '${t['full_name']} (${t['phone'] ?? ''})',
                            style: const TextStyle(fontSize: 12.5),
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
                          selectedTeacherName = match.isNotEmpty
                              ? match.first['full_name']
                              : null;
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
                      hintText:
                          'e.g. Juz Amma memorization and Makharij revision',
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
                          final halaqah =
                              await HalaqahService.instance.createHalaqah(
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
                                content: Text(
                                  isOfflineOnly
                                      ? 'Study Circle "$name" created in offline cache.'
                                      : 'Study Circle "$name" created successfully.',
                                ),
                                backgroundColor:
                                    isOfflineOnly ? p.warning : p.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to create circle: ${SupabaseService.cleanErrorMessage(e)}',
                                ),
                                backgroundColor: p.danger,
                              ),
                            );
                          }
                        } finally {
                          if (ctx.mounted) {
                            setDialogState(() => isCreating = false);
                          }
                        }
                      },
                child: isCreating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
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
    final p = AppColors.of(context);

    return ProBottomSheetShell(
      title: 'Memorization Circles',
      subtitle: 'Configure halaqahs, assign Ustazs & monitor enrollment',
      icon: Icons.menu_book_rounded,
      iconColor: p.primary,
      heightFactor: 0.85,
      trailingAction: ElevatedButton.icon(
        onPressed: _showAddHalaqahDialog,
        icon: const Icon(Icons.add_rounded, size: 15),
        label: const Text('New Circle', style: TextStyle(fontSize: 11.5)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        ),
      ),
      child: ValueListenableBuilder<List<Halaqah>>(
        valueListenable: HalaqahService.instance.halaqahsNotifier,
        builder: (context, halaqahs, _) {
          if (halaqahs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ProEmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'No Study Circles Created Yet',
                  message:
                      'Create your first Halaqah circle to assign teachers and enroll students.',
                  actionLabel: 'Create First Circle',
                  onAction: _showAddHalaqahDialog,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            itemCount: halaqahs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final h = halaqahs[i];
              final studentCount =
                  StudentService.instance.getStudentsForHalaqah(h.name).length;

              return ProCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            h.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                              color: p.ink,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded,
                              size: 19, color: p.danger),
                          tooltip: 'Delete Circle',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Delete Circle?'),
                                content: Text(
                                    'Are you sure you want to remove "${h.name}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(c);
                                      HalaqahService.instance
                                          .deleteHalaqah(h.id);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: p.danger,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ProStatusPill(
                          label: 'Ustaz: ${h.teacherName}',
                          icon: Icons.person_outline_rounded,
                          color: p.primary,
                        ),
                        ProStatusPill(
                          label: '$studentCount Students',
                          icon: Icons.groups_outlined,
                          color: p.gold,
                        ),
                      ],
                    ),
                    if (h.schedule.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 14, color: p.inkMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              h.schedule,
                              style: TextStyle(
                                fontSize: 12,
                                color: p.inkSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (h.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        h.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: p.inkMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
