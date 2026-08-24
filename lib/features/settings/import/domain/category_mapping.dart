import '../../../../core/text/ascii_fold.dart';
import 'staged_transaction.dart';

/// Trạng thái BA GIÁ TRỊ cho một danh mục Rolly — KHÔNG được gộp
/// "chưa quyết định" và "quyết định để trống" làm một, vì đó chính là khác
/// biệt giữa "âm thầm bỏ qua" (cấm) và "Tony chủ động chọn Chưa phân loại"
/// (hợp lệ, xem `docs/decisions.md` § Phase 9).
///
/// PHẢI override `==`/`hashCode` (không dùng danh tính đối tượng mặc định)
/// — `DropdownButton` trong `_MappingView` so khớp `value` (từ `state.mapping`)
/// với từng `DropdownMenuItem.value` (dựng mới mỗi lần build) bằng `==`; hai
/// thực thể `MappingToCategory` khác instance nhưng cùng `categoryId` PHẢI
/// coi là bằng nhau, nếu không dropdown ném assertion "0 item khớp value"
/// ngay khi màn ánh xạ có gợi ý sẵn — bug thật bắt được bằng widget test.
sealed class MappingChoice {
  const MappingChoice();
}

class MappingUndecided extends MappingChoice {
  const MappingUndecided();

  @override
  bool operator ==(Object other) => other is MappingUndecided;

  @override
  int get hashCode => (MappingUndecided).hashCode;
}

class MappingToCategory extends MappingChoice {
  const MappingToCategory(this.categoryId);
  final int categoryId;

  @override
  bool operator ==(Object other) =>
      other is MappingToCategory && other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(MappingToCategory, categoryId);
}

/// "Tạo một danh mục TonyFino MỚI mang đúng tên Rolly này".
///
/// Tồn tại vì trước đây màn ánh xạ chỉ cho chọn giữa các danh mục CÓ SẴN và
/// "Chưa phân loại" — nên mọi danh mục Rolly không trùng tên danh mục mặc
/// định (thật: "Giặt đồ" 8 giao dịch, "Thực phẩm", "Tiền nhà", "Thức ăn &
/// Đồ uống" 197 giao dịch) chỉ còn cách nhét bừa vào một danh mục khác hoặc
/// đổ vào "Chưa phân loại" — người dùng thấy đúng như "import bị mất Giặt
/// đồ". Đây KHÔNG phải suy đoán tự động: vẫn là một lựa chọn Tony bấm tay,
/// đúng tinh thần "không tự động commit kết quả suy đoán".
///
/// Chỉ mang [name]/[kind]; `categoryId` thật chỉ có SAU khi controller gọi
/// repository lúc xác nhận ánh xạ — nên [resolveRollyRows] không nhận được
/// lựa chọn này (xem `StateError` bên dưới).
class MappingCreateCategory extends MappingChoice {
  const MappingCreateCategory({required this.name, required this.kind});
  final String name;
  final String kind;

  @override
  bool operator ==(Object other) =>
      other is MappingCreateCategory &&
      other.name == name &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(MappingCreateCategory, name, kind);
}

class MappingUncategorized extends MappingChoice {
  const MappingUncategorized();

  @override
  bool operator ==(Object other) => other is MappingUncategorized;

  @override
  int get hashCode => (MappingUncategorized).hashCode;
}

/// Gợi ý mặc định CHỈ khi tên đã chuẩn hoá (fold dấu + hạ chữ) trùng khớp
/// TUYỆT ĐỐI với tên một danh mục TonyFino có sẵn — không phỏng đoán ngữ
/// nghĩa nào khác (Luật bắt buộc #7: không tự động commit một kết quả suy
/// đoán). Bucket "Chuyển khoản/Tiết kiệm" hay "Không có danh mục Rolly"
/// không bao giờ có gợi ý — không có tên category gốc nào để so khớp.
MappingChoice suggestDefaultMapping(
  RollyCategoryUsage usage,
  List<({int id, String name})> tonyfinoCategories,
) {
  // Nhóm "Chuyển khoản / Tiết kiệm" KHÔNG phải một khoản chi tiêu, nên nó
  // không có danh mục đúng nào để chọn — trước đây nó nằm đó ở trạng thái
  // "Chưa chọn" và chặn cả nút Tiếp tục, không ai đoán được phải chọn gì.
  //
  // Gợi ý sẵn "Chưa phân loại" là câu trả lời ĐÚNG cho nó: các dòng này
  // được gắn vào mục tiêu tiết kiệm ở bước sau (file có mảng `savings`),
  // qua `goalId` chứ không qua danh mục. Đây vẫn là gợi ý — Tony đổi được.
  if (usage.bucket.isSavingsTransferBucket) {
    return const MappingUncategorized();
  }
  if (usage.bucket.rollyCategoryId == null) return const MappingUndecided();
  final normalizedTitle = foldToAscii(usage.title);
  for (final category in tonyfinoCategories) {
    if (foldToAscii(category.name) == normalizedTitle) {
      return MappingToCategory(category.id);
    }
  }
  return const MappingUndecided();
}

bool allCategoriesDecided(
  List<RollyCategoryUsage> usages,
  Map<CategoryBucketKey, MappingChoice> mapping,
) {
  for (final usage in usages) {
    final choice = mapping[usage.bucket];
    if (choice is! MappingToCategory &&
        choice is! MappingUncategorized &&
        choice is! MappingCreateCategory) {
      return false;
    }
  }
  return true;
}

/// Áp bảng ánh xạ ĐÃ QUYẾT ĐỊNH HẾT vào từng dòng staged — gọi sau khi
/// [allCategoriesDecided] đã `true`, nếu không ném lỗi lập trình (gọi sai
/// thứ tự ở tầng controller, không phải lỗi người dùng cần `Result`).
List<ResolvedImportRow> resolveRollyRows(
  List<StagedRollyTransaction> rows,
  Map<CategoryBucketKey, MappingChoice> mapping,
) {
  return [
    for (final row in rows)
      ResolvedImportRow(
        sourceId: row.sourceId,
        amountMinor: row.amountMinor,
        occurredAt: row.occurredAt,
        note: row.note,
        isTransfer: row.sourceType == RollySourceType.savingsTransfer,
        categoryId: switch (mapping[row.categoryBucket]) {
          MappingToCategory(:final categoryId) => categoryId,
          MappingUncategorized() => null,
          MappingCreateCategory() => throw StateError(
            'resolveRollyRows gặp MappingCreateCategory chưa được tạo thật '
            '(bucket=${row.categoryBucket}) — controller phải tạo danh mục '
            'rồi thay bằng MappingToCategory(id) TRƯỚC khi gọi hàm này.',
          ),
          MappingUndecided() || null => throw StateError(
            'resolveRollyRows gọi khi ánh xạ chưa quyết định hết '
            '(bucket=${row.categoryBucket}) — phải gate bằng '
            'allCategoriesDecided() trước.',
          ),
        },
      ),
  ];
}

/// Gợi ý `iconCode` cho danh mục MỚI tạo từ import, tra theo tên đã chuẩn
/// hoá (fold dấu + hạ chữ) — **khớp TUYỆT ĐỐI hoặc không gì cả**, không có
/// so khớp mờ, không suy luận ngữ nghĩa. Bảng này liệt kê đúng những tên
/// danh mục có thật trong dữ liệu Rolly của Tony (`raw_rolly/category_view`)
/// nên nó là một bảng TRA CỨU, không phải một phỏng đoán.
///
/// Vì sao cần: từ khi `CategoryAvatar` vẽ icon 3D, mọi danh mục mới đều rơi
/// về `more_horiz` nghĩa là "Thức ăn & Đồ uống" (197 giao dịch) và "Giao
/// thông" (38) đội CÙNG một icon giấy tờ — nhìn thấy ngay trên máy thật.
/// Icon vẫn sửa được ở màn Danh mục nên đoán sai chỉ tốn một cú bấm, khác
/// hẳn đoán sai một con số tiền.
String suggestIconCodeForName(String name) {
  const byFoldedName = {
    'thuc an & do uong': 'restaurant',
    'thuc an va do uong': 'restaurant',
    'an uong': 'restaurant',
    'thuc pham': 'shopping_bag',
    'mua sam': 'shopping_bag',
    'giao thong': 'directions_car',
    'di chuyen': 'directions_car',
    'du lich': 'directions_car',
    'tien nha': 'home',
    'nha cua': 'home',
    'gia dinh': 'family_restroom',
    'dien tu': 'devices',
    'suc khoe': 'health_and_safety',
    'the thao': 'health_and_safety',
    'lam dep': 'spa',
    'giao duc': 'school',
    'giai tri': 'theater_comedy',
    'luong': 'payments',
    'tien thuong': 'payments',
    'dau tu': 'payments',
    'kinh doanh': 'payments',
  };
  return byFoldedName[foldToAscii(name)] ?? 'more_horiz';
}
