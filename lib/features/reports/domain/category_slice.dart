/// Một dòng tổng chi theo danh mục đã gộp sẵn ở SQL (KHÔNG lặp Dart trên sổ
/// cái) — đầu vào thuần Dart cho [buildCategorySlices], tách khỏi kiểu
/// `Category` của drift để hàm gộp lát bánh test được không cần DB (cùng
/// triết lý `category_matcher.dart` ở Phase 7: domain không đụng DB).
class CategorySourceAmount {
  const CategorySourceAmount({
    required this.categoryId,
    required this.label,
    required this.categoryColorId,
    required this.iconCode,
    required this.amountMinor,
    this.tagIds,
  });

  /// `null` cho giao dịch chưa gán danh mục — nhóm riêng, KHÔNG gộp chung
  /// với lát "Khác" do tràn quá 6 lát (hai khái niệm "không có" khác nhau,
  /// bài học Phase 9 § CategoryBucketKey).
  final int? categoryId;
  final String label;
  final int categoryColorId;
  final String iconCode;

  /// Luôn ÂM hoặc 0 (tổng chi) — dấu giữ nguyên từ SQL, `.abs` khi hiển thị.
  final int amountMinor;

  /// Khác `null` = đây là một nhóm THẺ (chế độ "gom theo thẻ"), không phải
  /// danh mục; [categoryId] khi đó luôn `null`. Là một trường riêng chứ
  /// không mượn `categoryId == null`: cái đó đã có nghĩa "chưa phân loại"
  /// (bài học Phase 9 § CategoryBucketKey — hai kiểu "không có" không được
  /// chung một giá trị).
  final List<int>? tagIds;
}

class CategorySlice {
  const CategorySlice({
    required this.categoryId,
    required this.label,
    required this.categoryColorId,
    required this.iconCode,
    required this.amountMinor,
    required this.isOther,
    this.tagIds,
  });

  /// `null` cho lát "Khác" (isOther) VÀ cho "Chưa phân loại" — phân biệt hai
  /// ca bằng [isOther], không bằng `categoryId` (cùng lý do Phase 9 §
  /// CategoryBucketKey đã áp dụng cho [CategorySourceAmount] ở trên). Khác
  /// null thì đây LUÔN là id của một danh mục CẤP GỐC thật (Phase 20 — lát
  /// bánh chính giờ vẽ theo danh mục cha, xem [rollupToRootCategories]) —
  /// UI dùng field này để tra `CategoryRootBreakdown` tương ứng khi bấm vào
  /// hàng chú thích, quyết định có mở sheet xem danh mục con hay không.
  final int? categoryId;
  final String label;
  final int categoryColorId;
  final String iconCode;

  /// Luôn ÂM hoặc 0.
  final int amountMinor;

  /// `true` cho lát tổng hợp "Khác" (danh mục hạng 7 trở đi bị gộp) — UI
  /// dùng cờ này để đổi hành vi chạm (mở sheet đầy đủ) thay vì sheet chi
  /// tiết một danh mục.
  final bool isOther;

  /// Xem [CategorySourceAmount.tagIds].
  final List<int>? tagIds;

  bool get isTagGroup => tagIds != null;
}

/// Mắt người chỉ phân biệt tin cậy 6–8 sắc độ trong một biểu đồ tròn — giới
/// hạn 6 lát lớn nhất + gộp phần còn lại (nếu có) vào một lát "Khác" duy
/// nhất, sắp theo | amount | giảm dần. Thuần hàm, không side-effect — test
/// được bằng dữ liệu giả lập, không cần DB đã seed.
List<CategorySlice> buildCategorySlices(
  List<CategorySourceAmount> sources, {
  int maxSlices = 6,
}) {
  final nonZero = sources.where((s) => s.amountMinor != 0).toList()
    ..sort((a, b) => b.amountMinor.abs().compareTo(a.amountMinor.abs()));

  if (nonZero.length <= maxSlices) {
    return [
      for (final s in nonZero)
        CategorySlice(
          categoryId: s.categoryId,
          label: s.label,
          categoryColorId: s.categoryColorId,
          iconCode: s.iconCode,
          amountMinor: s.amountMinor,
          isOther: false,
          tagIds: s.tagIds,
        ),
    ];
  }

  final visible = nonZero.take(maxSlices);
  final rest = nonZero.skip(maxSlices);
  final otherTotal = rest.fold<int>(0, (sum, s) => sum + s.amountMinor);

  return [
    for (final s in visible)
      CategorySlice(
        categoryId: s.categoryId,
        label: s.label,
        categoryColorId: s.categoryColorId,
        iconCode: s.iconCode,
        amountMinor: s.amountMinor,
        isOther: false,
        tagIds: s.tagIds,
      ),
    CategorySlice(
      categoryId: null,
      label: 'Khác',
      categoryColorId: -1, // UI resolve riêng — không trỏ vào bảng màu 12 mục
      iconCode: 'more_horiz',
      amountMinor: otherTotal,
      isOther: true,
    ),
  ];
}

/// Thông tin phân cấp TỐI THIỂU cần cho [rollupToRootCategories] — tách khỏi
/// `Category` (drift) để hàm rollup test được không cần DB, cùng triết lý
/// [CategorySourceAmount] ở trên (Phase 7 § category_matcher: domain không
/// đụng DB). Gồm cả tên/màu/icon (không chỉ id/parentId) vì một danh mục
/// CHA có thể KHÔNG có giao dịch trực tiếp nào (chỉ con có) — khi đó
/// [CategorySourceAmount] của SQL không có hàng nào mang tên/màu/icon của
/// cha để rollup mượn, phải tra từ đây.
class CategoryHierarchyEntry {
  const CategoryHierarchyEntry({
    required this.id,
    required this.parentCategoryId,
    required this.name,
    required this.categoryColorId,
    required this.iconCode,
  });

  final int id;
  final int? parentCategoryId;
  final String name;
  final int categoryColorId;
  final String iconCode;
}

/// Một danh mục CẤP GỐC đã cộng dồn chính nó + mọi danh mục con (Phase 20).
/// [children] là các hàng [CategorySourceAmount] GỐC (chưa gộp) đã rơi vào
/// nhóm này — có thể là chính danh mục gốc (giao dịch gán thẳng vào cha)
/// hoặc một danh mục con của nó; giữ nguyên để vẽ sheet "xem danh mục con".
class CategoryRootBreakdown {
  const CategoryRootBreakdown({
    required this.rootCategoryId,
    required this.label,
    required this.categoryColorId,
    required this.iconCode,
    required this.amountMinor,
    required this.children,
  });

  /// `null` = nhóm "Chưa phân loại" (không có danh mục cha nào, [children]
  /// luôn rỗng — không có gì để bấm xem chi tiết).
  final int? rootCategoryId;
  final String label;
  final int categoryColorId;
  final String iconCode;

  /// Luôn ÂM hoặc 0 — tổng của TOÀN BỘ [children] cộng lại.
  final int amountMinor;
  final List<CategorySourceAmount> children;

  /// Chỉ đáng bấm xem "breakdown" khi có NHIỀU HƠN MỘT nguồn đóng góp —
  /// một cha chỉ có đúng giao dịch của chính nó (chưa dùng danh mục con
  /// nào) thì bấm vào cũng chỉ thấy lại đúng một hàng đã hiện sẵn, vô ích.
  bool get hasBreakdown => children.length > 1;
}

/// Cộng dồn [sources] (đã ĐÚNG TỪNG SỐ từ SQL, phẳng theo `categoryId` thật
/// trên giao dịch) lên cấp danh mục CHA theo [hierarchy] — CHỦ ĐÍCH làm ở
/// tầng Dart thuần, không phải một JOIN/groupBy SQL thứ hai, để KHÔNG THỂ
/// xảy ra Cartesian fan-out (mỗi số hạng trong [sources] chỉ được cộng đúng
/// MỘT lần qua `fold`, không nhân bản qua bất kỳ JOIN nào) — xem
/// docs/decisions.md § Phase 20 câu hỏi 3. Thuần hàm, test được không cần
/// DB.
List<CategoryRootBreakdown> rollupToRootCategories(
  List<CategorySourceAmount> sources,
  List<CategoryHierarchyEntry> hierarchy,
) {
  final byId = {for (final h in hierarchy) h.id: h};

  final byRoot = <int?, List<CategorySourceAmount>>{};
  for (final s in sources) {
    final categoryId = s.categoryId;
    final rootId = categoryId == null
        ? null
        : (byId[categoryId]?.parentCategoryId ?? categoryId);
    (byRoot[rootId] ??= []).add(s);
  }

  final result = <CategoryRootBreakdown>[];
  byRoot.forEach((rootId, group) {
    final total = group.fold<int>(0, (sum, s) => sum + s.amountMinor);

    if (rootId == null) {
      // "Chưa phân loại" — `watchCategoryBreakdown` gộp mọi `categoryId:
      // null` thành đúng MỘT hàng ở SQL, nên nhóm này luôn có đúng 1 phần tử.
      final s = group.single;
      result.add(
        CategoryRootBreakdown(
          rootCategoryId: null,
          label: s.label,
          categoryColorId: s.categoryColorId,
          iconCode: s.iconCode,
          amountMinor: total,
          children: const [],
        ),
      );
      return;
    }

    final root = byId[rootId];
    final sortedChildren = [...group]
      ..sort((a, b) => b.amountMinor.abs().compareTo(a.amountMinor.abs()));
    result.add(
      CategoryRootBreakdown(
        rootCategoryId: rootId,
        // Phòng hờ danh mục cha không tìm thấy trong `hierarchy` (không nên
        // xảy ra — danh mục chỉ lưu trữ, không bao giờ xoá cứng) — mượn tạm
        // tên/màu/icon của hàng đầu tiên trong nhóm thay vì crash.
        label: root?.name ?? group.first.label,
        categoryColorId: root?.categoryColorId ?? group.first.categoryColorId,
        iconCode: root?.iconCode ?? group.first.iconCode,
        amountMinor: total,
        children: sortedChildren,
      ),
    );
  });

  return result;
}

/// Chi của một TỔ HỢP thẻ trong kỳ — xem
/// `ReportsRepository.watchTagGroupBreakdown` cho lý do gộp theo tổ hợp
/// chứ không theo từng thẻ.
class TagGroupAmount {
  const TagGroupAmount({required this.tagIds, required this.amountMinor});

  /// Đã sắp tăng dần, không rỗng.
  final List<int> tagIds;

  /// Luôn ÂM (tổng chi), cùng quy ước với [CategorySourceAmount].
  final int amountMinor;
}

/// Tên + màu tối thiểu của một thẻ — tách khỏi `Tag` (drift) cùng lý do
/// [CategoryHierarchyEntry].
class TagInfo {
  const TagInfo({required this.id, required this.name, required this.colorId});

  final int id;
  final String name;
  final int colorId;
}

/// Nguồn cho biểu đồ tròn ở chế độ "gom theo thẻ": mỗi TỔ HỢP thẻ một lát,
/// cộng với các lát danh mục (đã rollup về cấp gốc) của phần KHÔNG gắn thẻ.
///
/// [untaggedRootSources] phải là breakdown đã lọc `untaggedOnly` rồi rollup
/// — hai tập rời nhau, nên tổng mọi lát ở đây đúng bằng tổng chi của chế độ
/// thường, và phần trăm vẫn cộng ra 100%.
List<CategorySourceAmount> buildTagModeSources({
  required List<CategorySourceAmount> untaggedRootSources,
  required List<TagGroupAmount> tagGroups,
  required Map<int, TagInfo> tagsById,
}) {
  return [
    for (final g in tagGroups)
      CategorySourceAmount(
        categoryId: null,
        label: g.tagIds
            .map((id) => '#${tagsById[id]?.name ?? '?'}')
            .join(' + '),
        categoryColorId: tagsById[g.tagIds.first]?.colorId ?? -1,
        iconCode: 'sell',
        amountMinor: g.amountMinor,
        tagIds: g.tagIds,
      ),
    ...untaggedRootSources,
  ];
}
