import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_providers.dart';
import '../../core/router/app_bottom_nav.dart';
import '../../data/db/database.dart' show Tag;
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/app_card.dart';
import '../../ui/empty_state.dart';
import 'tags_providers.dart';
import 'widgets/tag_edit_sheet.dart';

/// Quản lý thẻ (Phase 17) — CRUD phẳng, không cha-con/lưu trữ (khác
/// `CategoriesScreen`). Xoá một thẻ gỡ nó khỏi mọi giao dịch đang gắn (xem
/// `TagRepository.delete`) — xác nhận trước vì không có "Khôi phục" như
/// lưu trữ danh mục/ví.
class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Thẻ')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showTagEditSheet(context: context),
        child: const Icon(kIconAdd),
      ),
      body: tagsAsync.when(
        data: (tags) {
          if (tags.isEmpty) {
            return const EmptyState(
              icon: kIconSell,
              title: 'Chưa có thẻ nào',
              message:
                  'Bấm nút "+" để tạo thẻ đầu tiên — vd "công tác", "gia đình".',
            );
          }
          // Một thẻ cho cả danh sách, dòng kẻ mảnh — cùng cách với màn
          // Danh mục (rà soát bố cục 2026-09-28).
          return ListView(
            padding: EdgeInsets.all(context.space.screenHorizontal),
            children: [
              AppCard(
                padding: EdgeInsets.symmetric(vertical: context.space.xs),
                child: Column(
                  children: [
                    for (var i = 0; i < tags.length; i++) ...[
                      _TagRow(
                        tag: tags[i],
                        onDelete: () => _confirmDelete(
                          context,
                          ref,
                          tags[i].id,
                          tags[i].name,
                        ),
                      ),
                      if (i < tags.length - 1)
                        Divider(
                          height: 1,
                          indent:
                              context.space.dividerIndent + context.space.lg,
                          endIndent: context.space.lg,
                          color: context.colors.hairline,
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: kFabClearance),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Lỗi: $error')),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int id,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Xoá thẻ "$name"?'),
        content: const Text(
          'Thẻ này sẽ được gỡ khỏi mọi giao dịch đang gắn. Không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await ref.read(tagRepositoryProvider).delete(id);
    if (!context.mounted) return;
    if (result.isErr) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.when(ok: (_) => '', err: (e) => e.message)),
        ),
      );
    }
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tag, required this.onDelete});

  final Tag tag;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: () => showTagEditSheet(
          context: context,
          existingId: tag.id,
          existingName: tag.name,
          existingColorId: tag.categoryColorId,
        ),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor:
              context.colors.categoryFills[tag.categoryColorId %
                  context.colors.categoryFills.length],
          child: const Icon(kIconSell, color: Colors.white, size: 16),
        ),
        title: Text(tag.name),
        trailing: IconButton(
          icon: const Icon(kIconDelete),
          tooltip: 'Xoá thẻ',
          onPressed: onDelete,
        ),
      ),
    );
  }
}
