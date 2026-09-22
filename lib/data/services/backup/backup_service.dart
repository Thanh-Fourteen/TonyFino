import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/result/result.dart';
import '../../db/database.dart';
import '../receipt_image_service.dart';

/// Logic thuần export/import DB — KHÔNG chạm `dart:io` trực tiếp, KHÔNG chạm
/// platform channel. Đây là thứ round-trip test (Phase 4) chạy trực tiếp
/// trên `NativeDatabase.memory()`; nơi bytes thực sự đi đâu (SAF, share
/// sheet, iOS documents) là việc của `BackupDestination`, tách riêng có chủ
/// đích.
///
/// ⚠️ Phase 17 NGOẠI LỆ CÓ CHỦ ĐÍCH: ảnh hoá đơn đính kèm SỐNG trên đĩa
/// (`ReceiptImageService`), không phải trong DB — một backup chỉ xuất JSON
/// (không kèm ảnh) sẽ ÂM THẦM làm mất ảnh đính kèm qua một lượt sao lưu/
/// khôi phục, đúng cảnh báo TODOS.md § Phase 17 "Xác minh". [_receiptImages]
/// được TIÊM VÀO (giống `TransactionRepository`) thay vì `const
/// ReceiptImageService()` cứng — round-trip test (có ảnh) vẫn chạy được
/// trên `NativeDatabase.memory()` KHÔNG cần thiết bị thật, chỉ cần fake
/// `path_provider` (xem `test/support/fake_path_provider.dart`).
class BackupService {
  BackupService(this._db, {ReceiptImageService? receiptImageService})
    : _receiptImages = receiptImageService ?? const ReceiptImageService();

  final AppDatabase _db;
  final ReceiptImageService _receiptImages;

  /// Version của CHÍNH ĐỊNH DẠNG backup — độc lập với `schemaVersion` của
  /// drift (bàn giao Phase 4). Tăng khi đổi cấu trúc JSON, không phải khi
  /// đổi schema DB.
  static const formatVersion = 1;

  Future<Uint8List> exportToJson({required DateTime exportedAt}) async {
    final wallets = await _db.select(_db.wallets).get()
      ..sort((a, b) => a.id.compareTo(b.id));
    final transactions = await _db.select(_db.transactions).get()
      ..sort((a, b) => a.id.compareTo(b.id));
    final categories = await _db.select(_db.categories).get()
      ..sort((a, b) => a.id.compareTo(b.id));
    final categoryKeywords = await _db.select(_db.categoryKeywords).get()
      ..sort((a, b) => a.id.compareTo(b.id));
    final budgets = await _db.select(_db.budgets).get()
      ..sort((a, b) => a.id.compareTo(b.id));
    final recurringTransactions =
        await _db.select(_db.recurringTransactions).get()
          ..sort((a, b) => a.id.compareTo(b.id));
    final transactionLines = await _db.select(_db.transactionLines).get()
      ..sort((a, b) => a.id.compareTo(b.id));
    final transactionTemplates =
        await _db.select(_db.transactionTemplates).get()
          ..sort((a, b) => a.id.compareTo(b.id));
    final savingsGoals = await _db.select(_db.savingsGoals).get()
      ..sort((a, b) => a.id.compareTo(b.id));
    final debts = await _db.select(_db.debts).get()
      ..sort((a, b) => a.id.compareTo(b.id));
    final jarGoals = await _db.select(_db.jarGoals).get();
    final notes = await _db.select(_db.notes).get();
    final jars = await _db.select(_db.jars).get()
      ..sort((a, b) => a.id.compareTo(b.id));
    final tags = await _db.select(_db.tags).get()
      ..sort((a, b) => a.id.compareTo(b.id));
    final transactionTags = await _db.select(_db.transactionTags).get()
      ..sort((a, b) => a.transactionId.compareTo(b.transactionId));

    // Ảnh hoá đơn (Phase 17): base64 trong CHÍNH file JSON, KHÔNG phải file
    // rời — một file `.json` duy nhất vẫn là toàn bộ backup, khớp cơ chế
    // chia sẻ/SAF hiện có (`BackupDestination.write` chỉ nhận MỘT
    // `Uint8List`). Chỉ đọc file cho những `receiptImageFilename` THỰC SỰ
    // được tham chiếu — không quét cả thư mục `receipts/` (có thể còn rác từ
    // ảnh đã gỡ nhưng chưa xoá kịp, xem ghi chú ở dưới).
    final receiptImages = <String, String>{};
    for (final fileName
        in transactions.map((t) => t.receiptImageFilename).nonNulls.toSet()) {
      final bytes = await _receiptImages.readImage(fileName);
      if (bytes != null) {
        receiptImages[fileName] = base64Encode(bytes);
      }
    }

    final map = <String, Object?>{
      'version': formatVersion,
      'schemaVersion': _db.schemaVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'wallets': wallets.map(_walletToJson).toList(),
      'transactions': transactions.map(_transactionToJson).toList(),
      'categories': categories.map(_categoryToJson).toList(),
      'categoryKeywords': categoryKeywords.map(_keywordToJson).toList(),
      'budgets': budgets.map(_budgetToJson).toList(),
      // 7 bảng thêm ở Phase 24 — trước đó bị BỎ SÓT khỏi backup (phát hiện
      // sống trong diễn tập backup→gỡ cài→cài lại→restore, thấy thật mục
      // tiêu tiết kiệm "CCTG" của Tony biến mất sau restore) — xem
      // docs/decisions.md § Phase 24. `formatVersion` GIỮ NGUYÊN (không đổi
      // cấu trúc key cũ, chỉ thêm key mới) — backup CŨ vẫn đọc được nhờ mọi
      // khoá mới đều tra bằng `?? const []` ở `importFromJson`.
      'recurringTransactions': recurringTransactions
          .map(_recurringTransactionToJson)
          .toList(),
      'transactionLines': transactionLines.map(_transactionLineToJson).toList(),
      'transactionTemplates': transactionTemplates
          .map(_transactionTemplateToJson)
          .toList(),
      'savingsGoals': savingsGoals.map(_savingsGoalToJson).toList(),
      // 🚨 Hũ chia thu nhập (v13) — bỏ sót khỏi backup từ lúc thêm bảng,
      // đúng lại lỗi Phase 24 đã bắt được với mục tiêu tiết kiệm: gỡ cài
      // rồi restore là mất sạch cách chia hũ, im lặng, không báo gì. Bắt
      // được lần này cũng bằng một lần restore THẬT trên máy chứ không phải
      // đọc code. `categories.jarId` (dây nối danh mục ↔ hũ) cũng phải đi
      // kèm, nếu không hũ về nhưng không hũ nào biết mình gồm danh mục gì.
      'jars': jars.map(_jarToJson).toList(),
      'jarGoals': jarGoals.map(_jarGoalToJson).toList(),
      'notes': notes.map(_noteToJson).toList(),
      'debts': debts.map(_debtToJson).toList(),
      'tags': tags.map(_tagToJson).toList(),
      'transactionTags': transactionTags.map(_transactionTagToJson).toList(),
      'receiptImages': receiptImages,
    };

    return Uint8List.fromList(utf8.encode(jsonEncode(map)));
  }

  /// Xoá sạch 4 bảng rồi nạp lại từ JSON, GIỮ NGUYÊN id gốc — để restore là
  /// một phép thay thế toàn bộ, không phải merge (tránh trùng lặp âm thầm).
  Future<Result<void, AppError>> importFromJson(Uint8List bytes) async {
    final Map<String, Object?> map;
    try {
      map = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    } catch (e) {
      return Err(
        AppError(
          'File backup không đọc được — không phải JSON hợp lệ.',
          cause: e,
        ),
      );
    }

    final version = map['version'];
    if (version != formatVersion) {
      return Err(
        AppError('Định dạng backup không tương thích (version $version).'),
      );
    }

    try {
      // Backup CŨ (trước Phase 13) không có khoá 'wallets' — không đụng bảng
      // `wallets` hiện có (giữ nguyên ví đã tạo từ onCreate/migration của
      // chính máy này), và mỗi giao dịch phục hồi thiếu `walletId` sẽ gán
      // vào ví mặc định hiện có. Backward-compat có chủ đích, không phải
      // thiếu sót — xem docs/decisions.md § Phase 13.
      final walletsJson = map['wallets'] as List?;
      final fallbackWalletId = walletsJson == null
          ? (await (_db.select(
              _db.wallets,
            )..orderBy([(w) => OrderingTerm.asc(w.id)])).getSingle()).id
          : null;

      await _db.transaction(() async {
        // Xoá CON trước CHA (thứ tự không bắt buộc vì app chưa từng bật
        // `PRAGMA foreign_keys`, nhưng vẫn giữ đúng thứ tự logic — xem
        // ghi chú `TransactionTags`).
        await _db.delete(_db.transactionTags).go();
        await _db.delete(_db.transactionLines).go();
        await _db.delete(_db.recurringTransactions).go();
        await _db.delete(_db.transactionTemplates).go();
        await _db.delete(_db.categoryKeywords).go();
        await _db.delete(_db.budgets).go();
        await _db.delete(_db.transactions).go();
        await _db.delete(_db.notes).go();
        await _db.delete(_db.jarGoals).go();
        await _db.delete(_db.jars).go();
        await _db.delete(_db.savingsGoals).go();
        await _db.delete(_db.debts).go();
        await _db.delete(_db.tags).go();
        await _db.delete(_db.categories).go();
        if (walletsJson != null) {
          await _db.delete(_db.wallets).go();
          for (final row in walletsJson.cast<Map<String, Object?>>()) {
            await _db
                .into(_db.wallets)
                .insert(_walletFromJson(row), mode: InsertMode.insertOrReplace);
          }
        }

        // Ví phải khôi phục XONG trước khi tới danh mục (khối `wallets` ở
        // trên) — từ v11 mỗi danh mục trỏ vào một ví.
        // Tên PHẢI khác `fallbackWalletId` ở scope ngoài: đặt trùng tên sẽ
        // che mất biến đó, và dòng khôi phục GIAO DỊCH bên dưới lặng lẽ đổi
        // ngữ nghĩa (nó cố ý là `null` khi backup có sẵn `wallets`, để
        // `walletId!` nổ nếu dữ liệu thiếu thay vì đoán bừa một ví).
        final categoryFallbackWalletId =
            (await (_db.select(
                  _db.wallets,
                )..orderBy([(w) => OrderingTerm.asc(w.id)])).get())
                .firstOrNull
                ?.id ??
            await _db
                .into(_db.wallets)
                .insert(
                  WalletsCompanion.insert(
                    name: kDefaultWalletName,
                    categoryColorId: 0,
                    iconCode: 'account_balance_wallet',
                  ),
                );
        for (final row
            in (map['categories'] as List).cast<Map<String, Object?>>()) {
          await _db
              .into(_db.categories)
              .insert(
                _categoryFromJson(
                  row,
                  fallbackWalletId: categoryFallbackWalletId,
                ),
                mode: InsertMode.insertOrReplace,
              );
        }
        // Backup CŨ (trước Phase 24) không có 7 khoá này — `?? const []` coi
        // như "không có dòng nào", không lỗi (cùng quy ước 'wallets' cũ ở trên).
        // Hũ phải nạp TRƯỚC danh mục — `categories.jarId` là khoá ngoại
        // trỏ vào đây.
        for (final row
            in ((map['jars'] as List?) ?? const [])
                .cast<Map<String, Object?>>()) {
          await _db
              .into(_db.jars)
              .insert(_jarFromJson(row), mode: InsertMode.insertOrReplace);
        }
        // Dây nối hũ ↔ quỹ (v15) — nạp SAU hũ, cùng lý do thứ tự với
        // `categories.jarId`.
        for (final row
            in ((map['jarGoals'] as List?) ?? const [])
                .cast<Map<String, Object?>>()) {
          await _db
              .into(_db.jarGoals)
              .insert(_jarGoalFromJson(row), mode: InsertMode.insertOrReplace);
        }
        // Ghi chú (v16) — không phụ thuộc bảng nào, nạp lúc nào cũng được.
        for (final row
            in ((map['notes'] as List?) ?? const [])
                .cast<Map<String, Object?>>()) {
          await _db
              .into(_db.notes)
              .insert(_noteFromJson(row), mode: InsertMode.insertOrReplace);
        }
        for (final row
            in ((map['savingsGoals'] as List?) ?? const [])
                .cast<Map<String, Object?>>()) {
          await _db
              .into(_db.savingsGoals)
              .insert(
                _savingsGoalFromJson(row),
                mode: InsertMode.insertOrReplace,
              );
        }
        for (final row
            in ((map['debts'] as List?) ?? const [])
                .cast<Map<String, Object?>>()) {
          await _db
              .into(_db.debts)
              .insert(_debtFromJson(row), mode: InsertMode.insertOrReplace);
        }
        for (final row
            in (map['transactions'] as List).cast<Map<String, Object?>>()) {
          await _db
              .into(_db.transactions)
              .insert(
                _transactionFromJson(row, fallbackWalletId: fallbackWalletId),
                mode: InsertMode.insertOrReplace,
              );
        }
        for (final row
            in ((map['transactionLines'] as List?) ?? const [])
                .cast<Map<String, Object?>>()) {
          await _db
              .into(_db.transactionLines)
              .insert(
                _transactionLineFromJson(row),
                mode: InsertMode.insertOrReplace,
              );
        }
        for (final row
            in ((map['tags'] as List?) ?? const [])
                .cast<Map<String, Object?>>()) {
          await _db
              .into(_db.tags)
              .insert(_tagFromJson(row), mode: InsertMode.insertOrReplace);
        }
        for (final row
            in ((map['transactionTags'] as List?) ?? const [])
                .cast<Map<String, Object?>>()) {
          await _db
              .into(_db.transactionTags)
              .insert(
                _transactionTagFromJson(row),
                mode: InsertMode.insertOrReplace,
              );
        }
        for (final row
            in (map['categoryKeywords'] as List).cast<Map<String, Object?>>()) {
          await _db
              .into(_db.categoryKeywords)
              .insert(_keywordFromJson(row), mode: InsertMode.insertOrReplace);
        }
        for (final row
            in (map['budgets'] as List).cast<Map<String, Object?>>()) {
          await _db
              .into(_db.budgets)
              .insert(_budgetFromJson(row), mode: InsertMode.insertOrReplace);
        }
        for (final row
            in ((map['recurringTransactions'] as List?) ?? const [])
                .cast<Map<String, Object?>>()) {
          await _db
              .into(_db.recurringTransactions)
              .insert(
                _recurringTransactionFromJson(row),
                mode: InsertMode.insertOrReplace,
              );
        }
        for (final row
            in ((map['transactionTemplates'] as List?) ?? const [])
                .cast<Map<String, Object?>>()) {
          await _db
              .into(_db.transactionTemplates)
              .insert(
                _transactionTemplateFromJson(row),
                mode: InsertMode.insertOrReplace,
              );
        }
      });

      // Ảnh hoá đơn (Phase 17) — GHI SAU KHI transaction DB đã thành công
      // (I/O file không nằm trong phạm vi rollback SQLite, không có lý do
      // giữ trong cùng khối). Backup CŨ (trước Phase 17) không có khoá
      // 'receiptImages' — `?? const {}` coi như không có ảnh nào, không lỗi.
      final receiptImagesJson =
          (map['receiptImages'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      for (final entry in receiptImagesJson.entries) {
        await _receiptImages.writeImageWithFilename(
          entry.key,
          base64Decode(entry.value as String),
        );
      }

      return const Ok(null);
    } catch (e) {
      final error = AppError(
        'Import backup thất bại — dữ liệu cũ đã được giữ nguyên.',
        cause: e,
      );
      await _db
          .into(_db.appEvents)
          .insert(
            AppEventsCompanion.insert(
              level: 'error',
              message: error.message,
              contextJson: Value(e.toString()),
            ),
          );
      return Err(error);
    }
  }

  Map<String, Object?> _transactionToJson(Transaction t) => {
    'id': t.id,
    'amountMinor': t.amountMinor,
    'currency': t.currency,
    'currencyScale': t.currencyScale,
    'occurredAt': t.occurredAt.toIso8601String(),
    'categoryId': t.categoryId,
    'note': t.note,
    'noteAscii': t.noteAscii,
    'sourceId': t.sourceId,
    'walletId': t.walletId,
    'isTransfer': t.isTransfer,
    'linkedTransactionId': t.linkedTransactionId,
    'createdAt': t.createdAt.toIso8601String(),
    'updatedAt': t.updatedAt.toIso8601String(),
    'receiptImageFilename': t.receiptImageFilename,
    // Phase 24 — thêm 'goalId'/'debtId' (đã tồn tại từ Phase 16 nhưng chưa
    // từng vào backup, xem ghi chú lớn ở exportToJson).
    'goalId': t.goalId,
    'debtId': t.debtId,
  };

  // `sourceId` đọc kiểu `String?` — key vắng mặt (backup cũ từ trước Phase 9)
  // trả `null` tự nhiên từ `Map`, không cần nhánh riêng cho "backup cũ".
  //
  // `walletId` (Phase 13): backup CŨ không có khoá này — [fallbackWalletId]
  // (khác `null` CHỈ khi backup thiếu hẳn khoá 'wallets', xem
  // `importFromJson`) lấp vào, KHÔNG BAO GIỜ null cho một backup mới đủ khoá
  // 'wallets' (ở đó bản thân JSON luôn có `walletId` thật của từng dòng).
  TransactionsCompanion _transactionFromJson(
    Map<String, Object?> j, {
    int? fallbackWalletId,
  }) => TransactionsCompanion.insert(
    id: Value(j['id'] as int),
    amountMinor: j['amountMinor'] as int,
    currency: j['currency'] as String,
    currencyScale: j['currencyScale'] as int,
    occurredAt: DateTime.parse(j['occurredAt'] as String),
    walletId: (j['walletId'] as int?) ?? fallbackWalletId!,
    categoryId: Value(j['categoryId'] as int?),
    note: Value(j['note'] as String?),
    noteAscii: Value(j['noteAscii'] as String?),
    sourceId: Value(j['sourceId'] as String?),
    isTransfer: Value(j['isTransfer'] as bool? ?? false),
    linkedTransactionId: Value(j['linkedTransactionId'] as int?),
    createdAt: Value(DateTime.parse(j['createdAt'] as String)),
    updatedAt: Value(DateTime.parse(j['updatedAt'] as String)),
    // Backup CŨ (trước Phase 17) không có khoá này — key vắng mặt trả
    // `null` tự nhiên từ `Map`, đúng nghĩa "không có ảnh", không cần nhánh
    // riêng cho "backup cũ" (cùng quy ước `sourceId` ở trên).
    receiptImageFilename: Value(j['receiptImageFilename'] as String?),
    // Backup CŨ (trước Phase 24) không có 2 khoá này — key vắng mặt trả
    // `null` tự nhiên từ `Map`, đúng nghĩa "không gắn mục tiêu/khoản nợ nào",
    // cùng quy ước `sourceId`/`receiptImageFilename` ở trên.
    goalId: Value(j['goalId'] as int?),
    debtId: Value(j['debtId'] as int?),
  );

  Map<String, Object?> _walletToJson(Wallet w) => {
    'id': w.id,
    'name': w.name,
    'categoryColorId': w.categoryColorId,
    'iconCode': w.iconCode,
    'isArchived': w.isArchived,
    'createdAt': w.createdAt.toIso8601String(),
  };

  WalletsCompanion _walletFromJson(Map<String, Object?> j) =>
      WalletsCompanion.insert(
        id: Value(j['id'] as int),
        name: j['name'] as String,
        categoryColorId: j['categoryColorId'] as int,
        iconCode: j['iconCode'] as String,
        isArchived: Value(j['isArchived'] as bool),
        createdAt: Value(DateTime.parse(j['createdAt'] as String)),
      );

  Map<String, Object?> _categoryToJson(Category c) => {
    'id': c.id,
    'name': c.name,
    'kind': c.kind,
    'categoryColorId': c.categoryColorId,
    'iconCode': c.iconCode,
    'isArchived': c.isArchived,
    'createdAt': c.createdAt.toIso8601String(),
    'parentCategoryId': c.parentCategoryId,
    'sortOrder': c.sortOrder,
    'emoji': c.emoji,
    'walletId': c.walletId,
    'jarId': c.jarId,
  };

  // `parentCategoryId`/`sortOrder` (Phase 13): backup CŨ không có hai khoá
  // này — `null`/`0` là đúng giá trị mặc định của chính hai cột đó lúc mới
  // thêm (migration `addColumn`), nên không cần fallback nào khác.
  /// [fallbackWalletId] dùng cho backup CŨ (trước v11) — hồi đó danh mục
  /// chưa thuộc ví nào, nên khôi phục vào ví đầu tiên, đúng cách migration
  /// v10→v11 backfill dữ liệu tại chỗ. Không được để `walletId` rỗng: cột
  /// NOT NULL, và một danh mục không có ví thì không màn nào thấy nó.
  CategoriesCompanion _categoryFromJson(
    Map<String, Object?> j, {
    required int fallbackWalletId,
  }) => CategoriesCompanion.insert(
    id: Value(j['id'] as int),
    name: j['name'] as String,
    kind: j['kind'] as String,
    categoryColorId: j['categoryColorId'] as int,
    iconCode: j['iconCode'] as String,
    isArchived: Value(j['isArchived'] as bool),
    createdAt: Value(DateTime.parse(j['createdAt'] as String)),
    parentCategoryId: Value(j['parentCategoryId'] as int?),
    sortOrder: Value(j['sortOrder'] as int? ?? 0),
    // Backup CŨ (trước Phase 17) không có khoá này — `null` đúng nghĩa
    // "chưa đặt emoji", cùng quy ước `parentCategoryId`/`sortOrder` ở trên.
    emoji: Value(j['emoji'] as String?),
    walletId: j['walletId'] as int? ?? fallbackWalletId,
    // Backup trước v13 không có khoá này — `null` = danh mục chưa thuộc hũ
    // nào, đúng mặc định của cột.
    jarId: Value(j['jarId'] as int?),
  );

  Map<String, Object?> _keywordToJson(CategoryKeyword k) => {
    'id': k.id,
    'categoryId': k.categoryId,
    'keyword': k.keyword,
    'keywordAscii': k.keywordAscii,
    'weight': k.weight,
    'createdAt': k.createdAt.toIso8601String(),
  };

  CategoryKeywordsCompanion _keywordFromJson(Map<String, Object?> j) =>
      CategoryKeywordsCompanion.insert(
        id: Value(j['id'] as int),
        categoryId: j['categoryId'] as int,
        keyword: j['keyword'] as String,
        keywordAscii: j['keywordAscii'] as String,
        weight: Value((j['weight'] as num).toDouble()),
        createdAt: Value(DateTime.parse(j['createdAt'] as String)),
      );

  Map<String, Object?> _budgetToJson(Budget b) => {
    'id': b.id,
    'categoryId': b.categoryId,
    'yearMonth': b.yearMonth,
    'amountMinor': b.amountMinor,
    'currency': b.currency,
    'currencyScale': b.currencyScale,
    'createdAt': b.createdAt.toIso8601String(),
    // Phase 24 — thêm 'carryOver' (đã tồn tại từ Phase 15 nhưng chưa từng
    // vào backup).
    'carryOver': b.carryOver,
  };

  BudgetsCompanion _budgetFromJson(Map<String, Object?> j) =>
      BudgetsCompanion.insert(
        id: Value(j['id'] as int),
        categoryId: j['categoryId'] as int,
        yearMonth: j['yearMonth'] as String,
        amountMinor: j['amountMinor'] as int,
        currency: j['currency'] as String,
        currencyScale: j['currencyScale'] as int,
        createdAt: Value(DateTime.parse(j['createdAt'] as String)),
        // Backup CŨ (trước Phase 24) không có khoá này — `false` đúng giá
        // trị mặc định của chính cột này lúc mới thêm (migration Phase 15).
        carryOver: Value(j['carryOver'] as bool? ?? false),
      );

  Map<String, Object?> _recurringTransactionToJson(RecurringTransaction r) => {
    'id': r.id,
    'categoryId': r.categoryId,
    'amountMinor': r.amountMinor,
    'currency': r.currency,
    'currencyScale': r.currencyScale,
    'note': r.note,
    'frequency': r.frequency,
    'nextOccurrenceDate': r.nextOccurrenceDate.toIso8601String(),
    'isActive': r.isActive,
    'createdAt': r.createdAt.toIso8601String(),
  };

  RecurringTransactionsCompanion _recurringTransactionFromJson(
    Map<String, Object?> j,
  ) => RecurringTransactionsCompanion.insert(
    id: Value(j['id'] as int),
    categoryId: Value(j['categoryId'] as int?),
    amountMinor: j['amountMinor'] as int,
    currency: j['currency'] as String,
    currencyScale: j['currencyScale'] as int,
    note: Value(j['note'] as String?),
    frequency: j['frequency'] as String,
    nextOccurrenceDate: DateTime.parse(j['nextOccurrenceDate'] as String),
    isActive: Value(j['isActive'] as bool? ?? true),
    createdAt: Value(DateTime.parse(j['createdAt'] as String)),
  );

  Map<String, Object?> _transactionLineToJson(TransactionLine l) => {
    'id': l.id,
    'transactionId': l.transactionId,
    'categoryId': l.categoryId,
    'amountMinor': l.amountMinor,
  };

  TransactionLinesCompanion _transactionLineFromJson(Map<String, Object?> j) =>
      TransactionLinesCompanion.insert(
        id: Value(j['id'] as int),
        transactionId: j['transactionId'] as int,
        categoryId: Value(j['categoryId'] as int?),
        amountMinor: j['amountMinor'] as int,
      );

  Map<String, Object?> _transactionTemplateToJson(TransactionTemplate t) => {
    'id': t.id,
    'name': t.name,
    'amountMinor': t.amountMinor,
    'currency': t.currency,
    'currencyScale': t.currencyScale,
    'categoryId': t.categoryId,
    'note': t.note,
    'createdAt': t.createdAt.toIso8601String(),
  };

  TransactionTemplatesCompanion _transactionTemplateFromJson(
    Map<String, Object?> j,
  ) => TransactionTemplatesCompanion.insert(
    id: Value(j['id'] as int),
    name: j['name'] as String,
    amountMinor: j['amountMinor'] as int,
    currency: j['currency'] as String,
    currencyScale: j['currencyScale'] as int,
    categoryId: Value(j['categoryId'] as int?),
    note: Value(j['note'] as String?),
    createdAt: Value(DateTime.parse(j['createdAt'] as String)),
  );

  Map<String, Object?> _jarToJson(Jar j) => {
    'id': j.id,
    'walletId': j.walletId,
    'name': j.name,
    'percent': j.percent,
    'categoryColorId': j.categoryColorId,
    'iconCode': j.iconCode,
    'carryOver': j.carryOver,
    'sortOrder': j.sortOrder,
    'isArchived': j.isArchived,
    'createdAt': j.createdAt.toIso8601String(),
    // v14 — hũ tiết kiệm. Thiếu khoá này thì khôi phục xong mọi hũ tiết
    // kiệm biến thành hũ tiêu. Dây nối tới quỹ nằm ở bảng riêng `jarGoals`
    // từ v15.
    'kind': j.kind,
    // v17 — chiều của hũ quỹ (nạp vào / tiêu từ quỹ).
    'goalFlow': j.goalFlow,
  };

  JarsCompanion _jarFromJson(Map<String, Object?> j) => JarsCompanion.insert(
    id: Value(j['id'] as int),
    walletId: j['walletId'] as int,
    name: j['name'] as String,
    percent: j['percent'] as int,
    categoryColorId: j['categoryColorId'] as int,
    iconCode: j['iconCode'] as String,
    carryOver: Value(j['carryOver'] as bool? ?? false),
    sortOrder: Value(j['sortOrder'] as int? ?? 0),
    isArchived: Value(j['isArchived'] as bool? ?? false),
    createdAt: Value(DateTime.parse(j['createdAt'] as String)),
    // Bản sao lưu trước v14 không có khoá này — mọi hũ hồi đó là hũ tiêu.
    kind: Value(j['kind'] as String? ?? 'spend'),
    // Bản sao lưu trước v17: mọi hũ quỹ hồi đó đều là chiều "nạp vào".
    goalFlow: Value(j['goalFlow'] as String? ?? 'in'),
  );

  Map<String, Object?> _jarGoalToJson(JarGoal l) => {
    'jarId': l.jarId,
    'goalId': l.goalId,
    'percent': l.percent,
  };

  JarGoalsCompanion _jarGoalFromJson(Map<String, Object?> l) =>
      JarGoalsCompanion.insert(
        jarId: l['jarId'] as int,
        goalId: l['goalId'] as int,
        percent: Value(l['percent'] as int? ?? 100),
      );

  Map<String, Object?> _noteToJson(Note n) => {
    'id': n.id,
    'title': n.title,
    'body': n.body,
    'isPinned': n.isPinned,
    'createdAt': n.createdAt.toIso8601String(),
    'updatedAt': n.updatedAt.toIso8601String(),
  };

  NotesCompanion _noteFromJson(Map<String, Object?> n) => NotesCompanion.insert(
    id: Value(n['id'] as int),
    title: Value(n['title'] as String? ?? ''),
    body: Value(n['body'] as String? ?? ''),
    isPinned: Value(n['isPinned'] as bool? ?? false),
    createdAt: Value(DateTime.parse(n['createdAt'] as String)),
    updatedAt: Value(DateTime.parse(n['updatedAt'] as String)),
  );

  Map<String, Object?> _savingsGoalToJson(SavingsGoal g) => {
    'id': g.id,
    'name': g.name,
    'targetAmountMinor': g.targetAmountMinor,
    'currency': g.currency,
    'currencyScale': g.currencyScale,
    'targetDate': g.targetDate?.toIso8601String(),
    'isArchived': g.isArchived,
    'createdAt': g.createdAt.toIso8601String(),
    'sortOrder': g.sortOrder,
    'sourceId': g.sourceId,
  };

  SavingsGoalsCompanion _savingsGoalFromJson(Map<String, Object?> j) =>
      SavingsGoalsCompanion.insert(
        id: Value(j['id'] as int),
        name: j['name'] as String,
        targetAmountMinor: j['targetAmountMinor'] as int,
        currency: j['currency'] as String,
        currencyScale: j['currencyScale'] as int,
        targetDate: Value(
          j['targetDate'] == null
              ? null
              : DateTime.parse(j['targetDate'] as String),
        ),
        isArchived: Value(j['isArchived'] as bool? ?? false),
        createdAt: Value(DateTime.parse(j['createdAt'] as String)),
        // Bản sao lưu cũ (trước v18) không có trường này — 0 cho tất cả,
        // đúng trạng thái "chưa kéo thả lần nào".
        sortOrder: Value(j['sortOrder'] as int? ?? 0),
        sourceId: Value(j['sourceId'] as String?),
      );

  Map<String, Object?> _debtToJson(Debt d) => {
    'id': d.id,
    'counterpartyName': d.counterpartyName,
    'kind': d.kind,
    'principalMinor': d.principalMinor,
    'currency': d.currency,
    'currencyScale': d.currencyScale,
    'startDate': d.startDate.toIso8601String(),
    'isArchived': d.isArchived,
    'createdAt': d.createdAt.toIso8601String(),
  };

  DebtsCompanion _debtFromJson(Map<String, Object?> j) => DebtsCompanion.insert(
    id: Value(j['id'] as int),
    counterpartyName: j['counterpartyName'] as String,
    kind: j['kind'] as String,
    principalMinor: j['principalMinor'] as int,
    currency: j['currency'] as String,
    currencyScale: j['currencyScale'] as int,
    startDate: DateTime.parse(j['startDate'] as String),
    isArchived: Value(j['isArchived'] as bool? ?? false),
    createdAt: Value(DateTime.parse(j['createdAt'] as String)),
  );

  Map<String, Object?> _tagToJson(Tag t) => {
    'id': t.id,
    'name': t.name,
    'categoryColorId': t.categoryColorId,
    'createdAt': t.createdAt.toIso8601String(),
  };

  TagsCompanion _tagFromJson(Map<String, Object?> j) => TagsCompanion.insert(
    id: Value(j['id'] as int),
    name: j['name'] as String,
    categoryColorId: j['categoryColorId'] as int,
    createdAt: Value(DateTime.parse(j['createdAt'] as String)),
  );

  Map<String, Object?> _transactionTagToJson(TransactionTag t) => {
    'transactionId': t.transactionId,
    'tagId': t.tagId,
  };

  TransactionTagsCompanion _transactionTagFromJson(Map<String, Object?> j) =>
      TransactionTagsCompanion.insert(
        transactionId: j['transactionId'] as int,
        tagId: j['tagId'] as int,
      );
}
