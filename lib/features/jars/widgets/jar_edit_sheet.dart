import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../data/db/database.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/app_bottom_sheet.dart';
import '../../../data/repositories/jar_repository.dart';
import '../../../ui/color_icon_picker.dart';
import '../../savings/savings_providers.dart';
import '../../wallets/selected_wallet_provider.dart';

/// Thêm/sửa một hũ. [existing] `null` = thêm mới.
Future<void> showJarEditSheet({required BuildContext context, Jar? existing}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => _JarEditSheet(existing: existing),
  );
}

class _JarEditSheet extends ConsumerStatefulWidget {
  const _JarEditSheet({this.existing});

  final Jar? existing;

  @override
  ConsumerState<_JarEditSheet> createState() => _JarEditSheetState();
}

class _JarEditSheetState extends ConsumerState<_JarEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _percent;
  late int _colorId;
  late String _iconCode;
  late bool _carryOver;
  late JarKind _kind;

  /// Quỹ đã chọn → tỉ lệ phần của quỹ thuộc hũ (mặc định 100).
  final Map<int, int> _goalPercents = {};
  bool _loadingGoals = false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final j = widget.existing;
    _name = TextEditingController(text: j?.name ?? '');
    _percent = TextEditingController(text: j == null ? '' : '${j.percent}');
    _colorId = j?.categoryColorId ?? 0;
    _iconCode = j?.iconCode ?? 'more_horiz';
    _carryOver = j?.carryOver ?? false;
    _kind = j?.jarKind ?? JarKind.spend;
    if (j != null) _loadGoalLinks(j.id);
  }

  /// Đọc dây nối hũ ↔ quỹ bằng FUTURE, không phải `Stream.first` — stream
  /// lấy-một-giá-trị ngoài ngữ cảnh watch treo vô hạn trong widget test
  /// (bẫy đã ghi ở project_tonyfino_gotchas).
  Future<void> _loadGoalLinks(int jarId) async {
    setState(() => _loadingGoals = true);
    final links = await ref.read(jarRepositoryProvider).goalLinksOf(jarId);
    if (!mounted) return;
    setState(() {
      _goalPercents
        ..clear()
        ..addEntries([for (final l in links) MapEntry(l.goalId, l.percent)]);
      _loadingGoals = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _percent.dispose();
    super.dispose();
  }

  List<JarGoalLink> get _goalLinks => [
    for (final e in _goalPercents.entries)
      JarGoalLink(goalId: e.key, percent: e.value),
  ];

  Future<void> _save() async {
    final name = _name.text.trim();
    final percent = int.tryParse(_percent.text.trim()) ?? -1;
    if (name.isEmpty) {
      setState(() => _error = 'Nhập tên hũ');
      return;
    }
    // Hũ TIÊU 0% không bao giờ nhận đồng nào — gần như chắc chắn gõ nhầm.
    // Hũ TIẾT KIỆM thì 0% là hợp lệ và có nghĩa thật: tháng này không phân
    // bổ thu nhập cho nó, nhưng tiền gửi vào các quỹ của hũ vẫn được đếm.
    final minPercent = _kind == JarKind.saving ? 0 : 1;
    if (percent < minPercent || percent > 100) {
      setState(
        () => _error = _kind == JarKind.saving
            ? 'Tỉ lệ phải từ 0 đến 100'
            : 'Tỉ lệ phải từ 1 đến 100',
      );
      return;
    }
    // Hũ tiết kiệm không gắn quỹ thì không bao giờ đếm được đồng nào — nó
    // sẽ nằm đó báo "đã gửi 0 ₫" mãi mãi mà không ai hiểu vì sao.
    if (_kind == JarKind.saving && _goalPercents.isEmpty) {
      setState(() => _error = 'Chọn ít nhất một quỹ cho hũ tiết kiệm');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });

    final repo = ref.read(jarRepositoryProvider);
    final result = _isEditing
        ? await repo.update(
            id: widget.existing!.id,
            name: name,
            percent: percent,
            categoryColorId: _colorId,
            iconCode: _iconCode,
            carryOver: _carryOver,
            kind: _kind,
            goals: _goalLinks,
          )
        : await repo.insert(
            walletId: ref.read(selectedWalletIdProvider)!,
            name: name,
            percent: percent,
            categoryColorId: _colorId,
            iconCode: _iconCode,
            carryOver: _carryOver,
            kind: _kind,
            goals: _goalLinks,
          );

    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      ok: (_) => Navigator.of(context).pop(),
      err: (e) => setState(() => _error = e.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    // `showAppBottomSheet` CHỈ chừa phần bàn phím che — lề trái/phải/trên là
    // việc của từng sheet. Sheet này quên, nên chữ "Sửa hũ", ô "Tên hũ" và
    // hàng màu dính sát mép màn hình, phần bo góc còn cắt vào chữ: đúng chỗ
    // Tony báo "nhấn vào 1 hũ bị lỗi". Dùng ĐÚNG lề của các sheet khác
    // (`category_edit_sheet`, `wallet_edit_sheet`…) chứ không tự chế số mới.
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.space.screenHorizontal,
        vertical: context.space.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? 'Sửa hũ' : 'Thêm hũ',
            style: context.text.titleLarge,
          ),
          SizedBox(height: context.space.lg),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _name,
                    autofocus: !_isEditing,
                    decoration: InputDecoration(
                      labelText: 'Tên hũ',
                      errorText: _error,
                    ),
                  ),
                  SizedBox(height: context.space.md),
                  TextField(
                    controller: _percent,
                    keyboardType: TextInputType.number,
                    // CỐ Ý là `digitsOnly`, KHÔNG phải bộ tách nhóm nghìn:
                    // đây là PHẦN TRĂM (1–100), không phải số tiền. "100"
                    // mà thành "100" thì không sao, nhưng dùng chung
                    // formatter tiền là mời một lần sửa tương lai vô tình
                    // biến ô này thành ô tiền.
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Tỉ lệ thu nhập',
                      helperText: 'Phần trăm TỔNG THU của kỳ dồn vào hũ này',
                      suffixText: '%',
                    ),
                  ),
                  SizedBox(height: context.space.md),
                  Text('Loại hũ', style: context.text.labelMedium),
                  SizedBox(height: context.space.xs),
                  SegmentedButton<JarKind>(
                    segments: const [
                      ButtonSegment(
                        value: JarKind.spend,
                        label: Text('Hũ tiêu'),
                      ),
                      ButtonSegment(
                        value: JarKind.saving,
                        label: Text('Hũ tiết kiệm'),
                      ),
                    ],
                    selected: {_kind},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => setState(() => _kind = v.first),
                  ),
                  SizedBox(height: context.space.xs),
                  Text(
                    _kind == JarKind.spend
                        ? 'Đo tiền CHI ra từ các danh mục bạn xếp vào hũ.'
                        : 'Đo tiền GỬI VÀO một quỹ trong kỳ — mỗi lần nạp '
                              'quỹ đó tự tính vào hũ, không cần danh mục.',
                    style: context.text.labelSmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  if (_kind == JarKind.saving) ...[
                    SizedBox(height: context.space.md),
                    if (_loadingGoals)
                      const Center(child: CircularProgressIndicator())
                    else
                      _GoalPicker(
                        selected: _goalPercents,
                        onToggle: (goalId, checked) => setState(() {
                          if (checked) {
                            _goalPercents[goalId] = 100;
                          } else {
                            _goalPercents.remove(goalId);
                          }
                        }),
                        onPercent: (goalId, percent) =>
                            setState(() => _goalPercents[goalId] = percent),
                      ),
                  ] else ...[
                    SizedBox(height: context.space.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Cộng dồn sang kỳ sau'),
                      subtitle: const Text(
                        'Tiền chưa tiêu hết ở kỳ này được giữ lại — dùng cho '
                        'hũ đầu tư, giáo dục. Hũ tiêu dùng thường ngày thì tắt.',
                      ),
                      value: _carryOver,
                      onChanged: (v) => setState(() => _carryOver = v),
                    ),
                  ],
                  SizedBox(height: context.space.md),
                  Text('Màu', style: context.text.labelMedium),
                  SizedBox(height: context.space.xs),
                  ColorSwatchPicker(
                    selectedColorId: _colorId,
                    onSelected: (id) => setState(() => _colorId = id),
                  ),
                  SizedBox(height: context.space.md),
                  Text('Icon', style: context.text.labelMedium),
                  SizedBox(height: context.space.xs),
                  AppIconPicker(
                    icons: categoryIconByCode,
                    groups: categoryIconGroups,
                    selectedCode: _iconCode,
                    onSelected: (code) => setState(() => _iconCode = code),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: context.space.lg),
          Row(
            children: [
              if (_isEditing)
                TextButton(
                  // Màu cảnh báo, KHÔNG lấy màu nhấn mặc định của
                  // `TextButton` — từ khi màu nhấn là petrol, nút xoá trông
                  // y hệt mọi nút chữ vô hại khác trên cùng sheet.
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.budgetOver,
                  ),
                  onPressed: _saving
                      ? null
                      : () async {
                          final navigator = Navigator.of(context);
                          await ref
                              .read(jarRepositoryProvider)
                              .archive(widget.existing!.id);
                          navigator.pop();
                        },
                  child: const Text('Xoá hũ'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Lưu'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chọn CÁC quỹ mà hũ tiết kiệm này gom, mỗi quỹ một tỉ lệ (v15).
///
/// Vì sao nhiều quỹ + tỉ lệ: Tony có hũ gom mấy quỹ liên quan ("khám bệnh",
/// "bảo hiểm"…) và muốn "số tiền hũ bằng tổng các quỹ liên quan"; tỉ lệ để
/// một quỹ dùng chung chia được cho hai hũ mà tổng không đội lên. Mặc định
/// 100% — cứ tick là gom cả quỹ.
///
/// Chỉ mời chọn quỹ ĐANG HOẠT ĐỘNG; quỹ đã lưu trữ mà hũ đang gắn thì giữ
/// nguyên dây nối (không âm thầm gỡ), chỉ không hiện ở đây.
class _GoalPicker extends ConsumerWidget {
  const _GoalPicker({
    required this.selected,
    required this.onToggle,
    required this.onPercent,
  });

  final Map<int, int> selected;
  final void Function(int goalId, bool checked) onToggle;
  final void Function(int goalId, int percent) onPercent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals =
        ref.watch(activeSavingsGoalsProvider).value ?? const <SavingsGoal>[];
    if (goals.isEmpty) {
      return Text(
        'Chưa có quỹ nào. Tạo một quỹ ở tab "Quỹ" trước, rồi quay lại gắn '
        'vào hũ này.',
        style: context.text.bodySmall?.copyWith(
          color: context.colors.budgetWarn,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quỹ trong hũ', style: context.text.labelMedium),
        Text(
          'Tiền gửi vào các quỹ này được tính là tiền của hũ.',
          style: context.text.labelSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        for (final g in goals)
          _GoalRow(
            goal: g,
            percent: selected[g.id],
            onToggle: (checked) => onToggle(g.id, checked),
            onPercent: (p) => onPercent(g.id, p),
          ),
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.goal,
    required this.percent,
    required this.onToggle,
    required this.onPercent,
  });

  final SavingsGoal goal;

  /// `null` = quỹ chưa được chọn.
  final int? percent;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onPercent;

  @override
  Widget build(BuildContext context) {
    final checked = percent != null;
    return Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            value: checked,
            title: Text(goal.name, overflow: TextOverflow.ellipsis),
            onChanged: (v) => onToggle(v ?? false),
          ),
        ),
        // Tỉ lệ chỉ hiện khi quỹ ĐÃ chọn — một ô "%" mờ bên cạnh quỹ chưa
        // tick chỉ làm rối, và 100% là câu trả lời đúng cho gần như mọi lần.
        if (checked)
          SizedBox(
            width: 92,
            child: DropdownButtonFormField<int>(
              initialValue: percent,
              isDense: true,
              decoration: const InputDecoration(isDense: true, suffixText: '%'),
              items: [
                for (final p in const [100, 75, 50, 25, 10])
                  DropdownMenuItem(value: p, child: Text('$p')),
                if (!const [100, 75, 50, 25, 10].contains(percent))
                  DropdownMenuItem(value: percent, child: Text('$percent')),
              ],
              onChanged: (p) => onPercent(p ?? 100),
            ),
          ),
      ],
    );
  }
}
