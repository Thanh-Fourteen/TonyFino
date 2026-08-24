import 'package:drift/drift.dart';

import '../../core/money/money.dart';
import '../../core/result/result.dart';
import '../db/database.dart';

/// Số dư một ví, gộp trực tiếp — KHÔNG lưu cột nào (D7 mở rộng sang ví, Phase
/// 13). Chuyển khoản VẪN tính vào số dư từng ví (khác báo cáo/ngân sách theo
/// danh mục, nơi chuyển khoản bị loại) vì nó thật sự đổi số dư của ví đó.
class WalletBalance {
  const WalletBalance({required this.wallet, required this.balance});

  final Wallet wallet;
  final Money balance;
}

class WalletRepository {
  WalletRepository(this._db);

  final AppDatabase _db;

  Stream<List<Wallet>> watchActive() {
    final query = _db.select(_db.wallets)
      ..where((w) => w.isArchived.equals(false))
      ..orderBy([(w) => OrderingTerm.asc(w.id)]);
    return query.watch();
  }

  Stream<List<Wallet>> watchArchived() {
    final query = _db.select(_db.wallets)
      ..where((w) => w.isArchived.equals(true))
      ..orderBy([(w) => OrderingTerm.asc(w.id)]);
    return query.watch();
  }

  /// Số dư từng ví, JOIN + `SUM` trong MỘT query — LEFT JOIN để ví chưa có
  /// giao dịch nào vẫn hiện (số dư 0), cùng kỹ thuật `BudgetRepository`
  /// (Phase 11).
  Stream<List<WalletBalance>> watchActiveBalances() {
    final w = _db.wallets;
    final t = _db.transactions;
    final sumExpr = t.amountMinor.sum();

    final query =
        _db.select(w).join([leftOuterJoin(t, t.walletId.equalsExp(w.id))])
          ..addColumns([sumExpr])
          ..where(w.isArchived.equals(false))
          ..groupBy([w.id])
          ..orderBy([OrderingTerm.asc(w.id)]);

    return query.watch().map(
      (rows) => rows.map((row) {
        final wallet = row.readTable(w);
        // Số dư = SỐ DƯ BAN ĐẦU + tổng giao dịch (v12). Quên vế đầu là
        // lỗi im lặng khó thấy nhất ở đây: mọi con số vẫn "trông hợp
        // lý", chỉ lệch đúng bằng số Tony đã khai.
        return WalletBalance(
          wallet: wallet,
          balance: Money.vnd(
            wallet.openingBalanceMinor + (row.read(sumExpr) ?? 0),
          ),
        );
      }).toList(),
    );
  }

  /// "Ví mặc định" cho quick-add/importer (Phase 13) — ví có `id` nhỏ nhất
  /// hiện có, KHÔNG cần cột `isDefault` riêng (xem docs/decisions.md § Phase
  /// 13). Luôn có ít nhất một ví (migration/`onCreate` đảm bảo).
  Future<int> defaultWalletId() async {
    final row =
        await (_db.select(_db.wallets)
              ..orderBy([(w) => OrderingTerm.asc(w.id)])
              ..limit(1))
            .getSingle();
    return row.id;
  }

  /// Ví mới sinh ra CÓ SẴN bộ danh mục mặc định (v11 — mỗi ví có danh mục
  /// riêng). Không seed thì ví vừa tạo rỗng danh mục, và Tony phải gõ tay 13
  /// danh mục trước khi ghi được đồng đầu tiên — một cái ví không dùng được
  /// ngay là ví hỏng. Tony vẫn tự do thêm/sửa/xoá sau đó.
  ///
  /// Cả hai bước nằm trong MỘT transaction: tạo ví xong mà seed hỏng giữa
  /// chừng sẽ để lại một ví nửa vời.
  Future<Result<int, AppError>> insert({
    required String name,
    required int categoryColorId,
    required String iconCode,
    int openingBalanceMinor = 0,
  }) async {
    try {
      final id = await _db.transaction(() async {
        final walletId = await _db
            .into(_db.wallets)
            .insert(
              WalletsCompanion.insert(
                name: name,
                categoryColorId: categoryColorId,
                iconCode: iconCode,
                openingBalanceMinor: Value(openingBalanceMinor),
              ),
            );
        await seedDefaultCategories(_db, walletId: walletId);
        return walletId;
      });
      return Ok(id);
    } catch (e) {
      final error = AppError('Không tạo được ví.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  Future<Result<void, AppError>> update({
    required int id,
    required String name,
    required int categoryColorId,
    required String iconCode,
    int? openingBalanceMinor,
  }) async {
    try {
      await (_db.update(_db.wallets)..where((w) => w.id.equals(id))).write(
        WalletsCompanion(
          name: Value(name),
          categoryColorId: Value(categoryColorId),
          iconCode: Value(iconCode),
          openingBalanceMinor: openingBalanceMinor == null
              ? const Value.absent()
              : Value(openingBalanceMinor),
        ),
      );
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không sửa được ví.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  /// Lưu trữ/khôi phục — KHÔNG BAO GIỜ xoá cứng một ví (đã có giao dịch tham
  /// chiếu qua FK `transactions.walletId`).
  Future<Result<void, AppError>> setArchived(int id, bool archived) async {
    try {
      await (_db.update(_db.wallets)..where((w) => w.id.equals(id))).write(
        WalletsCompanion(isArchived: Value(archived)),
      );
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không cập nhật được trạng thái ví.', cause: e);
      await _logError(error);
      return Err(error);
    }
  }

  /// Chuyển khoản giữa 2 ví (Phase 13) — tạo HAI dòng `transactions` liên kết
  /// qua `linkedTransactionId`, `categoryId: null` cho cả hai, `isTransfer:
  /// true` để loại khỏi báo cáo/ngân sách theo danh mục (xem
  /// docs/decisions.md § Phase 13 "Chuyển khoản"). Cả hai dòng cùng
  /// [occurredAt]/[note]. Trong MỘT `db.transaction()` — hỏng giữa chừng thì
  /// không dòng nào được ghi.
  Future<Result<void, AppError>> createTransfer({
    required int sourceWalletId,
    required int destWalletId,
    required Money amount,
    required DateTime occurredAt,
    String? note,
  }) async {
    if (sourceWalletId == destWalletId) {
      return const Err(AppError('Ví nguồn và ví đích phải khác nhau.'));
    }
    try {
      await _db.transaction(() async {
        final sourceId = await _db
            .into(_db.transactions)
            .insert(
              TransactionsCompanion.insert(
                amountMinor: -amount.abs.minorUnits,
                currency: amount.currency,
                currencyScale: amount.currencyScale,
                occurredAt: occurredAt,
                walletId: sourceWalletId,
                categoryId: const Value(null),
                note: Value(note),
                isTransfer: const Value(true),
              ),
            );
        final destId = await _db
            .into(_db.transactions)
            .insert(
              TransactionsCompanion.insert(
                amountMinor: amount.abs.minorUnits,
                currency: amount.currency,
                currencyScale: amount.currencyScale,
                occurredAt: occurredAt,
                walletId: destWalletId,
                categoryId: const Value(null),
                note: Value(note),
                isTransfer: const Value(true),
                linkedTransactionId: Value(sourceId),
              ),
            );
        await (_db.update(_db.transactions)
              ..where((t) => t.id.equals(sourceId)))
            .write(TransactionsCompanion(linkedTransactionId: Value(destId)));
      });
      return const Ok(null);
    } catch (e) {
      final error = AppError('Không tạo được chuyển khoản.', cause: e);
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
