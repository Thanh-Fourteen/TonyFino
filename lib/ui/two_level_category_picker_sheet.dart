import 'package:flutter/material.dart';

import '../data/db/database.dart' show Category;
import '../theme/context_ext.dart';
import 'app_bottom_sheet.dart';
import 'two_level_category_picker.dart';

/// Bottom sheet chọn danh mục HAI TẦNG, trả về id đã chọn (`null` nếu đóng
/// mà không chọn). Dùng ở mọi chỗ chọn danh mục KIỂU SHEET (thẻ ở màn chat,
/// dòng tách giao dịch) — nơi form không có sẵn chỗ nhúng thẳng
/// [TwoLevelCategoryPicker].
///
/// 🚨 SHEET "CHỌN XONG ĐÓNG NGAY" LÀM TẦNG HAI KHÔNG BAO GIỜ HIỆN RA.
///
/// Bug thật Tony bắt được: gõ "hủ tíu trưa 30k" rồi bấm chip danh mục trên
/// thẻ, chỉ chọn được danh mục cha, "chưa chọn được thư mục con". Nguyên
/// nhân không nằm ở [TwoLevelCategoryPicker] (nó đúng): hàng danh mục con
/// chỉ hiện SAU KHI đã chọn một cha, mà chỗ gọi lại `Navigator.pop` ngay
/// trong `onChanged` — nên đúng cái frame mà hàng con lẽ ra hiện lên thì
/// sheet đã đóng. Tầng hai chỉ nhìn thấy được khi thẻ vốn ĐÃ mang sẵn một
/// danh mục con.
///
/// Nên sheet này giữ lựa chọn trong state của CHÍNH NÓ và chỉ đóng khi lựa
/// chọn đã dứt điểm:
///  * chọn một CON → đóng ngay (không còn tầng nào sâu hơn để chọn);
///  * chọn một CHA KHÔNG có con → đóng ngay (giữ nguyên tốc độ cũ, không
///    bắt thêm một cú bấm vô nghĩa);
///  * chọn một CHA CÓ con → ở lại, hiện hàng con + nút chốt "Dùng «…»" cho
///    người muốn dừng ở mức cha.
Future<int?> showTwoLevelCategoryPickerSheet({
  required BuildContext context,
  required List<Category> categories,
  required String? kind,
  int? selectedCategoryId,
  String title = 'Chọn danh mục',
}) {
  return showAppBottomSheet<int>(
    context: context,
    builder: (sheetContext) => _TwoLevelCategoryPickerSheet(
      categories: categories,
      kind: kind,
      initialSelectedId: selectedCategoryId,
      title: title,
    ),
  );
}

class _TwoLevelCategoryPickerSheet extends StatefulWidget {
  const _TwoLevelCategoryPickerSheet({
    required this.categories,
    required this.kind,
    required this.initialSelectedId,
    required this.title,
  });

  final List<Category> categories;
  final String? kind;
  final int? initialSelectedId;
  final String title;

  @override
  State<_TwoLevelCategoryPickerSheet> createState() =>
      _TwoLevelCategoryPickerSheetState();
}

class _TwoLevelCategoryPickerSheetState
    extends State<_TwoLevelCategoryPickerSheet> {
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSelectedId;
  }

  bool _hasChildren(int categoryId) =>
      widget.categories.any((c) => c.parentCategoryId == categoryId);

  Category? _byId(int? id) {
    if (id == null) return null;
    for (final c in widget.categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _onChanged(int? id) {
    if (id == null) return;
    final picked = _byId(id);
    // Con, hoặc cha không có con nào → không còn gì để chọn thêm, chốt luôn.
    if (picked?.parentCategoryId != null || !_hasChildren(id)) {
      Navigator.of(context).pop(id);
      return;
    }
    setState(() => _selectedId = id);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _byId(_selectedId);
    final rootId = selected == null
        ? null
        : (selected.parentCategoryId ?? selected.id);
    // Nút chốt chỉ có nghĩa khi đang dừng ở một CHA còn có con chưa chọn —
    // chọn con thì sheet đã đóng, cha không con cũng vậy.
    final pendingRoot = (rootId != null && rootId == _selectedId)
        ? _byId(rootId)
        : null;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: context.space.screenHorizontal,
          right: context.space.screenHorizontal,
          top: context.space.lg,
          bottom: context.space.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: context.text.titleLarge),
            SizedBox(height: context.space.lg),
            TwoLevelCategoryPicker(
              categories: widget.categories,
              kind: widget.kind,
              selectedId: _selectedId,
              onChanged: _onChanged,
            ),
            if (pendingRoot != null) ...[
              SizedBox(height: context.space.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(pendingRoot.id),
                  child: Text('Dùng "${pendingRoot.name}"'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
