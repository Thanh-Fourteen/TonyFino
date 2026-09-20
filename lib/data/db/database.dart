import 'package:drift/drift.dart';

import '../../core/text/ascii_fold.dart';
import 'schema_versions.steps.dart';
import '../../features/quick_add/domain/parser/normalizer.dart';
import 'seed/category_seed.dart';
import 'tables.dart';

part 'database.g.dart';

/// Tên ví tự tạo lúc `onCreate` (cài mới) hoặc lúc migration 3→4 (nâng cấp
/// từ bản cũ) — cả hai đường đều hội tụ về đúng MỘT ví có sẵn ngay từ đầu,
/// luôn có `id` nhỏ nhất trong bảng (xem docs/decisions.md § Phase 13 "Ví
/// mặc định... ví có id nhỏ nhất").
const kDefaultWalletName = 'Ví mặc định';

@DriftDatabase(
  tables: [
    Transactions,
    Categories,
    CategoryKeywords,
    Budgets,
    RecurringTransactions,
    Wallets,
    TransactionLines,
    TransactionTemplates,
    SavingsGoals,
    Debts,
    Tags,
    TransactionTags,
    AppEvents,
    Jars,
    JarGoals,
    Notes,
  ],
  // Bảng ảo FTS5 duy nhất của app — chỉ khai được qua `.drift` file (xem
  // comment đầu file đó), KHÔNG qua Dart `Table`. `searchTransactionIds`
  // chỉ trả `transactionId` thô — `TransactionRepository.watchSearch` tự
  // JOIN kết quả này với `transactions`/`categories` qua API drift đã có
  // (`watchAllWithCategory`-kiểu), không cần viết SQL thô cho phần đó.
  include: {'transactions_fts.drift'},
  queries: {
    'searchTransactionIds':
        'SELECT transaction_id FROM transactions_fts '
        'WHERE transactions_fts MATCH :term',
  },
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      // `m.createAll()` tự tạo CẢ bảng ảo `transactions_fts` (Phase 17, khai
      // ở `transactions_fts.drift`, nạp qua `include:` bên dưới) — virtual
      // table khai qua `.drift` file là một `DatabaseSchemaEntity` thật, nằm
      // trong `allSchemaEntities` giống mọi bảng Dart khác, KHÔNG cần
      // `customStatement` tay (xem docs/decisions.md § Phase 17 "Tìm kiếm
      // FTS5" cho lý do vì sao đây là bảng ảo duy nhất khai qua `.drift`
      // thay vì Dart, và tại sao KHÔNG dùng bảng FTS5 "external content" +
      // trigger tay).
      await m.createAll();
      // Ví TRƯỚC, danh mục SAU — từ v11 mỗi danh mục thuộc về một ví, nên
      // phải có ví tồn tại rồi mới seed được vào nó.
      final defaultWalletId = await into(wallets).insert(
        WalletsCompanion.insert(
          name: kDefaultWalletName,
          categoryColorId: 0,
          iconCode: 'account_balance_wallet',
        ),
      );
      await seedDefaultCategories(this, walletId: defaultWalletId);
    },
    // 🚨 Dùng `stepByStep` (sinh bằng `dart run drift_dev schema steps
    // drift_schemas/app_database lib/data/db/schema_versions.steps.dart`,
    // KHÔNG sửa tay file đó) thay vì `if (from < N && to >= N)` tự viết như
    // trước Phase 16 — lý do CHUYỂN ĐỔI (không phải chỉ để đẹp code):
    // `Migrator.alterTable(TableMigration(table, ...))` dựng lại bảng theo
    // ĐÚNG hình dạng của ĐỐI TƯỢNG `table` được truyền vào — nếu truyền
    // thẳng getter bảng SỐNG (`transactions`, vd `this.transactions`), đối
    // tượng đó LUÔN phản ánh class `Transactions` MỚI NHẤT (kể cả cột thêm
    // ở các Phase SAU migration này được viết, vd `goalId`/`debtId` ở Phase
    // 16 dù bước v3→v4 được viết từ Phase 13) — bắt buộc phải liệt kê MỌI
    // cột chưa có ở bảng CŨ vào `newColumns` (kể cả cột "thuộc về" một
    // migration sau) để tránh "no such column" lúc copy dữ liệu, nhưng làm
    // vậy thì bảng KẾT QUẢ ở phiên bản trung gian (vd v4) lại thừa cột so
    // với hình dạng v4 THẬT — `SchemaVerifier` của drift_dev bắt được ngay
    // ("Contains the following unexpected entries: goal_id, debt_id") khi
    // test giả lập dừng ở v4. Hai yêu cầu (không "no such column" LẪN không
    // thừa cột ở bản trung gian) không thể cùng thoả nếu `table` luôn là
    // đối tượng SỐNG — phải dùng đối tượng bảng ĐÓNG BĂNG đúng hình dạng
    // của TỪNG phiên bản, chính là mục đích của `stepByStep`/`schema.xxx`
    // (mỗi closure nhận một `schema` chỉ biết đúng hình dạng ở phiên bản đó).
    // Xem docs/decisions.md § Phase 16 "Chuyển migration hand-rolled sang
    // stepByStep".
    onUpgrade: stepByStep(
      // v1→v2 (Phase 9): thêm `transactions.source_id` cho idempotency
      // importer — không có dữ liệu cũ nào cần backfill, mọi dòng đã có tự
      // động thành null. SQLite từ chối `ALTER TABLE ADD COLUMN ... UNIQUE`
      // trực tiếp nên phải tách hai bước: thêm cột trước, tạo index UNIQUE sau.
      from1To2: (m, schema) async {
        await m.addColumn(schema.transactions, schema.transactions.sourceId);
        await m.createIndex(schema.idxTransactionsSourceId);
      },
      // v2→v3 (Phase 12): thêm bảng `recurring_transactions` — bảng MỚI hoàn
      // toàn, không đụng cột nào của bảng cũ, nên không có backfill nào cần lo.
      from2To3: (m, schema) async {
        await m.createTable(schema.recurringTransactions);
      },
      // v3→v4 (Phase 13) — migration schema LỚN NHẤT từ trước tới giờ, đọc kỹ
      // docs/decisions.md § Phase 13 "Chiến lược migration 3→4" trước khi
      // sửa: (1) tạo bảng `wallets`, (2) tạo "Ví mặc định" lấy
      // `defaultWalletId` RUNTIME (không phải hằng số), (3)
      // `alterTable`/`TableMigration` cho `transactions.walletId` — BẮT
      // BUỘC dùng cách này (không phải `addColumn`) vì NOT NULL cần backfill
      // giá trị chỉ biết lúc chạy migration, (4) `addColumn` cho
      // `isTransfer`/`linkedTransactionId` (có default/nullable, an toàn với
      // `addColumn` thường), (5) `addColumn` cho hai cột mới của `categories`.
      from3To4: (m, schema) async {
        await m.createTable(schema.wallets);
        // `into()` cần kiểu SỐNG (`WalletsCompanion`/`WalletsData`) nên vẫn
        // dùng getter `wallets` sống ở đây — bảng vừa được tạo đúng hình
        // dạng qua `schema.wallets` phía trên nên INSERT này an toàn.
        final defaultWalletId = await into(wallets).insert(
          WalletsCompanion.insert(
            name: kDefaultWalletName,
            categoryColorId: 0,
            iconCode: 'account_balance_wallet',
          ),
        );
        // `newColumns` chỉ cần liệt kê 3 cột thuộc về CHÍNH bước này —
        // `schema.transactions` (Shape8/Schema4) chỉ biết đúng hình dạng v4,
        // không "nhìn thấy" `goalId`/`debtId` của Phase 16 — đây chính là
        // điểm khác biệt với cách viết tay cũ.
        await m.alterTable(
          TableMigration(
            schema.transactions,
            newColumns: [
              schema.transactions.walletId,
              schema.transactions.isTransfer,
              schema.transactions.linkedTransactionId,
            ],
            columnTransformer: {
              schema.transactions.walletId: Constant(defaultWalletId),
            },
          ),
        );
        await m.addColumn(
          schema.categories,
          schema.categories.parentCategoryId,
        );
        await m.addColumn(schema.categories, schema.categories.sortOrder);
      },
      // v4→v5 (Phase 14) — hai bảng MỚI hoàn toàn (`transaction_lines`,
      // `transaction_templates`), không đụng cột nào của bảng cũ nên không
      // có backfill nào cần lo — cùng mức rủi ro thấp như v2→v3 (Phase 12).
      from4To5: (m, schema) async {
        await m.createTable(schema.transactionLines);
        await m.createTable(schema.transactionTemplates);
      },
      // v5→v6 (Phase 15) — một cột mới, có DEFAULT hằng số (`false`), an
      // toàn với `addColumn` thường.
      from5To6: (m, schema) async {
        await m.addColumn(schema.budgets, schema.budgets.carryOver);
      },
      // v6→v7 (Phase 16) — hai bảng MỚI hoàn toàn (`savings_goals`, `debts`)
      // + hai cột nullable MỚI trên `transactions` (`goal_id`/`debt_id`) —
      // không đụng dữ liệu cột cũ nào, cùng mức rủi ro thấp như v2→v3/v4→v5.
      from6To7: (m, schema) async {
        await m.createTable(schema.savingsGoals);
        await m.createTable(schema.debts);
        await m.addColumn(schema.transactions, schema.transactions.goalId);
        await m.addColumn(schema.transactions, schema.transactions.debtId);
      },
      // v7→v8 (Phase 17) — hai bảng MỚI (`tags`, `transaction_tags`) + hai
      // cột nullable mới (`categories.emoji`, `transactions.receipt_image_
      // filename`) + bảng ảo FTS5 `transactions_fts` (khai qua `.drift`,
      // xem `transactions_fts.drift`) — `m.createTable` xử lý virtual table
      // đúng như bảng thường (drift tự phát hiện qua kiểu entity).
      //
      // BACKFILL bắt buộc cho `transactions_fts`: bảng ảo mới tạo RỖNG,
      // không tự động "nhìn thấy" dữ liệu `transactions` đã có TRƯỚC migration
      // này (khác bảng external-content — cố tình không dùng, xem `.drift`)
      // — thiếu bước này thì mọi ghi chú giao dịch NHẬP TỪ TRƯỚC Phase 17
      // (import Rolly, quick-add cũ...) sẽ vô hình với tìm kiếm cho tới khi
      // Tony tự sửa lại từng giao dịch, một kiểu mất dữ liệu ÂM THẦM đúng
      // lớp lỗi TODOS.md luôn cảnh báo. Đọc trực tiếp bằng `customSelect`
      // (không qua `schema.transactions` — chỉ đọc 2 cột ổn định từ v1/v2,
      // không phải `alterTable`, nên không dính bẫy "đối tượng bảng sống"
      // của Phase 16) rồi chèn qua Companion SỐNG của `transactionsFts`
      // (bảng vừa tạo đúng hình dạng ở bước này, an toàn — cùng lý do
      // `WalletsCompanion` ở bước v3→v4 dùng được getter sống).
      from7To8: (m, schema) async {
        await m.createTable(schema.tags);
        await m.createTable(schema.transactionTags);
        await m.addColumn(schema.categories, schema.categories.emoji);
        await m.addColumn(
          schema.transactions,
          schema.transactions.receiptImageFilename,
        );
        await m.createTable(schema.transactionsFts);

        final existingNotes = await customSelect(
          'SELECT id, note_ascii FROM transactions WHERE note_ascii IS NOT NULL',
        ).get();
        for (final row in existingNotes) {
          await into(transactionsFts).insert(
            TransactionsFtsCompanion.insert(
              noteAscii: row.read<String>('note_ascii'),
              // FTS5 KHÔNG khai được kiểu cột (SQLite: mọi cột FTS5, kể cả
              // UNINDEXED, luôn là văn bản) — `transactionId` sinh ra kiểu
              // `String` (xem `TransactionsFtsCompanion`), không phải `int`
              // như cột `transactions.id` thật. Parse ngược lại ở
              // `TransactionRepository.watchSearch`.
              transactionId: row.read<int>('id').toString(),
            ),
          );
        }
      },
      // v8→v9 (Phase 19) — thêm `savings_goals.source_id` cho import
      // idempotent (khớp lịch sử tiết kiệm Rolly), cùng mẫu tách hai bước
      // `addColumn` rồi `createIndex` như v1→v2 (SQLite từ chối `ALTER TABLE
      // ADD COLUMN ... UNIQUE` trực tiếp).
      from8To9: (m, schema) async {
        await m.addColumn(schema.savingsGoals, schema.savingsGoals.sourceId);
        await m.createIndex(schema.idxSavingsGoalsSourceId);
      },
      // v9→v10 (Phase 22 addendum) — Tony yêu cầu trực tiếp: "cafe 20k" phải
      // vào "Ăn uống → Tiêu vặt". Không đổi CỘT/BẢNG nào (`categories`/
      // `category_keywords` giữ nguyên hình dạng từ v1) nên dùng thẳng
      // getter SỐNG (`categories`/`categoryKeywords`, không phải
      // `schema.xxx`) — an toàn vì không có rủi ro "thừa cột ở phiên bản
      // trung gian" (chỉ DML, không DDL). Idempotent theo TÊN: nếu "Tiêu
      // vặt" đã tồn tại dưới "Ăn uống" (vd máy đã nhập lịch sử Rolly thật có
      // sẵn danh mục con này), TÁI SỬ DỤNG thay vì tạo trùng.
      from9To10: (m, schema) async {
        // 🚨 CHỈ dùng SQL THÔ ở đây, KHÔNG dùng table getter sống
        // (`select(categories)`, `CategoriesCompanion.insert`). Getter sống
        // luôn phản ánh class Dart MỚI NHẤT — từ v11 nó có `wallet_id`, mà
        // ở thời điểm bước này chạy bảng thật vẫn là hình dạng v10 chưa có
        // cột đó ⇒ "no such column: wallet_id". Cùng đúng cái bẫy đã ghi ở
        // đầu `onUpgrade`; SQL thô miễn nhiễm vì nó chỉ nói tới những cột
        // thật sự tồn tại ở phiên bản này.
        final anUong = await customSelect(
          "SELECT id, kind, category_color_id FROM categories "
          "WHERE name = 'Ăn uống' AND parent_category_id IS NULL LIMIT 1",
        ).getSingleOrNull();
        if (anUong == null) return;
        final anUongId = anUong.read<int>('id');

        final existingSub = await customSelect(
          "SELECT id FROM categories "
          "WHERE name = 'Tiêu vặt' AND parent_category_id = ? LIMIT 1",
          variables: [Variable<int>(anUongId)],
        ).getSingleOrNull();

        int tieuVatId;
        if (existingSub != null) {
          tieuVatId = existingSub.read<int>('id');
        } else {
          await customStatement(
            'INSERT INTO categories '
            '(name, kind, category_color_id, icon_code, parent_category_id) '
            "VALUES ('Tiêu vặt', ?, ?, 'local_cafe', ?)",
            [
              anUong.read<String>('kind'),
              anUong.read<int>('category_color_id'),
              anUongId,
            ],
          );
          tieuVatId = (await customSelect(
            'SELECT last_insert_rowid() AS id',
          ).getSingle()).read<int>('id');
        }

        const movedKeywords = {
          'cà phê': 1.3,
          'cafe': 1.3,
          'cf': 1.1,
          'ăn vặt': 1.1,
        };
        for (final entry in movedKeywords.entries) {
          await customStatement(
            'DELETE FROM category_keywords WHERE category_id = ? AND keyword = ?',
            [anUongId, entry.key],
          );
          final onSub = await customSelect(
            'SELECT id FROM category_keywords '
            'WHERE category_id = ? AND keyword = ? LIMIT 1',
            variables: [Variable<int>(tieuVatId), Variable<String>(entry.key)],
          ).getSingleOrNull();
          if (onSub == null) {
            await customStatement(
              'INSERT INTO category_keywords '
              '(category_id, keyword, keyword_ascii, weight) VALUES (?, ?, ?, ?)',
              [tieuVatId, entry.key, foldToAscii(entry.key), entry.value],
            );
          }
        }
      },
      // v10→v11: MỖI VÍ CÓ BỘ DANH MỤC RIÊNG — thêm `categories.wallet_id`.
      //
      // Backfill: mọi danh mục đang có thuộc về ví ĐẦU TIÊN (ví mặc định).
      // Lấy id đó ở RUNTIME chứ không hardcode `1` — cùng lý do đã ghi ở
      // bước v3→v4: id của "Ví mặc định" do autoIncrement sinh ra, và trên
      // một sổ đã qua nhiều lần sửa/xoá nó không đảm bảo bằng 1.
      //
      // Không có `NOT NULL DEFAULT` nào đúng được ở đây (giá trị phụ thuộc
      // dữ liệu), nên đi đúng đường của drift: `alterTable` + `columnTransformer`
      // ánh xạ cột mới sang một hằng số tính lúc chạy.
      from10To11: (m, schema) async {
        final walletRow = await customSelect(
          'SELECT id FROM wallets ORDER BY id LIMIT 1',
        ).getSingleOrNull();
        // Sổ chưa có ví nào là chuyện không thể xảy ra (v3→v4 luôn tạo ví
        // mặc định), nhưng nếu có thì tạo lại còn hơn ném cả migration.
        final walletId =
            walletRow?.read<int>('id') ??
            await into(wallets).insert(
              WalletsCompanion.insert(
                name: kDefaultWalletName,
                categoryColorId: 0,
                iconCode: 'account_balance_wallet',
              ),
            );
        await m.alterTable(
          TableMigration(
            schema.categories,
            newColumns: [schema.categories.walletId],
            columnTransformer: {schema.categories.walletId: Constant(walletId)},
          ),
        );
      },
      // v11→v12: `wallets.opening_balance_minor` — số dư có sẵn trước giao
      // dịch đầu tiên. Cột thêm thuần tuý, `DEFAULT 0` đúng nghĩa cho MỌI ví
      // đang có (sổ hiện tại không hề biết khái niệm này nên số dư của
      // chúng vốn đã là "0 + tổng giao dịch"), nên chỉ cần `addColumn` —
      // không backfill phụ thuộc dữ liệu như bước trước.
      from11To12: (m, schema) async {
        await m.addColumn(schema.wallets, schema.wallets.openingBalanceMinor);
      },
      // v12→v13: hũ chia thu nhập. Bảng MỚI + một cột nullable trên
      // `categories` — không đụng dữ liệu cũ, `jar_id = NULL` nghĩa là
      // "chưa xếp hũ", đúng trạng thái của mọi danh mục đang có. KHÔNG tự
      // tạo bộ 6 hũ ở đây: bật một phương pháp tài chính lên sổ của người
      // ta mà không hỏi là quyết định thay họ — có nút "Dùng mẫu 6 hũ" ở
      // màn Hũ để Tony tự chọn.
      from12To13: (m, schema) async {
        await m.createTable(schema.jars);
        await m.addColumn(schema.categories, schema.categories.jarId);
      },
      // v13→v14: hũ có HAI loại — hũ tiêu và hũ tiết kiệm (gắn một quỹ). Hai
      // cột thêm thuần tuý: `kind DEFAULT 'spend'` đúng nghĩa cho mọi hũ
      // đang có (trước bản này chỉ có một loại là hũ tiêu), `goal_id` NULL.
      from13To14: (m, schema) async {
        await m.addColumn(schema.jars, schema.jars.kind);
        await m.addColumn(schema.jars, schema.jars.goalId);
      },
      // v14→v15: hũ tiết kiệm nối NHIỀU quỹ, mỗi quỹ một tỉ lệ. Dây nối rời
      // khỏi `jars.goal_id` sang bảng `jar_goals`, nên phải CHUYỂN dữ liệu
      // trước rồi mới bỏ cột — `alterTable` dựng lại `jars` theo hình dạng
      // v15 (không còn `goal_id`), đọc sau khi bỏ cột là mất trắng dây nối.
      from14To15: (m, schema) async {
        await m.createTable(schema.jarGoals);
        await m.database.customStatement(
          'INSERT INTO jar_goals (jar_id, goal_id, percent) '
          'SELECT id, goal_id, 100 FROM jars WHERE goal_id IS NOT NULL',
        );
        await m.alterTable(TableMigration(schema.jars));
      },
      // v15→v16: bảng `notes` — bảng MỚI hoàn toàn, không đụng dữ liệu cũ.
      from15To16: (m, schema) async {
        await m.createTable(schema.notes);
      },
    ),
    beforeOpen: (details) async {
      // CHỈ chạy khi sổ đã ở phiên bản mới nhất.
      //
      // `beforeOpen` cũng chạy trong test migration sinh tự động, ở những
      // phiên bản schema CŨ — lúc đó `categories` chưa có `wallet_id`/
      // `jar_id`, và một truy vấn bằng getter bảng SỐNG (luôn mang hình
      // dạng mới nhất) sẽ nổ "Null check operator used on a null value".
      // Cùng họ với cái bẫy đã dính ở migration v9→v10.
      if (details.versionNow != schemaVersion) return;
      await backfillSeedKeywords(this);
      await repairSubcategoryKinds(this);
    },
  );
}

/// Ép lại bất biến "danh mục CON luôn mang `kind` của cha"
/// (`CategoryRepository.kindIsInheritedFromParent`) cho những hàng đã lỡ sai.
///
/// 🚨 Vì sao chạy MỖI LẦN MỞ chứ không một lần rồi thôi như
/// [backfillSeedKeywords]: cái này không phải "bù dữ liệu mới" mà là một BẤT
/// BIẾN. Ở đây không có ý định nào của người dùng để làm hỏng — `kind` riêng
/// của một danh mục con không hiện ra ở bất kỳ màn nào, không ai cố ý đặt
/// nó khác cha. Ngược lại, dữ liệu sai có thể quay lại từ một bản khôi phục
/// sao lưu cũ hoặc một lần import, nên chốt một lần là không đủ.
///
/// Rẻ: một câu UPDATE trên bảng vài chục hàng, chỉ động vào đúng hàng lệch
/// (mệnh đề `WHERE ... IS NOT`), nên lần mở bình thường ghi 0 hàng.
///
/// Sổ Tony có sẵn ít nhất một hàng như vậy: danh mục "Thưởng" nằm dưới một
/// gốc THU nhưng `kind = 'expense'`, khiến "thưởng 1tr" ở màn chat ghi ra
/// −1.000.000 (xem `CategoryRepository.update`).
Future<void> repairSubcategoryKinds(AppDatabase db) async {
  await db.customUpdate(
    'UPDATE categories SET kind = ('
    '  SELECT p.kind FROM categories p WHERE p.id = categories.parent_category_id'
    ') WHERE parent_category_id IS NOT NULL AND kind IS NOT ('
    '  SELECT p.kind FROM categories p WHERE p.id = categories.parent_category_id'
    ')',
    updates: {db.categories},
  );
}

/// Đánh dấu đã bù từ khoá — ghi vào `app_events` để chỉ chạy MỘT LẦN.
const kSeedKeywordBackfillMarker = 'seed_keywords_backfill_v2';

/// Bù những từ khoá seed MỚI vào sổ ĐÃ TỒN TẠI.
///
/// 🚨 Vì sao cần: `seedDefaultCategories` chỉ chạy lúc `onCreate` và lúc tạo
/// ví mới. Thêm từ khoá vào `category_seed.dart` KHÔNG tự tới được sổ đang
/// dùng — nên sửa "hủ tíu chưa nhận ra là đồ ăn" ở file seed là sửa cho
/// người cài mới, còn máy Tony thì vẫn y nguyên. Đúng cái bẫy làm một bản
/// sửa trông như đã xong mà thực tế không đổi gì trên máy người dùng.
///
/// Chạy MỘT LẦN (mốc ghi ở `app_events`) chứ không phải mỗi lần mở app: nếu
/// chạy lại mãi thì từ khoá người dùng CHỦ ĐỘNG XOÁ sẽ mọc lại sau mỗi lần
/// khởi động. Thêm đợt từ khoá mới sau này thì đổi [kSeedKeywordBackfillMarker].
///
/// Khớp danh mục theo TÊN trong từng ví (danh mục không có cột "khoá seed").
/// Danh mục Tony đã đổi tên thì bỏ qua — thà thiếu vài từ khoá còn hơn nhét
/// từ khoá "ăn uống" vào một danh mục đã được đặt lại thành thứ khác.
Future<void> backfillSeedKeywords(AppDatabase db) async {
  final already =
      await (db.select(db.appEvents)
            ..where((e) => e.message.equals(kSeedKeywordBackfillMarker))
            ..limit(1))
          .getSingleOrNull();
  if (already != null) return;

  final rootSeedByName = {for (final s in defaultCategorySeeds) s.name: s};
  final rootKeyByName = {for (final s in defaultCategorySeeds) s.name: s.key};
  final categories = await db.select(db.categories).get();
  final categoryById = {for (final c in categories) c.id: c};

  /// Từ khoá seed ứng với một danh mục đang có trong sổ.
  ///
  /// Phải xử lý CẢ HAI CẤP: từ khoá cà phê nằm ở danh mục CON "Tiêu vặt"
  /// (Phase 22), bù thiếu vế đó thì đợt bổ sung "caphe"/"coffee"/"highlands"
  /// không bao giờ tới được sổ đang dùng — đúng lỗi mà chính hàm này sinh ra
  /// để chữa.
  List<SeedKeyword> seedKeywordsFor(Category category) {
    final parentId = category.parentCategoryId;
    if (parentId == null) {
      return rootSeedByName[category.name]?.keywords ?? const [];
    }
    final parentKey = rootKeyByName[categoryById[parentId]?.name];
    if (parentKey == null) return const [];
    for (final sub in defaultSubcategorySeeds) {
      if (sub.parentKey == parentKey && sub.name == category.name) {
        return sub.keywords;
      }
    }
    return const [];
  }

  await db.transaction(() async {
    var inserted = 0;
    for (final category in categories) {
      for (final keyword in seedKeywordsFor(category)) {
        final result = await db
            .into(db.categoryKeywords)
            .insert(
              CategoryKeywordsCompanion.insert(
                categoryId: category.id,
                keyword: keyword.keyword,
                keywordAscii: normalize(keyword.keyword).ascii,
                weight: Value(keyword.weight),
              ),
              // UNIQUE(categoryId, keyword) — từ khoá đã có thì bỏ qua im
              // lặng, không ghi đè trọng số người dùng có thể đã chỉnh.
              mode: InsertMode.insertOrIgnore,
            );
        if (result > 0) inserted++;
      }
    }
    await db
        .into(db.appEvents)
        .insert(
          AppEventsCompanion.insert(
            level: 'info',
            message: kSeedKeywordBackfillMarker,
            contextJson: Value('{"inserted":$inserted}'),
          ),
        );
  });
}

/// Chèn 12 danh mục mặc định + ~300 từ khoá tiếng Việt (`category_seed.dart`),
/// cộng thêm danh mục CON mặc định (`defaultSubcategorySeeds`, Phase 22
/// addendum) VÀO MỘT VÍ.
///
/// Gọi ở hai chỗ: `onCreate` (ví mặc định của sổ mới) và `WalletRepository`
/// khi Tony tạo ví mới — ví mới sinh ra rỗng danh mục thì không dùng được
/// ngay, phải gõ tay 13 danh mục trước khi ghi được đồng nào.
Future<void> seedDefaultCategories(
  AppDatabase db, {
  required int walletId,
}) async {
  await db.transaction(() async {
    final rootIdByKey = <String, int>{};
    final rootSeedByKey = {for (final s in defaultCategorySeeds) s.key: s};

    for (final categorySeed in defaultCategorySeeds) {
      final categoryId = await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: categorySeed.name,
              kind: categorySeed.kind,
              categoryColorId: categorySeed.colorId,
              iconCode: categorySeed.iconCode,
              walletId: walletId,
            ),
          );
      rootIdByKey[categorySeed.key] = categoryId;

      for (final keyword in categorySeed.keywords) {
        await db
            .into(db.categoryKeywords)
            .insert(
              CategoryKeywordsCompanion.insert(
                categoryId: categoryId,
                keyword: keyword.keyword,
                keywordAscii: foldToAscii(keyword.keyword),
                weight: Value(keyword.weight),
              ),
            );
      }
    }

    for (final subSeed in defaultSubcategorySeeds) {
      final parentId = rootIdByKey[subSeed.parentKey]!;
      final parentSeed = rootSeedByKey[subSeed.parentKey]!;
      final subCategoryId = await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: subSeed.name,
              kind: parentSeed.kind,
              categoryColorId: parentSeed.colorId,
              iconCode: subSeed.iconCode,
              parentCategoryId: Value(parentId),
              walletId: walletId,
            ),
          );

      for (final keyword in subSeed.keywords) {
        await db
            .into(db.categoryKeywords)
            .insert(
              CategoryKeywordsCompanion.insert(
                categoryId: subCategoryId,
                keyword: keyword.keyword,
                keywordAscii: foldToAscii(keyword.keyword),
                weight: Value(keyword.weight),
              ),
            );
      }
    }
  });
}
