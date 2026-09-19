import 'package:drift/drift.dart' show Value;
import '../../ui/amount_visibility.dart';
import '../../ui/grouped_number_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/money/money.dart';
import '../../core/providers/database_providers.dart';
import '../../core/time/clock_provider.dart';
import '../../data/db/database.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/services/receipt_image_service.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/app_bottom_sheet.dart';
import '../../ui/app_chip.dart';
import '../../ui/category_avatar.dart';
import '../../ui/two_level_category_picker.dart';
import '../../ui/two_level_category_picker_sheet.dart';
import '../savings/savings_providers.dart';
import '../tags/tags_providers.dart';
import '../wallets/wallets_providers.dart';
import 'day_label.dart';
import 'transactions_providers.dart';

/// Số tiền/danh mục/ghi chú/ví SẴN CÓ để mở sheet Thêm (KHÔNG phải sheet
/// Sửa) — dùng chung cho "Nhân đôi" (Phase 6/14) và "Áp dụng mẫu" (Phase 14):
/// cả hai đều là "tạo một giao dịch MỚI, điền sẵn để chỉnh trước khi lưu
/// thật", chỉ khác nguồn snapshot. Ngày LUÔN là hôm nay (không nằm trong
/// prefill) — xem `TransactionFormSheetState.initState`.
class TransactionFormPrefill {
  const TransactionFormPrefill({
    this.amountMinor,
    this.categoryId,
    this.note,
    this.walletId,
    this.goalId,
    this.goalName,
    this.debtId,
    this.debtName,
    this.isExpenseHint,
    this.receiptImageBytes,
    this.receiptImageExtension,
  });

  factory TransactionFormPrefill.fromTransaction(Transaction transaction) =>
      TransactionFormPrefill(
        amountMinor: transaction.amountMinor,
        categoryId: transaction.categoryId,
        note: transaction.note,
        walletId: transaction.walletId,
      );

  factory TransactionFormPrefill.fromTemplate(TransactionTemplate template) =>
      TransactionFormPrefill(
        amountMinor: template.amountMinor,
        categoryId: template.categoryId,
        note: template.note,
      );

  /// "Trả/Thu" cho một khoản vay/cho vay (Phase 16) — mặc định CHI nếu
  /// [isDebtIOwe] (mình trả nợ), THU nếu không (mình thu tiền cho vay).
  factory TransactionFormPrefill.forDebtContribution({
    required int debtId,
    required String debtName,
    required bool isDebtIOwe,
  }) => TransactionFormPrefill(
    debtId: debtId,
    debtName: debtName,
    isExpenseHint: isDebtIOwe,
  );

  /// Quét hoá đơn OCR (Phase 18) — [amountMinor]/[note] là GỢI Ý trích từ
  /// `receipt_ocr_parser.dart`, có thể `null` nếu không trích được (form vẫn
  /// mở, chỉ trống hơn, KHÔNG bao giờ tự lưu — Luật #7). Đính kèm luôn
  /// [receiptImageBytes] (chính ảnh vừa chụp/chọn để quét) làm ảnh hoá đơn
  /// của giao dịch — tái dùng đúng cơ chế "ảnh mới, chưa ghi đĩa cho tới khi
  /// Lưu" của Phase 17 (`TransactionFormSheetState._newImageBytes`), không
  /// cần Tony đính kèm lại lần hai chính tấm ảnh vừa quét.
  factory TransactionFormPrefill.fromReceiptScan({
    required int? amountMinor,
    required String? merchantName,
    required Uint8List receiptImageBytes,
    required String receiptImageExtension,
  }) => TransactionFormPrefill(
    amountMinor: amountMinor,
    note: merchantName,
    isExpenseHint: true,
    receiptImageBytes: receiptImageBytes,
    receiptImageExtension: receiptImageExtension,
  );

  final int? amountMinor;
  final int? categoryId;
  final String? note;
  final int? walletId;
  final int? goalId;
  final String? goalName;
  final int? debtId;
  final String? debtName;

  /// Ghi đè "Chi"/"Thu" mặc định khi [amountMinor] không có (form không suy
  /// được dấu từ đâu khác) — `null` giữ hành vi cũ (mặc định "Chi").
  final bool? isExpenseHint;

  final Uint8List? receiptImageBytes;
  final String? receiptImageExtension;
}

/// Form thêm/sửa dạng BOTTOM SHEET (không phải trang mới, Luật bố cục). Nút
/// Lưu nằm NGOÀI phần cuộn được, ở cuối `Column` của chính sheet — sheet đã
/// tự cộng `viewInsets.bottom` (bàn phím) vào đệm đáy (`showAppBottomSheet`,
/// Phase 5) nên nút luôn nổi TRÊN bàn phím, không bị nav bar/bàn phím che —
/// đây chính là than phiền #3 về Rolly ("form sửa thiếu nút Save").
Future<void> showTransactionFormSheet({
  required BuildContext context,
  TransactionWithCategory? existing,
  TransactionFormPrefill? prefill,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (sheetContext) =>
        TransactionFormSheet(existing: existing, prefill: prefill),
  );
}

/// "Nhân đôi" (Phase 8, viết lại ở Phase 14) — MỞ sheet Thêm điền sẵn số
/// tiền/danh mục/ghi chú của bản gốc, ngày = hôm nay, để chỉnh trước khi lưu
/// thật — KHÔNG còn tự động ghi + Hoàn tác như bản Phase 8 cũ (xem
/// docs/decisions.md § Phase 14 "Nhân đôi giao dịch").
Future<void> openDuplicateTransactionSheet(
  BuildContext context,
  Transaction transaction,
) {
  return showTransactionFormSheet(
    context: context,
    prefill: TransactionFormPrefill.fromTransaction(transaction),
  );
}

class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({super.key, this.existing, this.prefill});

  final TransactionWithCategory? existing;
  final TransactionFormPrefill? prefill;

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      TransactionFormSheetState();
}

class _LineDraft {
  _LineDraft({this.categoryId, String amountText = ''})
    : amountController = TextEditingController(text: amountText);

  int? categoryId;
  final TextEditingController amountController;

  void dispose() => amountController.dispose();
}

class TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  late bool _isExpense;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  int? _selectedCategoryId;
  int? _selectedWalletId;
  late DateTime _date;
  bool _saving = false;
  String? _amountError;
  final List<_LineDraft> _lines = [];
  bool _linesLoaded = false;
  int? _goalId;
  String? _goalName;
  int? _debtId;
  String? _debtName;
  Set<int> _tagIds = {};
  bool _tagsLoaded = false;
  String? _existingReceiptImageFilename;
  Uint8List? _newImageBytes;
  String? _newImageExtension;
  bool _imageRemoved = false;
  static const _receiptImages = ReceiptImageService();

  bool get _isEditing => widget.existing != null;
  bool get _hasImage =>
      _newImageBytes != null ||
      (_existingReceiptImageFilename != null && !_imageRemoved);
  bool get _isSplit => _lines.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing?.transaction;
    final prefill = widget.prefill;
    final seedAmountMinor = existing?.amountMinor ?? prefill?.amountMinor;
    // 🚨 Chiều tiền: SỬA thì suy từ dấu, ĐIỀN SẴN thì theo gợi ý.
    //
    // Giao dịch đang sửa mang dấu thật trong `amountMinor` nên dấu là nguồn
    // đúng. Nhưng số tiền ĐIỀN SẴN là ĐỘ LỚN (dương) — `extractReceiptInfo`
    // trả 414000 chứ không phải -414000 — nên nhánh "suy từ dấu" biến mọi
    // hoá đơn quét được thành khoản THU. Quét hoá đơn Emart thật của Tony ra
    // "Thu 414.000đ": đúng số, sai hẳn chiều.
    _isExpense = existing != null
        ? existing.amountMinor < 0
        : (prefill?.isExpenseHint ?? true);
    _amountController = TextEditingController(
      text: seedAmountMinor == null
          ? ''
          : groupDigits(seedAmountMinor.abs().toString()),
    );
    _noteController = TextEditingController(
      text: existing?.note ?? prefill?.note ?? '',
    );
    _selectedCategoryId = existing?.categoryId ?? prefill?.categoryId;
    _selectedWalletId = existing?.walletId ?? prefill?.walletId;
    _date = existing?.occurredAt ?? ref.read(clockProvider).now();
    // Gắn kết mục tiêu/khoản vay (Phase 16) — CARRY qua nguyên trạng, không
    // có UI đổi/tháo gắn kết ở form này (chỉ đọc từ giao dịch đang sửa hoặc
    // từ prefill "Đóng góp"/"Trả nợ"), tránh scope creep một bộ chọn đầy đủ
    // mà đặc tả Phase 16 không yêu cầu.
    _goalId = existing?.goalId ?? prefill?.goalId;
    // Tên quỹ chỉ để HIỆN. Prefill mang sẵn tên khi mở từ màn Quỹ; khi Tony
    // mở một khoản nạp quỹ CŨ từ danh sách thì không có prefill nào cả, nên
    // phải tra ngược từ `goalId` (xem `_resolveGoalName`). Trước đây dòng này
    // chỉ đọc prefill, nên sửa một khoản quỹ từ danh sách là mất sạch dấu vết
    // quỹ: không dòng "Gắn với …", lại còn mời chọn danh mục.
    _debtId = existing?.debtId ?? prefill?.debtId;
    _debtName = prefill?.debtName;
    _existingReceiptImageFilename = existing?.receiptImageFilename;
    // Quét hoá đơn (Phase 18) — ảnh vừa quét đã có sẵn trong prefill, coi
    // như Tony vừa tự đính kèm nó qua "Đính kèm ảnh" (cùng đường ghi đĩa lúc
    // Lưu, xem `_save()`), không cần một cơ chế riêng.
    _newImageBytes = prefill?.receiptImageBytes;
    _newImageExtension = prefill?.receiptImageExtension;

    if (existing != null) {
      _loadExistingLines(existing.id);
      _loadExistingTags(existing.id);
    } else {
      _linesLoaded = true;
      _tagsLoaded = true;
    }
  }

  Future<void> _loadExistingTags(int transactionId) async {
    final tags = await ref
        .read(tagRepositoryProvider)
        .getForTransaction(transactionId);
    if (!mounted) return;
    setState(() {
      _tagIds = tags.map((t) => t.id).toSet();
      _tagsLoaded = true;
    });
  }

  Future<void> _loadExistingLines(int transactionId) async {
    final lines = await ref
        .read(transactionRepositoryProvider)
        .getLinesFor(transactionId);
    if (!mounted) return;
    setState(() {
      _lines.addAll([
        for (final line in lines)
          _LineDraft(
            categoryId: line.categoryId,
            amountText: line.amountMinor.abs().toString(),
          ),
      ]);
      _linesLoaded = true;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = ref.read(clockProvider).now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) {
      setState(
        () => _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
        ),
      );
    }
  }

  void _addLine() {
    setState(() => _lines.add(_LineDraft()));
  }

  void _removeLine(int index) {
    setState(() => _lines.removeAt(index).dispose());
  }

  /// Bỏ tách — xoá hết dòng con nháp, quay về chọn MỘT danh mục cho cả giao
  /// dịch (dùng lại [_selectedCategoryId] hiện có, nếu có).
  void _stopSplitting() {
    setState(() {
      for (final line in _lines) {
        line.dispose();
      }
      _lines.clear();
    });
  }

  Future<void> _pickLineCategory(
    _LineDraft line,
    List<Category> categories,
  ) async {
    // Cùng bộ chọn hai tầng với phần danh mục chính — trước đây đây là một
    // `SimpleDialog` liệt kê phẳng toàn bộ danh mục, tức là chỗ DUY NHẤT
    // trong luồng ghi khoản vẫn còn làm phẳng sau khi form chính đã sửa.
    // Dùng `showTwoLevelCategoryPickerSheet` chứ không tự dựng sheet: sheet
    // tự dựng ở đây từng `pop` ngay trong `onChanged`, nên hàng danh mục
    // CON không bao giờ kịp hiện ra (cùng bug với sheet ở màn chat).
    final pickedId = await showTwoLevelCategoryPickerSheet(
      context: context,
      categories: categories,
      kind: _isExpense ? 'expense' : 'income',
      selectedCategoryId: line.categoryId,
      title: 'Chọn danh mục cho dòng này',
    );
    if (pickedId == null) return;
    setState(() => line.categoryId = pickedId);
  }

  int? _parseAmount(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : int.parse(digits);
  }

  Future<void> _save() async {
    final parsed = _parseAmount(_amountController.text);
    if (parsed == null || parsed == 0) {
      setState(() => _amountError = 'Nhập số tiền hợp lệ');
      return;
    }
    setState(() {
      _amountError = null;
      _saving = true;
    });

    final amount = Money.vnd(_isExpense ? -parsed : parsed);
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    final repo = ref.read(transactionRepositoryProvider);
    final now = ref.read(clockProvider).now();
    // Chưa chạm bộ chọn ví (chỉ hiện khi >1 ví, xem build()) → mặc định ví
    // đầu tiên đang active — luôn có ít nhất một ví (migration/onCreate đảm
    // bảo), xem docs/decisions.md § Phase 13.
    final walletId =
        _selectedWalletId ??
        await ref.read(walletRepositoryProvider).defaultWalletId();

    final lineInputs = _isSplit
        ? _lines
              .map(
                (l) => TransactionLineInput(
                  categoryId: l.categoryId,
                  amountMinor:
                      (_parseAmount(l.amountController.text) ?? 0) *
                      (_isExpense ? -1 : 1),
                ),
              )
              .toList()
        : null;

    // Ảnh chỉ THỰC SỰ ghi ra đĩa lúc Lưu (không phải lúc chọn) — cùng triết
    // lý "chưa ghi gì cho tới khi Lưu" của cả sheet. Ảnh cũ (nếu có và bị
    // thay/gỡ) được `TransactionRepository` tự dọn sau khi DB ghi thành
    // công, không phải ở đây.
    String? newImageFileName;
    if (_newImageBytes != null) {
      newImageFileName = await _receiptImages.saveImage(
        _newImageBytes!,
        now: now,
        extension: _newImageExtension ?? 'jpg',
      );
    }
    final receiptImageFilenameUpdate = _newImageBytes != null
        ? Value(newImageFileName)
        : (_imageRemoved ? const Value(null) : const Value<String?>.absent());

    final result = _isEditing
        ? await repo.update(
            id: widget.existing!.transaction.id,
            amount: amount,
            occurredAt: _date,
            updatedAt: now,
            walletId: walletId,
            categoryId: _selectedCategoryId,
            note: note,
            lines: Value(lineInputs ?? const []),
            goalId: Value(_goalId),
            debtId: Value(_debtId),
            tagIds: Value(_tagIds.toList()),
            receiptImageFilename: receiptImageFilenameUpdate,
          )
        : await repo.insert(
            amount: amount,
            occurredAt: _date,
            walletId: walletId,
            categoryId: _selectedCategoryId,
            note: note,
            lines: lineInputs,
            goalId: _goalId,
            debtId: _debtId,
            tagIds: _tagIds.toList(),
            receiptImageFilename: newImageFileName,
          );

    if (!mounted) return;
    setState(() => _saving = false);

    result.when(
      ok: (_) => Navigator.of(context).pop(),
      err: (error) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Không lưu được'),
          content: Text(error.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    // Cùng lý do (và cùng cách chữa) với `_duplicate()` bên dưới: giữ lấy
    // context của Navigator GỐC TRƯỚC khi `pop()`, đừng đưa `context` của
    // chính `State` này cho một hàm chạy tiếp SAU pop.
    //
    // `deleteTransactionWithUndo` gọi `ScaffoldMessenger.of(context)` trên
    // context đó; khi route chứa nó đang giữa chừng bị gỡ, thanh snackbar
    // hiện ra nhưng KHÔNG bao giờ tự tắt — đo trên máy thật: "Đã xoá giao
    // dịch" nằm lại hơn 4 phút, sống qua cả chuyển tab lẫn vuốt-đóng, che
    // mất thanh điều hướng dưới, chỉ khởi động lại app mới hết.
    final navigatorContext = Navigator.of(context, rootNavigator: true).context;
    final transaction = widget.existing!.transaction;
    Navigator.of(context).pop();
    await deleteTransactionWithUndo(navigatorContext, ref, transaction);
  }

  Future<void> _pickImage() async {
    final source = await showAppBottomSheet<ImageSource>(
      context: context,
      isScrollControlled: false,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(kIconAddAPhoto),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(kIconImage),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _newImageBytes = bytes;
      _newImageExtension = _extensionFromPath(picked.path);
      _imageRemoved = false;
    });
  }

  String _extensionFromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return 'jpg';
    return path.substring(dot + 1).toLowerCase();
  }

  void _removeImage() {
    setState(() {
      _newImageBytes = null;
      _newImageExtension = null;
      _imageRemoved = true;
    });
  }

  void _duplicate() {
    final transaction = widget.existing!.transaction;
    // Lấy `context` của CHÍNH Navigator (ổn định, không biến mất khi một
    // route bên trong nó bị pop) TRƯỚC khi đóng sheet hiện tại — tái dùng
    // `context` của chính `State` này để mở sheet MỚI ngay sau `pop()` không
    // đáng tin cậy ở đây (`_delete()` từng mắc đúng lỗi này, xem ở trên):
    // `showModalBottomSheet` mới
    // cần `Navigator.of(context)` trong lúc route CŨ (chứa context đó) đang
    // giữa chừng bị gỡ, khiến `pumpAndSettle()` không bao giờ hội tụ trong
    // widget test — bắt được bằng test thật, không phải đoán.
    final navigatorContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop();
    openDuplicateTransactionSheet(navigatorContext, transaction);
  }

  /// Tên quỹ để hiện trên đầu sheet — ưu tiên tên prefill đưa sang (mở từ màn
  /// Quỹ), rồi tra ngược từ `_goalId` (mở một khoản quỹ CŨ từ danh sách).
  /// `null` khi giao dịch không gắn quỹ, hoặc quỹ đã bị lưu trữ (giao dịch vẫn
  /// sửa được, chỉ mất cái tên — cùng cách `draft_card.dart` xử lý).
  String? _resolveGoalName() {
    if (_goalName != null) return _goalName;
    final goalId = _goalId;
    if (goalId == null) return null;
    final goals = ref.watch(activeSavingsGoalsProvider).value ?? const [];
    for (final goal in goals) {
      if (goal.id == goalId) return goal.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(activeCategoriesProvider);
    final walletsAsync = ref.watch(activeWalletsProvider);
    final now = ref.read(clockProvider).now();
    final categories = categoriesAsync.value ?? const <Category>[];
    final goalName = _resolveGoalName();
    // Giao dịch GẮN QUỸ không có danh mục theo thiết kế (xem
    // `savings_matcher.dart`/`SavingsContributionSheet`), nên cả khối chọn
    // danh mục lẫn nút "Tách giao dịch" đều bị giấu đi ở đây — hiện lưới danh
    // mục ra chỉ mời gán bừa một danh mục vào một khoản để dành, vừa thổi
    // phồng chi tiêu của danh mục đó vừa làm khoản đó trông như đã tiêu mất.
    final isGoalLinked = _goalId != null;

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
            _isEditing ? 'Sửa giao dịch' : 'Thêm giao dịch',
            style: context.text.titleLarge,
          ),
          if (goalName != null || _debtName != null) ...[
            SizedBox(height: context.space.xs),
            Text(
              goalName != null
                  ? 'Gắn với quỹ: $goalName'
                  : 'Gắn với khoản vay: $_debtName',
              style: context.text.labelMedium?.copyWith(
                color: context.colors.brandText,
              ),
            ),
          ],
          SizedBox(height: context.space.lg),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Chi')),
                      ButtonSegment(value: false, label: Text('Thu')),
                    ],
                    selected: {_isExpense},
                    onSelectionChanged: (selection) => setState(() {
                      _isExpense = selection.first;
                      // Đổi chiều tiền thì bỏ danh mục đang chọn nếu nó
                      // thuộc chiều kia — bộ chọn giờ lọc theo `kind`, giữ
                      // lại một danh mục chi trên form "Thu" nghĩa là chip
                      // đó biến mất khỏi màn mà giá trị vẫn âm thầm ở lại.
                      final picked = _selectedCategoryId;
                      if (picked == null) return;
                      final all =
                          ref.read(activeCategoriesProvider).value ??
                          const <Category>[];
                      for (final c in all) {
                        if (c.id != picked) continue;
                        final wantKind = _isExpense ? 'expense' : 'income';
                        if (c.kind != wantKind) _selectedCategoryId = null;
                        break;
                      }
                    }),
                  ),
                  SizedBox(height: context.space.md),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [ThousandsSeparatorInputFormatter()],
                    autofocus: !_isEditing,
                    decoration: InputDecoration(
                      labelText: _isSplit ? 'Tổng số tiền' : 'Số tiền',
                      suffixText: '₫',
                      errorText: _amountError,
                    ),
                  ),
                  SizedBox(height: context.space.md),
                  if (isGoalLinked)
                    // Không có khối danh mục nào cả — xem `isGoalLinked`.
                    const SizedBox.shrink()
                  else if (!_linesLoaded)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_isSplit)
                    _SplitLinesEditor(
                      lines: _lines,
                      categories: categories,
                      parentAmountController: _amountController,
                      onAddLine: _addLine,
                      onRemoveLine: _removeLine,
                      onPickCategory: _pickLineCategory,
                      onStopSplitting: _stopSplitting,
                    )
                  else ...[
                    Row(
                      children: [
                        Text('Danh mục', style: context.text.labelMedium),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: categories.length < 2 ? null : _addLine,
                          icon: const Icon(kIconCallSplit, size: 16),
                          label: const Text('Tách giao dịch'),
                        ),
                      ],
                    ),
                    SizedBox(height: context.space.xs),
                    categoriesAsync.when(
                      data: (all) => TwoLevelCategoryPicker(
                        categories: all,
                        kind: _isExpense ? 'expense' : 'income',
                        selectedId: _selectedCategoryId,
                        onChanged: (id) =>
                            setState(() => _selectedCategoryId = id),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (error, _) =>
                          Text('Không tải được danh mục: $error'),
                    ),
                  ],
                  // Chỉ hiện bộ chọn ví khi có >1 ví active — một ví duy
                  // nhất (mặc định trước khi Tony tự tạo thêm) thì chọn ngầm,
                  // không cần thêm một hàng UI vô nghĩa (xem
                  // docs/decisions.md § Phase 13).
                  if ((walletsAsync.value?.length ?? 0) > 1) ...[
                    SizedBox(height: context.space.md),
                    Text('Ví', style: context.text.labelMedium),
                    SizedBox(height: context.space.xs),
                    Wrap(
                      spacing: context.space.xs,
                      runSpacing: context.space.xs,
                      children: [
                        for (final wallet in walletsAsync.value!)
                          AppChip(
                            label: wallet.name,
                            editable: false,
                            selected:
                                wallet.id ==
                                (_selectedWalletId ??
                                    walletsAsync.value!.first.id),
                            onTap: () =>
                                setState(() => _selectedWalletId = wallet.id),
                          ),
                      ],
                    ),
                  ],
                  SizedBox(height: context.space.md),
                  Row(
                    children: [
                      Text(
                        'Ngày: ${formatDayLabel(_date, now)}',
                        style: context.text.bodyMedium,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _pickDate,
                        child: const Text('Đổi ngày'),
                      ),
                    ],
                  ),
                  SizedBox(height: context.space.md),
                  TextField(
                    controller: _noteController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú (tuỳ chọn)',
                    ),
                  ),
                  SizedBox(height: context.space.md),
                  Text('Thẻ (tuỳ chọn)', style: context.text.labelMedium),
                  SizedBox(height: context.space.xs),
                  if (!_tagsLoaded)
                    const SizedBox.shrink()
                  else
                    ref
                        .watch(tagsProvider)
                        .when(
                          data: (tags) => tags.isEmpty
                              ? Text(
                                  'Chưa có thẻ nào — tạo ở Quản lý › Thẻ.',
                                  style: context.text.labelMedium?.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                )
                              : Wrap(
                                  spacing: context.space.xs,
                                  runSpacing: context.space.xs,
                                  children: [
                                    for (final tag in tags)
                                      AppChip(
                                        label: tag.name,
                                        editable: false,
                                        selected: _tagIds.contains(tag.id),
                                        icon: CircleAvatar(
                                          radius: 6,
                                          backgroundColor:
                                              context.colors.categoryFills[tag
                                                      .categoryColorId %
                                                  context
                                                      .colors
                                                      .categoryFills
                                                      .length],
                                        ),
                                        onTap: () => setState(() {
                                          if (!_tagIds.add(tag.id)) {
                                            _tagIds.remove(tag.id);
                                          }
                                        }),
                                      ),
                                  ],
                                ),
                          loading: () => const SizedBox.shrink(),
                          error: (error, _) =>
                              Text('Không tải được thẻ: $error'),
                        ),
                  SizedBox(height: context.space.md),
                  Text(
                    'Ảnh hoá đơn (tuỳ chọn)',
                    style: context.text.labelMedium,
                  ),
                  SizedBox(height: context.space.xs),
                  _hasImage
                      ? Row(
                          children: [
                            _ReceiptImageThumbnail(
                              newImageBytes: _newImageBytes,
                              existingFileName: _imageRemoved
                                  ? null
                                  : _existingReceiptImageFilename,
                              receiptImages: _receiptImages,
                            ),
                            SizedBox(width: context.space.sm),
                            TextButton(
                              onPressed: _removeImage,
                              child: Text(
                                'Xoá ảnh',
                                style: TextStyle(
                                  color: context.colors.expenseFill,
                                ),
                              ),
                            ),
                          ],
                        )
                      : OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(kIconAddAPhoto, size: 18),
                          label: const Text('Đính kèm ảnh'),
                        ),
                ],
              ),
            ),
          ),
          SizedBox(height: context.space.lg),
          Row(
            children: [
              if (_isEditing) ...[
                TextButton.icon(
                  onPressed: _saving ? null : _delete,
                  icon: Icon(kIconDelete, color: context.colors.expenseFill),
                  label: Text(
                    'Xoá',
                    style: TextStyle(color: context.colors.expenseFill),
                  ),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : _duplicate,
                  icon: const Icon(kIconContentCopy),
                  label: const Text('Nhân đôi'),
                ),
              ],
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

/// Danh sách dòng con của một giao dịch tách (Phase 14) — mỗi dòng một số
/// tiền + một danh mục (chọn qua dialog, xem `_pickLineCategory`), cộng dồn
/// hiện ngay bên dưới để so với tổng cha; sai lệch chỉ chặn thật ở
/// `TransactionRepository` khi Lưu (nguồn sự thật duy nhất), ở đây chỉ là gợi
/// ý trực quan.
class _SplitLinesEditor extends StatelessWidget {
  const _SplitLinesEditor({
    required this.lines,
    required this.categories,
    required this.parentAmountController,
    required this.onAddLine,
    required this.onRemoveLine,
    required this.onPickCategory,
    required this.onStopSplitting,
  });

  final List<_LineDraft> lines;
  final List<Category> categories;
  final TextEditingController parentAmountController;
  final VoidCallback onAddLine;
  final void Function(int index) onRemoveLine;
  final void Function(_LineDraft line, List<Category> categories)
  onPickCategory;
  final VoidCallback onStopSplitting;

  static int? _parse(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : int.parse(digits);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesById = {for (final c in categories) c.id: c};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Các dòng con', style: context.text.labelMedium),
            const Spacer(),
            TextButton(
              onPressed: onStopSplitting,
              child: const Text('Bỏ tách'),
            ),
          ],
        ),
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: context.space.xs),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: lines[i].amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [ThousandsSeparatorInputFormatter()],
                    decoration: const InputDecoration(
                      isDense: true,
                      suffixText: '₫',
                    ),
                  ),
                ),
                SizedBox(width: context.space.xs),
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: () => onPickCategory(lines[i], categories),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.space.sm,
                        vertical: context.space.sm,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: context.colors.hairline),
                        borderRadius: BorderRadius.circular(context.radii.sm),
                      ),
                      child: Row(
                        children: [
                          if (lines[i].categoryId != null &&
                              categoriesById[lines[i].categoryId] != null) ...[
                            CategoryAvatar(
                              categoryColorId:
                                  categoriesById[lines[i].categoryId]!
                                      .categoryColorId,
                              iconCode:
                                  categoriesById[lines[i].categoryId]!.iconCode,
                              size: 18,
                            ),
                            SizedBox(width: context.space.xs),
                            Expanded(
                              child: Text(
                                categoriesById[lines[i].categoryId]!.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ] else
                            Expanded(
                              child: Text(
                                'Chọn danh mục',
                                style: TextStyle(
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => onRemoveLine(i),
                  icon: const Icon(kIconDelete),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: onAddLine,
          icon: const Icon(kIconAdd, size: 16),
          label: const Text('Thêm dòng'),
        ),
        // `ListenableBuilder` gộp mọi `TextEditingController` liên quan
        // (tổng cha + từng dòng con) — chỉ dòng tổng-hợp này rebuild mỗi lần
        // gõ, không phải cả `_SplitLinesEditor`, để không mất focus/con trỏ
        // đang gõ dở ở một `TextField` khác.
        ListenableBuilder(
          listenable: Listenable.merge([
            parentAmountController,
            ...lines.map((l) => l.amountController),
          ]),
          builder: (context, _) {
            final linesSum = lines.fold<int>(
              0,
              (sum, l) => sum + (_parse(l.amountController.text) ?? 0),
            );
            final parentAmount = _parse(parentAmountController.text) ?? 0;
            final matches = linesSum == parentAmount;
            return Text(
              AmountVisibility.mask(
                context,
                'Tổng dòng con: ${Money.vnd(linesSum).format()} / '
                'Cần khớp: ${Money.vnd(parentAmount).format()}',
              ),
              style: context.text.labelMedium?.copyWith(
                color: matches
                    ? context.colors.onSurfaceVariant
                    : context.colors.expenseFill,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Ảnh thu nhỏ 56×56 cho ảnh hoá đơn — [newImageBytes] (vừa chọn, chưa ghi
/// đĩa) ưu tiên hơn [existingFileName] (đã có, đọc lại qua
/// [ReceiptImageService], MỘT LẦN lúc build vì file không đổi trong lúc
/// sheet mở). `null` cả hai (file đã bị xoá ngoài app) hiện icon thay thế
/// thay vì lỗi — một ảnh thiếu không phải lỗi nghiêm trọng của một giao dịch.
class _ReceiptImageThumbnail extends StatelessWidget {
  const _ReceiptImageThumbnail({
    required this.newImageBytes,
    required this.existingFileName,
    required this.receiptImages,
  });

  final Uint8List? newImageBytes;
  final String? existingFileName;
  final ReceiptImageService receiptImages;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (newImageBytes != null) {
      child = Image.memory(newImageBytes!, fit: BoxFit.cover);
    } else if (existingFileName != null) {
      child = FutureBuilder<Uint8List?>(
        future: receiptImages.readImage(existingFileName!),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            return Icon(kIconImage, color: context.colors.onSurfaceVariant);
          }
          return Image.memory(bytes, fit: BoxFit.cover);
        },
      );
    } else {
      child = Icon(kIconImage, color: context.colors.onSurfaceVariant);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(context.radii.sm),
      child: SizedBox(width: 56, height: 56, child: child),
    );
  }
}
