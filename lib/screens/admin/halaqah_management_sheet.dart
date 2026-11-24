import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
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
    } catch (e) {
      debugPrint('[HalaqahManagementSheet] fetch teachers error: $e');
    }
  }

  void _showAddHalaqahDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => _AddHalaqahDialog(
        teachers: _teachers,
        hostMessenger: ScaffoldMessenger.of(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    return ProBottomSheetShell(
      title: loc.studyCircles,
      subtitle: loc.manageCircles,
      icon: Icons.menu_book_rounded,
      iconColor: p.primary,
      heightFactor: 0.85,
      trailingAction: ElevatedButton.icon(
        onPressed: _showAddHalaqahDialog,
        icon: const Icon(Icons.add_rounded, size: 15),
        label: Text(loc.create, style: const TextStyle(fontSize: 11.5)),
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
                  title: loc.translate('noCirclesCreatedTitle'),
                  message: loc.translate('createFirstCircleDesc'),
                  actionLabel: loc.translate('createFirstCircleAction'),
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
                          tooltip: loc.translate('deleteCircleTooltip'),
                          onPressed: () {
                            final messenger = ScaffoldMessenger.of(context);
                            showDialog(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: Text(
                                    loc.translate('deleteCircleConfirmTitle')),
                                content: Text(
                                  loc.tr('deleteCircleConfirmBody', {
                                    'name': h.name,
                                  }),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c),
                                    child: Text(loc.cancel),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(c);
                                      try {
                                        await HalaqahService.instance
                                            .deleteHalaqah(h.id);
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              loc.tr('removedCircleMsg', {
                                                'name': h.name,
                                              }),
                                            ),
                                            backgroundColor: p.success,
                                          ),
                                        );
                                      } catch (e) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              loc.tr(
                                                  'couldNotDeleteCircleMsg', {
                                                'error': SupabaseService
                                                    .cleanErrorMessage(e),
                                              }),
                                            ),
                                            backgroundColor: p.danger,
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: p.danger,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Text(loc.delete),
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
                          label: loc.tr('ustazNameLabel', {
                            'name': h.teacherName,
                          }),
                          icon: Icons.person_outline_rounded,
                          color: p.primary,
                        ),
                        ProStatusPill(
                          label: loc.tr('studentsBadgeLabel', {
                            'count': '$studentCount',
                          }),
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

class _AddHalaqahDialog extends StatefulWidget {
  final List<Map<String, dynamic>> teachers;
  final ScaffoldMessengerState hostMessenger;

  const _AddHalaqahDialog({
    required this.teachers,
    required this.hostMessenger,
  });

  @override
  State<_AddHalaqahDialog> createState() => _AddHalaqahDialogState();
}

class _AddHalaqahDialogState extends State<_AddHalaqahDialog> {
  final _nameCtrl = TextEditingController();
  final _scheduleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selectedTeacherId;
  String? _selectedTeacherName;
  bool _isCreating = false;
  bool _didInitLocalizedDefaults = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitLocalizedDefaults) {
      _didInitLocalizedDefaults = true;
      _scheduleCtrl.text =
          AppLocalizations.of(context).translate('defaultCircleSchedule');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _scheduleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final name = _nameCtrl.text.trim();
    setState(() => _isCreating = true);
    try {
      await HalaqahService.instance.createHalaqah(
        name: name,
        teacherId: _selectedTeacherId,
        teacherName: _selectedTeacherName,
        schedule: _scheduleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.hostMessenger.showSnackBar(
        SnackBar(
          content: Text(loc.tr('circleCreatedSuccessMsg', {'name': name})),
          backgroundColor: p.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
      }
      widget.hostMessenger.showSnackBar(
        SnackBar(
          content: Text(
            loc.tr('failedCreateCircleMsg', {
              'error': SupabaseService.cleanErrorMessage(e),
            }),
          ),
          backgroundColor: p.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_circle_outline_rounded, color: p.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(loc.translate('createStudyCircleTitle'))),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: loc.translate('halaqahNameReqLabel'),
                hintText: loc.translate('halaqahNameHint'),
                prefixIcon: const Icon(Icons.school_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedTeacherId,
              isExpanded: true,
              hint: Text(loc.translate('assignTeacherOptionalHint')),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    loc.translate('unassignedAssignLater'),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
                ...widget.teachers.map((t) {
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
                setState(() {
                  _selectedTeacherId = val;
                  if (val != null) {
                    final match = widget.teachers.where((t) => t['id'] == val);
                    _selectedTeacherName = match.isNotEmpty
                        ? match.first['full_name']?.toString()
                        : null;
                  } else {
                    _selectedTeacherName = null;
                  }
                });
              },
              decoration: InputDecoration(
                labelText: loc.translate('assignedUstazTitle'),
                prefixIcon: const Icon(Icons.person_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _scheduleCtrl,
              decoration: InputDecoration(
                labelText: loc.translate('scheduleFieldLabel'),
                hintText: loc.translate('scheduleHint'),
                prefixIcon: const Icon(Icons.access_time_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: loc.translate('curriculumFocusLabel'),
                hintText: loc.translate('curriculumFocusHint'),
                prefixIcon: const Icon(Icons.menu_book_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: Text(loc.cancel),
        ),
        ElevatedButton(
          onPressed:
              (_isCreating || _nameCtrl.text.trim().isEmpty) ? null : _submit,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(loc.translate('createCircleAction')),
        ),
      ],
    );
  }
}
