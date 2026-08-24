import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../theme/tokens/palette.dart';
import '../../../core/result/result.dart';
import '../../../core/text/ascii_fold.dart';
import '../../../core/providers/database_providers.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/savings_goal_repository.dart';
import '../../transactions/transactions_providers.dart';
import 'domain/category_mapping.dart';
import 'domain/csv_transactions.dart';
import 'domain/rolly_file_loader.dart';
import 'domain/rolly_json_parser.dart';
import 'domain/rolly_reconciliation.dart';
import 'domain/rolly_savings_parser.dart';
import 'domain/rolly_subcategory_parser.dart';
import 'domain/staged_transaction.dart';
import '../../wallets/selected_wallet_provider.dart';
import '../../wallets/wallets_providers.dart';

sealed class ImportStep {
  const ImportStep();
}

class ImportIdle extends ImportStep {
  const ImportIdle();
}

class ImportBusy extends ImportStep {
  const ImportBusy();
}

/// Đợi Tony giải quyết bảng ánh xạ danh mục — chỉ có ở đường Rolly JSON, CSV
/// tự resolve theo tên nên bỏ qua bước này.
class ImportMappingCategories extends ImportStep {
  const ImportMappingCategories({
    required this.parseResult,
    required this.mapping,
  });
  final RollyParseResult parseResult;
  final Map<CategoryBucketKey, MappingChoice> mapping;

  bool get allDecided =>
      allCategoriesDecided(parseResult.categoryUsages, mapping);
}

/// Sẵn sàng dry-run — chung cho cả Rolly (sau ánh xạ) lẫn CSV (đã tự resolve).
class ImportReadyForDryRun extends ImportStep {
  const ImportReadyForDryRun({
    required this.rows,
    this.reconciliation,
    this.parseIssues = const [],
    this.unmatchedCategoryNames = const {},
  });
  final List<ResolvedImportRow> rows;
  final RollyReconciliationReport? reconciliation;
  final List<String> parseIssues;
  final Set<String> unmatchedCategoryNames;
}

class ImportDryRunResult extends ImportStep {
  const ImportDryRunResult({
    required this.rows,
    required this.newCount,
    required this.duplicateCount,
    this.reconciliation,
    this.parseIssues = const [],
    this.unmatchedCategoryNames = const {},
  });
  final List<ResolvedImportRow> rows;
  final int newCount;
  final int duplicateCount;
  final RollyReconciliationReport? reconciliation;
  final List<String> parseIssues;
  final Set<String> unmatchedCategoryNames;
}

class ImportCommitted extends ImportStep {
  const ImportCommitted({
    required this.inserted,
    required this.skippedDuplicate,
    this.reconciliation,
    this.followUpSubcategory,
    this.followUpSavings,
    this.followUpError,
  });
  final int inserted;
  final int skippedDuplicate;
  final RollyReconciliationReport? reconciliation;

  /// Kết quả hai bước CHẠY NỐI TIẾP ngay sau khi ghi giao dịch, lấy từ
  /// CHÍNH file Tony vừa chọn — `null` khi file không có mảng tương ứng
  /// (file chỉ có `input`/`category_view`), khác `0` là "có chạy nhưng
  /// không có gì để đổi".
  final SubcategoryBackfillSummary? followUpSubcategory;
  final RollySavingsImportSummary? followUpSavings;

  /// Bước nối tiếp hỏng thì KHÔNG nuốt lặng: giao dịch đã ghi xong và vẫn
  /// đúng, nhưng phải nói rõ phần nào chưa chạy được để Tony bấm tay lại.
  final String? followUpError;
}

class ImportFailed extends ImportStep {
  const ImportFailed(this.message);
  final String message;
}

/// Xem trước import tiết kiệm Rolly (Phase 19) — không có bước ánh xạ danh
/// mục nào (`savings_goals` không có `categoryId`), nên đi thẳng từ "đã
/// chọn file" sang "xem trước" như CSV, khác nhánh Rolly JSON giao dịch.
class ImportSavingsPreview extends ImportStep {
  const ImportSavingsPreview({
    required this.goals,
    required this.contributionSourceIdsByRollyGoalId,
    required this.issues,
    required this.existingSourceIds,
  });

  final List<StagedRollySavingsGoal> goals;
  final Map<int, List<String>> contributionSourceIdsByRollyGoalId;
  final List<String> issues;
  final Set<String> existingSourceIds;

  int get newCount => goals.length - existingSourceIds.length;
}

class ImportSavingsCommitted extends ImportStep {
  const ImportSavingsCommitted(this.summary);
  final RollySavingsImportSummary summary;
}

/// Xem trước khôi phục danh mục phụ Rolly (bổ sung sau Phase 20) — chưa
/// ghi gì, chỉ đếm bao nhiêu giao dịch sẽ được gán lại (không có khái niệm
/// "trùng lặp" như goal/transaction vì đây là UPDATE tại chỗ, không INSERT).
class ImportSubcategoryPreview extends ImportStep {
  const ImportSubcategoryPreview({required this.entries, required this.issues});
  final List<StagedSubcategoryBackfill> entries;
  final List<String> issues;
}

class ImportSubcategoryCommitted extends ImportStep {
  const ImportSubcategoryCommitted(this.summary);
  final SubcategoryBackfillSummary summary;
}

/// Bộ não màn nhập dữ liệu (Phase 9) — chọn file → parse → (Rolly: ánh xạ
/// danh mục) → dry-run diff → commit. Mỗi bước là một trạng thái tường minh
/// (`ImportStep`), KHÔNG có "commit ẩn" nào ở giữa — chỉ [commit] mới thật
/// sự ghi vào `transactions`.
class ImportController extends Notifier<ImportStep> {
  /// Bytes của file Rolly Tony vừa chọn ở [pickRollyFile], giữ lại để sau
  /// khi commit còn chạy nốt backfill danh mục phụ + tiết kiệm mà KHÔNG bắt
  /// chọn lại đúng file đó thêm hai lần nữa.
  ///
  /// Cố ý để ở FIELD chứ không nhét vào từng `ImportStep`: nó không phải
  /// thứ UI vẽ ra, và luồng ánh xạ đi qua bốn trạng thái liên tiếp — kéo
  /// bytes qua cả bốn chỉ để dùng ở bước cuối là nhiễu vô ích.
  Uint8List? _lastRollyFileBytes;

  @override
  ImportStep build() {
    // Giữ `categoriesProvider` sống — cần đọc `.value` trong các hàm dưới
    // (gợi ý ánh xạ, resolve CSV theo tên). Bài học Phase 8: `ref.read`
    // không giữ một `StreamProvider` chảy nếu không ai `watch`/`listen` nó.
    //
    // CỐ Ý `ref.listen`, KHÔNG `ref.watch`: `watch` bên trong `build()` của
    // MỘT `Notifier` khiến Riverpod HUỶ VÀ DỰNG LẠI TOÀN BỘ instance này mỗi
    // khi `categoriesProvider` phát giá trị mới — một coroutine `pickRollyFile`/
    // `commit`/... đang chạy dở trên instance CŨ (đã bị huỷ) thì gán `state =`
    // vào hư không, còn widget tree lúc đó đang xem instance MỚI với state
    // `build()` vừa trả về (`ImportIdle`) — cả wizard "biến mất" giữa chừng
    // không báo lỗi gì. Bắt được bằng widget test thật (DB mới mở → seed 12
    // danh mục → `categoriesProvider` phát lần đầu ĐÚNG LÚC wizard đang chạy
    // dở → state bị xoá về Idle không dấu vết). `ref.listen` giữ subscription
    // sống y hệt `watch` (cùng coi là "đang có người nghe" theo CHANGELOG
    // pause behavior) nhưng KHÔNG kích hoạt lại `build()` của chính notifier
    // này khi giá trị đổi.
    ref.listen(categoriesProvider, (_, _) {});
    return const ImportIdle();
  }

  void reset() => state = const ImportIdle();

  Future<void> pickRollyFile() async {
    state = const ImportBusy();
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Chọn file JSON đã kéo từ Rolly',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) {
        state = const ImportIdle();
        return;
      }
      final bytes = await file.readAsBytes();
      final loaded = decodeRollyImportFile(bytes);
      _lastRollyFileBytes = bytes;
      // CHỜ danh mục của ví hiện hành phát xong TRƯỚC khi tính gợi ý ánh xạ.
      // Gợi ý chỉ được tính MỘT LẦN ở đây; nếu lúc này danh sách còn rỗng
      // (luồng ví/danh mục chưa kịp phát — mở màn rồi chọn file ngay là ra)
      // thì mọi danh mục Rolly đều thành "Chưa chọn" và bảng ánh xạ chốt
      // sai vĩnh viễn cho lần import đó. Đúng họ lỗi "import làm mất danh
      // mục" đã sửa trước đó, chỉ khác nguyên nhân.
      await _awaitCategoriesReady();
      final parseResult = parseRollyInputRows(
        loaded.inputRows,
        categoryTitleById: loaded.categoryTitleById,
      );
      final categories = _tonyfinoCategoryNames();
      final mapping = <CategoryBucketKey, MappingChoice>{
        for (final usage in parseResult.categoryUsages)
          usage.bucket: suggestDefaultMapping(usage, categories),
      };
      state = ImportMappingCategories(
        parseResult: parseResult,
        mapping: mapping,
      );
    } catch (e) {
      state = ImportFailed('Không đọc được file Rolly: $e');
    }
  }

  void setCategoryMapping(CategoryBucketKey bucket, MappingChoice choice) {
    final current = state;
    if (current is! ImportMappingCategories) return;
    state = ImportMappingCategories(
      parseResult: current.parseResult,
      mapping: {...current.mapping, bucket: choice},
    );
  }

  /// BẤT ĐỒNG BỘ kể từ khi có [MappingCreateCategory] — mọi danh mục Tony
  /// chọn "Tạo mới" phải được insert THẬT (lấy `id`) rồi thay vào bảng ánh xạ
  /// trước khi [resolveRollyRows] chạy, vì hàm đó chỉ biết `categoryId`.
  /// Tạo danh mục ở đây, KHÔNG ở lúc commit: nếu chờ tới commit thì màn xem
  /// trước (dry-run) sẽ hiện sai danh mục — mà dry-run chính là chỗ Tony đối
  /// chiếu số trước khi ghi, hiện sai ở đó là phá đúng cái van an toàn.
  Future<void> confirmMapping() async {
    final current = state;
    if (current is! ImportMappingCategories || !current.allDecided) return;

    final mapping = {...current.mapping};
    final toCreate = <CategoryBucketKey, MappingCreateCategory>{
      for (final entry in mapping.entries)
        if (entry.value case final MappingCreateCategory c) entry.key: c,
    };
    if (toCreate.isNotEmpty) {
      state = const ImportBusy();
      final repo = ref.read(categoryRepositoryProvider);
      // Danh mục mới thuộc về VÍ ĐANG CHỌN (v11) — cũng chính là ví mà
      // `commit()` gán cho các giao dịch nhập vào. Chưa chốt được ví thì
      // dừng hẳn thay vì tạo danh mục mồ côi không màn nào thấy.
      final walletId = ref.read(selectedWalletIdProvider);
      if (walletId == null) {
        state = const ImportFailed(
          'Chưa xác định được ví để nhập vào — mở lại màn này sau khi ví đã '
          'tải xong.',
        );
        return;
      }
      // Danh mục đã có sẵn trùng tên (fold dấu) thì DÙNG LẠI, không tạo trùng
      // — Tony có thể bấm "Tạo mới" cho hai nhóm Rolly cùng tên, hoặc chạy
      // lại wizard lần hai sau khi lần đầu đã tạo.
      final existing = {
        for (final c in _tonyfinoCategoryNames()) foldToAscii(c.name): c.id,
      };
      // Rải màu quanh bảng 12 màu danh mục thay vì gán cứng một màu: import
      // thật tạo tới 5-6 danh mục một lượt, cho hết cùng màu thì biểu đồ tròn
      // ở màn Báo cáo biến thành một mảng xám không phân biệt được lát nào là
      // lát nào (thấy tận mắt khi diễn tập trên emulator với 358 giao dịch
      // thật). Bắt đầu lệch theo số danh mục đã có để không đụng ngay màu của
      // các danh mục mặc định.
      var colorCursor = existing.length;
      for (final entry in toCreate.entries) {
        final key = foldToAscii(entry.value.name);
        var id = existing[key];
        if (id == null) {
          final result = await repo.insert(
            name: entry.value.name,
            kind: entry.value.kind,
            walletId: walletId,
            categoryColorId: colorCursor++ % paletteCategoryColors.length,
            iconCode: suggestIconCodeForName(entry.value.name),
          );
          switch (result) {
            case Ok(:final value):
              id = value;
              existing[key] = value;
            case Err(:final error):
              state = ImportFailed(
                'Không tạo được danh mục "${entry.value.name}": '
                '${error.message}',
              );
              return;
          }
        }
        mapping[entry.key] = MappingToCategory(id);
      }
    }

    final resolved = resolveRollyRows(current.parseResult.rows, mapping);
    final reconciliation = computeRollyReconciliation(current.parseResult.rows);
    state = ImportReadyForDryRun(
      rows: resolved,
      reconciliation: reconciliation,
      parseIssues: current.parseResult.issues,
    );
  }

  Future<void> pickCsvFile() async {
    state = const ImportBusy();
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Chọn file CSV',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (file == null) {
        state = const ImportIdle();
        return;
      }
      final bytes = await file.readAsBytes();
      final text = String.fromCharCodes(bytes);
      final categoryIdByName = {
        for (final c in _tonyfinoCategoryNames()) c.name: c.id,
      };
      final parsed = parseTransactionsCsv(
        text,
        categoryIdByName: categoryIdByName,
      );
      state = ImportReadyForDryRun(
        rows: parsed.rows,
        unmatchedCategoryNames: parsed.unmatchedCategoryNames,
      );
    } catch (e) {
      state = ImportFailed('Không đọc được file CSV: $e');
    }
  }

  Future<void> runDryRun() async {
    final current = state;
    if (current is! ImportReadyForDryRun) return;
    state = const ImportBusy();
    final repo = ref.read(transactionRepositoryProvider);
    final existing = await repo.findExistingSourceIds(
      current.rows.map((r) => r.sourceId),
    );
    state = ImportDryRunResult(
      rows: current.rows,
      newCount: current.rows.length - existing.length,
      duplicateCount: existing.length,
      reconciliation: current.reconciliation,
      parseIssues: current.parseIssues,
      unmatchedCategoryNames: current.unmatchedCategoryNames,
    );
  }

  Future<void> commit() async {
    final current = state;
    if (current is! ImportDryRunResult) return;
    state = const ImportBusy();
    final repo = ref.read(transactionRepositoryProvider);
    // Lịch sử nhập từ Rolly/CSV không có khái niệm ví — luôn gán vào ví mặc
    // định (xem docs/decisions.md § Phase 13).
    final walletId = await ref.read(walletRepositoryProvider).defaultWalletId();
    final result = await repo.insertImportBatch([
      for (final row in current.rows)
        (
          amountMinor: row.amountMinor,
          occurredAt: row.occurredAt,
          categoryId: row.categoryId,
          note: row.note,
          sourceId: row.sourceId,
          isTransfer: row.isTransfer,
        ),
    ], walletId: walletId);
    switch (result) {
      case Err(:final error):
        state = ImportFailed(error.message);
      case Ok(:final value):
        // Chạy nốt hai bước còn lại từ CHÍNH file vừa chọn. Đặt ở SAU commit
        // chứ không phải trước: cả hai đều đối chiếu theo `sourceId` của
        // giao dịch, nên chúng chỉ có việc để làm khi giao dịch đã nằm
        // trong sổ. Đây không phải "commit ẩn": Tony vừa bấm xác nhận ghi
        // đúng file này, và kết quả từng bước hiện tường minh ở màn xong.
        final followUp = await _runFollowUpsFromLastFile();
        state = ImportCommitted(
          inserted: value.inserted,
          skippedDuplicate: value.skippedDuplicate,
          reconciliation: current.reconciliation,
          followUpSubcategory: followUp.subcategory,
          followUpSavings: followUp.savings,
          followUpError: followUp.error,
        );
    }
  }

  /// Đọc lại file Rolly vừa chọn và chạy nốt những mảng nó có. Mảng nào
  /// vắng thì bỏ qua LẶNG LẼ (file chỉ có `input` là hợp lệ hoàn toàn);
  /// mảng nào có mà chạy hỏng thì trả lỗi để màn xong nói rõ.
  Future<
    ({
      SubcategoryBackfillSummary? subcategory,
      RollySavingsImportSummary? savings,
      String? error,
    })
  >
  _runFollowUpsFromLastFile() async {
    final bytes = _lastRollyFileBytes;
    if (bytes == null) return (subcategory: null, savings: null, error: null);

    SubcategoryBackfillSummary? subcategory;
    RollySavingsImportSummary? savings;
    final errors = <String>[];

    try {
      final loaded = decodeRollySubcategoryImportFile(bytes);
      final parsed = parseSubcategoryBackfill(
        loaded.subcategoryRows,
        loaded.inputRows,
      );
      final result = await ref
          .read(categoryRepositoryProvider)
          .backfillSubcategoriesFromRolly(parsed.entries);
      switch (result) {
        case Ok(:final value):
          subcategory = value;
        case Err(:final error):
          errors.add('danh mục phụ: ${error.message}');
      }
    } on RollyFileFormatException {
      // File không có mảng `subcategory` — hoàn toàn bình thường.
    }

    try {
      final loaded = decodeRollySavingsImportFile(bytes);
      final parsed = parseRollySavingsGoals(loaded.savingsRows);
      final result = await ref
          .read(savingsGoalRepositoryProvider)
          .importFromRolly(
            goals: parsed.goals,
            contributionSourceIdsByRollyGoalId: mapSavingsContributionSourceIds(
              loaded.inputRows,
            ),
          );
      switch (result) {
        case Ok(:final value):
          savings = value;
        case Err(:final error):
          errors.add('tiết kiệm: ${error.message}');
      }
    } on RollyFileFormatException {
      // File không có mảng `savings` — bình thường.
    }

    return (
      subcategory: subcategory,
      savings: savings,
      error: errors.isEmpty ? null : errors.join(' · '),
    );
  }

  /// Nhập lịch sử tiết kiệm cũ của Rolly (Phase 19) — file gộp
  /// `{"savings": [...], "input": [...]}`, xem `rolly_file_loader.dart`.
  /// Không có bước ánh xạ danh mục (không áp dụng cho mục tiêu tiết kiệm).
  Future<void> pickRollySavingsFile() async {
    state = const ImportBusy();
    try {
      final file = await FilePicker.pickFile(
        dialogTitle:
            'Chọn file JSON tiết kiệm Rolly ({"savings":..., "input":...})',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) {
        state = const ImportIdle();
        return;
      }
      final bytes = await file.readAsBytes();
      final loaded = decodeRollySavingsImportFile(bytes);
      final parsed = parseRollySavingsGoals(loaded.savingsRows);
      final contributionMap = mapSavingsContributionSourceIds(loaded.inputRows);
      final repo = ref.read(savingsGoalRepositoryProvider);
      final existing = await repo.findExistingGoalSourceIds(
        parsed.goals.map((g) => g.sourceId),
      );
      state = ImportSavingsPreview(
        goals: parsed.goals,
        contributionSourceIdsByRollyGoalId: contributionMap,
        issues: parsed.issues,
        existingSourceIds: existing,
      );
    } catch (e) {
      state = ImportFailed('Không đọc được file tiết kiệm Rolly: $e');
    }
  }

  Future<void> commitSavingsImport() async {
    final current = state;
    if (current is! ImportSavingsPreview) return;
    state = const ImportBusy();
    final repo = ref.read(savingsGoalRepositoryProvider);
    final result = await repo.importFromRolly(
      goals: current.goals,
      contributionSourceIdsByRollyGoalId:
          current.contributionSourceIdsByRollyGoalId,
    );
    result.when(
      ok: (summary) => state = ImportSavingsCommitted(summary),
      err: (error) => state = ImportFailed(error.message),
    );
  }

  /// Khôi phục danh mục phụ cho lịch sử Rolly (bổ sung sau Phase 20) — file
  /// gộp `{"subcategory": [...], "input": [...]}`.
  Future<void> pickRollySubcategoryFile() async {
    state = const ImportBusy();
    try {
      final file = await FilePicker.pickFile(
        dialogTitle:
            'Chọn file JSON danh mục phụ Rolly ({"subcategory":..., "input":...})',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) {
        state = const ImportIdle();
        return;
      }
      final bytes = await file.readAsBytes();
      final loaded = decodeRollySubcategoryImportFile(bytes);
      final parsed = parseSubcategoryBackfill(
        loaded.subcategoryRows,
        loaded.inputRows,
      );
      state = ImportSubcategoryPreview(
        entries: parsed.entries,
        issues: parsed.issues,
      );
    } catch (e) {
      state = ImportFailed('Không đọc được file danh mục phụ Rolly: $e');
    }
  }

  Future<void> commitSubcategoryBackfill() async {
    final current = state;
    if (current is! ImportSubcategoryPreview) return;
    state = const ImportBusy();
    final repo = ref.read(categoryRepositoryProvider);
    final result = await repo.backfillSubcategoriesFromRolly(current.entries);
    result.when(
      ok: (summary) => state = ImportSubcategoryCommitted(summary),
      err: (error) => state = ImportFailed(error.message),
    );
  }

  /// Xuất TOÀN BỘ giao dịch hiện có ra CSV rồi mở share sheet — không đi qua
  /// state machine ở trên (không phải một bước của luồng nhập), chỉ dùng
  /// chung domain codec để tự round-trip được với [pickCsvFile].
  Future<void> exportCsv() async {
    final db = ref.read(appDatabaseProvider);
    final transactions = await (db.select(
      db.transactions,
    )..orderBy([(t) => OrderingTerm.asc(t.occurredAt)])).get();
    final categoryNameById = {
      for (final c in _tonyfinoCategoryNames()) c.id: c.name,
    };

    final csvText = encodeTransactionsCsv([
      for (final t in transactions)
        CsvExportRow(
          occurredAt: t.occurredAt,
          amountMinor: t.amountMinor,
          categoryName: t.categoryId == null
              ? null
              : categoryNameById[t.categoryId],
          note: t.note,
          sourceId: t.sourceId,
        ),
    ]);

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(csvText.codeUnits),
            mimeType: 'text/csv',
            name: 'tonyfino-export.csv',
          ),
        ],
        subject: 'Xuất giao dịch TonyFino (CSV)',
      ),
    );
  }

  /// Chờ `activeWalletsProvider` rồi `categoriesProvider` phát giá trị đầu.
  /// Ví suy ra ĐỒNG BỘ từ danh sách ví (xem `selectedWalletIdProvider`) nên
  /// chỉ cần hai lần chờ này, không có vòng lặp dò nào.
  Future<void> _awaitCategoriesReady() async {
    if (ref.read(categoriesProvider).value?.isNotEmpty ?? false) return;
    await ref.read(activeWalletsProvider.future);
    await ref.read(categoriesProvider.future);
  }

  List<({int id, String name})> _tonyfinoCategoryNames() {
    final categories = ref.read(categoriesProvider).value ?? const [];
    return [for (final c in categories) (id: c.id, name: c.name)];
  }
}

final importControllerProvider = NotifierProvider<ImportController, ImportStep>(
  ImportController.new,
);
