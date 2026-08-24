import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/clock_provider.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/icons.dart';
import '../home_period_provider.dart';

/// Chip chọn kỳ — dùng CHUNG ở Trang chủ và màn Hũ.
///
/// Cùng một `homePeriodProvider`: đổi kỳ ở đâu thì cả hai màn đổi theo. Hai
/// bộ chọn kỳ độc lập cho hai màn nói về cùng một khoảng thời gian là cách
/// chắc chắn nhất để ra hai con số rồi không biết tin cái nào.
class PeriodChip extends ConsumerWidget {
  const PeriodChip({super.key, required this.period});

  final HomePeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        avatar: const Icon(kIconCalendarToday, size: 18),
        label: Text(period.label),
        onPressed: () async {
          final notifier = ref.read(homePeriodProvider.notifier);
          final picked = await showModalBottomSheet<HomePeriodPreset>(
            context: context,
            showDragHandle: true,
            builder: (sheetContext) => SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in HomePeriodPreset.values)
                      ListTile(
                        title: Text(p.label),
                        trailing: p == period.preset
                            ? Icon(kIconCheck, color: context.colors.brandText)
                            : null,
                        onTap: () => Navigator.of(sheetContext).pop(p),
                      ),
                  ],
                ),
              ),
            ),
          );
          if (picked == null) return;
          if (picked != HomePeriodPreset.custom) {
            notifier.setPreset(picked);
            return;
          }
          if (!context.mounted) return;
          final now = ref.read(clockProvider).now();
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: DateTime(now.year + 1, 12, 31),
            helpText: 'Chọn khoảng thời gian',
            saveText: 'Xong',
          );
          if (range == null) return;
          notifier.setCustomRange(range.start, range.end);
        },
      ),
    );
  }
}
