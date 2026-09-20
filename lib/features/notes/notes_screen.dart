import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_providers.dart';
import '../../core/time/clock_provider.dart';
import '../../data/db/database.dart';
import '../../data/repositories/note_repository.dart';
import '../../theme/context_ext.dart';
import '../../theme/tokens/icons.dart';
import '../../ui/app_card.dart';
import '../../ui/empty_state.dart';
import '../transactions/day_label.dart';
import 'note_edit_screen.dart';
import 'notes_providers.dart';

/// Ghi chú tự do (v16) — Tony: *"tạo 1 trang note cho người dùng note tùy
/// ý"*.
///
/// Cố ý KHÔNG dính gì tới giao dịch: không chọn danh mục, không số tiền,
/// không ngày. Mỗi thứ bắt phải điền là một lý do để thôi ghi chú. Ở đây
/// chỉ có tiêu đề (tuỳ chọn), nội dung, và nút ghim.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    final notes = notesAsync.value ?? const <Note>[];
    final now = ref.watch(clockProvider).now();

    return Scaffold(
      appBar: AppBar(title: const Text('Ghi chú')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openNoteEditScreen(context),
        icon: const Icon(kIconAdd),
        label: const Text('Ghi chú mới'),
      ),
      body: notesAsync.isLoading && !notesAsync.hasValue
          ? const Center(child: CircularProgressIndicator())
          : notes.isEmpty
          ? const Center(
              child: EmptyState(
                icon: kIconEdit,
                title: 'Chưa có ghi chú nào',
                message:
                    'Chỗ để gõ bất cứ thứ gì: cần mua, cần nhớ, dự tính chi '
                    'tháng sau. Bấm "Ghi chú mới" để bắt đầu.',
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                context.space.screenHorizontal,
                context.space.md,
                context.space.screenHorizontal,
                // Chừa chỗ cho FAB có nhãn — nếu không, ghi chú cuối nằm
                // dưới nút và không bấm vào được.
                context.space.xxl * 2,
              ),
              itemCount: notes.length,
              separatorBuilder: (_, _) =>
                  SizedBox(height: context.space.betweenCards),
              itemBuilder: (context, i) => _NoteCard(note: notes[i], now: now),
            ),
    );
  }
}

class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.note, required this.now});

  final Note note;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = notePreview(note.title, note.body);
    return AppCard(
      onTap: () => openNoteEditScreen(context, existing: note),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  noteDisplayTitle(note.title, note.body),
                  style: context.text.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: note.isPinned ? 'Bỏ ghim' : 'Ghim lên đầu',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  kIconPushPin,
                  size: 20,
                  // Ghim BẬT thì icon tô đặc + màu nhấn; tắt thì nét rỗng
                  // xám — phân biệt bằng hai thứ, không chỉ màu.
                  fill: note.isPinned ? 1 : 0,
                  color: note.isPinned
                      ? context.colors.brandText
                      : context.colors.onSurfaceVariant,
                ),
                onPressed: () => ref
                    .read(noteRepositoryProvider)
                    .setPinned(id: note.id, pinned: !note.isPinned),
              ),
            ],
          ),
          if (preview.isNotEmpty) ...[
            SizedBox(height: context.space.xxs),
            Text(
              preview,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          SizedBox(height: context.space.xs),
          Text(
            formatDayLabel(note.updatedAt, now),
            style: context.text.labelSmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
