import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../data/db/database.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/app_bottom_sheet.dart';
import '../../../ui/color_icon_picker.dart';
import '../../wallets/selected_wallet_provider.dart';

/// Thêm/sửa một hũ. [existing] `null` = thêm mới.
Future<void> showJarEditSheet({required BuildContext context, Jar? existing}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => _JarEditSheet(existing: existing),
  );
}

class _JarEditSheet extends ConsumerStatefulWidget {
  const _JarEditSheet({this.existing});

  final Jar? existing;

  @override
  ConsumerState<_JarEditSheet> createState() => _JarEditSheetState();
}

class _JarEditSheetState extends ConsumerState<_JarEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _percent;
  late int _colorId;
  late String _iconCode;
  late bool _carryOver;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final j = widget.existing;
    _name = TextEditingController(text: j?.name ?? '');
    _percent = TextEditingController(text: j == null ? '' : '${j.percent}');
    _colorId = j?.categoryColorId ?? 0;
    _iconCode = j?.iconCode ?? 'more_horiz';
    _carryOver = j?.carryOver ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _percent.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final percent = int.tryParse(_percent.text.trim()) ?? -1;
    if (name.isEmpty) {
      setState(() => _error = 'Nhập tên hũ');
      return;
    }
    // 0% là một hũ không bao giờ nhận đồng nào — gần như chắc chắn là gõ
    // nhầm, chặn ngay thay vì để nó nằm đó gây khó hiểu.
    if (percent < 1 || percent > 100) {
      setState(() => _error = 'Tỉ lệ phải từ 1 đến 100');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });

    final repo = ref.read(jarRepositoryProvider);
    final result = _isEditing
        ? await repo.update(
            id: widget.existing!.id,
            name: name,
            percent: percent,
            categoryColorId: _colorId,
            iconCode: _iconCode,
            carryOver: _carryOver,
          )
        : await repo.insert(
            walletId: ref.read(selectedWalletIdProvider)!,
            name: name,
            percent: percent,
            categoryColorId: _colorId,
            iconCode: _iconCode,
            carryOver: _carryOver,
          );

    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      ok: (_) => Navigator.of(context).pop(),
      err: (e) => setState(() => _error = e.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    // `showAppBottomSheet` CHỈ chừa phần bàn phím che — lề trái/phải/trên là
    // việc của từng sheet. Sheet này quên, nên chữ "Sửa hũ", ô "Tên hũ" và
    // hàng màu dính sát mép màn hình, phần bo góc còn cắt vào chữ: đúng chỗ
    // Tony báo "nhấn vào 1 hũ bị lỗi". Dùng ĐÚNG lề của các sheet khác
    // (`category_edit_sheet`, `wallet_edit_sheet`…) chứ không tự chế số mới.
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
            _isEditing ? 'Sửa hũ' : 'Thêm hũ',
            style: context.text.titleLarge,
          ),
          SizedBox(height: context.space.lg),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _name,
                    autofocus: !_isEditing,
                    decoration: InputDecoration(
                      labelText: 'Tên hũ',
                      errorText: _error,
                    ),
                  ),
                  SizedBox(height: context.space.md),
                  TextField(
                    controller: _percent,
                    keyboardType: TextInputType.number,
                    // CỐ Ý là `digitsOnly`, KHÔNG phải bộ tách nhóm nghìn:
                    // đây là PHẦN TRĂM (1–100), không phải số tiền. "100"
                    // mà thành "100" thì không sao, nhưng dùng chung
                    // formatter tiền là mời một lần sửa tương lai vô tình
                    // biến ô này thành ô tiền.
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Tỉ lệ thu nhập',
                      helperText: 'Phần trăm TỔNG THU của kỳ dồn vào hũ này',
                      suffixText: '%',
                    ),
                  ),
                  SizedBox(height: context.space.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cộng dồn sang kỳ sau'),
                    subtitle: const Text(
                      'Tiền chưa tiêu hết ở kỳ này được giữ lại — dùng cho hũ '
                      'tiết kiệm, đầu tư. Hũ tiêu dùng thì tắt.',
                    ),
                    value: _carryOver,
                    onChanged: (v) => setState(() => _carryOver = v),
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
                ],
              ),
            ),
          ),
          SizedBox(height: context.space.lg),
          Row(
            children: [
              if (_isEditing)
                TextButton(
                  // Màu cảnh báo, KHÔNG lấy màu nhấn mặc định của
                  // `TextButton` — từ khi màu nhấn là petrol, nút xoá trông
                  // y hệt mọi nút chữ vô hại khác trên cùng sheet.
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.budgetOver,
                  ),
                  onPressed: _saving
                      ? null
                      : () async {
                          final navigator = Navigator.of(context);
                          await ref
                              .read(jarRepositoryProvider)
                              .archive(widget.existing!.id);
                          navigator.pop();
                        },
                  child: const Text('Xoá hũ'),
                ),
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
