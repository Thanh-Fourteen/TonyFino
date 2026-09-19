import 'package:drift/drift.dart';

import '../../core/money/money.dart';
import '../../core/result/result.dart';
import '../../core/text/ascii_fold.dart';
import '../db/database.dart';
import '../services/receipt_image_service.dart';

/// Mọi READ ở đây là `Stream` — không có snapshot một lần nào cho số dư hay
/// danh sách giao dịch, vì bất cứ giá trị "chụp một lần" nào cũng có thể trở
/// nên cũ ngay sau lần ghi kế tiếp (D7). Mọi WRITE trả `Result<T, AppError>`:
/// không exception rò ra UI, không fire-and-forget.
class TransactionRepository {
  TransactionRepository(this._db, {ReceiptImageService? receiptImageService})
    : _receiptImages = receiptImageService ?? const ReceiptImageService();

  final AppDatabase _db;
  final ReceiptImageService _receiptImages;

  /// Thứ tự "mới nhất lên đầu" dùng chung cho MỌI danh sách giao dịch.
  ///
  /// 🚨 `occurredAt` một mình KHÔNG đủ: màn chat và bộ nhập Rolly ghi NGÀY
  /// TRẦN (00:00), nên mọi khoản trong cùng một ngày có `occurredAt` y hệt
  /// nhau và SQLite trả chúng theo thứ tự tuỳ ý — thực tế là theo rowid tăng
  /// dần, tức khoản gõ buổi sáng nằm TRÊN khoản vừa gõ xong. Tony thấy đúng
  /// thế ở thẻ "Gần đây": trong một ngày thứ tự bị ngược so với màn chat.
  ///
  /// Tiêu chí phụ là `createdAt` (lúc thật sự ghi) rồi `id` — `createdAt`
  /// chỉ chính xác tới GIÂY, hai khoản gửi trong cùng một tin nhắn có thể
  /// trùng giây, `id` tăng dần phân xử nốt.
  List<OrderClauseGenerator<$TransactionsTable>> get _newestFirst => [
    (t) => OrderingTerm.desc(t.occurredAt),
    (t) => OrderingTerm.desc(t.createdAt),
    (t) => OrderingTerm.desc(t.id),
  ];

  /// Cùng thứ tự với [_newestFirst] cho truy vấn có JOIN.
  List<OrderingTerm> get _newestFirstJoined => [
    OrderingTerm.desc(_db.transactions.occurredAt),
    OrderingTerm.desc(_db.transactions.createdAt),
    OrderingTerm.desc(_db.transactions.id),
  ];

  /// Số dư = SUM(amount_minor) phát trực tiếp từ drift `Stream` — không có
  /// cột `balance`, không có biến đệm nào giữ giá trị này ở tầng repository.
  /// VND cố định ở v1 (chưa có đa loại tiền tệ trong UI).
  Stream<Money> watchBalance() {
    final sumExpr = _db.transactions.amountMinor.sum();
    final query = _db.selectOnly(_db.transactions)..addColumns([sumExpr]);
    return query.watchSingle().map((row) {
      final total = row.read(sumExpr) ?? 0;
      return Money.vnd(total);
    });
  }

  Stream<List<Transaction>> watchAll({int? limit}) {
    final query = _db.select(_db.transactions)..orderBy(_newestFirst);
    if (limit != null) {
      query.limit(limit);
    }
    return query.watch();
  }

  /// Giống [watchAll] nhưng join sẵn `categories` — `TransactionRow`
  /// (lib/ui) cần `categoryColorId`/`iconCode` để tô đúng màu qua theme
  /// (D10), không phải chỉ `categoryId` thô.
  ///
  /// [TransactionWithCategory.linesCount] (Phase 14) đọc qua một subquery
  /// scalar đếm số dòng con của mỗi giao dịch — 0 nghĩa là giao dịch KHÔNG
  /// tách dòng (kể cả khi `categoryId` cũng `null`, vd. quick-add chưa xác
  /// nhận danh mục — hai khái niệm "chưa phân loại" và "đã tách nhiều danh
  /// mục" đều có `categoryId: null` nhưng KHÁC NHAU, phải phân biệt được ở
  /// UI, không thể gộp qua cùng một cột).
  /// [tagIds] (Phase 17) — `null`/rỗng = không lọc; khác `null` = chỉ giao
  /// dịch gắn ÍT NHẤT MỘT thẻ trong tập này, cùng kỹ thuật `isInQuery`
  /// (không JOIN thẳng `transaction_tags`) như `ReportsRepository._taggedWith`
  /// — tránh nhân hàng khi một giao dịch gắn nhiều thẻ.
  /// [categoryIds] (Phase 25, màn "Chi tiết danh mục") — `null` = không lọc;
  /// khác `null` = giao dịch có `categoryId` TRỰC TIẾP trong tập này, HOẶC
  /// (giao dịch tách dòng, Phase 14) có ÍT NHẤT một dòng con thuộc tập này —
  /// hai vế nối bằng `|` (OR), không phải JOIN thêm bảng `transaction_lines`
  /// vào câu lệnh ngoài, nên không có rủi ro nhân hàng kiểu Cartesian.
  /// [from]/[to] giới hạn theo `occurredAt` — nửa mở `[from, to)`, cùng quy
  /// ước với `ReportRange` nên hai con số (breakdown báo cáo và danh sách
  /// giao dịch bên dưới nó) luôn nói về đúng một tập giao dịch.
  /// [goalId] (màn "Lịch sử quỹ") — `null` = KHÔNG lọc; khác `null` = chỉ
  /// những giao dịch gắn đúng mục tiêu tiết kiệm đó, tức là lịch sử nạp/rút
  /// của một quỹ. Trước đây không có tham số này nên không có đường nào xem
  /// được một quỹ đã nạp/rút những gì: thẻ quỹ bấm vào chỉ mở sheet sửa
  /// tên/số tiền, còn trong danh sách chung thì mọi khoản quỹ đều đội lốt
  /// "Chưa phân loại".
  Stream<List<TransactionWithCategory>> watchAllWithCategory({
    int? limit,
    Set<int>? tagIds,
    Set<int>? categoryIds,
    DateTime? from,
    DateTime? to,
    int? goalId,
    bool excludeGoalLinked = false,
  }) {
    final linesCountExpr = subqueryExpression<int>(
      _db.selectOnly(_db.transactionLines)
        ..addColumns([_db.transactionLines.id.count()])
        ..where(
          _db.transactionLines.transactionId.equalsExp(_db.transactions.id),
        ),
    );
    // JOIN thêm `savings_goals` để dòng nào gắn quỹ thì mang sẵn TÊN quỹ ra
    // tới UI trong CÙNG một query — `TransactionRow` cần cái tên để hiện
    // "Để dành › Mua nhà" thay vì "Chưa phân loại". LEFT JOIN: tuyệt đại đa
    // số giao dịch có `goalId` null và vẫn phải ra đủ.
    final query =
        _db.select(_db.transactions).join([
            leftOuterJoin(
              _db.categories,
              _db.categories.id.equalsExp(_db.transactions.categoryId),
            ),
            leftOuterJoin(
              _db.savingsGoals,
              _db.savingsGoals.id.equalsExp(_db.transactions.goalId),
            ),
          ])
          ..addColumns([linesCountExpr])
          ..orderBy(_newestFirstJoined);
    if (goalId != null) {
      query.where(_db.transactions.goalId.equals(goalId));
    }
    // Lọc theo hũ TIÊU: một lần nạp quỹ mang danh mục "Phát sinh" không phải
    // chi của hũ chứa "Phát sinh" (xem `JarRepository.watchProgress`), nên
    // danh sách cũng không được liệt kê nó.
    if (excludeGoalLinked) {
      query.where(_db.transactions.goalId.isNull());
    }
    if (tagIds != null && tagIds.isNotEmpty) {
      query.where(
        _db.transactions.id.isInQuery(
          _db.selectOnly(_db.transactionTags)
            ..addColumns([_db.transactionTags.transactionId])
            ..where(_db.transactionTags.tagId.isIn(tagIds)),
        ),
      );
    }
    if (from != null) {
      query.where(_db.transactions.occurredAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where(_db.transactions.occurredAt.isSmallerThanValue(to));
    }
    if (categoryIds != null && categoryIds.isNotEmpty) {
      query.where(
        _db.transactions.categoryId.isIn(categoryIds) |
            _db.transactions.id.isInQuery(
              _db.selectOnly(_db.transactionLines)
                ..addColumns([_db.transactionLines.transactionId])
                ..where(_db.transactionLines.categoryId.isIn(categoryIds)),
            ),
      );
    }
    if (limit != null) {
      query.limit(limit);
    }
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => TransactionWithCategory(
              transaction: row.readTable(_db.transactions),
              category: row.readTableOrNull(_db.categories),
              goal: row.readTableOrNull(_db.savingsGoals),
              linesCount: row.read(linesCountExpr) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// Tìm kiếm không dấu qua FTS5 (Phase 17, xem `transactions_fts.drift`) —
  /// [rawQuery] được `foldToAscii` TRƯỚC khi ghép câu truy vấn MATCH, khớp
  /// đúng cách `note_ascii` được sinh ra lúc ghi (không dấu, chữ thường), để
  /// gõ có dấu hay không dấu đều ra cùng kết quả. Rỗng sau khi fold → trả
  /// danh sách rỗng ngay, không query gì (tránh MATCH '' — cú pháp không hợp
  /// lệ ở FTS5).
  ///
  /// Mỗi từ bọc trong `"..."*` (cụm từ + tiền tố) — vừa tránh FTS5 hiểu nhầm
  /// một từ trùng từ khoá vận hành của nó (`AND`/`OR`/`NOT`/dấu `-`) thành
  /// toán tử thay vì văn bản cần tìm, vừa cho khớp-tiền-tố (gõ dở từ vẫn ra
  /// kết quả, đúng cảm giác "tìm khi đang gõ").
  ///
  /// `asyncExpand` (KHÔNG rxdart) nối hai bước phản ứng: bước 1
  /// (`searchTransactionIds`, sinh bởi drift từ `queries:` ở
  /// `database.dart`) tự phát lại khi CÓ giao dịch mới khớp/hết khớp
  /// (`readsFrom: {transactionsFts}`); bước 2 là một `select().join()` kiểu
  /// giống hệt [watchAllWithCategory], tự phản ánh sửa danh mục/ghi chú của
  /// đúng những giao dịch đang khớp mà không cần bước 1 phát lại.
  Stream<List<TransactionWithCategory>> watchSearch(String rawQuery) {
    final folded = foldToAscii(rawQuery);
    if (folded.isEmpty) return Stream.value(const []);
    final matchQuery = _buildFtsMatchQuery(folded);

    return _db.searchTransactionIds(matchQuery).watch().asyncExpand((
      idStrings,
    ) {
      if (idStrings.isEmpty) {
        return Stream.value(const <TransactionWithCategory>[]);
      }
      final ids = idStrings.map(int.parse).toSet();
      final linesCountExpr = subqueryExpression<int>(
        _db.selectOnly(_db.transactionLines)
          ..addColumns([_db.transactionLines.id.count()])
          ..where(
            _db.transactionLines.transactionId.equalsExp(_db.transactions.id),
          ),
      );
      final query =
          _db.select(_db.transactions).join([
              leftOuterJoin(
                _db.categories,
                _db.categories.id.equalsExp(_db.transactions.categoryId),
              ),
            ])
            ..addColumns([linesCountExpr])
            ..where(_db.transactions.id.isIn(ids))
            ..orderBy(_newestFirstJoined);
      return query.watch().map(
        (rows) => rows
            .map(
              (row) => TransactionWithCategory(
                transaction: row.readTable(_db.transactions),
                category: row.readTableOrNull(_db.categories),
                linesCount: row.read(linesCountExpr) ?? 0,
              ),
            )
            .toList(),
      );
    });
  }

  String _buildFtsMatchQuery(String folded) {
    final tokens = folded
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty);
    return tokens.map((token) => '"${token.replaceAll('"', '""')}"*').join(' ');
  }

  /// Đồng bộ tường minh vào `transactions_fts` (Phase 17) — LUÔN xoá dòng cũ
  /// (nếu có) rồi chèn lại nếu còn `note`, thay vì cố phân biệt "note có đổi
  /// không" — đơn giản hơn và không thể lệch, đúng nơi `noteAscii` chính nó
  /// cũng luôn ghi đè toàn bộ chứ không vá từng phần.
  Future<void> _syncFts(int transactionId, String? note) async {
    await (_db.delete(
      _db.transactionsFts,
    )..where((f) => f.transactionId.equals(transactionId.toString()))).go();
    if (note != null) {
      await _db
          .into(_db.transactionsFts)
          .insert(
            TransactionsFtsCompanion.insert(
              noteAscii: foldToAscii(note),
              transactionId: transactionId.toString(),
            ),
          );
    }
  }

  Future<void> _replaceTags(int transactionId, List<int> tagIds) async {
    await (_db.delete(
      _db.transactionTags,
    )..where((t) => t.transactionId.equals(transactionId))).go();
    for (final tagId in tagIds) {
      await _db
          .into(_db.transactionTags)
          .insert(
            TransactionTagsCompanion.insert(
              transactionId: transactionId,
              tagId: tagId,
            ),
          );
    }
  }

  /// Các dòng con của một giao dịch đã tách (Phase 14), sắp theo `id` (đúng
  /// thứ tự tạo). Rỗng nếu giao dịch không tách — call site tự suy ra "có
  /// tách hay không" từ độ dài danh sách, không cần cột `isSplit` riêng.
  Stream<List<TransactionLine>> watchLinesFor(int transactionId) {
    return (_db.select(_db.transactionLines)
          ..where((l) => l.transactionId.equals(transactionId))
          ..orderBy([(l) => OrderingTerm.asc(l.id)]))
        .watch();
  }

  /// Snapshot MỘT LẦN (không phải `Stream`) — dùng để nạp dòng con hiện có
  /// lúc `TransactionFormSheet` mở ở chế độ Sửa, một lần duy nhất lúc
  /// `initState`, không cần cập nhật sống khi sheet đang mở (không có nơi
  /// nào khác ghi vào `transaction_lines` của CÙNG giao dịch trong lúc sheet
  /// đang mở). Tách khỏi [watchLinesFor] vì một `Stream.first` tạo trực
  /// tiếp trong `initState` (không qua Riverpod `ref.watch`) không đáng tin
  /// cậy hoàn tất trong `pumpAndSettle` của widget test — bắt được bằng test
  /// thật (treo tới hết vòng đời test), một `Future` một lần thì luôn ổn.
  Future<List<TransactionLine>> getLinesFor(int transactionId) {
    return (_db.select(_db.transactionLines)
          ..where((l) => l.transactionId.equals(transactionId))
          ..orderBy([(l) => OrderingTerm.asc(l.id)]))
        .get();
  }

  /// Thu/chi CỘNG DỒN TỪ ĐẦU THÁNG chứa [reference] — nguồn cho số hero
  /// "chi tiêu từ đầu tháng" (KHÔNG PHẢI số dư — số dư của app nhập tay là
  /// hư cấu, xem TODOS.md § Bố cục). `reference` luôn đến từ `Clock` inject
  /// ở tầng gọi (provider), KHÔNG bao giờ `DateTime.now()` ở đây.
  ///
  /// Loại `isTransfer` (Phase 13) — chuyển khoản giữa ví không phải thu/chi,
  /// tính vào đây sẽ thổi phồng cả hai con số (xem docs/decisions.md § Phase
  /// 13 "Chuyển khoản"). Tổng TOÀN VÍ (`watchBalance`) KHÔNG lọc — xem lý do
  /// ở đó.
  /// [from]/[to] ghi đè khoảng mặc định (tháng lịch chứa [reference]) — màn
  /// Giao dịch truyền đúng kỳ đang lọc vào đây, nếu không thẻ tổng ở đầu
  /// màn nói về tháng lịch còn danh sách bên dưới nói về kỳ đã chọn: hai
  /// con số cạnh nhau, không con số nào sai riêng lẻ, mà đặt cạnh nhau thì
  /// trông như app tính sai.
  Stream<MonthSummary> watchMonthToDateSummary(
    DateTime reference, {
    DateTime? from,
    DateTime? to,
  }) {
    final monthStart = from ?? DateTime(reference.year, reference.month);
    final monthEnd = to ?? DateTime(reference.year, reference.month + 1);

    // Một query watch duy nhất (không rxdart để combine hai stream) — cộng
    // hai chiều thu/chi bằng Dart trên tập kết quả đã lọc theo tháng, đủ rẻ
    // vì khối lượng giao dịch một tháng của một người dùng cá nhân rất nhỏ.
    final query = _db.select(_db.transactions)
      ..where(
        (t) =>
            t.occurredAt.isBiggerOrEqualValue(monthStart) &
            t.occurredAt.isSmallerThanValue(monthEnd) &
            t.isTransfer.equals(false),
      );
    return query.watch().map((rows) {
      var expense = 0;
      var income = 0;
      var savings = 0;
      for (final row in rows) {
        // 🚨 Dòng gắn MỤC TIÊU TIẾT KIỆM tách riêng, không cộng vào thu/chi.
        //
        // Cất tiền không phải là tiêu tiền (nên không vào `expense`), nhưng
        // cũng không còn là tiền tiêu được (nên phải trừ khỏi `net`). Trước
        // đây những dòng này bị loại HẲN khỏi truy vấn, nên "Còn lại" ở tab
        // Giao dịch báo dư nhiều hơn thực tế — đúng lỗi Tony chỉ ra, cùng
        // một lỗi với Trang chủ.
        if (row.goalId != null) {
          savings += row.amountMinor;
        } else if (row.amountMinor < 0) {
          expense += row.amountMinor;
        } else {
          income += row.amountMinor;
        }
      }
      return MonthSummary(
        expense: Money.vnd(expense),
        income: Money.vnd(income),
        savings: Money.vnd(savings),
      );
    });
  }

  /// [categoryId] bị BỎ QUA (giao dịch cha lưu `categoryId: null`) khi
  /// [lines] có ≥1 phần tử — một giao dịch tách dòng không còn một danh mục
  /// đơn nào đúng nữa, xem docs/decisions.md § Phase 14 "Tách giao dịch: hai
  /// đường dữ liệu". Tổng [lines] PHẢI khớp `amount.minorUnits` — kiểm ở
  /// ĐÂY (ranh giới repository, có thể có nhiều call site trong tương lai),
  /// KHÔNG phải ràng buộc DB (SQLite không kiểm được tổng qua nhiều hàng
  /// trong một CHECK cột); form tự kiểm lại lần nữa trước khi gọi để báo lỗi
  /// tại chỗ thay vì chờ round-trip DB.
  Future<Result<int, AppError>> insert({
    required Money amount,
    required DateTime occurredAt,
    required int walletId,
    int? categoryId,
    String? note,
    String? sourceId,
    List<TransactionLineInput>? lines,
    int? goalId,
    int? debtId,
    List<int>? tagIds,
    String? receiptImageFilename,
  }) async {
    final linesError = _validateLines(lines, amount.minorUnits);
    if (linesError != null) return Err(linesError);

    try {
      final id = await _db.transaction(() async {
        final newId = await _db
            .into(_db.transactions)
            .insert(
              TransactionsCompanion.insert(
                amountMinor: amount.minorUnits,
                currency: amount.currency,
                currencyScale: amount.currencyScale,
                occurredAt: occurredAt,
                walletId: walletId,
                categoryId: Value(
                  lines == null || lines.isEmpty ? categoryId : null,
                ),
                note: Value(note),
                noteAscii: Value(note == null ? null : foldToAscii(note)),
                sourceId: Value(sourceId),
                goalId: Value(goalId),
                debtId: Value(debtId),
                receiptImageFilename: Value(receiptImageFilename),
              ),
            );
        if (lines != null && lines.isNotEmpty) {
          await _insertLines(newId, lines);
        }
        if (tagIds != null && tagIds.isNotEmpty) {
          await _replaceTags(newId, tagIds);
        }
        await _syncFts(newId, note);
        return newId;
      });
      return Ok(id);
    } catch (e) {
      final error = AppError('Không lưu được giao dịch.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  Future<void> _insertLines(
    int transactionId,
    List<TransactionLineInput> lines,
  ) async {
    for (final line in lines) {
      await _db
          .into(_db.transactionLines)
          .insert(
            TransactionLinesCompanion.insert(
              transactionId: transactionId,
              categoryId: Value(line.categoryId),
              amountMinor: line.amountMinor,
            ),
          );
    }
  }

  /// `null` = hợp lệ (không tách dòng, hoặc tổng khớp) — trả `AppError` với
  /// thông điệp tiếng Việt rõ ràng khi lệch, để form hiện thẳng ra không cần
  /// dịch lại một mã lỗi chung chung.
  AppError? _validateLines(
    List<TransactionLineInput>? lines,
    int parentAmountMinor,
  ) {
    if (lines == null || lines.isEmpty) return null;
    final sum = lines.fold<int>(0, (acc, l) => acc + l.amountMinor);
    if (sum != parentAmountMinor) {
      return AppError(
        'Tổng các dòng con ($sum) không khớp tổng giao dịch ($parentAmountMinor).',
      );
    }
    return null;
  }

  /// Tập con của [sourceIds] ĐÃ TỒN TẠI trong DB — nguồn cho báo cáo dry-run
  /// diff của importer (Phase 9): "N giao dịch mới, M đã có sẵn sẽ bỏ qua"
  /// trước khi commit bất cứ gì.
  Future<Set<String>> findExistingSourceIds(Iterable<String> sourceIds) async {
    final ids = sourceIds.toList();
    if (ids.isEmpty) return {};
    final rows = await (_db.select(
      _db.transactions,
    )..where((t) => t.sourceId.isIn(ids))).get();
    return rows.map((r) => r.sourceId!).toSet();
  }

  /// Ghi hàng loạt giao dịch có `sourceId` — dùng cho importer (Phase 9),
  /// KHÔNG dùng cho quick-add/form tay (chúng gọi [insert] trực tiếp,
  /// `sourceId: null`). Bỏ qua NGAY từ đầu mọi dòng có `sourceId` đã tồn tại
  /// (tính bằng [findExistingSourceIds] TRƯỚC, không dựa vào SQLite tự chặn
  /// UNIQUE lúc insert — an toàn vì app chỉ có một tiến trình ghi, không có
  /// race giữa lúc kiểm tra và lúc ghi). Bọc trong MỘT transaction: hỏng giữa
  /// chừng thì không có dòng nào được ghi, không import dở dang.
  Future<Result<ImportBatchSummary, AppError>> insertImportBatch(
    List<
      ({
        int amountMinor,
        DateTime occurredAt,
        int? categoryId,
        String? note,
        String sourceId,
        bool isTransfer,
      })
    >
    rows, {
    required int walletId,
  }) async {
    try {
      final existing = await findExistingSourceIds(rows.map((r) => r.sourceId));
      final toInsert = rows
          .where((r) => !existing.contains(r.sourceId))
          .toList();

      await _db.transaction(() async {
        for (final row in toInsert) {
          await _db
              .into(_db.transactions)
              .insert(
                TransactionsCompanion.insert(
                  amountMinor: row.amountMinor,
                  currency: 'VND',
                  currencyScale: 0,
                  occurredAt: row.occurredAt,
                  walletId: walletId,
                  categoryId: Value(row.categoryId),
                  note: Value(row.note),
                  noteAscii: Value(
                    row.note == null ? null : foldToAscii(row.note!),
                  ),
                  sourceId: Value(row.sourceId),
                  isTransfer: Value(row.isTransfer),
                ),
              );
        }
      });

      return Ok(
        ImportBatchSummary(
          inserted: toInsert.length,
          skippedDuplicate: rows.length - toInsert.length,
        ),
      );
    } catch (e) {
      final error = AppError(
        'Import thất bại — không có dòng nào được ghi.',
        cause: e,
      );
      await _logError(error);
      return Err(error);
    }
  }

  /// [updatedAt] do tầng gọi truyền vào (từ `Clock` inject, Luật #3) —
  /// repository không tự đọc giờ hệ thống.
  /// [walletId] mặc định KHÔNG đổi nếu không truyền (`null`) — khác các
  /// trường khác (luôn ghi đè toàn bộ) vì hai call site sửa nhanh của
  /// quick-add (`correctCategory`/`correctDate`, Phase 8) chỉ biết
  /// `categoryId`/`date` mới, không giữ `walletId` trong state phiên chat;
  /// chỉ form sửa tay đầy đủ (`TransactionFormSheet`, Phase 13) mới có UI
  /// chọn ví nên mới truyền tường minh.
  /// [lines] cùng kiểu "Value 3 trạng thái" như drift Companion tự thân:
  /// `Value.absent()` (mặc định, KHÔNG truyền) = không đụng tới dòng con
  /// hiện có — quan trọng cho `correctCategory`/`correctDate` (Phase 8) và
  /// [duplicateTransactionWithUndo]-kiểu call site không biết gì về tách
  /// dòng, không được vô tình xoá mất một giao dịch đã tách của người dùng.
  /// `Value([])` = bỏ tách (xoá hết dòng con, quay về `categoryId` đơn qua
  /// [categoryId] tham số). `Value([...])` = thay TOÀN BỘ dòng con hiện có
  /// bằng danh sách mới (xoá cũ, chèn mới — form luôn gửi lại đầy đủ trạng
  /// thái nó biết, không có "sửa từng dòng").
  /// [goalId]/[debtId] cùng kiểu "Value 3 trạng thái" như [lines]:
  /// `Value.absent()` (mặc định) = KHÔNG đụng gắn kết hiện có — bắt buộc cho
  /// `correctCategory`/`correctDate` (Phase 8) và mọi call site không biết
  /// gì về mục tiêu/nợ, để không vô tình THÁO gắn kết một giao dịch Tony đã
  /// gắn với mục tiêu/khoản vay trước đó (cùng lý do [walletId] ở trên,
  /// Phase 16). `Value(id)`/`Value(null)` = ghi đè tường minh (gắn mới/tháo
  /// gắn) — `TransactionFormSheet` luôn gửi tường minh vì nó luôn biết trạng
  /// thái hiện tại.
  Future<Result<void, AppError>> update({
    required int id,
    required Money amount,
    required DateTime occurredAt,
    required DateTime updatedAt,
    int? walletId,
    int? categoryId,
    String? note,
    Value<List<TransactionLineInput>> lines = const Value.absent(),
    Value<int?> goalId = const Value.absent(),
    Value<int?> debtId = const Value.absent(),

    /// Cùng kiểu "Value 3 trạng thái" như [lines]/[goalId] — `absent()` =
    /// KHÔNG đụng thẻ hiện có (bắt buộc cho `correctCategory`/`correctDate`,
    /// không biết gì về thẻ). `Value([])` = gỡ hết thẻ, `Value([...])` =
    /// thay TOÀN BỘ (xoá cũ, gắn mới — cùng logic [lines]).
    Value<List<int>> tagIds = const Value.absent(),

    /// `absent()` = không đụng ảnh hiện có. `Value(null)` = gỡ ảnh (xoá file
    /// cũ khỏi đĩa). `Value(fileName)` = thay ảnh MỚI — file cũ (nếu có và
    /// khác file mới) bị xoá SAU KHI transaction DB thành công, không phải
    /// trong lúc transaction đang chạy (I/O đĩa không thuộc phạm vi rollback
    /// của SQLite, không có lý do giữ nó trong cùng khối).
    Value<String?> receiptImageFilename = const Value.absent(),
  }) async {
    if (lines.present) {
      final linesError = _validateLines(lines.value, amount.minorUnits);
      if (linesError != null) return Err(linesError);
    }

    try {
      String? oldReceiptImageFilename;
      final rowsAffected = await _db.transaction(() async {
        if (receiptImageFilename.present) {
          final existing = await (_db.select(
            _db.transactions,
          )..where((t) => t.id.equals(id))).getSingleOrNull();
          oldReceiptImageFilename = existing?.receiptImageFilename;
        }
        final affected =
            await (_db.update(
              _db.transactions,
            )..where((t) => t.id.equals(id))).write(
              TransactionsCompanion(
                amountMinor: Value(amount.minorUnits),
                currency: Value(amount.currency),
                currencyScale: Value(amount.currencyScale),
                occurredAt: Value(occurredAt),
                walletId: walletId == null
                    ? const Value.absent()
                    : Value(walletId),
                categoryId: lines.present && lines.value.isNotEmpty
                    ? const Value(null)
                    : Value(categoryId),
                note: Value(note),
                noteAscii: Value(note == null ? null : foldToAscii(note)),
                updatedAt: Value(updatedAt),
                goalId: goalId,
                debtId: debtId,
                receiptImageFilename: receiptImageFilename,
              ),
            );
        if (affected > 0) {
          if (lines.present) {
            await (_db.delete(
              _db.transactionLines,
            )..where((l) => l.transactionId.equals(id))).go();
            if (lines.value.isNotEmpty) {
              await _insertLines(id, lines.value);
            }
          }
          if (tagIds.present) {
            await _replaceTags(id, tagIds.value);
          }
          await _syncFts(id, note);
        }
        return affected;
      });
      if (rowsAffected == 0) {
        return Err(AppError('Giao dịch không còn tồn tại để sửa.'));
      }
      if (receiptImageFilename.present &&
          oldReceiptImageFilename != null &&
          oldReceiptImageFilename != receiptImageFilename.value) {
        await _receiptImages.deleteImage(oldReceiptImageFilename!);
      }
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không sửa được giao dịch.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  /// Ảnh chụp ĐỦ để dựng lại một giao dịch sau khi đã xoá — chụp TRƯỚC khi
  /// gọi [delete], vì `delete` xoá luôn dòng con, thẻ và file ảnh; sau đó thì
  /// không còn gì để đọc.
  ///
  /// 🚨 Tồn tại vì "Hoàn tác" từng chèn lại đúng năm cột nằm sẵn trong
  /// [Transaction] (`amount/occurredAt/walletId/categoryId/note`) và bỏ rơi
  /// tất cả phần còn lại. Hậu quả đo được trên máy thật: hoàn tác một khoản
  /// NẠP QUỸ trả tiền về ví nhưng `goalId` mất, nên quỹ không hồi — ví vẫn
  /// −11.000.000 mà quỹ tụt từ 6.000.000 về 5.000.000, tức là một triệu biến
  /// mất khỏi sổ và hiện lại thành một khoản chi "Chưa phân loại".
  Future<DeletedTransactionSnapshot?> captureForUndo(int id) async {
    final transaction = await (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (transaction == null) return null;

    final lines = await getLinesFor(id);
    final tagRows = await (_db.select(
      _db.transactionTags,
    )..where((t) => t.transactionId.equals(id))).get();
    final receiptFileName = transaction.receiptImageFilename;
    final receiptBytes = receiptFileName == null
        ? null
        : await _receiptImages.readImage(receiptFileName);

    return DeletedTransactionSnapshot(
      transaction: transaction,
      lines: [
        for (final line in lines)
          TransactionLineInput(
            categoryId: line.categoryId,
            amountMinor: line.amountMinor,
          ),
      ],
      tagIds: [for (final row in tagRows) row.tagId],
      receiptImageFilename: receiptFileName,
      receiptImageBytes: receiptBytes,
    );
  }

  /// Chèn lại một giao dịch từ [snapshot] — id MỚI, không khôi phục id cũ.
  /// Chấp nhận được cho một app cá nhân: không có gì tham chiếu tới id giao
  /// dịch từ bên ngoài.
  ///
  /// Ảnh ghi lại bằng `writeImageWithFilename` (ĐÚNG tên file cũ) chứ không
  /// phải `saveImage` (tự sinh tên mới), để hàng khôi phục mang lại chính
  /// `receiptImageFilename` cũ.
  Future<Result<int, AppError>> restore(
    DeletedTransactionSnapshot snapshot,
  ) async {
    final transaction = snapshot.transaction;
    final fileName = snapshot.receiptImageFilename;
    final bytes = snapshot.receiptImageBytes;
    if (fileName != null && bytes != null) {
      await _receiptImages.writeImageWithFilename(fileName, bytes);
    }
    return insert(
      amount: Money(
        minorUnits: transaction.amountMinor,
        currency: transaction.currency,
        currencyScale: transaction.currencyScale,
      ),
      occurredAt: transaction.occurredAt,
      walletId: transaction.walletId,
      categoryId: transaction.categoryId,
      note: transaction.note,
      lines: snapshot.lines.isEmpty ? null : snapshot.lines,
      goalId: transaction.goalId,
      debtId: transaction.debtId,
      tagIds: snapshot.tagIds,
      receiptImageFilename: bytes == null ? null : fileName,
    );
  }

  Future<Result<void, AppError>> delete(int id) async {
    try {
      final existing = await (_db.select(
        _db.transactions,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      await _db.transaction(() async {
        await (_db.delete(
          _db.transactionLines,
        )..where((l) => l.transactionId.equals(id))).go();
        await (_db.delete(
          _db.transactionTags,
        )..where((t) => t.transactionId.equals(id))).go();
        await (_db.delete(
          _db.transactionsFts,
        )..where((f) => f.transactionId.equals(id.toString()))).go();
        await (_db.delete(
          _db.transactions,
        )..where((t) => t.id.equals(id))).go();
      });
      if (existing?.receiptImageFilename != null) {
        await _receiptImages.deleteImage(existing!.receiptImageFilename!);
      }
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không xoá được giao dịch.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  Future<void> _logError(AppError error) async {
    await _db
        .into(_db.appEvents)
        .insert(
          AppEventsCompanion.insert(
            level: 'error',
            message: error.message,
            contextJson: Value(error.cause?.toString()),
          ),
        );
  }
}

class TransactionWithCategory {
  const TransactionWithCategory({
    required this.transaction,
    this.category,
    this.goal,
    this.linesCount = 0,
  });

  final Transaction transaction;

  /// Mục tiêu tiết kiệm mà giao dịch này gắn vào — `null` cho giao dịch
  /// thường (tuyệt đại đa số). Khác `null` nghĩa là đây là một lần NẠP (số
  /// âm) hoặc RÚT (số dương) quỹ, và UI phải hiện nó ra như vậy: một khoản
  /// để dành không có danh mục nên nếu chỉ nhìn `category == null` thì nó
  /// trông y hệt một khoản "chưa phân loại", đúng lỗi Tony chỉ ra.
  final SavingsGoal? goal;

  /// `null` khi `categoryId` là null HOẶC danh mục đã bị xoá — call site
  /// (`TransactionRow`) phải tự quyết định fallback (icon "?", màu xám).
  final Category? category;

  /// Số dòng con đã tách (Phase 14) — `0` nghĩa là KHÔNG tách. Khác `category
  /// == null` đơn thuần: một giao dịch "chưa phân loại" (chưa xác nhận danh
  /// mục ở quick-add) cũng có `category == null` nhưng `linesCount == 0` —
  /// hai khái niệm khác nhau, UI phải phân biệt qua trường này chứ không thể
  /// suy luận từ `category`.
  final int linesCount;

  bool get isSplit => linesCount > 0;
}

/// Mọi thứ cần để dựng lại một giao dịch đã xoá — xem
/// [TransactionRepository.captureForUndo].
class DeletedTransactionSnapshot {
  const DeletedTransactionSnapshot({
    required this.transaction,
    required this.lines,
    required this.tagIds,
    this.receiptImageFilename,
    this.receiptImageBytes,
  });

  final Transaction transaction;

  /// Rỗng khi giao dịch KHÔNG tách dòng.
  final List<TransactionLineInput> lines;
  final List<int> tagIds;

  /// Tên file ảnh hoá đơn cũ, và nội dung đọc ra trước khi `delete` xoá file.
  /// [receiptImageBytes] `null` khi giao dịch không có ảnh, hoặc file đã biến
  /// mất khỏi đĩa từ trước (khôi phục vẫn chạy, chỉ không có ảnh).
  final String? receiptImageFilename;
  final Uint8List? receiptImageBytes;
}

/// Một dòng con khi TẠO/SỬA một giao dịch tách (Phase 14) — snapshot trước
/// khi ghi, chưa có `id` (repository tự sinh lúc insert). Khác
/// `TransactionLine` (bản ghi DB thật, có `id`/`transactionId`) — tách riêng
/// để form không cần biết `transactionId` trước khi giao dịch cha được tạo.
class TransactionLineInput {
  const TransactionLineInput({
    required this.categoryId,
    required this.amountMinor,
  });

  final int? categoryId;
  final int amountMinor;
}

class ImportBatchSummary {
  const ImportBatchSummary({
    required this.inserted,
    required this.skippedDuplicate,
  });

  final int inserted;

  /// Đã có `sourceId` trùng từ trước — import lần hai của cùng file phải
  /// cho ra `inserted: 0` và `skippedDuplicate` bằng tổng số dòng.
  final int skippedDuplicate;
}

class MonthSummary {
  const MonthSummary({
    required this.expense,
    required this.income,
    this.savings = const Money.vnd(0),
  });

  /// Luôn ≤ 0 (hoặc = 0) — tổng `amountMinor` của mọi giao dịch chi trong kỳ.
  final Money expense;

  /// Luôn ≥ 0 — tổng `amountMinor` của mọi giao dịch thu trong kỳ.
  final Money income;

  /// Tiền ra/vào MỤC TIÊU TIẾT KIỆM. ÂM = đã cất đi. KHÔNG nằm trong
  /// [expense] — cùng quy ước với `PeriodSummary.savingsMinor`.
  final Money savings;

  /// Còn lại THẬT SỰ tiêu được: thu − chi − phần đã cất vào tiết kiệm.
  Money get net =>
      Money.vnd(income.minorUnits + expense.minorUnits + savings.minorUnits);
}
