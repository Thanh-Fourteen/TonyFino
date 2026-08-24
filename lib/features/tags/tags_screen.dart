import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_providers.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
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
          return ListView(
            padding: EdgeInsets.all(context.space.screenHorizontal),
            children: [
              for (final tag in tags)
                Card(
                  margin: EdgeInsets.only(bottom: context.space.xs),
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
                      child: const Icon(
                        kIconSell,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    title: Text(tag.name),
                    trailing: IconButton(
                      icon: const Icon(kIconDelete),
                      onPressed: () =>
                          _confirmDelete(context, ref, tag.id, tag.name),
                    ),
                  ),
                ),
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
