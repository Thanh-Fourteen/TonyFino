import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/money/money.dart';
import '../../core/providers/database_providers.dart';
import '../../core/time/clock_provider.dart';
import '../../data/db/database.dart';
import '../../data/services/ai/tailnet_fallback.dart';
import '../settings/settings_controller.dart';
import '../transactions/transactions_providers.dart';
import 'domain/ai_parse_fallback.dart';
import 'domain/category_keyword_entries.dart';
import 'domain/models/session_draft_card.dart';
import 'domain/parser/parser.dart';

/// Bản mặc định của Phase 8 — `NoopFallback` khi `cloudFallbackEnabled` còn
/// tắt (mặc định, D8). Bật lên thì đổi sang `TailnetFallback` thật — chỉ
/// `ref.watch` ở ĐÂY, KHÔNG động vào `QuickAddController` (đây là `Provider`
/// thường, không phải `Notifier.build()`, nên `ref.watch` tính lại giá trị
/// khi settings/danh mục đổi là hành vi ĐÚNG và AN TOÀN — khác hẳn cái bẫy
/// "watch trong Notifier.build() xoá sạch state phiên" đã ghi ở Phase 8/9,
/// class đó chỉ áp dụng cho `Notifier`, provider này không giữ state gì).
final aiParseFallbackProvider = Provider<AiParseFallback>((ref) {
  final settings = ref.watch(appSettingsProvider);
  if (!settings.cloudFallbackEnabled) return const NoopFallback();
  final categories = ref.watch(categoriesProvider).value ?? const [];
  return TailnetFallback(
    baseUrl: settings.aiFallbackBaseUrl,
    categories: categories,
  );
});

/// Toàn bộ từ khoá sống (seed + đã học) chuyển sang `CategoryKeywordEntry`
/// cho `category_matcher.dart` (Phase 7, không phụ thuộc DB) — `categoryKey`
/// = `categoryId.toString()` vì v1 chưa có màn đổi/xoá danh mục nên id ổn
/// định suốt vòng đời (xem doc comment `CategoryRepository.watchAllKeywords`).
final categoryKeywordEntriesProvider =
    StreamProvider<List<CategoryKeywordEntry>>((ref) {
      // 🚨 TÊN của một danh mục LÀ từ khoá mạnh nhất của chính nó.
      //
      // Tony có danh mục "Giặt đồ" (nhập từ Rolly, không kèm từ khoá nào),
      // nhưng gõ "giặt đồ 50k" lại ra Nhà cửa — vì `giặt đồ` là từ khoá
      // SEED của Nhà cửa, còn danh mục cùng tên thì không có từ khoá nào để
      // cạnh tranh. Không thứ gì có thể là tín hiệu mạnh hơn việc câu văn
      // chứa ĐÚNG TÊN một danh mục đang có, nên tên được gán trọng số 2.0 —
      // cao hơn mọi từ khoá seed (tối đa 1.3), đủ để thắng dứt khoát.
      //
      // Áp cho MỌI danh mục, không riêng danh mục Tony tự tạo: đó cũng là
      // hành vi đúng cho danh mục mặc định (gõ "giáo dục 2tr" thì vào Giáo
      // dục, không cần ai thêm từ khoá tay).
      final categories = ref.watch(categoriesProvider).value ?? const [];
      return ref
          .watch(categoryRepositoryProvider)
          .watchAllKeywords()
          .map(
            (rows) => buildCategoryKeywordEntries(
              categories: categories,
              keywordRows: rows,
            ),
          );
    });

const _recentInputsKey = 'tonyfino_quick_add_recent_inputs';
const _recentInputsMax = 5;

/// 5 mục nhập gần nhất — chip gợi ý phía trên thanh nhập (Luật bố cục
/// Phase 8). Không phải dữ liệu tài chính (khác `transactions`), lưu bằng
/// `shared_preferences` giống `AppSettingsController`.
class RecentInputsController extends Notifier<List<String>> {
  final _prefs = SharedPreferencesAsync();

  @override
  List<String> build() {
    unawaited(_load());
    return const [];
  }

  Future<void> _load() async {
    final raw = await _prefs.getString(_recentInputsKey);
    if (raw == null) return;
    final decoded = (jsonDecode(raw) as List).cast<String>();
    state = decoded;
  }

  Future<void> add(String text) async {
    final next = [text, ...state.where((t) => t != text)];
    state = next.take(_recentInputsMax).toList(growable: false);
    await _prefs.setString(_recentInputsKey, jsonEncode(state));
  }
}

final recentInputsProvider =
    NotifierProvider<RecentInputsController, List<String>>(
      RecentInputsController.new,
    );

/// "Hôm nay" cho việc format nhãn ngày ở widget — qua `Clock` inject (Luật
/// #3), KHÔNG BAO GIỜ `DateTime.now()` trực tiếp trong `lib/features/`.
final quickAddNowForLabelsProvider = Provider<DateTime>((ref) {
  return ref.watch(clockProvider).now();
});

class QuickAddState {
  const QuickAddState({this.messages = const []});

  /// Mới nhất trước — khớp `CustomScrollView(reverse: true)`, index 0 vẽ ở
  /// đáy màn hình.
  final List<SentMessage> messages;
}

/// Bộ não màn chat: gõ → parse cục bộ ngay → ghi lạc quan từng thẻ hiểu
/// được → hẹn giờ co lại sau 6 giây. KHÔNG có nút xác nhận nào ở đây — mọi
/// write xảy ra ngay trong `sendMessage`.
class QuickAddController extends Notifier<QuickAddState> {
  var _idCounter = 0;

  @override
  QuickAddState build() {
    // BẮT BUỘC giữ subscription của `categoryKeywordEntriesProvider` SỐNG
    // (không phải `read` — Riverpod 3 TỰ TẠM DỪNG `StreamProvider` khi không
    // ai đang "actively listen" nó, `sendMessage` bên dưới chỉ
    // `ref.read(...).value`, không tự tạo listener sống — thiếu dòng này thì
    // stream `category_keywords` không bao giờ thật sự chảy dữ liệu, mọi
    // danh mục khớp được sẽ luôn ra `null` âm thầm — bug thật bắt được trên
    // thiết bị thật, xem `docs/decisions.md` § Phase 8).
    //
    // NHƯNG PHẢI `ref.listen`, TUYỆT ĐỐI KHÔNG `ref.watch`: `watch` bên
    // trong `build()` của một `Notifier` khiến Riverpod HUỶ VÀ DỰNG LẠI
    // TOÀN BỘ instance này mỗi khi `category_keywords` phát giá trị mới —
    // và vòng lặp học (`correctCategory`) GHI vào chính bảng đó ở MỌI lần
    // sửa danh mục, nên `watch` sẽ xoá sạch `state.messages` (mọi thẻ chờ/
    // lỗi của phiên hiện tại) ngay sau lần sửa danh mục ĐẦU TIÊN trong bất
    // kỳ tin nhắn nào — bug thật, nghiêm trọng hơn cả bug `null` ở trên,
    // bắt được khi viết importer Phase 9 (cùng lớp lỗi, xem
    // `docs/decisions.md` § Phase 9). `ref.listen` giữ subscription sống y
    // hệt `watch` nhưng KHÔNG kích hoạt lại `build()` khi giá trị đổi.
    ref.listen(categoryKeywordEntriesProvider, (_, _) {});
    return const QuickAddState();
  }

  String _nextId(String prefix) => '$prefix-${_idCounter++}';

  /// Trả về id tin nhắn vừa tạo (`null` nếu không có gì để gửi) — dùng ở
  /// `QuickAddInputBar` để kiểm tra sau khi gửi có thẻ nào cần sheet đồng ý
  /// cloud fallback lần đầu hay không (Phase 23), KHÔNG đổi hành vi ghi lạc
  /// quan/undo có sẵn của hàm này.
  Future<String?> sendMessage(String rawText) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return null;

    final clock = ref.read(clockProvider);
    final keywords = ref.read(categoryKeywordEntriesProvider).value ?? const [];
    final drafts = parseMessage(
      trimmed,
      clock: clock,
      categoryKeywords: keywords,
    );
    if (drafts.isEmpty) return null;

    final cards = [
      for (final draft in drafts)
        SessionDraftCard.fromDraft(
          id: _nextId('card'),
          draft: draft,
          categoryId: draft.category == null
              ? null
              : int.tryParse(draft.category!.categoryKey),
        ),
    ];

    final message = SentMessage(
      id: _nextId('msg'),
      rawText: trimmed,
      sentAt: clock.now(),
      cards: cards,
    );
    state = QuickAddState(messages: [message, ...state.messages]);
    unawaited(ref.read(recentInputsProvider.notifier).add(trimmed));

    // "Hiểu nhưng không chắc" (Luật #7 vẫn ghi lạc quan NGAY — không chờ
    // mạng) VÀ "chưa hiểu" (không có gì để ghi trước) đều đủ điều kiện thử
    // fallback (D8/Phase 23: `amount == null` HOẶC `!confident`) — chạy nền,
    // không chặn ghi lạc quan của thẻ đã hiểu.
    for (final card in cards) {
      if (card.isUnderstood) {
        unawaited(_saveCard(message.id, card.id));
        if (!card.amountConfident) {
          unawaited(_tryFallback(message.id, card.id));
        }
      } else {
        unawaited(_tryFallback(message.id, card.id));
      }
    }
    return message.id;
  }

  /// Chỉ gọi khi parser cục bộ không chắc (`amount == null` hoặc
  /// `!confident`) — D8/Phase 23 quyết định khi nào có bản thật;
  /// `NoopFallback` (cloud fallback tắt, mặc định) luôn trả `null` nên đây
  /// là no-op an toàn khi tính năng chưa bật. Public — `QuickAddInputBar`
  /// gọi lại hàm này SAU KHI Tony đồng ý ở sheet lần đầu, cho đúng thẻ vừa
  /// kích hoạt sheet (Phase 23).
  Future<void> retryFallbackForCard(String messageId, String cardId) =>
      _tryFallback(messageId, cardId);

  Future<void> _tryFallback(String messageId, String cardId) async {
    final before = _findCard(messageId, cardId);
    if (before == null) return;
    if (before.isUnderstood && before.amountConfident) return;

    final fallback = ref.read(aiParseFallbackProvider);
    final clock = ref.read(clockProvider);
    final improved = await fallback.tryParse(before.rawText, clock: clock);
    if (improved == null || improved.isEmpty) return;

    final best = improved.first;
    if (best.amount == null) return;

    // Đọc lại NGAY TRƯỚC khi ghi — thẻ có thể đã đổi (Tony sửa tay, hoàn
    // tác…) trong lúc chờ mạng.
    final current = _findCard(messageId, cardId);
    if (current == null) return;
    final wasSaved = current.isSaved;
    final savedTransactionId = current.savedTransactionId;
    final savedAt = current.savedAt;
    // Tony đã TỰ TAY xác nhận danh mục trong lúc chờ mạng → không ghi đè
    // lựa chọn đó, chỉ áp dụng phần số tiền/ngày AI cải thiện được.
    final keepUserCategory = current.categoryConfirmed;

    _updateCard(messageId, cardId, (c) {
      final merged = SessionDraftCard.fromDraft(
        id: c.id,
        draft: best,
        categoryId: keepUserCategory
            ? c.categoryId
            : (best.category == null
                  ? null
                  : int.tryParse(best.category!.categoryKey)),
      );
      final withCategoryFlag = keepUserCategory
          ? merged.copyWith(categoryConfirmed: true)
          : merged;
      return wasSaved
          ? withCategoryFlag.copyWith(
              savedTransactionId: savedTransactionId,
              savedAt: savedAt,
            )
          : withCategoryFlag;
    });

    final refreshed = _findCard(messageId, cardId);
    if (refreshed == null || !refreshed.isUnderstood) return;
    if (wasSaved) {
      await ref
          .read(transactionRepositoryProvider)
          .update(
            id: refreshed.savedTransactionId!,
            amount: _resolveMoney(refreshed),
            occurredAt: refreshed.date,
            updatedAt: ref.read(clockProvider).now(),
            categoryId: refreshed.categoryId,
            note: refreshed.leftoverText.isEmpty
                ? null
                : refreshed.leftoverText,
          );
    } else {
      unawaited(_saveCard(messageId, cardId));
    }
  }

  Future<void> _saveCard(String messageId, String cardId) async {
    final card = _findCard(messageId, cardId);
    if (card == null || !card.isUnderstood) return;

    final repo = ref.read(transactionRepositoryProvider);
    // Quick-add không có bộ chọn ví (ngoài phạm vi Phase 13 — xem
    // docs/decisions.md § Phase 13 "Ví/danh mục mặc định cho quick-add") —
    // luôn ghi vào ví mặc định (id nhỏ nhất).
    final walletId = await ref.read(walletRepositoryProvider).defaultWalletId();
    final result = await repo.insert(
      amount: _resolveMoney(card),
      occurredAt: card.date,
      walletId: walletId,
      categoryId: card.categoryId,
      note: card.leftoverText.isEmpty ? null : card.leftoverText,
    );
    result.when(
      ok: (id) {
        final savedAt = ref.read(clockProvider).now();
        _updateCard(
          messageId,
          cardId,
          (c) => c.copyWith(savedTransactionId: id, savedAt: savedAt),
        );
      },
      // Lỗi ghi DB cục bộ thật sự hiếm (không phải lỗi mạng) — không có UI
      // riêng cho ca này ở v1; thẻ giữ nguyên chưa lưu, người dùng thấy
      // thiếu "✓ Đã lưu" và có thể thử gửi lại.
      err: (_) {},
    );
  }

  /// Số tiền có DẤU cho write vào drift — hướng thu/chi lấy từ
  /// `Categories.kind` của danh mục đã khớp/chọn (mặc định CHI nếu chưa có
  /// danh mục, đúng vì ~90% giao dịch cá nhân là chi — xem design system
  /// § Màu, luật màu #2).
  Money _resolveMoney(SessionDraftCard card) {
    final categories = ref.read(categoriesProvider).value ?? const [];
    Category? category;
    for (final c in categories) {
      if (c.id == card.categoryId) {
        category = c;
        break;
      }
    }
    final isIncome = category?.kind == 'income';
    final magnitude = card.amountMinor!;
    return Money.vnd(isIncome ? magnitude : -magnitude);
  }

  Future<void> correctCategory(
    String messageId,
    String cardId,
    int newCategoryId,
  ) async {
    final before = _findCard(messageId, cardId);
    if (before == null) return;

    _updateCard(
      messageId,
      cardId,
      (c) => c.copyWith(categoryId: newCategoryId, categoryConfirmed: true),
    );

    // 🚨 KHÔNG học âm thầm ở đây nữa.
    //
    // Trước bản này, mỗi lần sửa danh mục là cả cụm `leftoverText` bị ghi
    // ngay vào `category_keywords` mà Tony không hề biết — sửa nhầm một lần
    // là app âm thầm nhớ cái sai, và không có chỗ nào xem hay gỡ. Giờ
    // `DraftCard` hỏi ("Nhớ … ?") rồi mới gọi [learnFromCorrection]; không
    // bấm gì = không học gì.

    final after = _findCard(messageId, cardId);
    if (after != null && after.isSaved) {
      await ref
          .read(transactionRepositoryProvider)
          .update(
            id: after.savedTransactionId!,
            amount: _resolveMoney(after),
            occurredAt: after.date,
            updatedAt: ref.read(clockProvider).now(),
            categoryId: after.categoryId,
            note: after.leftoverText.isEmpty ? null : after.leftoverText,
          );
    }
  }

  /// Ghi nhận vòng lặp học SAU KHI người dùng đồng ý ở snackbar/sheet —
  /// mỗi phần tử [keywords] là một tín hiệu độc lập (xem
  /// `CategoryRepository.learnKeywords`).
  Future<void> learnFromCorrection({
    required int categoryId,
    required List<String> keywords,
  }) async {
    if (keywords.isEmpty) return;
    await ref
        .read(categoryRepositoryProvider)
        .learnKeywords(categoryId: categoryId, keywords: keywords);
  }

  Future<void> correctDate(
    String messageId,
    String cardId,
    DateTime newDate,
  ) async {
    _updateCard(
      messageId,
      cardId,
      (c) => c.copyWith(date: newDate, dateExplicit: true),
    );
    final after = _findCard(messageId, cardId);
    if (after != null && after.isSaved) {
      await ref
          .read(transactionRepositoryProvider)
          .update(
            id: after.savedTransactionId!,
            amount: _resolveMoney(after),
            occurredAt: after.date,
            updatedAt: ref.read(clockProvider).now(),
            categoryId: after.categoryId,
            note: after.leftoverText.isEmpty ? null : after.leftoverText,
          );
    }
  }

  /// "Hoàn tác" trên MỘT thẻ — xoá giao dịch thật (nếu đã lưu) và gỡ thẻ
  /// khỏi tin nhắn; tin nhắn không còn thẻ nào thì biến mất luôn.
  Future<void> undoCard(String messageId, String cardId) async {
    final card = _findCard(messageId, cardId);
    if (card?.savedTransactionId != null) {
      await ref
          .read(transactionRepositoryProvider)
          .delete(card!.savedTransactionId!);
    }
    _removeCard(messageId, cardId);
  }

  /// Sửa từ thẻ lỗi ("Mình chưa hiểu"): người dùng gõ lại chữ + tự nhập số
  /// tiền → ghép lại thành MỘT chuỗi rồi chạy lại parser cục bộ (để vẫn suy
  /// ra được ngày/danh mục từ phần chữ, không chỉ nuốt mỗi số tiền tay gõ).
  /// Thành công thì thẻ chuyển hẳn sang "hiểu" và ghi lạc quan như bình thường.
  Future<void> retryUnderstoodCard(
    String messageId,
    String cardId,
    String editedText,
    int manualAmountMinor,
  ) async {
    final combinedText = '$editedText $manualAmountMinorđ';
    final clock = ref.read(clockProvider);
    final keywords = ref.read(categoryKeywordEntriesProvider).value ?? const [];
    final drafts = parseMessage(
      combinedText,
      clock: clock,
      categoryKeywords: keywords,
    );
    if (drafts.isEmpty) return;
    final draft = drafts.first;
    if (draft.amount == null) return;

    final newCard = SessionDraftCard.fromDraft(
      id: cardId,
      draft: draft,
      categoryId: draft.category == null
          ? null
          : int.tryParse(draft.category!.categoryKey),
    );
    _replaceCard(messageId, cardId, newCard);
    unawaited(_saveCard(messageId, cardId));
  }

  /// "Hoàn tác tất cả" — nhiều giao dịch một tin nhắn (Luật bố cục Phase 8).
  Future<void> undoAllInMessage(String messageId) async {
    final message = state.messages.where((m) => m.id == messageId).firstOrNull;
    if (message == null) return;
    for (final card in message.cards) {
      await undoCard(messageId, card.id);
    }
  }

  SessionDraftCard? _findCard(String messageId, String cardId) {
    for (final message in state.messages) {
      if (message.id != messageId) continue;
      for (final card in message.cards) {
        if (card.id == cardId) return card;
      }
    }
    return null;
  }

  void _updateCard(
    String messageId,
    String cardId,
    SessionDraftCard Function(SessionDraftCard) update,
  ) {
    state = QuickAddState(
      messages: [
        for (final message in state.messages)
          if (message.id == messageId)
            message.copyWithCards([
              for (final card in message.cards)
                if (card.id == cardId) update(card) else card,
            ])
          else
            message,
      ],
    );
  }

  void _replaceCard(String messageId, String cardId, SessionDraftCard newCard) {
    state = QuickAddState(
      messages: [
        for (final message in state.messages)
          if (message.id == messageId)
            message.copyWithCards([
              for (final card in message.cards)
                if (card.id == cardId) newCard else card,
            ])
          else
            message,
      ],
    );
  }

  void _removeCard(String messageId, String cardId) {
    state = QuickAddState(
      messages: [
        for (final message in state.messages)
          if (message.id == messageId)
            message.copyWithCards([
              for (final card in message.cards)
                if (card.id != cardId) card,
            ])
          else
            message,
      ].where((m) => m.cards.isNotEmpty).toList(growable: false),
    );
  }
}

final quickAddControllerProvider =
    NotifierProvider<QuickAddController, QuickAddState>(QuickAddController.new);

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
