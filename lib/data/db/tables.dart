import 'package:drift/drift.dart';

/// Giao dịch. `amountMinor` CÓ DẤU (dương = thu, âm = chi) — đây là điều khiến
/// `Balance = SUM(amount_minor)` (D7) đúng bằng một phép SUM duy nhất, không
/// cần CASE theo `type`. KHÔNG có cột balance ở đây hay bất cứ đâu khác.
///
/// Index UNIQUE trên `sourceId` khai báo riêng (không phải `.unique()` trên
/// cột) vì SQLite từ chối `ALTER TABLE ADD COLUMN ... UNIQUE` thẳng —
/// `onUpgrade` v1→v2 phải `addColumn` trước rồi `createIndex` sau, hai bước
/// tách rời (xem `database.dart`).
@TableIndex(
  name: 'idx_transactions_source_id',
  columns: {#sourceId},
  unique: true,
)
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  IntColumn get currencyScale => integer()();
  DateTimeColumn get occurredAt => dateTime()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  TextColumn get note => text().nullable()();

  /// Ví chứa giao dịch này (Phase 13). NOT NULL — mọi giao dịch cũ được
  /// backfill vào "Ví mặc định" lúc migration schemaVersion 3→4 (xem
  /// docs/decisions.md § Phase 13 "Chiến lược migration 3→4").
  IntColumn get walletId => integer().references(Wallets, #id)();

  /// Chuyển khoản giữa 2 ví (Phase 13) — hai dòng liên kết qua
  /// [linkedTransactionId], `categoryId: null` cho cả hai (chuyển khoản
  /// không phải chi/thu, không có danh mục), loại khỏi mọi báo cáo/ngân sách
  /// theo danh mục bằng `& isTransfer.equals(false)`. Xem docs/decisions.md
  /// § Phase 13 "Chuyển khoản".
  BoolColumn get isTransfer => boolean().withDefault(const Constant(false))();
  IntColumn get linkedTransactionId =>
      integer().nullable().references(Transactions, #id)();

  /// Gắn giao dịch này với một mục tiêu tiết kiệm (Phase 16) — nullable, độc
  /// lập với `categoryId` (một giao dịch vừa có thể có danh mục "Mua sắm" vừa
  /// gắn một mục tiêu, vd. tiết kiệm mua một món đồ cụ thể). Xem `SavingsGoals`.
  IntColumn get goalId => integer().nullable().references(SavingsGoals, #id)();

  /// Gắn giao dịch này với một khoản vay/cho vay (Phase 16) — nullable, độc
  /// lập với `categoryId`. Xem `Debts`.
  IntColumn get debtId => integer().nullable().references(Debts, #id)();

  /// Cột bóng cho tìm kiếm không dấu — luôn `foldToAscii(note)`, giữ đồng bộ ở
  /// tầng repository, không ở DB. Từ Phase 17, đây chính là cột được đánh chỉ
  /// mục bởi bảng ảo `transactions_fts` (FTS5, tạo bằng SQL thô ở
  /// `database.dart`, KHÔNG khai báo Table Dart — drift's Table builder không
  /// có API cho virtual table, xem docs/decisions.md § Phase 17).
  TextColumn get noteAscii => text().nullable()();

  /// TÊN FILE ảnh hoá đơn đính kèm (Phase 17) — TUYỆT ĐỐI không phải đường
  /// dẫn tuyệt đối (Luật #5). File thật nằm ở thư mục app riêng
  /// (`ReceiptImageService`, `<app documents>/receipts/<tên file>`), resolve
  /// lại thư mục gốc mỗi lần mở app thay vì tin cache. `null` = không có ảnh.
  TextColumn get receiptImageFilename => text().nullable()();

  /// Khoá idempotent cho dữ liệu NHẬP TỪ NGUỒN NGOÀI (Phase 9 importer Rolly,
  /// CSV) — `null` cho giao dịch tạo tay/qua quick-add. Dạng `'rolly:<id>'`
  /// hay `'csv:<...>'`; UNIQUE khi khác null (SQLite coi nhiều `NULL` là
  /// KHÔNG trùng nhau trong ràng buộc UNIQUE, đúng ý: giao dịch tay không
  /// bao giờ cần so trùng qua cột này) — ràng buộc UNIQUE nằm ở
  /// `@TableIndex` phía trên, không phải `.unique()` ở đây. Chạy import lần
  /// hai gặp `sourceId` đã có thì bỏ qua dòng đó thay vì chèn trùng — xem
  /// bảng ánh xạ field ở `docs/decisions.md` § Phase 9.
  TextColumn get sourceId => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Danh mục. `categoryColorId` là CHỈ SỐ vào bảng màu cố định của theme
/// (D10) — TUYỆT ĐỐI không lưu chuỗi hex. Đây là sai lầm không thể đảo
/// ngược phổ biến nhất trong app quản lý chi tiêu (xem docs/decisions.md).
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// `'expense'` hoặc `'income'` — chỉ để gợi ý dấu mặc định ở quick-add.
  TextColumn get kind => text()();

  IntColumn get categoryColorId => integer()();
  TextColumn get iconCode => text()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Emoji TUỲ CHỌN cho danh mục (Phase 17) — `null` = dùng `iconCode` như
  /// cũ (mọi danh mục hiện có, kể cả 12 danh mục seed). Khi có, hiện thành
  /// một dấu nhỏ đè lên góc `CategoryAvatar` — KHÔNG thay thế icon, vì icon
  /// vẫn là nguồn nhận diện màu/hình chính (D10), emoji chỉ là điểm nhấn cá
  /// nhân hoá thêm. Xem docs/decisions.md § Phase 17 "Emoji danh mục".
  TextColumn get emoji => text().nullable()();

  /// Danh mục cha (Phase 13) — CHỈ MỘT CẤP, validate ở `CategoryRepository`
  /// rằng một danh mục đã có `parentCategoryId` không được làm cha của danh
  /// mục khác (xem docs/decisions.md § Phase 13 "Danh mục con CHỈ MỘT CẤP").
  IntColumn get parentCategoryId =>
      integer().nullable().references(Categories, #id)();

  /// Thứ tự hiển thị/kéo-thả trong nhóm cùng cấp (cùng `parentCategoryId`) —
  /// KHÔNG toàn cục. Danh mục mới mặc định xếp cuối nhóm của nó
  /// (`CategoryRepository.insert` tự tính `MAX(sortOrder)+1`); 12 danh mục
  /// seed cũ backfill về 0 lúc migration, thứ tự hiển thị giữ nguyên nhờ
  /// tie-break phụ `ORDER BY sortOrder, id`.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Ví sở hữu danh mục này — MỖI VÍ CÓ BỘ DANH MỤC RIÊNG (v11).
  ///
  /// Hệ quả cố ý, không phải thiếu sót: hai ví đều có thể có danh mục tên
  /// "Ăn uống" và đó là HAI danh mục khác nhau, không gộp. Vì vậy mọi màn
  /// đọc danh mục (danh sách, ngân sách, báo cáo, quick-add) đều phải lọc
  /// theo một ví — gộp nhiều ví lại sẽ hiện trùng tên mà không phân biệt
  /// được. Xem `selectedWalletIdProvider`.
  ///
  /// Danh mục con thừa hưởng ví của danh mục cha; `CategoryRepository` ép
  /// bất biến đó khi chèn.
  IntColumn get walletId => integer().references(Wallets, #id)();

  /// Hũ mà danh mục này thuộc về (v13) — `null` = chưa xếp vào hũ nào.
  ///
  /// MỘT danh mục thuộc TỐI ĐA MỘT hũ: nếu một danh mục nằm trong hai hũ
  /// thì cùng một khoản chi bị trừ hai lần và tổng các hũ không còn bằng
  /// tổng chi — mất luôn tính chất khiến phương pháp hũ có ý nghĩa.
  IntColumn get jarId => integer().nullable().references(Jars, #id)();
}

/// Hũ chia thu nhập (v13) — "6 chiếc lọ"/JARS của T. Harv Eker và họ hàng
/// envelope budgeting.
///
/// Khác `Budgets` ở hai điểm CỐT LÕI, nên là bảng riêng chứ không phải một
/// cờ trên ngân sách:
///  1. Hũ chia theo **PHẦN TRĂM THU NHẬP** của kỳ, không phải số tiền cố
///     định — thu nhập tháng này cao thì hạn mức mỗi hũ tự cao theo.
///  2. Hũ gom NHIỀU danh mục (qua `categories.jarId`), ngân sách gắn đúng
///     một danh mục.
///
/// Mỗi ví có bộ hũ riêng, cùng lý do với danh mục (xem `Categories.walletId`).
class Jars extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get walletId => integer().references(Wallets, #id)();
  TextColumn get name => text()();

  /// Phần trăm thu nhập của kỳ, 0–100. Lưu SỐ NGUYÊN phần trăm chứ không
  /// phải tỉ lệ thực: bộ mặc định JARS là 55/10/10/10/10/5 — số nguyên hết,
  /// và số nguyên thì cộng lại đúng 100 mà không có sai số dấu phẩy động.
  IntColumn get percent => integer()();

  IntColumn get categoryColorId => integer()();
  TextColumn get iconCode => text()();

  /// Hũ "quỹ chìm" (sinking fund): dư kỳ này CỘNG DỒN sang kỳ sau thay vì
  /// về 0. Đúng thứ làm nên hũ Tiết kiệm dài hạn/Tự do tài chính — tiền
  /// phải tích lại mới có nghĩa. Hũ tiêu dùng thì để `false`.
  BoolColumn get carryOver => boolean().withDefault(const Constant(false))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// `'spend'` (hũ tiêu) | `'saving'` (hũ tiết kiệm) — v14, xem `JarKind`.
  ///
  /// Hai loại đo NGƯỢC CHIỀU nhau nên phải là một cột, không suy ra được từ
  /// tên hay icon: hũ tiêu đo tiền RA khỏi các danh mục của nó (vượt hạn mức
  /// là xấu), hũ tiết kiệm đo tiền VÀO một quỹ trong kỳ (vượt mức là tốt).
  TextColumn get kind => text().withDefault(const Constant('spend'))();

  /// Quỹ (mục tiêu tiết kiệm) mà hũ tiết kiệm đổ vào — v14. Chỉ có nghĩa khi
  /// [kind] là `'saving'`; mọi lần nạp/rút quỹ này trong kỳ tự động tính vào
  /// hũ, không cần xếp danh mục nào.
  IntColumn get goalId => integer().nullable().references(SavingsGoals, #id)();
}

/// Ví (Phase 13) — mọi giao dịch thuộc về đúng một ví. Lưu trữ (archive)
/// thay vì xoá cứng, cùng triết lý `categories.isArchived`.
class Wallets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get categoryColorId => integer()();
  TextColumn get iconCode => text()();

  /// Số dư CÓ SẴN trong ví trước khi ghi giao dịch đầu tiên (v12) — tiền
  /// mặt đang cầm, số dư tài khoản lúc bắt đầu dùng app.
  ///
  /// Là một CỘT chứ không phải một giao dịch "số dư đầu kỳ" giả: một giao
  /// dịch giả sẽ lọt vào danh sách, vào báo cáo, vào tổng Thu của tháng —
  /// bóp méo mọi con số chi tiêu. Số dư ví = cột này + tổng giao dịch.
  IntColumn get openingBalanceMinor =>
      integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Vốn từ học được cho `category_matcher` (Phase 7/8) — seed ~300 từ khoá
/// tiếng Việt lúc tạo DB, rồi lớn dần qua "vòng lặp học" mỗi khi Tony sửa
/// danh mục của một draft (Phase 8), zero ML, zero mạng.
class CategoryKeywords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get keyword => text()();
  TextColumn get keywordAscii => text()();
  RealColumn get weight => real().withDefault(const Constant(1.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {categoryId, keyword},
  ];
}

/// Ngân sách theo danh mục theo tháng. Trạng thái tiến độ LUÔN tính bằng SQL
/// aggregate đối chiếu với `transactions`, KHÔNG lưu bộ đếm — cùng lý do D7.
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();

  /// `'YYYY-MM'`, vd `'2026-08'` — tháng LỊCH mà kỳ đó BẮT ĐẦU, bất kể
  /// `anchorDay` cấu hình được (Phase 15) dịch ranh giới NGÀY đi đâu. Xem
  /// docs/decisions.md § Phase 15 "Kỳ ngân sách theo ngày neo".
  TextColumn get yearMonth => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  IntColumn get currencyScale => integer()();

  /// Cộng dồn phần dư/vượt kỳ LIỀN TRƯỚC vào ngân sách hiệu lực kỳ này
  /// (Phase 15) — theo TỪNG danh mục, mặc định TẮT (giữ nguyên hành vi
  /// Phase 11 cho mọi ngân sách chưa bật). Tính 100% bằng SQL mỗi lần watch,
  /// KHÔNG có cột "ngân sách hiệu lực" nào lưu sẵn. Xem docs/decisions.md
  /// § Phase 15 "Carry-over".
  BoolColumn get carryOver => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {categoryId, yearMonth},
  ];
}

/// Mẫu giao dịch định kỳ (Phase 12) — hoá đơn/thu nhập lặp lại. `nextOccurrenceDate`
/// là con trỏ lịch trình, KHÔNG phải cache dẫn xuất — xem docs/decisions.md
/// § Phase 12 "next_occurrence_date là ngoại lệ có chủ đích với D7". Chỉ dùng để
/// NHẮC (thông báo local), không bao giờ tự động ghi vào `transactions`.
class RecurringTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  IntColumn get currencyScale => integer()();
  TextColumn get note => text().nullable()();

  /// `'daily'` | `'weekly'` | `'monthly'` | `'yearly'` — validate ở domain
  /// layer (`RecurringFrequency`), cùng quy ước TEXT-enum với `categories.kind`.
  TextColumn get frequency => text()();
  DateTimeColumn get nextOccurrenceDate => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tách một giao dịch thành nhiều dòng con, mỗi dòng một danh mục +
/// `amountMinor` riêng (Phase 14). Tổng các dòng con PHẢI bằng `amountMinor`
/// của giao dịch cha — validate ở `TransactionRepository`/form khi lưu,
/// KHÔNG phải ràng buộc DB (không có CHECK constraint nào ở đây, vì SQLite
/// không kiểm tra được tổng qua các hàng khác trong một CHECK cột).
///
/// Khi một giao dịch có dòng con, `transactions.category_id` của giao dịch
/// cha được set về `NULL` (không còn một danh mục đơn nào đúng nữa) — mọi
/// query gộp theo danh mục phải đọc qua
/// `lib/data/repositories/effective_category_amounts.dart` thay vì
/// `transactions.category_id` trực tiếp, xem docs/decisions.md § Phase 14
/// "Tách giao dịch: hai đường dữ liệu".
class TransactionLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().references(Transactions, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get amountMinor => integer()();
}

/// Mẫu giao dịch có tên (Phase 14) — snapshot số tiền/danh mục/ghi chú lúc
/// tạo mẫu, áp dụng nhanh vào một giao dịch MỚI từ màn Giao dịch. KHÔNG có
/// cột nào tham chiếu NGƯỢC từ `transactions` về đây — mẫu chỉ là khuôn lúc
/// tạo, không phải tham chiếu sống, nên sửa/xoá một mẫu không thể nào ảnh
/// hưởng giao dịch đã tạo từ nó trước đây (đúng theo cấu trúc, không cần
/// logic riêng để đảm bảo — xem docs/decisions.md § Phase 14 "Mẫu giao dịch").
class TransactionTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  IntColumn get currencyScale => integer()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Mục tiêu tiết kiệm (Phase 16) — tiến độ LUÔN dẫn xuất bằng `SUM(amount_minor)`
/// các giao dịch gắn `transactions.goal_id`, KHÔNG lưu cột "đã tiết kiệm bao
/// nhiêu" riêng (D7 — cùng lỗi khiến Rolly bị than phiền "số dư sai", không
/// lặp lại ở tính năng mới). Đóng góp là giao dịch CHI bình thường (âm, có
/// thể có `categoryId` riêng) gắn thêm `goalId`; rút khỏi mục tiêu là giao
/// dịch THU (dương) gắn cùng `goalId` — tiến độ = `-SUM(amount_minor)`, xem
/// `SavingsGoalRepository`.
@TableIndex(
  name: 'idx_savings_goals_source_id',
  columns: {#sourceId},
  unique: true,
)
class SavingsGoals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get targetAmountMinor => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  IntColumn get currencyScale => integer()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// ID của mục tiêu Rolly gốc (Phase 19, vd `'rolly-savings:49755'`) — dùng
  /// để import idempotent, cùng quy ước `Transactions.sourceId` (Phase 9).
  /// Nullable vì mục tiêu tạo tay trong app không có nguồn Rolly nào.
  TextColumn get sourceId => text().nullable()();
}

/// Khoản vay/cho vay (Phase 16) — `principalMinor` là số gốc CỐ ĐỊNH lúc tạo
/// (không phải một giao dịch), số dư CÒN LẠI luôn dẫn xuất từ `principalMinor`
/// trừ/cộng `SUM(amount_minor)` các giao dịch trả/thu gắn `transactions.debt_id`
/// (dấu tính theo `kind`, xem `DebtProgress`) — KHÔNG có cột "còn nợ bao
/// nhiêu" nào lưu sẵn, cùng triết lý D7 với `SavingsGoals` ở trên.
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get counterpartyName => text()();

  /// `'debt'` (mình nợ người khác) | `'loan'` (mình cho người khác vay) —
  /// validate ở tầng domain (`DebtKind`), cùng quy ước TEXT-enum với
  /// `categories.kind`/`recurring_transactions.frequency`.
  TextColumn get kind => text()();
  IntColumn get principalMinor => integer()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  IntColumn get currencyScale => integer()();
  DateTimeColumn get startDate => dateTime()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Thẻ (tag, Phase 17) — ĐỘC LẬP với cây danh mục (`Categories`/
/// `parentCategoryId`, Phase 13): một giao dịch có thể vừa có danh mục "Ăn
/// uống" vừa gắn nhiều thẻ tự do như "công tác"/"gia đình" cắt ngang mọi
/// danh mục, qua bảng nối [TransactionTags]. Không có cây/thứ bậc, không
/// `isArchived` (v1 chưa cần lưu trữ thẻ, xoá cứng đủ dùng — xoá một
/// [Tags] row tự động dọn các dòng [TransactionTags] tham chiếu nó qua
/// `onDelete: KeyAction.cascade`, không để lại tham chiếu treo).
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get categoryColorId => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {name},
  ];
}

/// Bảng nối nhiều-nhiều giữa [Transactions] và [Tags] (Phase 17). Khoá
/// chính GHÉP (không có `id` riêng) — một cặp (giao dịch, thẻ) chỉ có ý
/// nghĩa gắn/không gắn, không cần định danh riêng cho chính dòng nối.
///
/// KHÔNG khai `onDelete: KeyAction.cascade` — app chưa từng bật `PRAGMA
/// foreign_keys = ON` (kiểm chứng trực tiếp: không có `beforeOpen` nào gọi
/// pragma đó ở `open_database.dart`, giống mọi `.references()` khác trong
/// file này), nên SQLite mặc định KHÔNG ép ràng buộc khoá ngoại — khai
/// `onDelete` mà không bật pragma sẽ tạo ảo giác an toàn sai. Dọn dòng nối
/// mồ côi khi xoá một thẻ/giao dịch làm TƯỜNG MINH ở tầng repository (xem
/// `TagRepository.delete`/`TransactionRepository.delete`), cùng triết lý
/// `CategoryRepository.mergeInto` tự tay dọn thay vì tin DB.
class TransactionTags extends Table {
  IntColumn get transactionId => integer().references(Transactions, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {transactionId, tagId};
}

/// Nhật ký lỗi cho zero-fire-and-forget (D7): mọi write thất bại của
/// repository, ngoài việc trả `Result.err`, còn ghi một dòng ở đây.
class AppEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get occurredAt => dateTime().withDefault(currentDateAndTime)();

  /// `'error'` | `'warning'` | `'info'`.
  TextColumn get level => text()();
  TextColumn get message => text()();
  TextColumn get contextJson => text().nullable()();
}
