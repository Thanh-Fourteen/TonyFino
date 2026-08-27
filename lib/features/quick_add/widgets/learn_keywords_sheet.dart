import 'package:flutter/material.dart';

import '../../../theme/context_ext.dart';
import '../../../ui/app_chip.dart';
import '../domain/category_keyword_entries.dart';

/// Sheet "Nhớ từ nào" — mở từ nút *Chọn từ* trên snackbar sau khi người dùng
/// sửa danh mục của một thẻ ở màn chat.
///
/// Trả về danh sách từ đã chọn (`null` nếu đóng mà không xác nhận). Mỗi từ
/// được lưu thành MỘT từ khoá độc lập chứ không phải một cụm phải khớp trọn
/// — xem `CategoryRepository.learnKeywords` cho lý do.
Future<List<String>?> showLearnKeywordsSheet({
  required BuildContext context,
  required String leftoverText,
  required String categoryLabel,
  required List<String> initiallySelected,
}) {
  final candidates = keywordCandidates(leftoverText);
  if (candidates.isEmpty) return Future.value(null);
  return showModalBottomSheet<List<String>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _LearnKeywordsSheet(
      candidates: candidates,
      categoryLabel: categoryLabel,
      initiallySelected: initiallySelected,
      leftoverText: leftoverText,
    ),
  );
}

class _LearnKeywordsSheet extends StatefulWidget {
  const _LearnKeywordsSheet({
    required this.candidates,
    required this.categoryLabel,
    required this.initiallySelected,
    required this.leftoverText,
  });

  final String leftoverText;

  final List<({String word, bool suggested})> candidates;
  final String categoryLabel;
  final List<String> initiallySelected;

  @override
  State<_LearnKeywordsSheet> createState() => _LearnKeywordsSheetState();
}

class _LearnKeywordsSheetState extends State<_LearnKeywordsSheet> {
  late final Set<String> _selected = {...widget.initiallySelected};

  /// Nói đúng thứ SẼ được lưu, không nói chung chung — người dùng phải thấy
  /// trước rằng bỏ một từ ở giữa sẽ cắt cụm làm đôi.
  String _describeSelection() {
    final phrases = groupIntoPhrases(widget.leftoverText, _selected);
    if (phrases.isEmpty) return 'Chọn ít nhất một từ để nhớ.';
    if (phrases.length == 1) return 'Sẽ nhớ: "${phrases.single}".';
    return 'Sẽ nhớ ${phrases.length} từ khoá riêng: '
        '"${phrases.join('", "')}" — có đủ thì chắc nhất, có một cái vẫn tính.';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: context.space.screenHorizontal,
          right: context.space.screenHorizontal,
          top: context.space.lg,
          bottom: context.space.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhớ từ nào?', style: context.text.titleLarge),
            SizedBox(height: context.space.xs),
            Text(
              'Lần sau gõ những từ này sẽ tự vào "${widget.categoryLabel}".',
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: context.space.lg),
            Wrap(
              spacing: context.space.xs,
              runSpacing: context.space.xs,
              children: [
                for (final candidate in widget.candidates)
                  AppChip(
                    label: candidate.word,
                    editable: false,
                    selected: _selected.contains(candidate.word),
                    onTap: () => setState(() {
                      if (!_selected.remove(candidate.word)) {
                        _selected.add(candidate.word);
                      }
                    }),
                  ),
              ],
            ),
            SizedBox(height: context.space.md),
            // Nói rõ ý nghĩa của việc chọn nhiều từ — nếu không, người dùng
            // dễ tưởng phải gõ lại ĐÚNG cả cụm mới ăn.
            Text(
              _describeSelection(),
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: context.space.lg),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Bỏ qua'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(
                          // Trả về CỤM liên tiếp, không phải từ rời.
                          groupIntoPhrases(widget.leftoverText, _selected),
                        ),
                  child: const Text('Nhớ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
