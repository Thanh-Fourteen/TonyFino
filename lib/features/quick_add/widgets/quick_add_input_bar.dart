import '../../../ui/amount_visibility.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/money/money.dart';
import '../../../core/router/app_bottom_nav.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/app_chip.dart';
import '../../../ui/glass_surface.dart';
import '../../settings/recurring/widgets/recurring_add_sheet.dart';
import '../../settings/settings_controller.dart';
import '../../wallets/widgets/transfer_sheet.dart';
import '../domain/parser/amount_evaluator.dart';
import '../domain/parser/normalizer.dart';
import '../domain/parser/tokenizer.dart';
import '../quick_add_providers.dart';
import 'cloud_fallback_consent_sheet.dart';

/// Thanh nhập ghim đáy trên `glass_surface` — nơi giành lấy cảm giác cao
/// cấp (Luật bố cục Phase 8).
///
/// **Xem trước số tiền khi đang gõ** dùng LẠI `amount_evaluator.dart` (Phase
/// 7) thay vì viết một bộ regex song song — cả hai đều "zero độ trễ, zero
/// LLM, zero mạng" (tinh thần thật của yêu cầu "thuần regex" trong prompt),
/// nhưng dùng lại engine đệ quy xuống thật tránh đúng cái bẫy đã ghi ở
/// `docs/decisions.md` § Phase 7: hai nơi cài cùng một luật, chỉ một nơi
/// đúng. Chạy trên mỗi lần gõ vẫn tức thời vì input là một câu ngắn.
class QuickAddInputBar extends ConsumerStatefulWidget {
  const QuickAddInputBar({super.key});

  @override
  ConsumerState<QuickAddInputBar> createState() => _QuickAddInputBarState();
}

class _QuickAddInputBarState extends ConsumerState<QuickAddInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _speech = SpeechToText();
  int? _ghostAmount;
  bool _hasText = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    // `cancel()` không `await` được trong `dispose()` (đồng bộ) — an toàn bỏ
    // qua kết quả, plugin tự dọn phiên nghe dở nếu widget bị huỷ giữa chừng.
    unawaited(_speech.cancel());
    super.dispose();
  }

  /// Nhập giọng nói (Phase 18) — chuyển giọng nói thành văn bản rồi đẩy
  /// THẲNG qua CHÍNH `sendMessage`/parser Phase 7 đã có, y hệt như vừa gõ
  /// tay rồi bấm gửi — "giọng nói chỉ là một cách gõ khác", không cần một
  /// lớp xác nhận riêng vì `sendMessage` tự nó đã luôn là "ghi lạc quan CÓ
  /// THỂ sửa qua chip", chưa từng "tự động commit không sửa được" (xem
  /// docs/decisions.md § Phase 18).
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      return;
    }

    final available = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Máy không hỗ trợ giọng nói hoặc chưa cấp quyền micro.',
          ),
        ),
      );
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: _onSpeechResult,
      listenOptions: SpeechListenOptions(
        localeId: 'vi_VN',
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  void _onSpeechStatus(String status) {
    if ((status == 'done' || status == 'notListening') && mounted) {
      setState(() => _isListening = false);
    }
  }

  /// Điền văn bản NHẬN ĐƯỢC (kể cả kết quả tạm thời — Tony thấy chữ hiện
  /// dần, đúng cảm giác đang được nghe) trực tiếp vào ô nhập — `_onChanged`
  /// (đã gắn từ `initState`) tự chạy theo, ghost số tiền cũng tự cập nhật
  /// sống trong lúc nói, không cần logic riêng ở đây. Kết quả CUỐI CÙNG mới
  /// tự gửi — kết quả tạm thời không bao giờ tự gửi dở dang.
  void _onSpeechResult(SpeechRecognitionResult result) {
    _controller.text = result.recognizedWords;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
      _send();
    }
  }

  void _onChanged() {
    final text = _controller.text;
    final hasText = text.trim().isNotEmpty;
    final normalized = normalize(text).diacritics;
    final match = findAmount(tokenize(normalized));
    final ghost = match?.amount.minorUnits;
    if (hasText != _hasText || ghost != _ghostAmount) {
      setState(() {
        _hasText = hasText;
        _ghostAmount = ghost;
      });
    }
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    final notifier = ref.read(quickAddControllerProvider.notifier);
    unawaited(_sendAndMaybeAskConsent(notifier, text));
    _controller.clear();
    setState(() {
      _hasText = false;
      _ghostAmount = null;
    });
    // Bàn phím KHÔNG BAO GIỜ tự đóng sau khi gửi (Luật bố cục Phase 8) — chỉ
    // xoá chữ, giữ focus.
    _focusNode.requestFocus();
  }

  /// Gửi trước (ghi lạc quan xảy ra ngay, không chờ gì ở đây — xem
  /// `QuickAddController.sendMessage`), rồi CHỈ SAU ĐÓ kiểm tra có thẻ nào
  /// vừa gửi cần cloud fallback (`amount == null`/`!confident`) mà Tony
  /// chưa từng được hỏi hay không (Phase 23, D8: "sheet đồng ý một lần hiện
  /// ra lần đầu gặp câu mơ hồ"). Đồng ý → bật cờ + thử lại NGAY đúng (các)
  /// thẻ đó qua fallback thật; từ chối → chỉ đánh dấu đã hỏi, hành vi giữ
  /// nguyên y hệt trước Phase 23 (sửa tay).
  Future<void> _sendAndMaybeAskConsent(
    QuickAddController notifier,
    String text,
  ) async {
    final messageId = await notifier.sendMessage(text);
    if (messageId == null || !mounted) return;

    final settings = ref.read(appSettingsProvider);
    if (settings.cloudFallbackConsentAsked) return;

    final message = ref
        .read(quickAddControllerProvider)
        .messages
        .where((m) => m.id == messageId)
        .firstOrNull;
    if (message == null) return;
    final needsFallbackCards = message.cards
        // Thẻ để dành bị `QuickAddController._tryFallback` từ chối (nó sẽ
        // xoá mất `goalId`), nên đừng hỏi Tony đồng ý gửi lên mây cho một
        // thẻ mà dù đồng ý cũng không có gì xảy ra.
        .where((c) => !c.isSavings && (!c.isUnderstood || !c.amountConfident))
        .toList(growable: false);
    if (needsFallbackCards.isEmpty) return;

    if (!mounted) return;
    final accepted = await showCloudFallbackConsentSheet(context);
    final settingsController = ref.read(appSettingsProvider.notifier);
    if (accepted == true) {
      await settingsController.setCloudFallbackEnabled(true);
      for (final card in needsFallbackCards) {
        unawaited(notifier.retryFallbackForCard(messageId, card.id));
      }
    } else {
      await settingsController.markCloudFallbackConsentDeclined();
    }
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentInputsProvider);

    // Bàn phím mở thì thanh nhập ghim NGAY TRÊN bàn phím (Scaffold cha tự
    // co body qua `resizeToAvoidBottomInset`, đây chỉ đệm phần safe-area
    // tĩnh) — bàn phím đóng thì đệm thêm chiều cao nav nổi của `AppShell`
    // (đằng nào cũng bị bàn phím che khi mở, không cần đệm hai lần).
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Padding(
      padding: EdgeInsets.only(
        left: context.space.screenHorizontal,
        right: context.space.screenHorizontal,
        bottom:
            MediaQuery.viewPaddingOf(context).bottom +
            context.space.sm +
            (keyboardOpen ? 0 : kBottomNavReservedHeight),
        top: context.space.xs,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chip hành động nhanh (Phase 25, `docs/rolly-uiux-research.md`
          // § B) — mở thẳng sheet chuyển quỹ/tạo định kỳ đã có sẵn từ NGAY
          // luồng chat, không bắt Tony rời màn quick-add vào Cài đặt trước.
          // `editable: false` — đây là NÚT hành động, không phải một giá trị
          // đang chờ sửa (khác ý nghĩa `AppChip` dùng ở thẻ xác nhận Phase 8).
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                AppChip(
                  label: 'Chuyển quỹ',
                  icon: const Icon(kIconSwapHoriz, size: 16),
                  editable: false,
                  onTap: () => showTransferSheet(context),
                ),
                SizedBox(width: context.space.xs),
                AppChip(
                  label: 'Định kỳ',
                  icon: const Icon(kIconEventRepeat, size: 16),
                  editable: false,
                  onTap: () => showRecurringAddSheet(context),
                ),
              ],
            ),
          ),
          SizedBox(height: context.space.xs),
          if (recent.isNotEmpty) ...[
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (context, index) =>
                    SizedBox(width: context.space.xs),
                itemBuilder: (context, index) {
                  final text = recent[index];
                  return AppChip(
                    label: text,
                    editable: false,
                    onTap: () => ref
                        .read(quickAddControllerProvider.notifier)
                        .sendMessage(text),
                  );
                },
              ),
            ),
            SizedBox(height: context.space.xs),
          ],
          GlassSurface(
            borderRadius: BorderRadius.circular(context.radii.full),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.space.lg,
                vertical: context.space.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        // Ví dụ hint DẠY LUÔN khả năng nhiều khoản một câu
                        // (Phase 25, đúc theo cách Rolly dạy cú pháp qua
                        // placeholder — `docs/rolly-uiux-research.md` § B)
                        // — trước đây chỉ có một khoản, không hiện được
                        // khả năng `segmenter.dart` đã hỗ trợ từ Phase 7.
                        hintText: _isListening
                            ? 'Đang nghe…'
                            : 'Cà phê 35k, xăng 50k…',
                        isDense: true,
                        // 🚨 Ghost số tiền là `suffix`, KHÔNG phải một lớp
                        // `Stack` đè lên ô nhập.
                        //
                        // Bản cũ đặt nó trong `Stack` căn phải với ghi chú
                        // "đừng che chữ đang gõ" — nhưng `Stack` không có
                        // cách nào bảo đảm điều đó: chữ gõ dài tới mép phải
                        // là chồng lên ghost, hai lớp chữ nằm đè nhau. Tony
                        // chụp đúng cảnh đó với câu "cafe 20k, bún 30k,
                        // cháo 50k, tiền điện".
                        //
                        // `suffix` CHIẾM CHỖ trong bố cục, nên phần nhập tự
                        // co lại và chữ không bao giờ chạy xuống dưới nó.
                        suffix: _ghostAmount == null
                            ? null
                            : Padding(
                                padding: EdgeInsets.only(
                                  left: context.space.sm,
                                ),
                                child: Text(
                                  AmountVisibility.mask(
                                    context,
                                    Money.vnd(_ghostAmount!).format(),
                                  ),
                                  style: context.money.moneySmall.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(width: context.space.xs),
                  AnimatedSwitcher(
                    duration: context.durations.sheet,
                    switchInCurve: Curves.easeOutCubic,
                    // Nút violet khi ĐANG NGHE cũng như khi có chữ để gửi —
                    // "tô đặc = đang hoạt động", nhất quán một quy ước màu
                    // thay vì thêm một icon "đang ghi âm" riêng.
                    child: IconButton(
                      key: ValueKey(_hasText || _isListening),
                      onPressed: _hasText ? _send : _toggleListening,
                      icon: Icon(_hasText ? kIconArrowUpward : kIconMic),
                      style: IconButton.styleFrom(
                        backgroundColor: (_hasText || _isListening)
                            ? context.scheme.primary
                            : Colors.transparent,
                        foregroundColor: (_hasText || _isListening)
                            ? context.scheme.onPrimary
                            : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
