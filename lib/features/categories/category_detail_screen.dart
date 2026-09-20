import 'dart:async';

import '../../ui/amount_visibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money/money.dart';
import '../../core/providers/database_providers.dart';
import '../../core/time/clock_provider.dart';
import '../../data/db/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/transaction_repository.dart'
    show TransactionWithCategory;
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/app_card.dart';
import '../../ui/category_avatar.dart';
import '../../ui/day_header.dart';
import '../../ui/empty_state.dart';
import '../../ui/money_text.dart';
import '../../ui/transaction_row.dart';
import '../reports/domain/category_slice.dart';
import '../reports/domain/report_range.dart';
import '../transactions/day_label.dart';
import '../transactions/domain/day_groups.dart';
import '../transactions/domain/transaction_row_display.dart';
import '../transactions/transaction_form_sheet.dart';
import '../transactions/transactions_providers.dart';
import 'widgets/category_edit_sheet.dart';

/// Màn "Chi tiết danh mục" (Phase 25, đúc theo mẫu hình Rolly —
/// `docs/rolly-uiux-research.md` § G.3/G.5, ảnh THẬT Tony đã gửi, KHÔNG phải
/// suy đoán từ ảnh marketing) — gộp ba việc đang tách rời ở TonyFino trước
/// phase này: quản lý danh mục CON của riêng cha, breakdown chi tiêu theo
/// con, và danh sách giao dịch (cha + mọi con) cuộn được, TẤT CẢ trong MỘT
/// route riêng (không phải sheet, khớp Rolly là một MÀN ĐẦY ĐỦ chứ không
/// phải modal). CHỈ mở được từ một danh mục CẤP GỐC (`CategoriesScreen`
/// không đẩy tới đây cho danh mục con — con không có "con của con", Phase 13
/// giới hạn 1 cấp).
///
/// Bộ lọc ngày CỐ TÌNH luôn "Tất cả" — Rolly có bộ lọc riêng cho màn này
/// (khác bộ lọc toàn app), nhưng phần "Bàn giao" của Phase 25 không yêu cầu
/// việc đó, thêm một bộ lọc ngày thứ hai (khác `ReportFilterController` của
/// Báo cáo) là mở rộng phạm vi không cần thiết cho bản đầu — dễ thêm sau nếu
/// Tony thấy cần.
/// Cửa duy nhất để mở [CategoryDetailScreen].
///
/// Báo cáo TRƯỚC đây mở một bottom-sheet breakdown riêng, còn màn Danh mục
/// đẩy màn này — hai lối vào cho cùng một câu hỏi ("danh mục này gồm những
/// gì"), đúng kiểu chắp vá Tony đã kêu. Giờ cả hai đi qua đây.
void openCategoryDetailScreen(
  BuildContext context,
  int categoryId, {
  ReportRange? range,
  String? rangeLabel,
}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => CategoryDetailScreen(
        categoryId: categoryId,
        range: range,
        rangeLabel: rangeLabel,
      ),
    ),
  );
}

class CategoryDetailScreen extends ConsumerWidget {
  const CategoryDetailScreen({
    super.key,
    required this.categoryId,
    this.range,
    this.rangeLabel,
  });

  final int categoryId;

  /// Khoảng thời gian để tính breakdown + lọc giao dịch. `null` = TẤT CẢ
  /// thời gian (lối vào từ màn Danh mục — ở đó đang quản lý danh mục, không
  /// phải đọc báo cáo của một kỳ).
  ///
  /// Mở từ Báo cáo thì PHẢI truyền đúng khoảng đang lọc: bấm vào một lát
  /// bánh của "7 ngày qua" mà màn chi tiết hiện tổng cả đời thì hai con số
  /// không khớp nhau, người dùng tưởng app tính sai.
  final ReportRange? range;

  /// Nhãn kỳ đang xem, hiện dưới tiêu đề để biết con số thuộc kỳ nào.
  final String? rangeLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    Category? category;
    for (final c in categories) {
      if (c.id == categoryId) {
        category = c;
        break;
      }
    }
    if (category == null) {
      // Danh mục vừa bị lưu trữ/không còn trong danh sách đang xem — quay
      // lại thay vì hiện màn trống vô nghĩa (danh mục không bao giờ xoá
      // cứng nên đây chỉ xảy ra nếu category vừa được archive từ nơi khác).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.of(context).pop();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final children = categories
        .where((c) => c.parentCategoryId == categoryId)
        .toList();
    final relevantIds = {categoryId, for (final child in children) child.id};
    // Danh mục CON: mở được từ breakdown của cha (Rolly cũng đi tiếp một
    // nấc như vậy). Ở nấc này màn hình chỉ còn là "tổng + danh sách giao
    // dịch" — mọi thứ dính đến con-của-con phải biến mất, vì Phase 13 chốt
    // danh mục chỉ sâu 1 cấp.
    final isLeaf = category.parentCategoryId != null;
    // 🚨 HAI LỐI VÀO, HAI MỤC ĐÍCH KHÁC HẲN NHAU.
    //
    // Vào từ Báo cáo (`range != null`) là để ĐỌC SỐ: "Ăn uống tháng này hết
    // bao nhiêu, chia ra sao". Vào từ Quản lý → Danh mục là để SỬA CẤU
    // TRÚC: thêm/đổi danh mục con, soát từ khoá app đã học.
    //
    // Trộn hai thứ vào một màn thì lối vào báo cáo phải cuộn qua danh sách
    // danh mục con rồi tới bảng từ khoá mới thấy giao dịch — Tony nói thẳng
    // là "khó xem hơn". Bảng "Theo danh mục con" thì GIỮ ở cả hai lối vào:
    // đó chính là câu trả lời cho "chia ra sao".
    //
    // Cùng một nguyên tắc đã tách `ManageScreen` khỏi `SettingsScreen`.
    final isManaging = this.range == null;
    final now = ref.watch(clockProvider).now();
    final range =
        this.range ?? ReportRange.preset(ReportRangePreset.allTime, now);
    final resolvedCategory = category;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CategoryAvatar(
              categoryColorId: resolvedCategory.categoryColorId,
              iconCode: resolvedCategory.iconCode,
              emoji: resolvedCategory.emoji,
              size: 32,
            ),
            SizedBox(width: context.space.sm),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resolvedCategory.name, overflow: TextOverflow.ellipsis),
                  // Kỳ đang xem — bắt buộc khi vào từ Báo cáo, nếu không hai
                  // con số ở hai màn trông như mâu thuẫn nhau.
                  if (rangeLabel != null)
                    Text(
                      rangeLabel!,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(kIconEdit),
            onPressed: () => showCategoryEditSheet(
              context: context,
              existingId: resolvedCategory.id,
              existingName: resolvedCategory.name,
              existingKind: resolvedCategory.kind,
              existingColorId: resolvedCategory.categoryColorId,
              existingIconCode: resolvedCategory.iconCode,
              existingParentCategoryId: resolvedCategory.parentCategoryId,
              existingEmoji: resolvedCategory.emoji,
            ),
          ),
        ],
      ),
      // FAB CÓ NHÃN: một dấu cộng trần trên màn "Chi tiết danh mục" không
      // nói được nó thêm CÁI GÌ — người dùng đoán là thêm giao dịch.
      // FAB "Danh mục con" cũng là việc QUẢN LÝ — che mất góc dưới phải của
      // danh sách giao dịch ở lối vào báo cáo mà chẳng ai vào đó để tạo
      // danh mục.
      floatingActionButton: isLeaf || !isManaging
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showCategoryEditSheet(
                context: context,
                existingParentCategoryId: categoryId,
              ),
              icon: const Icon(kIconAdd),
              label: const Text('Danh mục con'),
            ),
      body: StreamBuilder(
        stream: ref
            .read(reportsRepositoryProvider)
            .watchCategoryBreakdown(range, categoryIds: relevantIds),
        builder: (context, breakdownSnapshot) {
          final breakdown =
              breakdownSnapshot.data ?? const <CategorySourceAmount>[];
          final totalMinor = breakdown.fold<int>(
            0,
            (sum, s) => sum + s.amountMinor,
          );

          return StreamBuilder(
            stream: ref
                .read(transactionRepositoryProvider)
                .watchAllWithCategory(
                  categoryIds: relevantIds,
                  from: range.start,
                  to: range.end,
                ),
            builder: (context, txSnapshot) {
              final transactions =
                  txSnapshot.data ?? const <TransactionWithCategory>[];
              final dayGroups = groupTransactionsByDay(transactions);
              final categoriesById = {for (final c in categories) c.id: c};

              return ListView(
                padding: EdgeInsets.only(bottom: context.space.xxl),
                children: [
                  Padding(
                    padding: EdgeInsets.all(context.space.screenHorizontal),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tổng cộng',
                          style: context.text.labelMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                        MoneyText(Money.vnd(totalMinor), size: MoneySize.large),
                        if (!isLeaf && breakdown.isNotEmpty) ...[
                          SizedBox(height: context.space.md),
                          Text(
                            'Theo danh mục con',
                            style: context.text.titleMedium,
                          ),
                          SizedBox(height: context.space.sm),
                          AppCard(
                            child: Column(
                              children: [
                                for (final source in _sortedByAbs(breakdown))
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: context.space.xxs,
                                    ),
                                    child: _BreakdownRow(
                                      source: source,
                                      totalAbsMinor: totalMinor.abs(),
                                      // Bấm một danh mục CON → mở đúng màn
                                      // này cho chính nó: tổng của riêng
                                      // con + danh sách giao dịch của con,
                                      // vẫn trong kỳ đang xem. Con không có
                                      // con nên phần breakdown tự rỗng.
                                      onTap:
                                          source.categoryId == null ||
                                              source.categoryId == categoryId
                                          ? null
                                          : () => openCategoryDetailScreen(
                                              context,
                                              source.categoryId!,
                                              range: this.range,
                                              rangeLabel: rangeLabel,
                                            ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (!isLeaf && isManaging) ...[
                          SizedBox(height: context.space.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Danh mục con',
                                style: context.text.titleMedium,
                              ),
                              Text(
                                '${children.length}',
                                style: context.text.labelMedium?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isLeaf && isManaging)
                    if (children.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.space.screenHorizontal,
                        ),
                        child: Text(
                          'Chưa có danh mục con nào — bấm nút + để thêm.',
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      for (final child in children)
                        _SubcategoryTile(category: child),
                  if (isManaging) ...[
                    SizedBox(height: context.space.lg),
                    _LearnedKeywords(categoryId: categoryId),
                  ],
                  SizedBox(height: context.space.lg),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.space.screenHorizontal,
                    ),
                    child: Text('Giao dịch', style: context.text.titleMedium),
                  ),
                  if (dayGroups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: EmptyState(
                        icon: kIconReceiptLong,
                        title: 'Chưa có giao dịch',
                        message: 'Chưa có giao dịch nào trong danh mục này.',
                      ),
                    )
                  else
                    for (final group in dayGroups) ...[
                      DayHeader(
                        label: formatDayLabel(group.day, now),
                        netTotal: Money.vnd(group.netMinor),
                      ),
                      for (final twc in group.items) ...[
                        // Một chỗ dùng chung với tab Giao dịch/Trang chủ/Tìm
                        // kiếm — xem `transaction_row_display.dart`.
                        TransactionRow(
                          categoryColorId: transactionRowDisplay(
                            twc,
                            categoriesById,
                          ).categoryColorId,
                          iconCode: transactionRowDisplay(
                            twc,
                            categoriesById,
                          ).iconCode,
                          emoji: transactionRowDisplay(
                            twc,
                            categoriesById,
                          ).emoji,
                          title: transactionRowDisplay(
                            twc,
                            categoriesById,
                          ).title,
                          subcategoryLabel: transactionRowDisplay(
                            twc,
                            categoriesById,
                          ).subcategoryLabel,
                          subtitle: twc.transaction.note ?? '',
                          amount: Money(
                            minorUnits: twc.transaction.amountMinor,
                            currency: twc.transaction.currency,
                            currencyScale: twc.transaction.currencyScale,
                          ),
                          onTap: () => showTransactionFormSheet(
                            context: context,
                            existing: twc,
                          ),
                        ),
                        TransactionRow.divider(context),
                      ],
                    ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.source,
    required this.totalAbsMinor,
    this.onTap,
  });

  final CategorySourceAmount source;
  final int totalAbsMinor;

  /// `null` khi hàng này là CHÍNH danh mục đang mở (giao dịch gán thẳng vào
  /// cha) — bấm vào chỉ đẩy lại đúng màn đang đứng, vô nghĩa.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pct = totalAbsMinor == 0
        ? 0
        : (source.amountMinor.abs() * 100 / totalAbsMinor).round();
    final row = Row(
      children: [
        CategoryAvatar(
          categoryColorId: source.categoryColorId,
          iconCode: source.iconCode,
          size: 28,
        ),
        SizedBox(width: context.space.sm),
        Expanded(
          child: Text(
            source.label,
            style: context.text.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$pct%',
          style: context.text.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        SizedBox(width: context.space.sm),
        Text(
          AmountVisibility.mask(
            context,
            Money.vnd(source.amountMinor).format(),
          ),
          style: context.text.labelMedium,
        ),
        if (onTap != null) ...[
          SizedBox(width: context.space.xxs),
          Icon(
            kIconChevronRight,
            size: 16,
            color: context.colors.onSurfaceVariant,
          ),
        ],
      ],
    );
    if (onTap == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.space.xxs),
        child: row,
      ),
    );
  }
}

class _SubcategoryTile extends ConsumerWidget {
  const _SubcategoryTile({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: context.space.screenHorizontal,
        vertical: context.space.xxs,
      ),
      child: ListTile(
        leading: CategoryAvatar(
          categoryColorId: category.categoryColorId,
          iconCode: category.iconCode,
          emoji: category.emoji,
        ),
        title: Text(category.name),
        trailing: PopupMenuButton<void>(
          itemBuilder: (context) => [
            PopupMenuItem(
              onTap: () => showCategoryEditSheet(
                context: context,
                existingId: category.id,
                existingName: category.name,
                existingKind: category.kind,
                existingColorId: category.categoryColorId,
                existingIconCode: category.iconCode,
                existingParentCategoryId: category.parentCategoryId,
                existingEmoji: category.emoji,
              ),
              child: const Text('Sửa'),
            ),
            PopupMenuItem(
              onTap: () => ref
                  .read(categoryRepositoryProvider)
                  .setArchived(category.id, true),
              child: const Text('Lưu trữ'),
            ),
          ],
        ),
      ),
    );
  }
}

List<CategorySourceAmount> _sortedByAbs(List<CategorySourceAmount> sources) {
  final sorted = [...sources]
    ..sort((a, b) => b.amountMinor.abs().compareTo(a.amountMinor.abs()));
  return sorted;
}

/// Mục "Từ khoá" — thứ app dùng để đoán danh mục cho câu chữ ở màn chat,
/// và giờ XEM và GỠ được.
///
/// 🚨 Vì sao cần: vòng lặp học chỉ biết CỘNG (khoá mới 1.5, mỗi lần đúng
/// +0.5, trần 5.0). Trước bản này nó còn chạy âm thầm, nên một lần sửa nhầm
/// là app nhớ cái sai vĩnh viễn và cách duy nhất để đè là dạy đúng nhiều
/// lần cho tới khi điểm vượt lên. Xoá được một dòng là lối thoát duy nhất.
///
/// 🚨 TÁCH "bạn đã dạy" khỏi "mặc định", và ẩn nhóm mặc định đi. Một danh
/// mục seed mang tới 85 khoá ("Ăn uống"), nên đổ phẳng tất cả ra thì thứ
/// Tony thật sự dạy — vài dòng — chìm nghỉm giữa danh sách phải cuộn mãi,
/// mà đó mới là thứ cần soát khi app đoán sai.
class _LearnedKeywords extends ConsumerStatefulWidget {
  const _LearnedKeywords({required this.categoryId});

  final int categoryId;

  @override
  ConsumerState<_LearnedKeywords> createState() => _LearnedKeywordsState();
}

class _LearnedKeywordsState extends ConsumerState<_LearnedKeywords> {
  bool _showSeeded = false;

  @override
  Widget build(BuildContext context) {
    final keywords =
        ref.watch(categoryKeywordsProvider(widget.categoryId)).value ??
        const <CategoryKeyword>[];
    if (keywords.isEmpty) return const SizedBox.shrink();

    // Phân biệt bằng TRỌNG SỐ, không phải bằng một cột riêng: khoá seed có
    // trọng số tối đa 1.4, khoá học luôn bắt đầu từ
    // `kLearnedKeywordInitialWeight` (1.5) và chỉ tăng. Giả định đó được
    // khoá lại bằng test trong `seed_keyword_coverage_test.dart` — nếu ai
    // đó thêm một seed nặng 1.5 thì test đỏ chứ không phải màn này lặng lẽ
    // xếp nhầm nhóm.
    final learned = [
      for (final k in keywords)
        if (k.weight >= kLearnedKeywordInitialWeight) k,
    ];
    final seeded = [
      for (final k in keywords)
        if (k.weight < kLearnedKeywordInitialWeight) k,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.space.screenHorizontal,
          ),
          child: Text('Từ khoá', style: context.text.titleMedium),
        ),
        SizedBox(height: context.space.xs),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.space.screenHorizontal,
          ),
          child: Text(
            'Gõ những từ này ở màn nhập nhanh sẽ tự vào danh mục này. '
            'Số bên cạnh là độ mạnh — càng cao càng chắc.',
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(height: context.space.sm),
        if (learned.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.space.screenHorizontal,
            ),
            child: Text(
              'Bạn chưa dạy từ nào cho danh mục này. Sửa danh mục của một '
              'thẻ ở màn nhập nhanh rồi bấm "Nhớ" là có.',
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          )
        else ...[
          _KeywordGroupLabel(label: 'Bạn đã dạy', count: learned.length),
          for (final keyword in learned) _KeywordTile(keyword: keyword),
        ],
        if (seeded.isNotEmpty) ...[
          SizedBox(height: context.space.xs),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.space.screenHorizontal,
            ),
            child: TextButton(
              onPressed: () => setState(() => _showSeeded = !_showSeeded),
              child: Text(
                _showSeeded
                    ? 'Ẩn ${seeded.length} từ khoá mặc định'
                    : 'Xem ${seeded.length} từ khoá mặc định',
              ),
            ),
          ),
          if (_showSeeded)
            for (final keyword in seeded) _KeywordTile(keyword: keyword),
        ],
      ],
    );
  }
}

class _KeywordGroupLabel extends StatelessWidget {
  const _KeywordGroupLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.space.screenHorizontal,
        vertical: context.space.xxs,
      ),
      child: Row(
        children: [
          Text(label, style: context.text.labelMedium),
          SizedBox(width: context.space.xs),
          Text(
            '$count',
            style: context.text.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeywordTile extends ConsumerWidget {
  const _KeywordTile({required this.keyword});

  final CategoryKeyword keyword;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      dense: true,
      title: Text(keyword.keyword),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            keyword.weight.toStringAsFixed(1),
            style: context.text.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          IconButton(
            icon: const Icon(kIconDelete, size: 20),
            tooltip: 'Quên từ này',
            onPressed: () => _forget(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _forget(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(categoryRepositoryProvider);
    final result = await repo.deleteKeyword(keyword.id);
    result.when(
      ok: (_) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Đã quên "${keyword.keyword}".'),
            action: SnackBarAction(
              label: 'Hoàn tác',
              // Học lại đúng khoá đó với trọng số CŨ — không phải 1.5 mặc
              // định, nếu không "hoàn tác" sẽ âm thầm hạ điểm một khoá đã
              // được dạy nhiều lần.
              onPressed: () => unawaited(
                repo.restoreKeyword(
                  categoryId: keyword.categoryId,
                  keyword: keyword.keyword,
                  weight: keyword.weight,
                ),
              ),
            ),
          ),
        );
      },
      err: (error) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      },
    );
  }
}
