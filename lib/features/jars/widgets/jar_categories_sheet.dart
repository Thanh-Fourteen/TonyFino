import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../data/db/database.dart';
import '../../../theme/context_ext.dart';
import '../../../ui/category_avatar.dart';
import '../../transactions/transactions_providers.dart';

/// Chọn danh mục nào thuộc hũ này.
///
/// Một danh mục thuộc TỐI ĐA MỘT hũ (xem `Categories.jarId`) — nên tick một
/// danh mục đang nằm ở hũ khác sẽ CHUYỂN nó sang đây, và bảng này nói rõ
/// điều đó thay vì im lặng đổi.
Future<void> showJarCategoriesSheet(BuildContext context, Jar jar) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _JarCategoriesSheet(jar: jar),
  );
}

class _JarCategoriesSheet extends ConsumerWidget {
  const _JarCategoriesSheet({required this.jar});

  final Jar jar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    // Chỉ danh mục CẤP GỐC: danh mục con thừa hưởng hũ của cha qua chính
    // danh mục cha (chi của con được gộp lên cha ở mọi báo cáo), nên cho
    // xếp riêng danh mục con sẽ tạo ra hai đường đi khác nhau cho cùng một
    // khoản tiền.
    final roots = categories
        .where((c) => c.parentCategoryId == null && !c.isArchived)
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
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
                  'khỏi hũ cũ.',
                  style: context.text.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          for (final c in roots)
            CheckboxListTile(
              value: c.jarId == jar.id,
              secondary: CategoryAvatar(
                categoryColorId: c.categoryColorId,
                iconCode: c.iconCode,
                size: 36,
              ),
              title: Text(c.name),
              subtitle: c.jarId != null && c.jarId != jar.id
                  ? Text(
                      'Đang ở hũ khác',
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.budgetWarn,
                      ),
                    )
                  : null,
              onChanged: (checked) => ref
                  .read(jarRepositoryProvider)
                  .setCategoryJar(
                    categoryId: c.id,
                    jarId: (checked ?? false) ? jar.id : null,
                  ),
            ),
          SizedBox(height: context.space.xl),
        ],
      ),
    );
  }
}
