import '../../../ui/grouped_number_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/app_bottom_sheet.dart';
import '../../../ui/color_icon_picker.dart';
import '../../categories/categories_screen.dart';
import '../selected_wallet_provider.dart';

Future<void> showWalletEditSheet({
  required BuildContext context,
  int? existingId,
  String? existingName,
  int? existingColorId,
  String? existingIconCode,
  int? existingOpeningBalanceMinor,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => WalletEditSheet(
      existingId: existingId,
      existingName: existingName,
      existingColorId: existingColorId,
      existingIconCode: existingIconCode,
      existingOpeningBalanceMinor: existingOpeningBalanceMinor,
    ),
  );
}

/// Sheet thêm/sửa ví (Phase 13) — cùng khuôn `BudgetEditSheet`/
/// `TransactionFormSheet`. Không có nút xoá — ví CHỈ lưu trữ (archive), xem
/// docs/decisions.md § Phase 13.
class WalletEditSheet extends ConsumerStatefulWidget {
  const WalletEditSheet({
    super.key,
    this.existingId,
    this.existingName,
    this.existingColorId,
    this.existingIconCode,
    this.existingOpeningBalanceMinor,
  });

  final int? existingId;
  final String? existingName;
  final int? existingColorId;
  final String? existingIconCode;
  final int? existingOpeningBalanceMinor;

  @override
  ConsumerState<WalletEditSheet> createState() => _WalletEditSheetState();
}

class _WalletEditSheetState extends ConsumerState<WalletEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _openingController;
  late int _colorId;
  late String _iconCode;
  bool _saving = false;
  String? _nameError;

  bool get _isEditing => widget.existingId != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingName ?? '');
    // Ô trống = 0, KHÔNG hiện sẵn số "0": một ô đã có "0" thì Tony phải xoá
    // trước khi gõ, còn ô trống thì gõ thẳng được.
    final opening = widget.existingOpeningBalanceMinor ?? 0;
    _openingController = TextEditingController(
      text: opening == 0 ? '' : groupDigits(opening.abs().toString()),
    );
    _colorId = widget.existingColorId ?? 0;
    _iconCode = widget.existingIconCode ?? 'account_balance_wallet';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Nhập tên ví');
      return;
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });

    final opening = int.tryParse(digitsOf(_openingController.text)) ?? 0;
    final repo = ref.read(walletRepositoryProvider);
    final result = _isEditing
        ? await repo.update(
            id: widget.existingId!,
            name: name,
            categoryColorId: _colorId,
            iconCode: _iconCode,
            openingBalanceMinor: opening,
          )
        : await repo.insert(
            name: name,
            categoryColorId: _colorId,
            iconCode: _iconCode,
            openingBalanceMinor: opening,
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
            _isEditing ? 'Sửa ví' : 'Thêm ví',
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
                      labelText: 'Tên ví',
                      errorText: _nameError,
                    ),
                  ),
                  SizedBox(height: context.space.md),
                  TextField(
                    controller: _openingController,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [ThousandsSeparatorInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Số dư ban đầu',
                      helperText: 'Tiền đang có sẵn trong ví trước khi ghi sổ',
                      suffixText: 'đ',
                    ),
                  ),
                  // CHỈ khi SỬA: ví chưa tồn tại thì chưa có danh mục nào
                  // để mở. Bấm vào đây cũng CHUYỂN ví đang xem sang ví này
                  // — nếu không, Tony mở màn Danh mục ra lại thấy danh mục
                  // của ví khác và tưởng app hỏng.
                  if (_isEditing) ...[
                    SizedBox(height: context.space.md),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          // Nền tròn sau icon dùng PETROL, không phải cam: cam ở
                          // 10% trên nền trắng ra một sắc be nhạt — mắt đọc thành
                          // nâu chứ không thành "cam nhạt" (Tony: "các màu nâu ở
                          // các nền icon"). Icon bên trong cũng petrol nên cả cụm
                          // là một khối cùng tông.
                          color: context.colors.brandText.withValues(
                            alpha: 0.10,
                          ),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          kIconCategory,
                          size: 20,
                          color: context.colors.brandText,
                        ),
                      ),
                      title: const Text('Danh mục của ví này'),
                      subtitle: const Text(
                        'Thêm, sửa, xoá danh mục & danh mục con',
                      ),
                      trailing: Icon(
                        kIconChevronRight,
                        size: 20,
                        color: context.colors.onSurfaceVariant,
                      ),
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        await ref
                            .read(walletSelectionOverrideProvider.notifier)
                            .select(widget.existingId!);
                        navigator.pop();
                        await navigator.push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CategoriesScreen(),
                          ),
                        );
                      },
                    ),
                  ],
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
                    icons: walletIconByCode,
                    selectedCode: _iconCode,
                    onSelected: (code) => setState(() => _iconCode = code),
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
