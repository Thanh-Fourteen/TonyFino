import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/app_bottom_sheet.dart';
import '../../../ui/app_chip.dart';
import '../../tags/tags_providers.dart';
import '../../transactions/transactions_providers.dart';
import '../domain/report_range.dart';
import '../reports_providers.dart';
import 'report_category_color.dart';
import '../../../core/time/clock_provider.dart';

/// **Bottom-sheet-first** (đặc tả design system): cả khoảng ngày lẫn danh
/// mục đều chọn qua sheet, KHÔNG phải `showDateRangePicker`/dialog Material.
/// Khoảng ngày dùng preset (7/30 ngày, 3/6 tháng, tất cả) thay vì lịch hai
/// đầu tự do — đủ cho một màn báo cáo cá nhân, và tránh dựng một calendar
/// picker tuỳ biến chỉ để dùng một lần.
class ReportFilterBar extends ConsumerWidget {
  const ReportFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportFilterProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categoryCount = filter.categoryIds?.length;
    final tagsAsync = ref.watch(tagsProvider);
    final tagCount = filter.tagIds?.length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: context.space.screenHorizontal),
      child: Row(
        children: [
          AppChip(
            // Với khoảng tuỳ chọn, nhãn phải là CHÍNH hai ngày đó — hiện
            // chữ "Khoảng tuỳ chọn…" thì người dùng không còn cách nào biết
            // mình đang xem đoạn nào mà không mở lại bảng chọn.
            label: filter.preset == ReportRangePreset.custom
                ? _formatRange(filter.range)
                : filter.preset.label,
            icon: const Icon(kIconCalendarToday),
            onTap: () => _openRangeSheet(context),
          ),
          SizedBox(width: context.space.sm),
          AppChip(
            label: categoryCount == null
                ? 'Mọi danh mục'
                : '$categoryCount danh mục',
            icon: const Icon(kIconTune),
            selected: categoryCount != null,
            onTap: () =>
                _openCategorySheet(context, categoriesAsync.value ?? const []),
          ),
          if ((tagsAsync.value ?? const []).isNotEmpty) ...[
            SizedBox(width: context.space.sm),
            AppChip(
              label: tagCount == null ? 'Mọi thẻ' : '$tagCount thẻ',
              icon: const Icon(kIconSell),
              selected: tagCount != null,
              onTap: () => _openTagSheet(context, tagsAsync.value ?? const []),
            ),
          ],
        ],
      ),
    );
  }

  void _openRangeSheet(BuildContext context) {
    showAppBottomSheet<void>(
      context: context,
      builder: (sheetContext) => const _RangeSheet(),
    );
  }

  void _openCategorySheet(BuildContext context, List<Category> categories) {
    showAppBottomSheet<void>(
      context: context,
      builder: (sheetContext) => _CategorySheet(categories: categories),
    );
  }

  void _openTagSheet(BuildContext context, List<Tag> tags) {
    showAppBottomSheet<void>(
      context: context,
      builder: (sheetContext) => _TagSheet(tags: tags),
    );
  }
}

/// Sheet đọc `ref` CỦA CHÍNH NÓ (`ConsumerWidget`), không nhận `WidgetRef`
/// truyền từ `ReportFilterBar` — sheet sống trong cây `Navigator` gốc
/// (`showAppBottomSheet` → `rootNavigator: true`), một `ref` "mượn" từ widget
/// cha có thể dính vào `Element` đã bị huỷ nếu `ReportFilterBar` unmount
/// trong lúc sheet còn mở.
class _RangeSheet extends ConsumerWidget {
  const _RangeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(reportFilterProvider).preset;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.space.lg,
          context.space.md,
          context.space.lg,
          context.space.lg,
        ),
        // CUỘN ĐƯỢC: danh sách preset đã lên 9 mục (thêm hôm nay/tháng
        // này/năm nay/tuỳ chọn) và tràn đáy bottom sheet trên máy màn thấp —
        // bắt được bằng widget test ("RenderFlex overflowed by 18 pixels").
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Khoảng ngày', style: context.text.titleLarge),
              SizedBox(height: context.space.md),
              for (final preset in ReportRangePreset.values)
                _RangeOption(
                  preset: preset,
                  selected: preset == current,
                  onTap: () async {
                    final notifier = ref.read(reportFilterProvider.notifier);
                    final navigator = Navigator.of(context);
                    if (preset != ReportRangePreset.custom) {
                      notifier.setPreset(preset);
                      navigator.pop();
                      return;
                    }
                    // Đóng bảng chọn TRƯỚC khi mở lịch: hai lớp modal chồng
                    // nhau thì bấm huỷ ở lịch lại lộ ra bảng cũ, trông như
                    // thao tác không ăn.
                    navigator.pop();
                    final now = ref.read(clockProvider).now();
                    // Dùng context của NAVIGATOR, không phải context của mục
                    // vừa bị pop — widget đó đã tháo khỏi cây, tra ancestor
                    // trên nó là hành vi không xác định (Flutter cảnh báo
                    // "Looking up a deactivated widget's ancestor is unsafe").
                    final picked = await showDateRangePicker(
                      context: navigator.context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(now.year + 1, 12, 31),
                      helpText: 'Chọn khoảng thời gian',
                      saveText: 'Xong',
                    );
                    if (picked == null) return;
                    notifier.setCustomRange(picked.start, picked.end);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangeOption extends StatelessWidget {
  const _RangeOption({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final ReportRangePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(preset.label, style: context.text.bodyLarge),
      trailing: selected
          ? Icon(kIconCheck, color: context.colors.brandText)
          : null,
      onTap: onTap,
    );
  }
}

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({required this.categories});

  final List<Category> categories;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...?ref.read(reportFilterProvider).categoryIds};
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.space.lg,
          context.space.md,
          context.space.lg,
          context.space.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Danh mục', style: context.text.titleLarge),
                ),
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: const Text('Bỏ chọn hết'),
                ),
              ],
            ),
            SizedBox(height: context.space.sm),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: context.space.sm,
                  runSpacing: context.space.sm,
                  children: [
                    for (final category in widget.categories)
                      AppChip(
                        label: category.name,
                        selected: _selected.contains(category.id),
                        editable: false,
                        icon: CircleAvatar(
                          radius: 8,
                          backgroundColor: reportCategoryColor(
                            context,
                            category.categoryColorId,
                          ),
                        ),
                        onTap: () => setState(() {
                          if (!_selected.add(category.id)) {
                            _selected.remove(category.id);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: context.space.md),
            FilledButton(
              onPressed: () {
                ref
                    .read(reportFilterProvider.notifier)
                    .setCategoryIds(_selected);
                Navigator.of(context).pop();
              },
              child: const Text('Áp dụng'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet lọc theo thẻ (Phase 17) — cùng khuôn `_CategorySheet` ở trên,
/// KHÔNG dùng lại chính nó vì kiểu phần tử khác (`Tag` không phải
/// `Category`) và không có khái niệm màu-qua-`reportCategoryColor` (thẻ
/// dùng thẳng `categoryFills`, không có sentinel "chưa phân loại").
class _TagSheet extends ConsumerStatefulWidget {
  const _TagSheet({required this.tags});

  final List<Tag> tags;

  @override
  ConsumerState<_TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends ConsumerState<_TagSheet> {
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...?ref.read(reportFilterProvider).tagIds};
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.space.lg,
          context.space.md,
          context.space.lg,
          context.space.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Thẻ', style: context.text.titleLarge)),
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: const Text('Bỏ chọn hết'),
                ),
              ],
            ),
            SizedBox(height: context.space.sm),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: context.space.sm,
                  runSpacing: context.space.sm,
                  children: [
                    for (final tag in widget.tags)
                      AppChip(
                        label: tag.name,
                        selected: _selected.contains(tag.id),
                        editable: false,
                        icon: CircleAvatar(
                          radius: 8,
                          backgroundColor:
                              context.colors.categoryFills[tag.categoryColorId %
                                  context.colors.categoryFills.length],
                        ),
                        onTap: () => setState(() {
                          if (!_selected.add(tag.id)) {
                            _selected.remove(tag.id);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: context.space.md),
            FilledButton(
              onPressed: () {
                ref.read(reportFilterProvider.notifier).setTagIds(_selected);
                Navigator.of(context).pop();
              },
              child: const Text('Áp dụng'),
            ),
          ],
        ),
      ),
    );
  }
}

/// "1/8 – 31/8/2026". `end` trong domain là NỬA KHOẢNG (đã +1 ngày) nên
/// hiện ra phải trừ lại một ngày, nếu không nhãn lệch một ngày so với đúng
/// khoảng Tony đã chọn.
String _formatRange(ReportRange range) {
  final last = range.end.subtract(const Duration(days: 1));
  final sameYear = range.start.year == last.year;
  final start = sameYear
      ? '${range.start.day}/${range.start.month}'
      : '${range.start.day}/${range.start.month}/${range.start.year}';
  return '$start – ${last.day}/${last.month}/${last.year}';
}
