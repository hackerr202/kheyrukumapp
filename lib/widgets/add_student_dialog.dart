import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/localization/app_localizations.dart';
import '../core/models/student.dart';
import '../core/services/halaqah_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/student_service.dart';
import '../core/services/supabase_service.dart';
import '../core/theme/app_colors.dart';
import '../screens/admin/halaqah_management_sheet.dart';
import 'pro_ui_kit.dart';

/// Flagship Stateful Dialog for Enrolling & Editing Students with full controller disposal.
class AddStudentDialog extends StatefulWidget {
  final ScaffoldMessengerState? hostMessenger;
  final BuildContext? hostContext;
  final Student? existingStudent;

  const AddStudentDialog({
    super.key,
    this.hostMessenger,
    this.hostContext,
    this.existingStudent,
  });

  static Future<void> show(
    BuildContext context, {
    Student? existingStudent,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AddStudentDialog(
        hostMessenger: ScaffoldMessenger.of(context),
        hostContext: Navigator.of(context).context,
        existingStudent: existingStudent,
      ),
    );
  }

  @override
  State<AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<AddStudentDialog> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _parentNameCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();
  final _parentEmailCtrl = TextEditingController();

  String? _gender; // 'male', 'female', or null
  String? _avatarUrl;
  bool _isUploadingAvatar = false;
  String? _selectedHalaqahId;
  String _selectedHalaqahName = '';
  String? _selectedParentId;
  bool _createNewParent = true;
  int _juz = 30;
  int _surah = 1;
  static const int _ayah = 1;
  bool _isSaving = false;

  bool get _isEditing => widget.existingStudent != null;

  @override
  void initState() {
    super.initState();
    final halaqahs = HalaqahService.instance.halaqahs;
    final existing = widget.existingStudent;
    if (existing != null) {
      _nameCtrl.text = existing.fullName;
      _ageCtrl.text = '${existing.age}';
      _gender = Student.normalizeGender(existing.gender);
      _avatarUrl = existing.avatarUrl;
      _juz = existing.currentJuz;
      _surah = existing.currentSurah;
      if (existing.halaqahId != null &&
          halaqahs.any((h) => h.id == existing.halaqahId)) {
        _selectedHalaqahId = existing.halaqahId;
        _selectedHalaqahName = existing.halaqahName;
      } else if (halaqahs.isNotEmpty) {
        final match = halaqahs.where(
          (h) => h.name.toLowerCase() == existing.halaqahName.toLowerCase(),
        );
        final resolved = match.isNotEmpty ? match.first : halaqahs.first;
        _selectedHalaqahId = resolved.id;
        _selectedHalaqahName = resolved.name;
      } else {
        _selectedHalaqahName = existing.halaqahName;
      }
      _createNewParent = false;
      return;
    }

    if (halaqahs.isNotEmpty) {
      _selectedHalaqahId = halaqahs.first.id;
      _selectedHalaqahName = halaqahs.first.name;
    }
    final registeredParents = StudentService.instance.getRegisteredParents();
    if (registeredParents.isNotEmpty) {
      _selectedParentId = registeredParents.first['id'];
      _createNewParent = false;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _parentNameCtrl.dispose();
    _parentPhoneCtrl.dispose();
    _parentEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (!mounted || picked == null) return;
      setState(() => _isUploadingAvatar = true);
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last;
      final uploaded = await StorageService.uploadAvatar(
        userIdOrName:
            _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'student',
        bytes: bytes,
        extension: ext.isNotEmpty ? ext : 'jpg',
      );
      if (!mounted) return;
      setState(() {
        _avatarUrl = uploaded;
        _isUploadingAvatar = false;
      });
    } catch (e) {
      debugPrint('[AddStudentDialog] Avatar upload error: $e');
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _submit(int? parsedAge) async {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final messenger = widget.hostMessenger ?? ScaffoldMessenger.of(context);
    final currentParents = StudentService.instance.getRegisteredParents();
    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        final updated = await StudentService.instance.updateStudent(
          existing: widget.existingStudent!,
          fullName: _nameCtrl.text.trim(),
          age: parsedAge ?? widget.existingStudent!.age,
          gender: _gender,
          avatarUrl: _avatarUrl,
          halaqahName: _selectedHalaqahName,
          halaqahId: _selectedHalaqahId,
          currentJuz: _juz,
          currentSurah: _surah,
          currentAyah: widget.existingStudent!.currentAyah,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              loc.tr('studentUpdatedMsg', {'name': updated.fullName}),
            ),
            backgroundColor: p.success,
          ),
        );
        return;
      }

      String finalParentId = '';
      String finalParentName = _parentNameCtrl.text.trim();
      String finalParentPhone = _parentPhoneCtrl.text.trim();

      if (!_createNewParent &&
          currentParents.isNotEmpty &&
          _selectedParentId != null) {
        final found = currentParents.firstWhere(
          (parent) => parent['id'] == _selectedParentId,
          orElse: () => currentParents.first,
        );
        finalParentId = found['id'] ?? '';
        finalParentName = found['name'] ?? '';
        finalParentPhone = found['phone'] ?? '';
      }

      final student = await StudentService.instance.addStudent(
        fullName: _nameCtrl.text.trim(),
        age: parsedAge ?? 8,
        gender: _gender,
        avatarUrl: _avatarUrl,
        halaqahName: _selectedHalaqahName,
        halaqahId: _selectedHalaqahId,
        parentId: finalParentId,
        parentName: finalParentName.isNotEmpty ? finalParentName : loc.roleParent,
        parentPhone: finalParentPhone,
        parentEmail: _parentEmailCtrl.text.trim(),
        currentJuz: _juz,
        currentSurah: _surah,
        currentAyah: _ayah,
      );

      if (_createNewParent &&
          student.id.isNotEmpty &&
          !student.id.startsWith('stu-')) {
        try {
          await SupabaseService.instance.generateInviteCode(
            role: 'parent',
            targetEmail: _parentEmailCtrl.text.trim().isNotEmpty
                ? _parentEmailCtrl.text.trim()
                : null,
            linkedStudentId: student.id,
          );
        } catch (e) {
          debugPrint('[AddStudentDialog] Invite code notice: $e');
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            loc.tr('studentEnrolledMsg', {'name': student.fullName}),
          ),
          backgroundColor: p.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            loc.tr(
              _isEditing ? 'updateFailedMsg' : 'enrollmentFailedMsg',
              {'error': SupabaseService.cleanErrorMessage(e)},
            ),
          ),
          backgroundColor: p.danger,
        ),
      );
    }
  }

  Widget _buildGenderOption(
    AppPalette p, {
    required String value,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _gender == value;
    final Color activeColor = value == 'male' ? p.primary : p.gold;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _gender = isSelected ? null : value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
          decoration: BoxDecoration(
            color:
                isSelected ? activeColor.withOpacity(0.13) : p.surfaceSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? activeColor : p.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? activeColor : p.inkSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? activeColor : p.inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final currentHalaqahs = HalaqahService.instance.halaqahs;
    final currentParents = StudentService.instance.getRegisteredParents();

    final parsedAge = int.tryParse(_ageCtrl.text.trim());
    final bool isAgeValid =
        parsedAge != null && parsedAge > 0 && parsedAge <= 99;

    final bool hasValidParent = _isEditing ||
        (!_createNewParent && _selectedParentId != null) ||
        (_createNewParent && _parentNameCtrl.text.trim().isNotEmpty);

    final bool canSubmit = _nameCtrl.text.trim().isNotEmpty &&
        isAgeValid &&
        hasValidParent &&
        (_selectedHalaqahId != null || _isEditing) &&
        !_isSaving &&
        !_isUploadingAvatar;

    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: p.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                          _isEditing
                              ? Icons.edit_rounded
                              : Icons.person_add_rounded,
                          color: p.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing ? loc.editStudent : loc.enrollStudent,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: p.ink,
                              ),
                            ),
                            Text(
                              _isEditing
                                  ? widget.existingStudent!.fullName
                                  : loc.parentLinkage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: p.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
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
                          child: _isUploadingAvatar
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
                              : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                  ? ClipOval(
                                      child: ProSignedImage(
                                        mediaRef: _avatarUrl!,
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
                        PositionedDirectional(
                          bottom: 0,
                          end: 0,
                          child: InkWell(
                            onTap: _isUploadingAvatar ? null : _pickAvatar,
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
                      loc.studentPhoto,
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
                loc.studentFullName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: p.inkMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameCtrl,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 14, color: p.ink),
                decoration: InputDecoration(
                  hintText: loc.studentFullName,
                  prefixIcon: const Icon(Icons.face_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                loc.studentAge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: p.inkMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 14, color: p.ink),
                decoration: InputDecoration(
                  hintText: '9',
                  prefixIcon: const Icon(Icons.cake, size: 20),
                  suffixText: isAgeValid ? '✓' : null,
                  suffixStyle: TextStyle(
                    color: p.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                loc.studentGender,
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
                  _buildGenderOption(
                    p,
                    value: 'male',
                    label: loc.male,
                    icon: Icons.male_rounded,
                  ),
                  const SizedBox(width: 10),
                  _buildGenderOption(
                    p,
                    value: 'female',
                    label: loc.female,
                    icon: Icons.female_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                loc.assignedCircle,
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
                    border: Border.all(color: p.primary.withOpacity(0.28)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: p.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc.translate('noHalaqahsYetMsg'),
                          style: TextStyle(fontSize: 12, color: p.ink),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final hostCtx = widget.hostContext ??
                              Navigator.of(context).context;
                          Navigator.of(context).pop();
                          HalaqahManagementSheet.show(hostCtx);
                        },
                        child: Text(loc.create),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedHalaqahId,
                  isExpanded: true,
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
                    setState(() {
                      _selectedHalaqahId = val;
                      final match = currentHalaqahs.firstWhere(
                        (h) => h.id == val,
                        orElse: () => currentHalaqahs.first,
                      );
                      _selectedHalaqahName = match.name;
                    });
                  },
                ),
              const SizedBox(height: 16),

              if (!_isEditing) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        loc.parentLinkage,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: p.inkMuted,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    if (currentParents.isNotEmpty)
                      InkWell(
                        onTap: () =>
                            setState(() => _createNewParent = !_createNewParent),
                        child: Text(
                          _createNewParent
                              ? loc.parentsTab
                              : '+ ${loc.create}',
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

                if (!_createNewParent && currentParents.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedParentId,
                    isExpanded: true,
                    dropdownColor: p.surface,
                    style: TextStyle(fontSize: 13.5, color: p.ink),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.family_restroom_rounded, size: 20),
                    ),
                    items: currentParents.map((parent) {
                      return DropdownMenuItem(
                        value: parent['id'],
                        child: Text(
                          '${parent['name']} (${parent['phone'] ?? parent['email'] ?? loc.roleParent})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedParentId = val);
                    },
                  )
                else ...[
                  TextField(
                    controller: _parentNameCtrl,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 13.5, color: p.ink),
                    decoration: InputDecoration(
                      hintText: loc.fullName,
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _parentPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(fontSize: 13.5, color: p.ink),
                    decoration: InputDecoration(
                      hintText: loc.phoneOptional,
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _parentEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(fontSize: 13.5, color: p.ink),
                    decoration: InputDecoration(
                      hintText: loc.parentEmailOptional,
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],

              Text(
                loc.startingMilestone,
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
                      initialValue: '$_juz',
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 13.5, color: p.ink),
                      decoration: InputDecoration(labelText: loc.juzLabel),
                      onChanged: (v) => _juz = int.tryParse(v) ?? 30,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: '$_surah',
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 13.5, color: p.ink),
                      decoration: InputDecoration(labelText: loc.surahLabel),
                      onChanged: (v) => _surah = int.tryParse(v) ?? 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(loc.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: (canSubmit && !_isSaving)
                          ? () => _submit(parsedAge)
                          : null,
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isEditing ? loc.save : loc.enrollStudent),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
