/// Nguồn gốc của một dòng đã parse từ Rolly — quyết định dấu `amountMinor`
/// VÀ có tính vào báo cáo đối chiếu Chi/Thu hay không (oracle Phase 2 định
/// nghĩa Expense/Income KHÔNG gồm Savings — xem `docs/decisions.md` § Phase 9).
enum RollySourceType { expense, income, savingsTransfer }

/// Khoá nhóm cho màn ánh xạ danh mục — CỐ Ý KHÔNG dùng thẳng `int?` làm khoá:
/// "dòng Savings đã khử trùng lặp" (không có category gốc nào ở Rolly) và
/// "dòng Expense/Income hiếm khi thiếu category_id thật" đều có
/// `rollyCategoryId == null`, nhưng là HAI khái niệm khác nhau — gộp chung
/// một khoá `null` sẽ trộn lẫn số đếm của chúng trong màn ánh xạ (bug thật
/// bắt được lúc viết test bằng `test/fixtures/rolly/sample.json`, vốn cố
/// tình có cả hai ca này). Dữ liệu thật (`raw_rolly/input.json`) chỉ từng
/// gặp ca Savings — ca "Expense null category" chưa quan sát thấy nhưng
/// field vẫn nullable để không giả định nó không thể xảy ra.
class CategoryBucketKey {
  const CategoryBucketKey.category(int id)
    : rollyCategoryId = id,
      isSavingsTransferBucket = false;
  const CategoryBucketKey.uncategorized()
    : rollyCategoryId = null,
      isSavingsTransferBucket = false;
  const CategoryBucketKey.savingsTransfer()
    : rollyCategoryId = null,
      isSavingsTransferBucket = true;

  final int? rollyCategoryId;
  final bool isSavingsTransferBucket;

  @override
  bool operator ==(Object other) =>
      other is CategoryBucketKey &&
      other.rollyCategoryId == rollyCategoryId &&
      other.isSavingsTransferBucket == isSavingsTransferBucket;

  @override
  int get hashCode => Object.hash(rollyCategoryId, isSavingsTransferBucket);

  @override
  String toString() => isSavingsTransferBucket
      ? 'CategoryBucketKey.savingsTransfer'
      : 'CategoryBucketKey.category($rollyCategoryId)';
}

/// Một dòng CHƯA gắn được `categoryId` TonyFino — đợi bảng ánh xạ do Tony
/// xác nhận trong UI. `amountMinor` đã CÓ DẤU đúng (âm/dương theo
/// [sourceType]), KHÔNG đợi tới lúc chọn danh mục mới quyết định dấu (khác
/// heuristic `category.kind` của quick-add Phase 8 — ở đây `type` gốc của
/// Rolly là sự thật đáng tin hơn).
class StagedRollyTransaction {
  const StagedRollyTransaction({
    required this.sourceId,
    required this.amountMinor,
    required this.occurredAt,
    required this.note,
    required this.sourceType,
    required this.categoryBucket,
  });

  final String sourceId;
  final int amountMinor;
  final DateTime occurredAt;
  final String? note;
  final RollySourceType sourceType;
  final CategoryBucketKey categoryBucket;
}

/// Một nhóm danh mục THẬT SỰ được tham chiếu bởi ít nhất một giao dịch sẽ
/// import — nguồn cho màn ánh xạ.
class RollyCategoryUsage {
  const RollyCategoryUsage({
    required this.bucket,
    required this.title,
    required this.transactionCount,
    required this.kind,
  });

  final CategoryBucketKey bucket;
  final String title;
  final int transactionCount;

  /// `'expense'` hoặc `'income'` — suy ra từ `type` gốc của CHÍNH các dòng
  /// trong nhóm này (đa số thắng), KHÔNG đoán theo tên. Chỉ dùng khi Tony
  /// chọn "Tạo danh mục mới": danh mục mới phải sinh ra đúng chiều tiền,
  /// nếu không nó sẽ nằm sai phía trong mọi báo cáo về sau.
  final String kind;
}

/// Sẵn sàng để insert thật — sau khi mọi `rollyCategoryId`/tên CSV đã được
/// giải quyết thành `categoryId` TonyFino (hoặc cố ý để `null` = "Chưa phân
/// loại", một lựa chọn tường minh chứ không phải bỏ sót).
class ResolvedImportRow {
  const ResolvedImportRow({
    required this.sourceId,
    required this.amountMinor,
    required this.occurredAt,
    required this.note,
    required this.categoryId,
    this.isTransfer = false,
  });

  final String sourceId;
  final int amountMinor;
  final DateTime occurredAt;
  final String? note;
  final int? categoryId;

  /// Dòng CHUYỂN TIỀN (nạp/rút tiết kiệm), không phải chi tiêu.
  ///
  /// Phải đánh dấu ngay lúc nhập: nếu để chúng thành khoản chi thường, báo
  /// cáo cộng luôn tiền chuyển vào tiết kiệm thành "đã tiêu" — sổ thật của
  /// Tony ra "Chưa phân loại 46% = 43.220.000₫", đúng bằng số tiền gửi tiết
  /// kiệm CCTG. Chính báo cáo đối chiếu lúc import cũng đã tách riêng chúng
  /// ("4 giao dịch chuyển khoản/tiết kiệm — không tính vào Chi/Thu").
  final bool isTransfer;
}
