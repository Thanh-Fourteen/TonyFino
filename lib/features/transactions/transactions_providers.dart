import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_providers.dart';
import '../../core/time/clock_provider.dart';
import '../../data/db/database.dart';
import '../../data/repositories/transaction_repository.dart';
import '../home/home_period_provider.dart';
import 'domain/entry_streak.dart';
import '../jars/jars_providers.dart';
import '../wallets/selected_wallet_provider.dart';

final transactionsWithCategoryProvider =
    StreamProvider<List<TransactionWithCategory>>((ref) {
      return ref.watch(transactionRepositoryProvider).watchAllWithCategory();
    });

/// Trạng thái lọc theo thẻ CHỈ cho `TransactionsScreen` (Phase 17) — Notifier
/// THUẦN UI STATE (không đọc DB trong `build()`), cùng lý do an toàn với
/// `ReportFilterController` (không dính bẫy `ref.watch` phá huỷ notifier).
class TransactionsTagFilterController extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  void setTagIds(Set<int> tagIds) => state = tagIds;
}

final transactionsTagFilterProvider =
    NotifierProvider<TransactionsTagFilterController, Set<int>>(
      TransactionsTagFilterController.new,
    );

/// Hũ đang lọc ở tab Giao dịch — `null` = không lọc theo hũ. UI state
/// thuần, cùng lý do an toàn với [TransactionsTagFilterController].
class TransactionsJarFilterController extends Notifier<int?> {
  @override
  int? build() => null;

  /// Bấm lại đúng hũ đang chọn thì bỏ lọc — một chạm để vào, một chạm để ra.
  void toggle(int jarId) => state = state == jarId ? null : jarId;

  void clear() => state = null;
}

final transactionsJarFilterProvider =
    NotifierProvider<TransactionsJarFilterController, int?>(
      TransactionsJarFilterController.new,
    );

/// Danh sách giao dịch đã lọc theo [transactionsTagFilterProvider] — TÁCH
/// KHỎI [transactionsWithCategoryProvider] (không đổi, vẫn không lọc) vì
/// `quick_add_screen.dart`/`draft_card.dart` cũng đọc provider đó và không
/// được phép bị ảnh hưởng bởi bộ lọc riêng của tab Giao dịch.
final filteredTransactionsProvider =
    StreamProvider<List<TransactionWithCategory>>((ref) {
      final tagIds = ref.watch(transactionsTagFilterProvider);
      // Cùng `homePeriodProvider` với Trang chủ, Hũ và Hạn mức — KHÔNG dựng
      // bộ chọn kỳ thứ hai cho riêng màn này. Trang chủ nói "tháng này chi
      // 8.359.000" mà danh sách giao dịch lại liệt kê cả đời thì hai màn
      // đang trả lời hai câu hỏi khác nhau bằng cùng một giao diện.
      final period = ref.watch(homePeriodProvider);
      final repo = ref.watch(transactionRepositoryProvider);

      final jarId = ref.watch(transactionsJarFilterProvider);
      final jar = jarId == null
          ? null
          : (ref.watch(jarsProvider).value ?? const <Jar>[])
                .where((j) => j.id == jarId)
                .firstOrNull;
      if (jar != null) {
        return watchJarTransactions(
          ref,
          jar,
          period.range,
          tagIds: tagIds.isEmpty ? null : tagIds,
        );
      }

      return repo.watchAllWithCategory(
        tagIds: tagIds.isEmpty ? null : tagIds,
        from: period.range.start,
        to: period.range.end,
      );
    });

/// Danh mục của VÍ ĐANG CHỌN (v11). Ví chưa chốt xong (`null`) thì phát
/// danh sách rỗng chứ KHÔNG phát danh mục của mọi ví — thà thấy trống một
/// khung hình còn hơn thấy hai danh mục trùng tên của hai ví khác nhau.
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final walletId = ref.watch(selectedWalletIdProvider);
  if (walletId == null) return Stream.value(const <Category>[]);
  return ref.watch(categoryRepositoryProvider).watchAll(walletId: walletId);
});

/// Từ khoá (seed + đã học) của MỘT danh mục — nguồn cho mục "Từ khoá đã
/// học" ở `CategoryDetailScreen`, nơi Tony xem và gỡ được thứ vòng lặp học
/// đã nhớ.
final categoryKeywordsProvider =
    StreamProvider.family<List<CategoryKeyword>, int>((ref, categoryId) {
      return ref.watch(categoryRepositoryProvider).watchKeywordsFor(categoryId);
    });

/// Danh mục CHƯA lưu trữ — dùng cho MỌI bộ chọn "chọn danh mục cho một
/// khoản MỚI" (Phase 13). `categoriesProvider` (không lọc) vẫn dùng cho
/// tra cứu/hiển thị lịch sử/lọc báo cáo — một giao dịch cũ gắn danh mục đã
/// lưu trữ vẫn phải hiện đúng tên/màu/icon của nó ở đó.
final activeCategoriesProvider = StreamProvider<List<Category>>((ref) {
  final walletId = ref.watch(selectedWalletIdProvider);
  if (walletId == null) return Stream.value(const <Category>[]);
  return ref.watch(categoryRepositoryProvider).watchActive(walletId: walletId);
});

final monthSummaryProvider = StreamProvider<MonthSummary>((ref) {
  final now = ref.watch(clockProvider).now();
  final period = ref.watch(homePeriodProvider);
  return ref
      .watch(transactionRepositoryProvider)
      .watchMonthToDateSummary(
        now,
        from: period.range.start,
        to: period.range.end,
      );
});

/// Chuỗi ngày ghi giao dịch liên tiếp (Phase 22) — TÁI DÙNG
/// [transactionsWithCategoryProvider] (không tính lại bằng query riêng),
/// chỉ trích `occurredAt` rồi đưa qua `computeEntryStreakDays` (tính theo
/// ngày giao dịch thật, xem `domain/entry_streak.dart`).
final entryStreakProvider = Provider<int>((ref) {
  final transactions = ref.watch(transactionsWithCategoryProvider).value;
  if (transactions == null) return 0;
  final now = ref.watch(clockProvider).now();
  return computeEntryStreakDays(
    occurredDates: transactions.map((t) => t.transaction.occurredAt),
    today: now,
  );
});

/// Xoá + `Hoàn tác` qua SnackBar (D7 checklist "xoá có undo") — dùng chung
/// giữa hàng vuốt-xoá trong danh sách và nút xoá trong form sửa, để không
/// viết logic hai lần theo hai hình dạng khác nhau.
///
/// Phần "chụp lại đủ để dựng lại" nằm ở `TransactionRepository.captureForUndo`
/// / `restore` chứ không ở đây: nó là chuyện của dữ liệu (đọc dòng con, thẻ,
/// bytes ảnh trước khi `delete` xoá sạch), test thẳng được mà không cần dựng
/// cây widget. Ở đây chỉ còn đúng phần giao diện.
Future<void> deleteTransactionWithUndo(
  BuildContext context,
  WidgetRef ref,
  Transaction transaction,
) async {
  final repo = ref.read(transactionRepositoryProvider);
  // 🚨 Chụp TRƯỚC khi xoá — sau `delete` thì dòng con/thẻ/ảnh không còn.
  final snapshot = await repo.captureForUndo(transaction.id);
  final result = await repo.delete(transaction.id);
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final errorMessage = result.when(ok: (_) => null, err: (e) => e.message);
  if (errorMessage != null) {
    messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    return;
  }

  // `hideCurrentSnackBar` trước khi hiện cái mới: xoá liên tiếp hai hàng thì
  // cái thứ hai xếp HÀNG ĐỢI sau cái thứ nhất chứ không thay thế nó, nên
  // thanh "Đã xoá giao dịch" ở lại gấp đôi thời gian và nút "Hoàn tác" đang
  // hiện lại thuộc về giao dịch TRƯỚC — bấm vào là khôi phục nhầm hàng.
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Đã xoá giao dịch'),
      // Nói rõ thời lượng thay vì dựa vào mặc định: đây là cửa sổ DUY NHẤT để
      // lấy lại một giao dịch, 4 giây mặc định quá ngắn cho một thao tác lỡ
      // tay mà người dùng chỉ nhận ra sau khi nhìn lại con số.
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: 'Hoàn tác',
        // Màu chữ mặc định của `SnackBarAction` là `secondary` của scheme —
        // teal đậm trên nền thanh gần đen, gần như không đọc được (đo trên
        // ảnh chụp máy thật). Thanh snackbar luôn tối ở cả hai theme nên
        // dùng thẳng màu chữ SÁNG, không lấy theo scheme.
        textColor: Colors.white,
        onPressed: () {
          if (snapshot != null) repo.restore(snapshot);
        },
      ),
    ),
  );
}
