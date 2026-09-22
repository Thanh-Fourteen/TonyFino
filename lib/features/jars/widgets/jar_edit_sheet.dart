import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../data/db/database.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/app_bottom_sheet.dart';
import '../../../data/repositories/jar_repository.dart';
import '../../../ui/category_avatar.dart';
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

/// Sheet tạo/sửa hũ.
///
/// 🎨 Bố cục làm lại 2026-09-22 theo lệnh Tony ("thiết kế lại layout tạo hũ,
/// sửa hũ đẹp hơn"). Bản cũ là một cột phẳng bảy khối xếp liền nhau — tên,
/// tỉ lệ, loại, chiều, quỹ, màu, icon — không nhóm, không tiêu đề, và mỗi
/// lựa chọn kéo theo một đoạn chữ giải thích dài bằng chính nó, nên cuộn
/// tới cuối là quên mất đang tạo hũ tên gì, màu gì.
///
/// Ba thay đổi, mỗi cái chữa một thứ cụ thể:
///
/// 1. **Thẻ XEM TRƯỚC dính trên đầu** — avatar đúng màu/icon đang chọn, tên
///    hũ, và một dòng phụ đọc ra đúng cấu hình ("10% · Hũ tiết kiệm · nạp
///    vào 2 quỹ"). Màu và icon nằm tận cuối sheet, cách ô tên cả màn hình;
///    không có chỗ nào cho thấy chúng ghép lại trông thế nào cho tới khi đã
///    bấm Lưu.
/// 2. **Chia thành mục có tiêu đề** (Nhận diện · Cách hũ hoạt động · Chia
///    bao nhiêu · Quỹ/Cộng dồn · Màu & icon), mỗi mục cách nhau bằng khoảng
///    trắng thật chứ không phải một dòng chữ xám.
/// 3. **Lỗi hiện ở một băng riêng ngay trên nút Lưu**, không còn treo vào
///    `errorText` của ô Tên: lỗi "Tỉ lệ phải từ 1 đến 100" hiện dưới ô tên
///    là chỉ sai chỗ duy nhất Tony nhìn.
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
  late JarGoalFlow _flow;

  /// Quỹ đã chọn → tỉ lệ phần của quỹ thuộc hũ (mặc định 100).
  final Map<int, int> _goalPercents = {};

  /// Quỹ → các hũ KHÁC đang theo dõi nó, kèm chiều. Để bảng chọn quỹ nói
  /// được "quỹ này đã nằm ở hũ nào rồi" ngay lúc tick.
  Map<int, List<JarGoalRole>> _goalRoles = const {};
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
    _flow = j?.flow ?? JarGoalFlow.deposit;
    // Thẻ xem trước phải đổi theo từng phím gõ — không có listener thì tên
    // trong thẻ đứng im cho tới khi chạm vào một control khác.
    _name.addListener(_onPreviewInputChanged);
    _percent.addListener(_onPreviewInputChanged);
    _loadGoalRoles();
    if (j != null) _loadGoalLinks(j.id);
  }

  Future<void> _loadGoalRoles() async {
    final walletId = ref.read(selectedWalletIdProvider);
    if (walletId == null) return;
    final roles = await ref.read(jarRepositoryProvider).goalJarRoles(walletId);
    if (!mounted) return;
    setState(() => _goalRoles = roles);
  }

  void _onPreviewInputChanged() {
    if (mounted) setState(() {});
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
    _name.removeListener(_onPreviewInputChanged);
    _percent.removeListener(_onPreviewInputChanged);
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
            flow: _flow,
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
            flow: _flow,
            goals: _goalLinks,
          );

    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      ok: (_) => Navigator.of(context).pop(),
      err: (e) => setState(() => _error = e.message),
    );
  }

  /// Dòng phụ của thẻ xem trước — đọc ra đúng cấu hình đang soạn, bằng
  /// chính những chữ mà thẻ hũ ngoài màn Hũ sẽ dùng.
  String get _previewSubtitle {
    final percent = int.tryParse(_percent.text.trim());
    final percentLabel = percent == null
        ? 'chưa đặt tỉ lệ'
        : percent == 0
        ? 'không lấy % thu nhập'
        : '$percent% thu nhập';
    if (_kind == JarKind.spend) {
      return '$percentLabel · Hũ tiêu'
          '${_carryOver ? ' · cộng dồn' : ''}';
    }
    final flowLabel = _flow == JarGoalFlow.deposit
        ? 'nạp vào quỹ'
        : 'tiêu từ quỹ';
    final n = _goalPercents.length;
    return '$percentLabel · Hũ tiết kiệm · '
        '${n == 0 ? 'chưa chọn quỹ' : '$flowLabel ($n quỹ)'}';
  }

  @override
  Widget build(BuildContext context) {
    // `showAppBottomSheet` CHỈ chừa phần bàn phím che — lề trái/phải/trên là
    // việc của từng sheet. Dùng ĐÚNG lề của các sheet khác
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
          _PreviewHeader(
            title: _isEditing ? 'Sửa hũ' : 'Thêm hũ',
            name: _name.text.trim().isEmpty ? 'Hũ chưa đặt tên' : _name.text,
            unnamed: _name.text.trim().isEmpty,
            subtitle: _previewSubtitle,
            colorId: _colorId,
            iconCode: _iconCode,
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
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Tên hũ',
                      hintText: 'Thiết yếu, Hưởng thụ, Khám bệnh…',
                    ),
                  ),

                  _SectionTitle(
                    'Cách hũ hoạt động',
                    hint: _kind == JarKind.spend
                        ? 'Đo tiền CHI ra từ các danh mục bạn xếp vào hũ.'
                        : 'Gắn hũ với một hoặc nhiều quỹ — mỗi lần nạp/rút '
                              'quỹ đó tự tính vào hũ, không cần danh mục.',
                  ),
                  SegmentedButton<JarKind>(
                    segments: const [
                      ButtonSegment(
                        value: JarKind.spend,
                        icon: Icon(kIconCategory, size: 18),
                        label: Text('Hũ tiêu'),
                      ),
                      ButtonSegment(
                        value: JarKind.saving,
                        icon: Icon(kIconSavings, size: 18),
                        label: Text('Hũ tiết kiệm'),
                      ),
                    ],
                    selected: {_kind},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => setState(() => _kind = v.first),
                  ),
                  if (_kind == JarKind.saving) ...[
                    SizedBox(height: context.space.md),
                    SegmentedButton<JarGoalFlow>(
                      segments: const [
                        ButtonSegment(
                          value: JarGoalFlow.deposit,
                          label: Text('Nạp vào quỹ'),
                        ),
                        ButtonSegment(
                          value: JarGoalFlow.spend,
                          label: Text('Tiêu từ quỹ'),
                        ),
                      ],
                      selected: {_flow},
                      showSelectedIcon: false,
                      onSelectionChanged: (v) =>
                          setState(() => _flow = v.first),
                    ),
                    SizedBox(height: context.space.xs),
                    _Hint(
                      _flow == JarGoalFlow.deposit
                          ? 'Chỉ đếm tiền NẠP VÀO quỹ trong kỳ. Tiền rút ra '
                                'không đụng tới hũ này — cùng một quỹ có thể '
                                'nằm ở cả hũ chiều ngược lại. Tỉ lệ dưới đây '
                                'là mức nên nạp mỗi kỳ.'
                          : 'Chỉ đếm tiền RÚT TỪ quỹ trong kỳ. Tiền nạp vào '
                                'không đụng tới hũ này. Tỉ lệ > 0 là TRẦN '
                                'được rút mỗi kỳ; để 0 nếu không đặt trần.',
                    ),
                  ],

                  _SectionTitle(
                    'Chia bao nhiêu thu nhập',
                    hint: _kind == JarKind.saving
                        ? 'Phần trăm TỔNG THU của kỳ. Để 0 nếu hũ này không '
                              'lấy phần nào của thu nhập.'
                        : 'Phần trăm TỔNG THU của kỳ dồn vào hũ này.',
                  ),
                  TextField(
                    controller: _percent,
                    keyboardType: TextInputType.number,
                    // CỐ Ý là `digitsOnly`, KHÔNG phải bộ tách nhóm nghìn:
                    // đây là PHẦN TRĂM (1–100), không phải số tiền. Dùng
                    // chung formatter tiền là mời một lần sửa tương lai vô
                    // tình biến ô này thành ô tiền.
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Tỉ lệ thu nhập',
                      suffixText: '%',
                    ),
                  ),
                  SizedBox(height: context.space.sm),
                  // Phím tắt cho những tỉ lệ THẬT SỰ hay dùng — đúng bộ 6 hũ
                  // kinh điển (55/10/10/10/10/5) cộng mốc 0 của hũ quỹ. Gõ
                  // tay vẫn được; đây chỉ là đường tắt.
                  _PercentChips(
                    current: int.tryParse(_percent.text.trim()),
                    allowZero: _kind == JarKind.saving,
                    onPick: (p) => setState(() {
                      _percent.text = '$p';
                      _percent.selection = TextSelection.collapsed(
                        offset: _percent.text.length,
                      );
                    }),
                  ),

                  if (_kind == JarKind.saving) ...[
                    _SectionTitle(
                      'Quỹ trong hũ',
                      hint: _flow == JarGoalFlow.deposit
                          ? 'Hũ này chỉ đếm tiền NẠP VÀO các quỹ dưới đây. '
                                'Tiền rút ra là việc của hũ chiều ngược lại.'
                          : 'Hũ này chỉ đếm tiền RÚT TỪ các quỹ dưới đây. '
                                'Tiền nạp vào là việc của hũ chiều ngược lại.',
                    ),
                    if (_loadingGoals)
                      const Center(child: CircularProgressIndicator())
                    else
                      _GoalPicker(
                        selected: _goalPercents,
                        roles: _goalRoles,
                        currentJarId: widget.existing?.id,
                        flow: _flow,
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
                    _SectionTitle('Cuối kỳ thì sao'),
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

                  _SectionTitle('Màu & icon'),
                  ColorSwatchPicker(
                    selectedColorId: _colorId,
                    onSelected: (id) => setState(() => _colorId = id),
                  ),
                  SizedBox(height: context.space.sm),
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
          // Lỗi đứng NGAY TRÊN nút Lưu — chỗ mắt đang nhìn khi vừa bấm Lưu
          // và không có gì xảy ra. Trước đây nó là `errorText` của ô Tên,
          // nên "Tỉ lệ phải từ 1 đến 100" hiện dưới ô tên.
          if (_error case final error?) ...[
            SizedBox(height: context.space.md),
            _ErrorBanner(message: error),
          ],
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

/// Đầu sheet: tiêu đề + thẻ XEM TRƯỚC hũ đang soạn.
///
/// Thẻ này cố ý dựng bằng chính `CategoryAvatar` mà thẻ hũ ngoài màn Hũ
/// dùng — xem trước bằng một widget KHÁC là cách chắc chắn để "xem trước"
/// và "thật" trôi khỏi nhau.
class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({
    required this.title,
    required this.name,
    required this.unnamed,
    required this.subtitle,
    required this.colorId,
    required this.iconCode,
  });

  final String title;
  final String name;
  final bool unnamed;
  final String subtitle;
  final int colorId;
  final String iconCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.text.titleLarge),
        SizedBox(height: context.space.md),
        Container(
          padding: EdgeInsets.all(context.space.sm),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainer,
            borderRadius: BorderRadius.circular(context.radii.lg),
          ),
          child: Row(
            children: [
              CategoryAvatar(
                categoryColorId: colorId,
                iconCode: iconCode,
                size: 44,
              ),
              SizedBox(width: context.space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: context.text.bodyLarge?.copyWith(
                        color: unnamed
                            ? context.colors.onSurfaceVariant
                            : null,
                        fontStyle: unnamed ? FontStyle.italic : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: context.space.xxs),
                    Text(
                      subtitle,
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tiêu đề một mục trong sheet + (tuỳ chọn) một dòng giải thích.
///
/// Tự chừa khoảng cách phía TRÊN: mỗi mục tự biết mình bắt đầu ở đâu, chỗ
/// gọi không phải rải `SizedBox` thủ công giữa từng khối — đúng lớp lỗi
/// "thẻ ẩn vẫn chừa khoảng trắng" đã sửa ở Trang chủ.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label, {this.hint});

  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: context.text.labelSmall?.copyWith(
              color: context.colors.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          if (hint case final hint?) ...[
            SizedBox(height: context.space.xxs),
            _Hint(hint),
          ],
          SizedBox(height: context.space.sm),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.text.labelSmall?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.space.sm),
      decoration: BoxDecoration(
        color: context.colors.budgetOver.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(context.radii.md),
      ),
      child: Row(
        children: [
          Icon(
            kIconWarning,
            size: 18,
            color: context.colors.budgetOver,
          ),
          SizedBox(width: context.space.xs),
          Expanded(
            child: Text(
              message,
              style: context.text.labelMedium?.copyWith(
                color: context.colors.budgetOver,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Phím tắt tỉ lệ — bộ 6 hũ kinh điển dùng đúng những con số này.
class _PercentChips extends StatelessWidget {
  const _PercentChips({
    required this.current,
    required this.allowZero,
    required this.onPick,
  });

  final int? current;
  final bool allowZero;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final values = [if (allowZero) 0, 5, 10, 15, 20, 55];
    return Wrap(
      spacing: context.space.xs,
      runSpacing: context.space.xs,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(v == 0 ? 'Không lấy %' : '$v%'),
            selected: current == v,
            onSelected: (_) => onPick(v),
          ),
      ],
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
    required this.roles,
    required this.currentJarId,
    required this.flow,
    required this.onToggle,
    required this.onPercent,
  });

  final Map<int, int> selected;

  /// Quỹ → các hũ đang theo dõi nó (gồm cả hũ đang sửa).
  final Map<int, List<JarGoalRole>> roles;
  final int? currentJarId;
  final JarGoalFlow flow;
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
        for (final g in goals)
          _GoalRow(
            goal: g,
            percent: selected[g.id],
            others: [
              for (final r in roles[g.id] ?? const <JarGoalRole>[])
                if (r.jarId != currentJarId) r,
            ],
            flow: flow,
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
    required this.others,
    required this.flow,
    required this.onToggle,
    required this.onPercent,
  });

  final SavingsGoal goal;

  /// `null` = quỹ chưa được chọn.
  final int? percent;

  /// Các hũ KHÁC đang theo dõi quỹ này.
  final List<JarGoalRole> others;

  /// Chiều của hũ đang soạn — để biết hũ khác là bổ sung hay trùng vai.
  final JarGoalFlow flow;

  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onPercent;

  @override
  Widget build(BuildContext context) {
    final checked = percent != null;
    // Trùng CHIỀU với một hũ khác = dòng tiền của quỹ bị đếm hai lần.
    // Ngược chiều thì hoàn toàn bình thường, thậm chí là cách dùng đúng
    // ("Tiết kiệm" lo nạp, "Phát sinh" lo rút trên cùng một quỹ).
    final clash = others.where((r) => r.flow == flow).toList();
    final complement = others.where((r) => r.flow != flow).toList();
    return Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            value: checked,
            title: Text(goal.name, overflow: TextOverflow.ellipsis),
            subtitle: others.isEmpty
                ? null
                : Text(
                    clash.isNotEmpty
                        ? '⚠ Đã nằm ở hũ "${clash.first.jarName}" CÙNG chiều '
                              '— tiền sẽ bị đếm hai lần'
                        : 'Cũng ở hũ "${complement.first.jarName}" '
                              '(${complement.first.flowLabel} quỹ) — bình thường',
                    style: context.text.labelSmall?.copyWith(
                      color: clash.isNotEmpty
                          ? context.colors.budgetOver
                          : context.colors.onSurfaceVariant,
                    ),
                  ),
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
