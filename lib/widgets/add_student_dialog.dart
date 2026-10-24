import 'package:flutter/material.dart';
import '../../core/services/halaqah_service.dart';
import '../../core/services/student_service.dart';
import '../../core/theme/app_colors.dart';
import '../admin/halaqah_management_sheet.dart';

/// Modal dialog for adding and enrolling a new student into a halaqah and linking to parent.
class AddStudentDialog {
  static void show(BuildContext context) {
    final nameCtrl = TextEditingController();

    final halaqahs = HalaqahService.instance.halaqahs;
    String? selectedHalaqahId = halaqahs.isNotEmpty ? halaqahs.first.id : null;
    String selectedHalaqahName = halaqahs.isNotEmpty ? halaqahs.first.name : '';

    final registeredParents = StudentService.instance.getRegisteredParents();
    String? selectedParentId = registeredParents.isNotEmpty ? registeredParents.first['id'] : null;

    int juz = 30;
    int surah = 1;
    int ayah = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final currentHalaqahs = HalaqahService.instance.halaqahs;
          final currentParents = StudentService.instance.getRegisteredParents();

          final bool canSubmit = nameCtrl.text.trim().isNotEmpty &&
              selectedParentId != null &&
              selectedParentId!.isNotEmpty &&
              selectedHalaqahId != null &&
              selectedHalaqahId!.isNotEmpty;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.person_add_rounded, color: Color(0xFFC9F24A)),
                SizedBox(width: 8),
                Text('Add Student & Link Parent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      labelText: 'Student Full Name *',
                      hintText: 'e.g. Abdur-Rahman Muhammed',
                      prefixIcon: Icon(Icons.face_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. DYNAMIC HALAQAH SELECTION
                  if (currentHalaqahs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC9F24A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFC9F24A).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFC9F24A)),
                              SizedBox(width: 6),
                              Text('No Study Circles Created Yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFC9F24A))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text('Please create at least one halaqah first.', style: TextStyle(fontSize: 11)),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              HalaqahManagementSheet.show(context);
                            },
                            icon: const Icon(Icons.add_circle_outline, size: 14),
                            label: const Text('Create Halaqah Now', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: selectedHalaqahId,
                      decoration: const InputDecoration(
                        labelText: 'Assign to Study Circle (Halaqah) *',
                        prefixIcon: Icon(Icons.menu_book_rounded, size: 20),
                      ),
                      items: currentHalaqahs.map((h) {
                        return DropdownMenuItem(
                          value: h.id,
                          child: Text('${h.name} (${h.teacherName})', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedHalaqahId = val;
                          final match = currentHalaqahs.firstWhere((h) => h.id == val, orElse: () => currentHalaqahs.first);
                          selectedHalaqahName = match.name;
                        });
                      },
                    ),

                  const SizedBox(height: 14),

                  // 2. PARENT SELECTION
                  if (currentParents.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
                              SizedBox(width: 6),
                              Text('No Parents Registered Yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber)),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text('Parents can join using invite codes or sign up with parental role.', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: selectedParentId,
                      decoration: const InputDecoration(
                        labelText: 'Select Registered Parent *',
                        prefixIcon: Icon(Icons.family_restroom_rounded, size: 20),
                      ),
                      items: currentParents.map((p) {
                        return DropdownMenuItem(
                          value: p['id'],
                          child: Text('${p['name']} (${p['phone'] ?? p['email'] ?? 'User'})', overflow: TextOverflow.ellipsis),
                        );
                      }).toList>,
                      onChanged: (val) {
                        setDialogState(() => selectedParentId = val);
                      },
                    ),

                  const SizedBox(height: 14),

                  // Initial Memorization Status
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: '$juz',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Juz (1-30)'),
                          onChanged: (v) => juz = int.tryParse(v) ?? 30,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: '$surah',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Surah (1-114)'),
                          onChanged: (v) => surah = int.tryParse(v) ?? 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: canSubmit
                    ? () async {
                        final foundParent = currentParents.firstWhere(
                          (p) => p['id'] == selectedParentId,
                          orElse: () => currentParents.first,
                        );

                        Navigator.pop(ctx);
                        await StudentService.instance.addStudent(
                          fullName: nameCtrl.text.trim(),
                          halaqahName: selectedHalaqahName,
                          halaqahId: selectedHalaqahId,
                          parentId: foundParent['id']!,
                          parentName: foundParent['name']!,
                          parentPhone: foundParent['phone'] ?? '',
                          parentEmail: foundParent['email'],
                          currentJuz: juz,
                          currentSurah: surah,
                          currentAyah: ayah,
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Enrolled "${nameCtrl.text.trim()}" in $selectedHalaqahName!'),
                              backgroundColor: const Color(0xFFC9F24A),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC9F24A),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Enroll Student'),
              ),
            ],
          );
        },
      ),
    );
  }
}
