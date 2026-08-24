/// `'debt'` (mình NỢ người khác) | `'loan'` (mình CHO người khác vay) — lưu
/// dạng TEXT trong DB (`debts.kind`), cùng quy ước TEXT-enum với
/// `categories.kind`/`recurring_transactions.frequency`.
enum DebtKind {
  debt('debt', 'Mình nợ'),
  loan('loan', 'Mình cho vay');

  const DebtKind(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static DebtKind fromDbValue(String value) => DebtKind.values.firstWhere(
    (k) => k.dbValue == value,
    orElse: () => throw ArgumentError('Loại vay không hợp lệ: $value'),
  );
}
