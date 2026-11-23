import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/services/halaqah_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/student_service.dart';
import '../core/services/supabase_service.dart';
import '../core/theme/app_colors.dart';
import '../screens/admin/halaqah_management_sheet.dart';
import 'pro_ui_kit.dart';

/// Flagship Dialog for Enrolling Students:
/// - Clean step-by-step layout in Deep Pine & Warm Gold
/// - Requires Student Age as mandatory field
/// - Optional student profile picture upload
/// - Allows selecting an existing parent OR entering parent details (auto-generating an invite code)
/// - Immediately persists to Supabase Cloud and local offline cache
class AddStudentDialog {
  static void show(BuildContext context) {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final parentNameCtrl = TextEditingController();
    final parentPhoneCtrl = TextEditingController();
    final parentEmailCtrl = TextEditingController();

    String? avatarUrl;
    bool isUploadingAvatar = false;

    final halaqahs = HalaqahService.instance.halaqahs;
    String? selectedHalaqahId = halaqahs.isNotEmpty ? halaqahs.first.id : null;
    String selectedHalaqahName =
        halaqahs.isNotEmpty ? halaqahs.first.name : '';

    final registeredParents = StudentService.instance.getRegisteredParents();
    String? selectedParentId =
        registeredParents.isNotEmpty ? registeredParents.first['id'] : null;
    bool createNewParent = registeredParents.isEmpty;

    int juz = 30;
    int surah = 1;
    const int ayah = 1;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final p = AppColors.of(ctx);
          final currentHalaqahs = HalaqahService.instance.halaqahs;
          final currentParents = StudentService.instance.getRegisteredParents();

          final parsedAge = int.tryParse(ageCtrl.text.trim());
          final bool isAgeValid = parsedAge != null && parsedAge > 0 && parsedAge <= 99;

          final bool canSubmit = nameCtrl.text.trim().isNotEmpty &&
              isAgeValid &&
              ((!createNewParent && selectedParentId != null) ||
                  (createNewParent && parentNameCtrl.text.trim().isNotEmpty)) &&
              selectedHalaqahId != null &&
              !isSaving &&
              !isUploadingAvatar;

          return Dialog(
            backgroundColor: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: p.border),
            ),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
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
                                color: p.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.person_add_rounded,
                                color: p.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Enroll New Student',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: p.ink,
                                  ),
                                ),
                                Text(
                                  'Assign to study circle & link parent',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: p.inkSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: Icon(Icons.close_rounded,
                              size: 20, color: p.inkSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Profile Picture (Optional)
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: p.primary.withOpacity(0.12),
                                  border: Border.all(
                                    color: p.gold.withOpacity(0.4),
                                    width: 2,
                                  ),
                                ),
                                child: isUploadingAvatar
                                    ? Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: p.primary,
                                          ),
                                        ),
                                      )
                                    : (avatarUrl != null &&
                                            avatarUrl!.isNotEmpty)
                                        ? ClipOval(
                                            child: ProSignedImage(
                                              mediaRef: avatarUrl!,
                                              width: 72,
                                              height: 72,
                                              fit: BoxFit.cover,
                                              errorWidget: Icon(
                                                Icons.person_rounded,
                                                size: 38,
                                                color: p.primary,
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.person_rounded,
                                            size: 38,
                                            color: p.primary,
                                          ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: isUploadingAvatar
                                      ? null
                                      : () async {
                                          try {
                                            final picker = ImagePicker();
                                            final picked = await picker.pickImage(
                                              source: ImageSource.gallery,
                                              maxWidth: 600,
                                              maxHeight: 600,
                                              imageQuality: 85,
                                            );
                                            if (picked == null) return;
                                            setDialogState(() => isUploadingAvatar = true);
                                            final bytes = await picked.readAsBytes();
                                            final ext = picked.name.split('.').last;
                                            final uploaded = await StorageService.uploadAvatar(
                                              userIdOrName: nameCtrl.text.trim().isNotEmpty
                                                  ? nameCtrl.text.trim()
                                                  : 'student',
                                              bytes: bytes,
                                              extension: ext.isNotEmpty ? ext : 'jpg',
                                            );
                                            if (ctx.mounted) {
                                              setDialogState(() {
                                                avatarUrl = uploaded;
                                                isUploadingAvatar = false;
                                              });
                                            }
                                          } catch (e) {
                                            debugPrint('[AddStudentDialog] Avatar upload error: $e');
                                            if (ctx.mounted) {
                                              setDialogState(() => isUploadingAvatar = false);
                                            }
                                          }
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: p.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: p.surface, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Photo (Optional)',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: p.inkSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'STUDENT FULL NAME *',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: p.inkMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      style: TextStyle(fontSize: 14, color: p.ink),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Abdur-Rahman Muhammed',
                        prefixIcon: Icon(Icons.face_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'STUDENT AGE (YEARS) *',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: p.inkMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: ageCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                      style: TextStyle(fontSize: 14, color: p.ink),
                      decoration: InputDecoration(
                        hintText: 'e.g. 9',
                        prefixIcon: const Icon(Icons.cake, size: 20),
                        suffixText: isAgeValid ? '✓ Valid' : null,
                        suffixStyle: TextStyle(
                          color: p.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'ASSIGNED STUDY CIRCLE (HALAQAH) *',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: p.inkMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (currentHalaqahs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: p.primary.withOpacity(0.28)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 18, color: p.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No halaqahs yet. Create one first.',
                                style: TextStyle(fontSize: 12, color: p.ink),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                HalaqahManagementSheet.show(context);
                              },
                              child: const Text('Create'),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: selectedHalaqahId,
                        dropdownColor: p.surface,
                        style: TextStyle(fontSize: 13.5, color: p.ink),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.menu_book_rounded, size: 20),
                        ),
                        items: currentHalaqahs.map((h) {
                          return DropdownMenuItem(
                            value: h.id,
                            child: Text(
                              '${h.name} (${h.teacherName})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedHalaqahId = val;
                            final match = currentHalaqahs.firstWhere(
                              (h) => h.id == val,
                              orElse: () => currentHalaqahs.first,
                            );
                            selectedHalaqahName = match.name;
                          });
                        },
                      ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PARENT LINKAGE *',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: p.inkMuted,
                            letterSpacing: 0.6,
                          ),
                        ),
                        if (currentParents.isNotEmpty)
                          InkWell(
                            onTap: () => setDialogState(
                              () => createNewParent = !createNewParent,
                            ),
                            child: Text(
                              createNewParent
                                  ? 'Select Existing Parent'
                                  : '+ Enter Parent Info',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: p.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    if (!createNewParent && currentParents.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: selectedParentId,
                        dropdownColor: p.surface,
                        style: TextStyle(fontSize: 13.5, color: p.ink),
                        decoration: const InputDecoration(
                          prefixIcon:
                              Icon(Icons.family_restroom_rounded, size: 20),
                        ),
                        items: currentParents.map((parent) {
                          return DropdownMenuItem(
                            value: parent['id'],
                            child: Text(
                              '${parent['name']} (${parent['phone'] ?? parent['email'] ?? 'Parent'})',
                              overflow: TextOverflow.ellipsis,
                            ),
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
                        style: TextStyle(fontSize: 13.5, color: p.ink),
                        decoration: const InputDecoration(
                          hintText:
                              'Parent Full Name (e.g. Abu Abdur-Rahman)',
                          prefixIcon:
                              Icon(Icons.person_outline_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: parentPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(fontSize: 13.5, color: p.ink),
                        decoration: const InputDecoration(
                          hintText: 'Parent Phone Number',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    Text(
                      'STARTING MEMORIZATION MILESTONE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: p.inkMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: '$juz',
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: 13.5, color: p.ink),
                            decoration:
                                const InputDecoration(labelText: 'Juz (1-30)'),
                            onChanged: (v) => juz = int.tryParse(v) ?? 30,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            initialValue: '$surah',
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: 13.5, color: p.ink),
                            decoration: const InputDecoration(
                                labelText: 'Surah (1-114)'),
                            onChanged: (v) => surah = int.tryParse(v) ?? 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: (canSubmit && !isSaving)
                                ? () async {
                                    setDialogState(() => isSaving = true);
                                    try {
                                      String finalParentId = '';
                                      String finalParentName =
                                          parentNameCtrl.text.trim();
                                      String finalParentPhone =
                                          parentPhoneCtrl.text.trim();

                                      if (!createNewParent &&
                                          currentParents.isNotEmpty &&
                                          selectedParentId != null) {
                                        final found =
                                            currentParents.firstWhere(
                                          (parent) =>
                                              parent['id'] == selectedParentId,
                                          orElse: () => currentParents.first,
                                        );
                                        finalParentId = found['id'] ?? '';
                                        finalParentName = found['name'] ?? '';
                                        finalParentPhone = found['phone'] ?? '';
                                      }

                                      final student = await StudentService
                                          .instance
                                          .addStudent(
                                        fullName: nameCtrl.text.trim(),
                                        age: parsedAge ?? 8,
                                        avatarUrl: avatarUrl,
                                        halaqahName: selectedHalaqahName,
                                        halaqahId: selectedHalaqahId,
                                        parentId: finalParentId,
                                        parentName: finalParentName.isNotEmpty
                                            ? finalParentName
                                            : 'Parent',
                                        parentPhone: finalParentPhone,
                                        parentEmail:
                                            parentEmailCtrl.text.trim(),
                                        currentJuz: juz,
                                        currentSurah: surah,
                                        currentAyah: ayah,
                                      );

                                      if (createNewParent &&
                                          student.id.isNotEmpty &&
                                          !student.id.startsWith('stu-')) {
                                        try {
                                          await SupabaseService.instance
                                              .generateInviteCode(
                                            role: 'parent',
                                            targetEmail: parentEmailCtrl.text
                                                    .trim()
                                                    .isNotEmpty
                                                ? parentEmailCtrl.text.trim()
                                                : null,
                                            linkedStudentId: student.id,
                                          );
                                        } catch (e) {
                                          debugPrint(
                                            '[AddStudentDialog] Invite code notice: $e',
                                          );
                                        }
                                      }

                                      if (ctx.mounted) {
                                        Navigator.of(ctx).pop();
                                        final isOfflineOnly =
                                            student.id.startsWith('stu-');
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isOfflineOnly
                                                  ? 'Student "${student.fullName}" saved locally (will sync when connected).'
                                                  : 'Student "${student.fullName}" enrolled successfully.',
                                            ),
                                            backgroundColor: isOfflineOnly
                                                ? p.warning
                                                : p.success,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Enrollment failed: ${SupabaseService.cleanErrorMessage(e)}',
                                            ),
                                            backgroundColor: p.danger,
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(() => isSaving = false);
                                      }
                                    }
                                  }
                                : null,
                            child: isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Enroll & Save Student'),
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
