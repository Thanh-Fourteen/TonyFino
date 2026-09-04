import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../data/db/database.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/app_bottom_sheet.dart';
import '../../../ui/category_avatar.dart';
import '../../../ui/color_icon_picker.dart';
import '../../transactions/transactions_providers.dart';
import '../../wallets/selected_wallet_provider.dart';

Future<void> showCategoryEditSheet({
  required BuildContext context,
  int? existingId,
  String? existingName,
  String? existingKind,
  int? existingColorId,
  String? existingIconCode,
  int? existingParentCategoryId,
  String? existingEmoji,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => CategoryEditSheet(
      existingId: existingId,
      existingName: existingName,
      existingKind: existingKind,
      existingColorId: existingColorId,
      existingIconCode: existingIconCode,
      existingParentCategoryId: existingParentCategoryId,
      existingEmoji: existingEmoji,
    ),
  );
}

/// Sheet thêm/sửa danh mục (Phase 13). [parentCategoryId] CHỈ nhận danh mục
/// CẤP GỐC (validate lại lần nữa ở `CategoryRepository`, xem
/// docs/decisions.md § Phase 13 "Danh mục con CHỈ MỘT CẤP") — sheet tự lọc
/// bớt để không đưa ra lựa chọn vô nghĩa ngay từ đầu.
class CategoryEditSheet extends ConsumerStatefulWidget {
  const CategoryEditSheet({
    super.key,
    this.existingId,
    this.existingName,
    this.existingKind,
    this.existingColorId,
    this.existingIconCode,
    this.existingParentCategoryId,
    this.existingEmoji,
  });

  final int? existingId;
  final String? existingName;
  final String? existingKind;
  final int? existingColorId;
  final String? existingIconCode;
  final int? existingParentCategoryId;
  final String? existingEmoji;

  @override
  ConsumerState<CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends ConsumerState<CategoryEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _emojiController;
  late bool _isExpense;
  late int _colorId;
  late String _iconCode;
  int? _parentCategoryId;
  bool _saving = false;
  String? _nameError;

  bool get _isEditing => widget.existingId != null;

  /// `kind` của danh mục cha đang chọn — `null` khi đang tạo/sửa một danh
  /// mục CẤP GỐC (lúc đó nút gạt Chi/Thu mới là nguồn quyết định).
  String? _parentKind(List<Category> categories) {
    final parentId = _parentCategoryId;
    if (parentId == null) return null;
    for (final category in categories) {
      if (category.id == parentId) return category.kind;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingName ?? '');
    _emojiController = TextEditingController(text: widget.existingEmoji ?? '');
    _isExpense = (widget.existingKind ?? 'expense') == 'expense';
    _colorId = widget.existingColorId ?? 0;
    _iconCode = widget.existingIconCode ?? 'more_horiz';
    _parentCategoryId = widget.existingParentCategoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Nhập tên danh mục');
      return;
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });

    final repo = ref.read(categoryRepositoryProvider);
    // Danh mục CON không có chiều tiền riêng — nó mang `kind` của cha
    // (`CategoryRepository.kindIsInheritedFromParent`). Repository ép lại
    // lần nữa, ở đây gửi sẵn giá trị đúng để nút gạt và thứ được lưu không
    // bao giờ nói hai chuyện khác nhau.
    final kind =
        _parentKind(ref.read(activeCategoriesProvider).value ?? const []) ??
        (_isExpense ? 'expense' : 'income');
    final emoji = _emojiController.text.trim();
    final result = _isEditing
        ? await repo.update(
            id: widget.existingId!,
            name: name,
            kind: kind,
            categoryColorId: _colorId,
            iconCode: _iconCode,
            parentCategoryId: _parentCategoryId,
            emoji: emoji.isEmpty ? null : emoji,
          )
        : await repo.insert(
            name: name,
            kind: kind,
            categoryColorId: _colorId,
            iconCode: _iconCode,
            // Danh mục CẤP GỐC mới thuộc về ví đang xem; danh mục CON bỏ qua
            // tham số này và thừa hưởng ví của cha (ép trong repository).
            walletId: ref.read(selectedWalletIdProvider),
            parentCategoryId: _parentCategoryId,
            emoji: emoji.isEmpty ? null : emoji,
          );

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
    final categoriesAsync = ref.watch(activeCategoriesProvider);
    final parentKind = _parentKind(categoriesAsync.value ?? const []);

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
            _isEditing ? 'Sửa danh mục' : 'Thêm danh mục',
            style: context.text.titleLarge,
          ),
          SizedBox(height: context.space.lg),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    autofocus: !_isEditing,
                    decoration: InputDecoration(
                      labelText: 'Tên danh mục',
                      errorText: _nameError,
                    ),
                  ),
                  SizedBox(height: context.space.md),
                  // Danh mục CON không được chọn chiều tiền: nó mang `kind`
                  // của cha (`CategoryRepository.kindIsInheritedFromParent`).
                  // Để nút gạt ở đây sẽ nói dối — trước bản này Tony bấm
                  // được "Thu" cho một danh mục con rồi nó vẫn ghi ra khoản
                  // CHI ở màn chat.
                  if (parentKind == null)
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Chi')),
                        ButtonSegment(value: false, label: Text('Thu')),
                      ],
                      selected: {_isExpense},
                      onSelectionChanged: (selection) =>
                          setState(() => _isExpense = selection.first),
                    )
                  else
                    Text(
                      parentKind == 'expense'
                          ? 'Danh mục CHI — theo danh mục cha'
                          : 'Danh mục THU — theo danh mục cha',
                      style: context.text.labelMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  // Chọn danh mục CHA đứng TRƯỚC màu/icon: "cái này là
                  // gì" phải hỏi trước "nó trông thế nào". Trước đây nó
                  // nằm CUỐI, sau cả bảng icon — thêm hai icon (v13) là
                  // nó bị đẩy khuất khỏi mép sheet và không bấm tới được
                  // trên màn hình thấp. Đặt ở đây thì mọi lần thêm icon
                  // sau này cũng không lặp lại chuyện đó.
                  SizedBox(height: context.space.md),
                  Text(
                    'Danh mục cha (tuỳ chọn)',
                    style: context.text.labelMedium,
                  ),
                  SizedBox(height: context.space.xs),
                  categoriesAsync.when(
                    data: (categories) {
                      final eligibleParents = categories.where(
                        (c) =>
                            c.parentCategoryId == null &&
                            c.id != widget.existingId,
                      );
                      return Wrap(
                        spacing: context.space.xs,
                        runSpacing: context.space.xs,
                        children: [
                          ChoiceChip(
                            label: const Text('Không có'),
                            selected: _parentCategoryId == null,
                            onSelected: (_) =>
                                setState(() => _parentCategoryId = null),
                          ),
                          for (final category in eligibleParents)
                            ChoiceChip(
                              label: Text(category.name),
                              avatar: CategoryAvatar(
                                categoryColorId: category.categoryColorId,
                                iconCode: category.iconCode,
                                size: 18,
                              ),
                              selected: _parentCategoryId == category.id,
                              onSelected: (_) => setState(
                                () => _parentCategoryId = category.id,
                              ),
                            ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (error, _) =>
                        Text('Không tải được danh mục: $error'),
                  ),
                  SizedBox(height: context.space.md),
                  Text('Màu', style: context.text.labelMedium),
                  SizedBox(height: context.space.xs),
                  ColorSwatchPicker(
                    selectedColorId: _colorId,
                    onSelected: (id) => setState(() => _colorId = id),
                  ),
                  SizedBox(height: context.space.md),
                  Text('Icon', style: context.text.labelMedium),
                  SizedBox(height: context.space.xs),
                  AppIconPicker(
                    icons: categoryIconByCode,
                    groups: categoryIconGroups,
                    selectedCode: _iconCode,
                    onSelected: (code) => setState(() => _iconCode = code),
                  ),
                  SizedBox(height: context.space.md),
                  Text('Emoji (tuỳ chọn)', style: context.text.labelMedium),
                  SizedBox(height: context.space.xs),
                  Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: TextField(
                          controller: _emojiController,
                          textAlign: TextAlign.center,
                          maxLength: 2,
                          decoration: const InputDecoration(
                            counterText: '',
                            hintText: '🍜',
                          ),
                        ),
                      ),
                      SizedBox(width: context.space.sm),
                      Expanded(
                        child: Text(
                          'Hiện thành một dấu nhỏ đè lên icon — bàn phím có sẵn '
                          'emoji, để trống nếu không cần.',
                          style: context.text.labelMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
