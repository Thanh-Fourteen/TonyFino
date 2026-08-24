import '../parser/parser.dart';

/// Trạng thái hiển thị của một thẻ trong phiên hiện tại — đúng 3 trạng thái
/// golden test yêu cầu: **chờ** (vừa lưu, còn "Hoàn tác" ~6 giây, chip cỡ
/// đầy đủ) → **đã lưu** (co lại, chip chữ thường) sau 6 giây, hoặc **không
/// hiểu** (không tìm thấy số tiền — không có gì để lưu).
enum SessionCardVisualState { pending, saved, error }

/// Một thẻ xác nhận trong phiên chat hiện tại — sinh ra từ một [ParsedDraft]
/// (Phase 7) rồi có thể bị NGƯỜI DÙNG sửa danh mục/ngày qua chip (không sửa
/// được ở đây: mở sheet sửa đầy đủ qua nhấn giữ → "Sửa"). Bất biến, thay
/// bằng `copyWith` — `QuickAddController` là nơi duy nhất cập nhật state.
class SessionDraftCard {
  const SessionDraftCard({
    required this.id,
    required this.rawText,
    required this.leftoverText,
    required this.amountMinor,
    required this.amountConfident,
    required this.categoryId,
    required this.categoryConfirmed,
    required this.date,
    required this.dateExplicit,
    this.savedTransactionId,
    this.savedAt,
  });

  /// Khoá cục bộ trong phiên — KHÔNG phải id DB (thẻ lỗi chẳng hạn không có
  /// id DB nào cả).
  final String id;

  /// Nguyên văn đoạn ứng với thẻ này (một tin nhắn có thể tách nhiều đoạn —
  /// `segmenter.dart`, Phase 7) — hiện lại y nguyên ở thẻ lỗi (Luật bố cục
  /// Phase 8: "giữ nguyên chữ gốc trong ô sửa được").
  final String rawText;

  /// Phần chữ còn lại sau khi trừ số tiền + ngày — nạp cho vòng lặp học khi
  /// người dùng sửa danh mục (`CategoryRepository.recordKeywordCorrection`).
  final String leftoverText;

  /// `null` = thẻ lỗi ("Mình chưa hiểu") — không có gì để lưu.
  final int? amountMinor;
  final bool amountConfident;

  /// `null` = chưa khớp danh mục nào ("Chưa phân loại", chip render kiểu
  /// chưa-xác-nhận cho tới khi người dùng chọn tay).
  final int? categoryId;

  /// `true` nếu người dùng đã TỰ TAY chọn qua chip (dù chọn lại đúng cái
  /// parser đã đoán) — chip hết hiện viền/mờ/`?` ngay khi này thành `true`.
  final bool categoryConfirmed;

  final DateTime date;

  /// Từ `ParsedDate.explicit` (Phase 7) hoặc `true` sau khi người dùng tự
  /// chọn ngày qua chip — mặc định về hôm nay khi parser không thấy cụm
  /// ngày nào VẪN LÀ MỘT PHỎNG ĐOÁN (dù thường đúng), nên vẫn render chip
  /// kiểu chưa-xác-nhận cho tới khi `true`.
  final bool dateExplicit;

  /// `null` cho tới khi ghi lạc quan vào drift xong (Luật #4 UI — ghi ngay,
  /// không nút xác nhận) — id giao dịch thật, dùng để `update()`/`delete()`
  /// khi người dùng sửa chip hoặc "Hoàn tác".
  final int? savedTransactionId;

  /// Mốc lưu — thẻ hiện "chờ" (còn Hoàn tác) trong 6 giây kể từ đây rồi tự
  /// co lại thành "đã lưu".
  final DateTime? savedAt;

  bool get isUnderstood => amountMinor != null;
  bool get isSaved => savedTransactionId != null;

  SessionDraftCard copyWith({
    int? categoryId,
    bool? categoryConfirmed,
    DateTime? date,
    bool? dateExplicit,
    int? savedTransactionId,
    DateTime? savedAt,
  }) {
    return SessionDraftCard(
      id: id,
      rawText: rawText,
      leftoverText: leftoverText,
      amountMinor: amountMinor,
      amountConfident: amountConfident,
      categoryId: categoryId ?? this.categoryId,
      categoryConfirmed: categoryConfirmed ?? this.categoryConfirmed,
      date: date ?? this.date,
      dateExplicit: dateExplicit ?? this.dateExplicit,
      savedTransactionId: savedTransactionId ?? this.savedTransactionId,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  factory SessionDraftCard.fromDraft({
    required String id,
    required ParsedDraft draft,
    required int? categoryId,
  }) {
    return SessionDraftCard(
      id: id,
      rawText: draft.rawText,
      leftoverText: draft.leftoverText,
      amountMinor: draft.amount?.minorUnits,
      amountConfident: draft.amount?.confident ?? false,
      categoryId: categoryId,
      categoryConfirmed: false,
      date: draft.date.date,
      dateExplicit: draft.date.explicit,
    );
  }
}

/// Một tin nhắn đã gửi trong phiên hiện tại, kèm mọi thẻ tách ra từ nó
/// (`segmenter.dart` có thể tách một tin nhắn thành nhiều thẻ).
class SentMessage {
  const SentMessage({
    required this.id,
    required this.rawText,
    required this.sentAt,
    required this.cards,
  });

  final String id;
  final String rawText;
  final DateTime sentAt;
  final List<SessionDraftCard> cards;

  SentMessage copyWithCards(List<SessionDraftCard> cards) {
    return SentMessage(id: id, rawText: rawText, sentAt: sentAt, cards: cards);
  }
}
