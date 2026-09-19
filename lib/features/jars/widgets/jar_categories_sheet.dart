import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../data/db/database.dart';
import '../../../theme/context_ext.dart';
import '../../../ui/category_avatar.dart';
import '../../transactions/transactions_providers.dart';
import '../domain/jar_membership.dart';
import '../jars_providers.dart';

/// Chọn danh mục nào thuộc hũ này — HAI CẤP, danh mục con xếp riêng được.
///
/// Một danh mục thuộc TỐI ĐA MỘT hũ (xem `Categories.jarId`) — nên tick một
/// danh mục đang nằm ở hũ khác sẽ CHUYỂN nó sang đây, và bảng này nói rõ
/// điều đó thay vì im lặng đổi.
///
/// Trước bản này bảng chỉ liệt kê danh mục CẤP GỐC, nên cả họ "Ăn uống" buộc
/// phải chung một hũ. Sổ thật của Tony không như vậy: "Ăn trưa thiết yếu"
/// là Thiết yếu, "Giao lưu"/"Ăn chung oxytocin" là Hưởng thụ. Luật thừa
/// hưởng nằm ở `jar_membership.dart`.
Future<void> showJarCategoriesSheet(BuildContext context, Jar jar) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (_) => _JarCategoriesSheet(jar: jar),
  );
}

class _JarCategoriesSheet extends ConsumerWidget {
  const _JarCategoriesSheet({required this.jar});

  final Jar jar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = (ref.watch(categoriesProvider).value ?? const [])
        // Chỉ danh mục CHI: hũ đo tiền ra, một danh mục thu ("Lương") trong
        // hũ không bao giờ cộng được đồng nào — chỉ làm nhiễu danh sách.
        .where((c) => !c.isArchived && c.kind == 'expense')
        .toList();
    final jarNames = {
      for (final j in ref.watch(jarsProvider).value ?? const <Jar>[])
        j.id: j.name,
    };
    final roots = categories.where((c) => c.parentCategoryId == null);
    final childrenOf = <int, List<Category>>{};
    for (final c in categories) {
      final parentId = c.parentCategoryId;
      if (parentId != null) (childrenOf[parentId] ??= []).add(c);
    }

    Future<void> toggle(Category c, Category? parent, bool checked) {
      return ref
          .read(jarRepositoryProvider)
          .setCategoryJar(
            categoryId: c.id,
            jarId: jarIdAfterToggle(
              jarId: jar.id,
              checked: checked,
              ownJarId: c.jarId,
              parentJarId: parent?.jarId,
            ),
          );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (context, controller) => ListView(
        controller: controller,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.space.screenHorizontal,
              0,
              context.space.screenHorizontal,
              context.space.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Danh mục trong hũ "${jar.name}"',
                  style: context.text.titleMedium,
                ),
                SizedBox(height: context.space.xxs),
                Text(
                  'Mỗi danh mục chỉ thuộc một hũ — chọn ở đây sẽ chuyển nó '
                  'khỏi hũ cũ. Danh mục con chưa chọn riêng thì theo hũ của '
                  'danh mục cha.',
                  style: context.text.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          for (final root in roots) ...[
            _CategoryTile(
              category: root,
              membership: jarMembership(
                jarId: jar.id,
                ownJarId: root.jarId,
                parentJarId: null,
              ),
              otherJarName: jarNames[root.jarId],
              parentName: null,
              indent: false,
              onChanged: (v) => toggle(root, null, v),
            ),
            for (final child in childrenOf[root.id] ?? const <Category>[])
              _CategoryTile(
                category: child,
                membership: jarMembership(
                  jarId: jar.id,
                  ownJarId: child.jarId,
                  parentJarId: root.jarId,
                ),
                otherJarName:
                    jarNames[effectiveJarId(
                      ownJarId: child.jarId,
                      parentJarId: root.jarId,
                    )],
                parentName: root.name,
                indent: true,
                onChanged: (v) => toggle(child, root, v),
              ),
          ],
          SizedBox(height: context.space.xl),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.membership,
    required this.otherJarName,
    required this.parentName,
    required this.indent,
    required this.onChanged,
  });

  final Category category;
  final JarMembership membership;

  /// Tên hũ hiệu lực — chỉ dùng khi [membership] là `elsewhere`.
  final String? otherJarName;
  final String? parentName;
  final bool indent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final inherited = membership == JarMembership.inherited;
    final subtitle = switch (membership) {
      JarMembership.inherited =>
        'Theo "$parentName" — muốn tách, chọn nó ở hũ khác',
      JarMembership.elsewhere =>
        otherJarName == null ? 'Đang ở hũ khác' : 'Đang ở hũ "$otherJarName"',
      _ => null,
    };
    return CheckboxListTile(
      contentPadding: EdgeInsetsDirectional.only(
        start: context.space.screenHorizontal + (indent ? 36 : 0),
        end: context.space.screenHorizontal,
      ),
      value:
          membership == JarMembership.direct ||
          membership == JarMembership.inherited,
      // Con đang theo cha thì bỏ tick không có nghĩa gì (gỡ dòng riêng ra
      // thì nó VẪN theo cha vào đúng hũ này) — khoá lại và nói cách tách
      // thật, thay vì để một ô tick bấm mà không đổi gì.
      onChanged: inherited ? null : (v) => onChanged(v ?? false),
      secondary: CategoryAvatar(
        categoryColorId: category.categoryColorId,
        iconCode: category.iconCode,
        emoji: category.emoji,
        size: indent ? 30 : 36,
      ),
      title: Text(
        category.name,
        style: indent ? context.text.bodyMedium : context.text.bodyLarge,
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: context.text.labelSmall?.copyWith(
                color: membership == JarMembership.elsewhere
                    ? context.colors.budgetWarn
                    : context.colors.onSurfaceVariant,
              ),
            ),
    );
  }
}
