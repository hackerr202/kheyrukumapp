import 'package:flutter/material.dart';
import '../core/services/halaqah_service.dart';
import '../core/services/student_service.dart';
import '../screens/admin/halaqah_management_sheet.dart';

/// Redesigned Modern, Spacious Dialog for Enrolling Students
/// - Clean step-by-step layout with lime accents
/// - Allows selecting existing parent OR instantly entering parent details
/// - Immediately saves student to both local persistent storage and Supabase cloud
class AddStudentDialog {
  static void show(BuildContext context) {
    final nameCtrl = TextEditingController();
    final parentNameCtrl = TextEditingController();
    final parentPhoneCtrl = TextEditingController();
    final parentEmailCtrl = TextEditingController();

    final halaqahs = HalaqahService.instance.halaqahs;
    String? selectedHalaqahId = halaqahs.isNotEmpty ? halaqahs.first.id : null;
    String selectedHalaqahName = halaqahs.isNotEmpty ? halaqahs.first.name : '';

    final registeredParents = StudentService.instance.getRegisteredParents();
    String? selectedParentId = registeredParents.isNotEmpty ? registeredParents.first['id'] : null;
    bool createNewParent = registeredParents.isEmpty;

    int juz = 30;
    int surah = 1;
    int ayah = 1;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
          final fieldBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
          final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
          final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
          final subtleBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
          const limeGreen = Color(0xFFC9F24A);

          final currentHalaqahs = HalaqahService.instance.halaqahs;
          final currentParents = StudentService.instance.getRegisteredParents();

          final bool canSubmit = nameCtrl.text.trim().isNotEmpty &&
              ((!createNewParent && selectedParentId != null) ||
                  (createNewParent && parentNameCtrl.text.trim().isNotEmpty)) &&
              selectedHalaqahId != null &&
              !isSaving;

          return Dialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: limeGreen.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person_add_rounded, color: limeGreen, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Enroll New Student',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  'Assign to study circle & link parent',
                                  style: TextStyle(fontSize: 11.5, color: subtextColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: Icon(Icons.close_rounded, size: 20, color: subtextColor),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Student Name
                    Text(
                      'STUDENT FULL NAME *',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtextColor, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      style: TextStyle(fontSize: 14, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'e.g. Abdur-Rahman Muhammed',
                        prefixIcon: const Icon(Icons.face_rounded, size: 20),
                        filled: true,
                        fillColor: fieldBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: subtleBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: subtleBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: limeGreen, width: 1.5)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Halaqah Selection
                    Text(
                      'ASSIGNED STUDY CIRCLE (HALAQAH) *',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtextColor, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    if (currentHalaqahs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: limeGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: limeGreen.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 18, color: limeGreen),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('No halaqahs yet. Create one first.', style: TextStyle(fontSize: 12, color: textColor)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                HalaqahManagementSheet.show(context);
                              },
                              child: const Text('Create', style: TextStyle(color: limeGreen, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: selectedHalaqahId,
                        dropdownColor: cardBg,
                        style: TextStyle(fontSize: 13.5, color: textColor),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.menu_book_rounded, size: 20),
                          filled: true,
                          fillColor: fieldBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: subtleBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: subtleBorder)),
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

                    const SizedBox(height: 16),

                    // Parent Selection / Creation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PARENT LINKAGE *',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtextColor, letterSpacing: 0.5),
                        ),
                        if (currentParents.isNotEmpty)
                          InkWell(
                            onTap: () => setDialogState(() => createNewParent = !createNewParent),
                            child: Text(
                              createNewParent ? 'Select Existing Parent' : '+ Enter Parent Info',
                              style: const TextStyle(fontSize: 11, color: limeGreen, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    if (!createNewParent && currentParents.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: selectedParentId,
                        dropdownColor: cardBg,
                        style: TextStyle(fontSize: 13.5, color: textColor),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.family_restroom_rounded, size: 20),
                          filled: true,
                          fillColor: fieldBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: subtleBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: subtleBorder)),
                        ),
                        items: currentParents.map((p) {
                          return DropdownMenuItem(
                            value: p['id'],
                            child: Text('${p['name']} (${p['phone'] ?? p['email'] ?? 'Parent'})', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() => selectedParentId = val);
                        },
                      )
                    else ...[
                      TextField(
                        controller: parentNameCtrl,
                        onChanged: (_) => setDialogState(() {}),
                        style: TextStyle(fontSize: 13.5, color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Parent Full Name (e.g. Abu Abdur-Rahman)',
                          prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                          filled: true,
                          fillColor: fieldBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: subtleBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: subtleBorder)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: parentPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(fontSize: 13.5, color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Parent Phone Number',
                          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                          filled: true,
                          fillColor: fieldBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: subtleBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: subtleBorder)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Memorization Progress
                    Text(
                      'STARTING MEMORIZATION MILESTONE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtextColor, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: '$juz',
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: 13, color: textColor),
                            decoration: InputDecoration(
                              labelText: 'Juz (1-30)',
                              filled: true,
                              fillColor: fieldBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: subtleBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: subtleBorder)),
                            ),
                            onChanged: (v) => juz = int.tryParse(v) ?? 30,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: '$surah',
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: 13, color: textColor),
                            decoration: InputDecoration(
                              labelText: 'Surah (1-114)',
                              filled: true,
                              fillColor: fieldBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: subtleBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: subtleBorder)),
                            ),
                            onChanged: (v) => surah = int.tryParse(v) ?? 1,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: subtleBorder),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Cancel', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: canSubmit
                                ? () async {
                                    setDialogState(() => isSaving = true);
                                    String finalParentId = selectedParentId ?? 'par-${DateTime.now().millisecondsSinceEpoch}';
                                    String finalParentName = parentNameCtrl.text.trim();
                                    String finalParentPhone = parentPhoneCtrl.text.trim();

                                    if (!createNewParent && currentParents.isNotEmpty) {
                                      final found = currentParents.firstWhere(
                                        (p) => p['id'] == selectedParentId,
                                        orElse: () => currentParents.first,
                                      );
                                      finalParentId = found['id']!;
                                      finalParentName = found['name']!;
                                      finalParentPhone = found['phone'] ?? '';
                                    }

                                    final student = await StudentService.instance.addStudent(
                                      fullName: nameCtrl.text.trim(),
                                      halaqahName: selectedHalaqahName,
                                      halaqahId: selectedHalaqahId,
                                      parentId: finalParentId,
                                      parentName: finalParentName.isNotEmpty ? finalParentName : 'Parent',
                                      parentPhone: finalParentPhone,
                                      parentEmail: parentEmailCtrl.text.trim(),
                                      currentJuz: juz,
                                      currentSurah: surah,
                                      currentAyah: ayah,
                                    );

                                    if (ctx.mounted) {
                                      Navigator.of(ctx).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Student "${student.fullName}" enrolled & saved successfully! 🎓'),
                                          backgroundColor: limeGreen,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: limeGreen,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isSaving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : const Text('Enroll & Save Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
