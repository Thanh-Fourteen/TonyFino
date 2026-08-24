import 'package:flutter/material.dart';

import '../core/money/money.dart';
import '../theme/tokens/curves.dart';
import '../theme/tokens/durations.dart';
import 'money_text.dart';

/// Animation #1 trong ngân sách 5 animation cứng: số đếm lên — **chỉ khi giá
/// trị đổi**, KHÔNG BAO GIỜ ở lần vẽ đầu (một hero card mới mở ra không được
/// đếm từ 0 lên; nó phải hiện đúng số ngay). 600ms `easeOutExpo`. Tabular
/// figures bắt buộc (thừa hưởng từ `MoneyText`/`AppTypography`) — thiếu là
/// chữ số giật khi đếm.
class CountUpText extends StatefulWidget {
  const CountUpText(this.amount, {super.key, this.size = MoneySize.hero});

  final Money amount;
  final MoneySize size;

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curved;
  late IntTween _tween;
  late Money _displayed;

  @override
  void initState() {
    super.initState();
    _displayed = widget.amount;
    _controller = AnimationController(
      vsync: this,
      duration: appDurations.countUp,
    );
    _curved = CurvedAnimation(parent: _controller, curve: appCurves.countUp);
    _tween = IntTween(
      begin: widget.amount.minorUnits,
      end: widget.amount.minorUnits,
    );
    _controller.addListener(_onTick);
  }

  void _onTick() {
    setState(() {
      _displayed = Money(
        minorUnits: _tween.evaluate(_curved),
        currency: widget.amount.currency,
        currencyScale: widget.amount.currencyScale,
      );
    });
  }

  @override
  void didUpdateWidget(CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount.minorUnits == widget.amount.minorUnits) return;
    _tween = IntTween(
      begin: oldWidget.amount.minorUnits,
      end: widget.amount.minorUnits,
    );
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MoneyText(_displayed, size: widget.size);
  }
}
