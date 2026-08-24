import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_providers.dart';
import '../../data/db/database.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/category_avatar.dart';
import '../transactions/transactions_providers.dart';
import 'category_detail_screen.dart';
import 'widgets/category_edit_sheet.dart';
import '../home/widgets/wallet_switcher_sheet.dart';
import '../wallets/selected_wallet_provider.dart';
import '../wallets/wallets_providers.dart';

/// Quản lý danh mục (Phase 13) — CRUD đầy đủ + gộp + kéo-thả sắp xếp (CHỈ
/// danh mục cấp gốc, xem docs/decisions.md § Phase 13 "Danh mục con CHỈ MỘT
/// CẤP") + danh mục con hiển thị lồng dưới cha.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final walletId = ref.watch(selectedWalletIdProvider);
    final walletName = ref
        .watch(activeWalletsProvider)
        .value
        ?.where((w) => w.id == walletId)
        .firstOrNull
        ?.name;

    return Scaffold(
      // Tiêu đề nói RÕ danh mục này thuộc ví nào, và bấm vào đổi được ví.
      // Kể từ v11 mỗi ví có bộ danh mục riêng — không ghi tên ví ở đây thì
      // màn này trông như "danh mục của app", Tony sửa xong lại tưởng đã
      // sửa cho mọi ví.
      appBar: AppBar(
        title: InkWell(
          onTap: () => showWalletSwitcherSheet(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Danh mục'),
                    Text(
                      walletName == null ? 'Đang tải ví…' : 'Ví: $walletName',
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                kIconExpandMore,
                size: 20,
                color: context.colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCategoryEditSheet(context: context),
        child: const Icon(kIconAdd),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          final topLevel = categories
              .where((c) => c.parentCategoryId == null && !c.isArchived)
              .toList();
          // TÁCH THU / CHI: trộn chung rồi ghi "Chi"/"Thu" ở dòng phụ bắt
          // mắt phải đọc từng dòng mới biết cái nào là cái nào. Hai loại này
          // gần như không bao giờ dùng cùng lúc — tìm danh mục chi thì
          // không ai muốn lướt qua "Lương".
          final expenseRoots = topLevel
              .where((c) => c.kind == 'expense')
              .toList();
          final incomeRoots = topLevel
              .where((c) => c.kind != 'expense')
              .toList();
          final childrenByParent = <int, List<Category>>{};
          for (final c in categories) {
            if (c.parentCategoryId != null && !c.isArchived) {
              (childrenByParent[c.parentCategoryId!] ??= []).add(c);
            }
          }
          final archived = categories.where((c) => c.isArchived).toList();

          // `ReorderableListView` riêng CHỈ chứa danh mục cấp gốc — trộn
          // chung với phần "Đã lưu trữ" (không kéo-thả được) trong CÙNG MỘT
          // reorderable list sẽ làm lệch index `onReorder` (nó đếm theo VỊ
          // TRÍ TRONG TOÀN BỘ children, không riêng phần đang kéo được).
          // `shrinkWrap` + tắt physics riêng để nó không tự cuộn, nhường cho
          // `ListView` NGOÀI cuộn cả trang (kể cả phần archived bên dưới).
          return ListView(
            padding: EdgeInsets.all(context.space.screenHorizontal),
            children: [
              // Hai danh sách kéo-thả TÁCH BIỆT. Chỉ số `onReorder` đếm
              // theo vị trí TRONG CHÍNH danh sách đó, nên mỗi loại phải có
              // list riêng — trộn chung rồi lọc hiển thị sẽ làm lệch index
              // và kéo một mục chi có thể xếp nhầm vào giữa các mục thu.
              if (expenseRoots.isNotEmpty) ...[
                _KindHeader(label: 'Danh mục chi', count: expenseRoots.length),
                _ReorderableGroups(
                  roots: expenseRoots,
                  childrenByParent: childrenByParent,
                  allCategories: categories,
                ),
              ],
              if (incomeRoots.isNotEmpty) ...[
                SizedBox(height: context.space.lg),
                _KindHeader(label: 'Danh mục thu', count: incomeRoots.length),
                _ReorderableGroups(
                  roots: incomeRoots,
                  childrenByParent: childrenByParent,
                  allCategories: categories,
                ),
              ],
              if (archived.isNotEmpty) ...[
                SizedBox(height: context.space.lg),
                Text('Đã lưu trữ', style: context.text.titleMedium),
                SizedBox(height: context.space.sm),
                for (final category in archived)
                  ListTile(
                    leading: CategoryAvatar(
                      categoryColorId: category.categoryColorId,
                      iconCode: category.iconCode,
                      size: 32,
                      emoji: category.emoji,
                    ),
                    title: Text(
                      category.name,
                      style: TextStyle(color: context.colors.onSurfaceVariant),
                    ),
                    trailing: TextButton(
                      onPressed: () => ref
                          .read(categoryRepositoryProvider)
                          .setArchived(category.id, false),
                      child: const Text('Khôi phục'),
                    ),
                  ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Lỗi: $error')),
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    super.key,
    required this.category,
    required this.children,
    required this.allCategories,
  });

  final Category category;
  final List<Category> children;
  final List<Category> allCategories;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryTile(category: category, allCategories: allCategories),
        for (final child in children)
          Padding(
            padding: EdgeInsetsDirectional.only(start: context.space.xl),
            child: _CategoryTile(category: child, allCategories: allCategories),
          ),
      ],
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.category, required this.allCategories});

  final Category category;
  final List<Category> allCategories;

  Future<void> _showMergeDialog(BuildContext context, WidgetRef ref) async {
    final targets = allCategories
        .where((c) => c.id != category.id && !c.isArchived)
        .toList();
    final targetId = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('Gộp "${category.name}" vào danh mục nào?'),
        children: [
          for (final target in targets)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(target.id),
              child: Row(
                children: [
                  CategoryAvatar(
                    categoryColorId: target.categoryColorId,
                    iconCode: target.iconCode,
                    size: 24,
                  ),
                  SizedBox(width: context.space.sm),
                  Text(target.name),
                ],
              ),
            ),
        ],
      ),
    );
    if (targetId == null) return;
    final result = await ref
        .read(categoryRepositoryProvider)
        .mergeInto(sourceId: category.id, targetId: targetId);
    if (!context.mounted) return;
    if (result.isErr) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.when(ok: (_) => '', err: (e) => e.message)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Danh mục CẤP GỐC (Phase 25) mở màn "Chi tiết danh mục" (quản lý con +
    // breakdown + giao dịch của riêng nó, khớp mẫu hình Rolly) — sửa tên/màu/
    // icon của chính nó vẫn làm được từ trong màn đó (nút bút ở AppBar).
    // Danh mục CON giữ nguyên hành vi cũ (sửa thẳng qua sheet) — con không có
    // gì để "chi tiết" thêm (không con-của-con, Phase 13 giới hạn 1 cấp).
    return Card(
      margin: EdgeInsets.only(bottom: context.space.xs),
      child: ListTile(
        onTap: category.parentCategoryId == null
            ? () => openCategoryDetailScreen(context, category.id)
            : () => showCategoryEditSheet(
                context: context,
                existingId: category.id,
                existingName: category.name,
                existingKind: category.kind,
                existingColorId: category.categoryColorId,
                existingIconCode: category.iconCode,
                existingParentCategoryId: category.parentCategoryId,
                existingEmoji: category.emoji,
              ),
        leading: CategoryAvatar(
          categoryColorId: category.categoryColorId,
          iconCode: category.iconCode,
          emoji: category.emoji,
        ),
        title: Text(category.name),
        // KHÔNG lặp lại "Chi"/"Thu" ở từng dòng: từ khi tách hai nhóm, tiêu
        // đề nhóm đã nói điều đó rồi — in lại 27 lần chỉ làm danh sách rối
        // và đẩy chiều cao mỗi hàng lên vô ích.
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thêm danh mục CON ngay tại hàng của danh mục cha — parent đã
            // biết sẵn nên KHÔNG phải chọn lại. Trước đây chỉ có nút "+"
            // chung ở góc màn, bấm vào phải tự tìm và chọn danh mục cha
            // trong một danh sách chip; Tony báo đúng chỗ này.
            if (category.parentCategoryId == null)
              IconButton(
                icon: const Icon(kIconAddCircle),
                color: context.colors.brandText,
                tooltip: 'Thêm danh mục con cho "${category.name}"',
                onPressed: () => showCategoryEditSheet(
                  context: context,
                  existingParentCategoryId: category.id,
                ),
              ),
            PopupMenuButton<void>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: () => _showMergeDialog(context, ref),
                  child: const Text('Gộp vào danh mục khác'),
                ),
                PopupMenuItem(
                  onTap: () => ref
                      .read(categoryRepositoryProvider)
                      .setArchived(category.id, true),
                  child: const Text('Lưu trữ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiêu đề "Danh mục chi"/"Danh mục thu".
class _KindHeader extends StatelessWidget {
  const _KindHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.space.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.text.labelMedium?.copyWith(
                color: context.colors.brandText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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

/// Một danh sách kéo-thả cho MỘT loại danh mục (chi hoặc thu).
class _ReorderableGroups extends ConsumerWidget {
  const _ReorderableGroups({
    required this.roots,
    required this.childrenByParent,
    required this.allCategories,
  });

  final List<Category> roots;
  final Map<int, List<Category>> childrenByParent;
  final List<Category> allCategories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorderItem: (oldIndex, newIndex) {
        final reordered = [...roots];
        final moved = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, moved);
        ref
            .read(categoryRepositoryProvider)
            .reorderSiblings(reordered.map((c) => c.id).toList());
      },
      children: [
        for (final category in roots)
          _CategoryGroup(
            key: ValueKey(category.id),
            category: category,
            children: childrenByParent[category.id] ?? const [],
            allCategories: allCategories,
          ),
      ],
    );
  }
}
