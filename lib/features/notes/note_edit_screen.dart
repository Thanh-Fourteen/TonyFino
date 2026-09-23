import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_providers.dart';
import '../../core/time/clock_provider.dart';
import '../../data/db/database.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';

void openNoteEditScreen(BuildContext context, {Note? existing}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => NoteEditScreen(existing: existing)),
  );
}

/// Soạn/sửa một ghi chú. MÀN RIÊNG chứ không phải bottom sheet: ghi chú có
/// thể dài, và một ô nhập nhiều dòng trong sheet thì bàn phím chiếm gần hết
/// chỗ còn lại (đúng vấn đề đã gặp ở form ghi khoản, docs Phase 6).
class NoteEditScreen extends ConsumerStatefulWidget {
  const NoteEditScreen({super.key, this.existing});

  final Note? existing;

  @override
  ConsumerState<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends ConsumerState<NoteEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  bool get _isDirty =>
      _title.text != (widget.existing?.title ?? '') ||
      _body.text != (widget.existing?.body ?? '');

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _body = TextEditingController(text: widget.existing?.body ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    // Ghi chú rỗng hoàn toàn thì không tạo hàng rác: thoát ra như chưa làm
    // gì. Sửa một ghi chú cũ thành rỗng thì cũng không xoá lén — người ta
    // có nút Xoá tường minh cho việc đó.
    if (title.isEmpty && body.isEmpty && !_isEditing) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(noteRepositoryProvider);
    final now = ref.read(clockProvider).now();
    final result = _isEditing
        ? await repo.update(
            id: widget.existing!.id,
            title: title,
            body: body,
            now: now,
          )
        : await repo.insert(title: title, body: body, now: now);
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      ok: (_) => Navigator.of(context).pop(),
      err: (e) => setState(() => _error = e.message),
    );
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá ghi chú?'),
        content: const Text('Ghi chú này sẽ mất hẳn, không hoàn tác được.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.colors.budgetOver,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(noteRepositoryProvider).delete(widget.existing!.id);
    navigator.pop();
  }

  Future<void> _handlePop(bool didPop, void result) async {
    if (didPop) return;
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bỏ thay đổi?'),
        content: const Text('Ghi chú chưa lưu sẽ mất.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Tiếp tục sửa'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.colors.budgetOver,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handlePop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Sửa ghi chú' : 'Ghi chú mới'),
          actions: [
            if (_isEditing)
              IconButton(
                tooltip: 'Xoá ghi chú',
                icon: Icon(kIconDelete, color: context.colors.budgetOver),
                onPressed: _saving ? null : _delete,
              ),
            IconButton(
              tooltip: 'Lưu',
              icon: const Icon(kIconCheck),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(context.space.screenHorizontal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _title,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.sentences,
                  style: context.text.titleMedium,
                  decoration: InputDecoration(
                    hintText: 'Tiêu đề (không bắt buộc)',
                    border: InputBorder.none,
                    errorText: _error,
                  ),
                ),
                Divider(height: 1, color: context.colors.hairline),
                SizedBox(height: context.space.sm),
                // `expands` + `maxLines: null`: ô nội dung chiếm hết chỗ còn
                // lại, chạm đâu cũng vào đúng ô — không phải nhắm đúng một
                // dòng chữ cao 20px.
                Expanded(
                  child: TextField(
                    controller: _body,
                    autofocus: _isEditing,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Gõ gì cũng được…',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
