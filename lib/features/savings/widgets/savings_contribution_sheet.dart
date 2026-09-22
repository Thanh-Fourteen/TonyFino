import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/time/clock_provider.dart';
import '../../../data/db/database.dart';
import '../../../theme/context_ext.dart';
import '../../../theme/tokens/icons.dart';
import '../../../ui/amount_visibility.dart';
import '../../../ui/app_bottom_sheet.dart';
import '../../../ui/app_chip.dart';
import '../../../ui/grouped_number_field.dart';
import '../../../ui/wallet_avatar.dart';
import '../../transactions/day_label.dart';
import '../../wallets/wallets_providers.dart';

/// Chiều tiền của một lần động vào quỹ. Tên theo cách Tony nói, không phải
/// theo dấu của `amountMinor`: "nạp"/"rút", chứ không phải "chi"/"thu".
enum SavingsMove {
  /// Ví trừ tiền, quỹ tăng — một dòng CHI gắn `goalId`.
  deposit,

  /// Ví cộng tiền, quỹ giảm — một dòng THU gắn cùng `goalId`.
  withdraw;

  String get title => switch (this) {
    SavingsMove.deposit => 'Nạp vào quỹ',
    SavingsMove.withdraw => 'Rút từ quỹ',
  };

  String get action => switch (this) {
    SavingsMove.deposit => 'Nạp',
    SavingsMove.withdraw => 'Rút',
  };

  String get amountLabel => switch (this) {
    SavingsMove.deposit => 'Nạp bao nhiêu',
    SavingsMove.withdraw => 'Rút bao nhiêu',
  };

  String get walletLabel => switch (this) {
    SavingsMove.deposit => 'Trừ từ ví',
    SavingsMove.withdraw => 'Trả về ví',
  };
}

Future<void> showSavingsContributionSheet({
  required BuildContext context,
  required int goalId,
  required String goalName,
  required SavingsMove move,
  int? savedMinor,
  int? targetAmountMinor,
  int? prefillMinor,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => SavingsContributionSheet(
      goalId: goalId,
      goalName: goalName,
      move: move,
      savedMinor: savedMinor,
      targetAmountMinor: targetAmountMinor,
      prefillMinor: prefillMinor,
    ),
  );
}

/// Nạp tiền vào / rút tiền ra khỏi MỘT quỹ — sheet riêng, KHÔNG phải form
/// "Thêm giao dịch" điền sẵn.
///
/// 🚨 Vì sao tách khỏi `TransactionFormSheet` thay vì thêm một prefill nữa.
///
/// Trước bản này, nút "+" trên thẻ quỹ mở thẳng form ghi khoản đầy đủ. Tony
/// nói đúng vấn đề: *"thêm bớt tiền vào đó cũng khó, đó không liên quan danh
/// mục"*. Đo trên máy thật thì cái form đó hỏi Tony sáu thứ, trong đó **năm
/// thứ vô nghĩa với một lần nạp quỹ**: nút gạt Chi/Thu (nạp tiền để dành bị
/// gọi là "Chi"), **lưới 11 danh mục chiếm nửa màn hình**, "Tách giao dịch",
/// Thẻ, Ảnh hoá đơn. Còn thứ duy nhất thật sự cần biết — nạp từ ví nào — thì
/// lại ẩn đi khi sổ mới có một ví.
///
/// Lưới danh mục không chỉ thừa, nó là cái BẪY: chọn đại một danh mục vào một
/// khoản để dành là vừa thổi phồng chi tiêu của danh mục đó trong báo cáo vừa
/// làm khoản đó trông như đã tiêu mất. Bỏ hẳn lưới đi thì không ai chọn nhầm
/// được nữa — chữa tận gốc chứ không phải thêm một dòng cảnh báo.
///
/// Dữ liệu ghi ra vẫn y hệt hình dạng cũ (một giao dịch mang `goalId`, KHÔNG
/// có `categoryId`), nên tiến độ quỹ, "Còn lại" ở Trang chủ và báo cáo Chi/Thu
/// không cần biết gì về sheet này. Đây thuần tuý là một lối vào hẹp hơn cho
/// đúng một việc.
class SavingsContributionSheet extends ConsumerStatefulWidget {
  const SavingsContributionSheet({
    super.key,
    required this.goalId,
    required this.goalName,
    required this.move,
    this.savedMinor,
    this.targetAmountMinor,
    this.prefillMinor,
  });

  final int goalId;
  final String goalName;
  final SavingsMove move;

  /// Tiến độ hiện tại, CHỈ để hiện dòng ngữ cảnh ("Đang có … / còn thiếu …").
  /// `null` thì bỏ dòng đó — sheet vẫn nạp/rút được bình thường.
  final int? savedMinor;
  final int? targetAmountMinor;

  /// Số tiền điền sẵn (số DƯƠNG) — vd hũ tiết kiệm mở sheet này với đúng
  /// phần còn thiếu của kỳ. Chỉ là gợi ý, Tony sửa được trước khi lưu.
  final int? prefillMinor;

  @override
  ConsumerState<SavingsContributionSheet> createState() =>
      _SavingsContributionSheetState();
}

class _SavingsContributionSheetState
    extends ConsumerState<SavingsContributionSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  int? _selectedWalletId;
  late DateTime _date;
  bool _saving = false;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _date = ref.read(clockProvider).now();
    final prefill = widget.prefillMinor;
    if (prefill != null && prefill > 0) {
      _amountController.text = groupDigits('$prefill');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = ref.read(clockProvider).now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null) return;
    setState(
      () => _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      ),
    );
  }

  Future<void> _save() async {
    final digits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(digits);
    if (parsed == null || parsed == 0) {
      setState(() => _amountError = 'Nhập số tiền hợp lệ');
      return;
    }
    setState(() {
      _amountError = null;
      _saving = true;
    });

    // Cùng quy ước dấu với `SavingsGoalProgress.savedMinor`
    // (`-SUM(amountMinor)`): nạp là dòng ÂM, rút là dòng DƯƠNG.
    final amount = Money.vnd(
      widget.move == SavingsMove.deposit ? -parsed : parsed,
    );
    final note = _noteController.text.trim();
    // Chưa chạm bộ chọn ví (chỉ hiện khi >1 ví) → ví mặc định, cùng cách
    // `TransactionFormSheet._save()` làm.
    final walletId =
        _selectedWalletId ??
        await ref.read(walletRepositoryProvider).defaultWalletId();

    final result = await ref
        .read(transactionRepositoryProvider)
        .insert(
          amount: amount,
          occurredAt: _date,
          walletId: walletId,
          // KHÔNG có danh mục — một khoản để dành không thuộc danh mục chi
          // tiêu nào (xem doc của lớp này).
          categoryId: null,
          note: note.isEmpty ? null : note,
          goalId: widget.goalId,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    result.when(
      ok: (_) => Navigator.of(context).pop(),
      err: (error) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Không ${widget.move.action.toLowerCase()} được'),
          content: Text(error.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }

  /// "Đang có 5.000.000 đ / 50.000.000 đ · còn thiếu 45.000.000 đ" — trả lời
  /// ngay câu hỏi duy nhất người ta hỏi khi đứng trước ô nhập số tiền: nạp
  /// bao nhiêu thì đủ.
  String? _progressLine() {
    final saved = widget.savedMinor;
    final target = widget.targetAmountMinor;
    if (saved == null || target == null) return null;
    final buffer = StringBuffer(
      'Đang có ${Money.vnd(saved).format()} / ${Money.vnd(target).format()}',
    );
    final remaining = target - saved;
    if (remaining > 0) {
      buffer.write(' · còn thiếu ${Money.vnd(remaining).format()}');
    } else {
      buffer.write(' · đã đủ');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(activeWalletsProvider);
    final wallets = walletsAsync.value ?? const <Wallet>[];
    final now = ref.watch(clockProvider).now();
    final progressLine = _progressLine();

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
            '${widget.move.title} ${widget.goalName}',
            style: context.text.titleLarge,
          ),
          if (progressLine != null) ...[
            SizedBox(height: context.space.xs),
            Text(
              AmountVisibility.mask(context, progressLine),
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
          SizedBox(height: context.space.lg),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [ThousandsSeparatorInputFormatter()],
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: widget.move.amountLabel,
                      suffixText: '₫',
                      errorText: _amountError,
                    ),
                  ),
                  // Bộ chọn ví chỉ hiện khi có >1 ví — cùng quy tắc với form
                  // ghi khoản (docs/decisions.md § Phase 13): một ví duy nhất
                  // thì chọn ngầm, thêm một hàng UI vô nghĩa làm gì.
                  if (wallets.length > 1) ...[
                    SizedBox(height: context.space.md),
                    Text(
                      widget.move.walletLabel,
                      style: context.text.labelMedium,
                    ),
                    SizedBox(height: context.space.xs),
                    Wrap(
                      spacing: context.space.xs,
                      runSpacing: context.space.xs,
                      children: [
                        for (final wallet in wallets)
                          AppChip(
                            label: wallet.name,
                            editable: false,
                            selected:
                                wallet.id ==
                                (_selectedWalletId ?? wallets.first.id),
                            icon: WalletAvatar(
                              categoryColorId: wallet.categoryColorId,
                              iconCode: wallet.iconCode,
                              size: 18,
                            ),
                            onTap: () =>
                                setState(() => _selectedWalletId = wallet.id),
                          ),
                      ],
                    ),
                  ],
                  SizedBox(height: context.space.md),
                  Row(
                    children: [
                      // 🚨 `Expanded`, KHÔNG phải `Text` + `Spacer`: nhãn
                      // ngày dài nhất là "Ngày: Hôm nay · Thứ Bảy" và trên
                      // bề ngang máy thật (393dp) nó cộng với nút "Đổi
                      // ngày" đã tràn 84px — sheet kêu overflow ngay lần mở
                      // đầu tiên. Cỡ chữ hệ thống lớn còn tràn nữa.
                      Expanded(
                        child: Text(
                          'Ngày: ${formatDayLabel(_date, now)}',
                          style: context.text.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: _pickDate,
                        child: const Text('Đổi ngày'),
                      ),
                    ],
                  ),
                  SizedBox(height: context.space.md),
                  TextField(
                    controller: _noteController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú (tuỳ chọn)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: context.space.lg),
          Row(
            children: [
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        widget.move == SavingsMove.deposit
                            ? kIconAddCircle
                            : kIconUndo,
                      ),
                label: Text(widget.move.action),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
