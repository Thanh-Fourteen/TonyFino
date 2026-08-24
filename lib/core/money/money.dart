import 'package:intl/intl.dart';

/// Ký hiệu hiển thị cho các loại tiền tệ được hỗ trợ. VND là loại duy nhất
/// dùng thật ở v1; USD giữ lại chỉ để test đa loại tiền không phá vỡ assert.
const Map<String, String> _currencySymbols = {'VND': '₫', 'USD': r'$'};

/// Giá trị tiền bất biến: `int` minor units + `currency` + `currencyScale`.
/// KHÔNG bao giờ `double`, KHÔNG `Decimal` trong DB hay trong kiểu này —
/// `Decimal` chỉ thoáng qua ở biên chuyển đổi hiển thị nếu cần.
///
/// `minorUnits` là số nguyên ký hiệu (dương = thu, âm = chi) tính theo đơn vị
/// nhỏ nhất của `currency` ở độ chính xác `currencyScale`. VND có
/// `currencyScale = 0` nên `minorUnits` chính là số đồng nguyên — đây là điều
/// khiến `Balance = SUM(amount_minor)` (D7) đúng ngay lập tức, không cần quy đổi.
class Money {
  const Money({
    required this.minorUnits,
    required this.currency,
    required this.currencyScale,
  });

  const Money.vnd(int amount)
    : minorUnits = amount,
      currency = 'VND',
      currencyScale = 0;

  final int minorUnits;
  final String currency;
  final int currencyScale;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(
      minorUnits: minorUnits + other.minorUnits,
      currency: currency,
      currencyScale: currencyScale,
    );
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(
      minorUnits: minorUnits - other.minorUnits,
      currency: currency,
      currencyScale: currencyScale,
    );
  }

  Money operator -() => Money(
    minorUnits: -minorUnits,
    currency: currency,
    currencyScale: currencyScale,
  );

  bool operator <(Money other) {
    _assertSameCurrency(other);
    return minorUnits < other.minorUnits;
  }

  bool operator <=(Money other) {
    _assertSameCurrency(other);
    return minorUnits <= other.minorUnits;
  }

  bool operator >(Money other) {
    _assertSameCurrency(other);
    return minorUnits > other.minorUnits;
  }

  bool operator >=(Money other) {
    _assertSameCurrency(other);
    return minorUnits >= other.minorUnits;
  }

  bool get isNegative => minorUnits < 0;
  bool get isPositive => minorUnits > 0;
  bool get isZero => minorUnits == 0;

  Money get abs => isNegative ? -this : this;

  /// Giá trị theo đơn vị lớn (vd. đồng, không phải xu) — chỉ dùng để hiển thị,
  /// không bao giờ để tính toán hay lưu trữ (mất chính xác với double).
  double get majorUnits => minorUnits / _scaleFactor;

  int get _scaleFactor {
    var factor = 1;
    for (var i = 0; i < currencyScale; i++) {
      factor *= 10;
    }
    return factor;
  }

  void _assertSameCurrency(Money other) {
    if (currency != other.currency || currencyScale != other.currencyScale) {
      throw CurrencyMismatchError(
        aCurrency: currency,
        bCurrency: other.currency,
      );
    }
  }

  /// `35.000 ₫` cho VND ở `vi_VN` — dấu `.` phân cách nghìn, không thập phân.
  String format({String locale = 'vi_VN'}) {
    final symbol = _currencySymbols[currency] ?? currency;
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: currencyScale,
    );
    return formatter.format(majorUnits);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency &&
      other.currencyScale == currencyScale;

  @override
  int get hashCode => Object.hash(minorUnits, currency, currencyScale);

  @override
  String toString() => format();
}

/// Ném khi cộng/trừ/so sánh hai [Money] khác loại tiền hoặc khác thang đo —
/// đây là lỗi lập trình (trộn tiền tệ), không phải lỗi người dùng, nên là
/// [Error] chứ không phải [Exception] có thể bắt và bỏ qua.
class CurrencyMismatchError extends Error {
  CurrencyMismatchError({required this.aCurrency, required this.bCurrency});

  final String aCurrency;
  final String bCurrency;

  @override
  String toString() =>
      'CurrencyMismatchError: không thể cộng/trừ $aCurrency với $bCurrency';
}
