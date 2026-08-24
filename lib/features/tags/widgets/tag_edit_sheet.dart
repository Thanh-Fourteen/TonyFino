import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../theme/context_ext.dart';
import '../../../ui/app_bottom_sheet.dart';
import '../../../ui/color_icon_picker.dart';

Future<void> showTagEditSheet({
  required BuildContext context,
  int? existingId,
  String? existingName,
  int? existingColorId,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => TagEditSheet(
      existingId: existingId,
      existingName: existingName,
      existingColorId: existingColorId,
    ),
  );
}

/// Sheet thêm/sửa thẻ (Phase 17) — chỉ tên + màu, không icon/cha-con (khác
/// `CategoryEditSheet`: thẻ cố ý phẳng, độc lập với cây danh mục).
class TagEditSheet extends ConsumerStatefulWidget {
  const TagEditSheet({
    super.key,
    this.existingId,
    this.existingName,
    this.existingColorId,
  });

  final int? existingId;
  final String? existingName;
  final int? existingColorId;

  @override
  ConsumerState<TagEditSheet> createState() => _TagEditSheetState();
}

class _TagEditSheetState extends ConsumerState<TagEditSheet> {
  late final TextEditingController _nameController;
  late int _colorId;
  bool _saving = false;
  String? _nameError;

  bool get _isEditing => widget.existingId != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingName ?? '');
    _colorId = widget.existingColorId ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Nhập tên thẻ');
      return;
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });

    final repo = ref.read(tagRepositoryProvider);
    final result = _isEditing
        ? await repo.update(
            id: widget.existingId!,
            name: name,
            categoryColorId: _colorId,
          )
        : await repo.insert(name: name, categoryColorId: _colorId);

    if (!mounted) return;
    setState(() => _saving = false);

    result.when(
      ok: (_) => Navigator.of(context).pop(),
      err: (error) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Không lưu được'),
          content: Text(error.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.space.screenHorizontal,
        vertical: context.space.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? 'Sửa thẻ' : 'Thêm thẻ',
            style: context.text.titleLarge,
          ),
          SizedBox(height: context.space.lg),
          TextField(
            controller: _nameController,
            autofocus: !_isEditing,
            decoration: InputDecoration(
              labelText: 'Tên thẻ',
              errorText: _nameError,
            ),
          ),
          SizedBox(height: context.space.md),
          Text('Màu', style: context.text.labelMedium),
          SizedBox(height: context.space.xs),
          ColorSwatchPicker(
            selectedColorId: _colorId,
            onSelected: (id) => setState(() => _colorId = id),
          ),
          SizedBox(height: context.space.lg),
          Row(
            children: [
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Lưu'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
