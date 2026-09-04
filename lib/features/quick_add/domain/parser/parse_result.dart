/// Kiểu dữ liệu công khai của parser tiếng Việt (Phase 7). File này CHỈ chứa
/// kiểu dữ liệu bất biến — không chứa logic phân tích (xem `parser.dart`).
///
/// Dart thuần, không phụ thuộc Flutter/DB — `Money`/DB đều nằm ở tầng gọi
/// (Phase 8), không import ngược ở đây.
library;

/// Nhãn buổi trong ngày, chỉ dùng làm TÍN HIỆU cho `category_matcher`
/// (vd. "sáng" gợi ý ăn sáng/cà phê) — KHÔNG dùng để gán giờ chính xác vào
/// [DateTime] đã resolve. Cố tình tách riêng thay vì đoán một giờ cụ thể.
enum TimeOfDayLabel { morning, noon, afternoon, evening, lateNight }

/// Từ chỉ buổi → nhãn. Dùng ở HAI chỗ, cố ý để chung một nguồn:
///  * `date_parser` nhận dạng cụm `"<buổi> nay"` / `"<buổi> qua"`;
///  * `categoryKeywordEntriesProvider` sinh tín hiệu phân loại cho danh mục
///    CON có tên chứa từ buổi ("Ăn trưa", "Đồ ăn sáng"…) — chính là lời hứa
///    ở doc comment của [TimeOfDayLabel] mà trước đây chưa ai nối dây, nên
///    "hủ tíu trưa 30k" dừng ở danh mục cha.
const Map<String, TimeOfDayLabel> timeOfDayWords = {
  'sáng': TimeOfDayLabel.morning,
  'trưa': TimeOfDayLabel.noon,
  'chiều': TimeOfDayLabel.afternoon,
  'tối': TimeOfDayLabel.evening,
  'khuya': TimeOfDayLabel.lateNight,
};

/// Một khoản tiền đã tìm thấy trong chuỗi — số tiền LUÔN LÀ ĐỘ LỚN không dấu
/// (VND, `currencyScale = 0`). Dấu thu/chi KHÔNG được quyết định ở đây —
/// đó là việc của danh mục khớp được (`Categories.kind`) ở tầng gọi (Luật
/// bố cục Phase 8), giữ parser không cần đoán ý định thu/chi từ mỗi con số.
class ParsedAmount {
  const ParsedAmount({required this.minorUnits, required this.confident});

  /// Độ lớn số tiền, đơn vị VND nguyên (currencyScale = 0). `null` (ở
  /// [ParsedDraft.amount]) nghĩa là không tìm thấy số tiền nào.
  final int minorUnits;

  /// `true` nếu có tín hiệu tường minh (đơn vị nghìn/triệu/k/tr/củ, ký hiệu
  /// tiền tệ đ/vnd, hoặc nhóm phân cách nghìn `35.000`) — `false` nếu chỉ là
  /// một số trần được suy đoán (hiếm khi xảy ra, xem `amount_evaluator.dart`).
  final bool confident;
}

/// Ngày đã resolve cho một draft, neo vào [Clock] được inject — KHÔNG BAO
/// GIỜ `DateTime.now()` (Luật #3 toàn dự án).
class ParsedDate {
  const ParsedDate({
    required this.date,
    required this.explicit,
    this.timeOfDayLabel,
  });

  /// Chỉ phần ngày (giờ/phút/giây = 0) — giờ chính xác không phải việc của
  /// parser (Luật bố cục Phase 8: ngày đã resolve phải hiển thị rõ, sửa được).
  final DateTime date;

  /// `true` nếu người dùng viết một cụm ngày tường minh ("hôm qua", "12/3",
  /// "thứ 3 tuần trước", …) — `false` nếu mặc định về hôm nay vì không tìm
  /// thấy cụm ngày nào trong chuỗi. Tầng UI dùng cờ này để quyết định chip
  /// ngày có hiện tín hiệu "chưa chắc" hay không (Luật #7).
  final bool explicit;

  final TimeOfDayLabel? timeOfDayLabel;
}

/// Một mục từ khoá danh mục — bản sao thuần Dart của bảng `CategoryKeywords`
/// (Phase 4), tách khỏi drift để `category_matcher` không phụ thuộc DB.
/// `categoryKey` là khoá ổn định (`CategorySeed.key`), KHÔNG phải id DB —
/// tầng gọi (Phase 8) tự tra `categoryKey → id` sau khi parser trả kết quả.
class CategoryKeywordEntry {
  const CategoryKeywordEntry({
    required this.categoryKey,
    required this.keyword,
    required this.keywordAscii,
    this.weight = 1.0,
    this.parentKey,
  });

  final String categoryKey;
  final String keyword;
  final String keywordAscii;
  final double weight;

  /// `categoryKey` của danh mục CHA, `null` nếu đây là danh mục gốc — đủ để
  /// `category_matcher` dựng lại cây hai tầng và chấm điểm theo NHÁNH (xem
  /// doc comment ở đó) mà tầng parser thuần vẫn không phải biết gì về drift.
  /// Mọi entry của cùng một `categoryKey` phải mang cùng một `parentKey`.
  final String? parentKey;
}

/// Một danh mục khớp được cho phần chữ còn lại của draft, kèm điểm số
/// `weight × độ dài khớp` (tính trên bản ascii-fold) để tầng gọi quyết định
/// ngưỡng tin cậy hiển thị chip.
class CategoryMatch {
  const CategoryMatch({required this.categoryKey, required this.score});

  final String categoryKey;
  final double score;
}

/// Một mục tiêu tiết kiệm đang hoạt động, ở dạng thuần Dart cho
/// `savings_matcher` — bản sao của `SavingsGoals` (Phase 16) đúng những
/// trường cần để nhận ra tên trong câu. `goalKey` là khoá ổn định
/// (`id.toString()` ở tầng gọi), cùng quy ước với [CategoryKeywordEntry].
class SavingsTargetEntry {
  const SavingsTargetEntry({
    required this.goalKey,
    required this.name,
    required this.nameAscii,
  });

  final String goalKey;
  final String name;

  /// Tên đã bỏ dấu + hạ chữ thường (`normalize(name).ascii` ở tầng gọi) —
  /// so khớp luôn chạy trên bản này để "quỹ mua nhà" khớp "quy mua nha".
  final String nameAscii;
}

/// Ý định "cất tiền vào / rút tiền ra khỏi một mục tiêu tiết kiệm" đọc được
/// từ một đoạn tin nhắn.
///
/// Đây KHÔNG phải một danh mục: giao dịch sinh ra mang `goalId` và KHÔNG có
/// `categoryId`, đúng cách màn Quỹ (Phase 16) đang ghi — nhờ vậy nó tự động
/// không bị tính vào Chi/Thu của báo cáo, mà rơi vào ô "đã cất đi" (xem
/// `TransactionRepository.watchMonthToDateSummary`).
class SavingsMatch {
  const SavingsMatch({required this.goalKey, required this.isWithdrawal});

  final String goalKey;

  /// `true` = RÚT tiền về ví ("rút 2tr từ tiết kiệm") — dòng THU gắn cùng
  /// `goalId`, làm tiến độ mục tiêu giảm đúng số đó (xem
  /// `TransactionFormPrefill.forGoalWithdrawal`). `false` = cất vào.
  final bool isWithdrawal;
}

/// Một giao dịch được rút ra từ một đoạn tin nhắn — có thể có NHIỀU
/// [ParsedDraft] cho một tin nhắn (`segmenter.dart`). KHÔNG BAO GIỜ tự động
/// commit — luôn cần thẻ xác nhận sửa được ở tầng UI (Luật #7).
class ParsedDraft {
  const ParsedDraft({
    required this.rawText,
    required this.leftoverText,
    required this.amount,
    required this.date,
    required this.category,
    this.savings,
  });

  /// Đoạn gốc (đã cắt khỏi tin nhắn nhiều khoản, chưa chuẩn hoá) ứng với
  /// draft này — hiện lại nguyên văn khi parser "chưa hiểu" (Luật bố cục
  /// Phase 8: "giữ nguyên chữ gốc trong ô sửa được").
  final String rawText;

  /// Phần chữ còn lại sau khi trừ đi cụm số tiền + cụm ngày đã khớp — đây là
  /// tín hiệu nạp cho `category_matcher`, và cũng là thứ được ghi/tăng
  /// weight vào `category_keywords` mỗi khi Tony sửa danh mục (vòng lặp học,
  /// Phase 8) — nên giữ nguyên dấu tiếng Việt, không ascii-fold ở đây.
  final String leftoverText;

  /// `null` nghĩa là không tìm thấy số tiền — draft này phải render thành
  /// thẻ lỗi "Mình chưa hiểu" (Luật bố cục Phase 8), không phải bị âm thầm bỏ.
  final ParsedAmount? amount;

  final ParsedDate date;

  /// `null` nghĩa là không khớp danh mục nào — UI hiện "Chưa phân loại"
  /// (đã có sẵn từ Phase 6), không phải lỗi.
  ///
  /// LUÔN `null` khi [savings] khác `null`: một dòng để dành không thuộc
  /// danh mục nào cả (xem [SavingsMatch]), nên hai trường này loại trừ nhau.
  final CategoryMatch? category;

  /// Khác `null` khi câu nói rõ đây là tiền cất vào/rút ra một mục tiêu tiết
  /// kiệm (`savings_matcher.dart`) — lúc đó [category] bị bỏ qua hoàn toàn.
  final SavingsMatch? savings;

  /// Draft được coi là "đã hiểu" khi tìm thấy số tiền — ngày/danh mục thiếu
  /// vẫn hiển thị được (ngày mặc định hôm nay, danh mục "Chưa phân loại"),
  /// nhưng thiếu số tiền thì không có gì để lưu.
  bool get isUnderstood => amount != null;
}
