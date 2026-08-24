/// Parser THUẦN DART cho lịch sử tiết kiệm cũ của Rolly (Phase 19) — nhận
/// thẳng `List<dynamic>` đã `jsonDecode` sẵn từ `savings.json`/
/// `savings_with_total.json`, đúng hình dạng quan sát THẬT (không đoán), xem
/// bảng ánh xạ field ở `docs/decisions.md` § Phase 19.
///
/// Rolly không lưu "đã đóng góp bao nhiêu" trên chính bản ghi mục tiêu — số
/// đó là TỔNG các dòng `input` có `type: 'Savings'` mà `linking_savings_id`
/// trỏ về mục tiêu này (xem [mapSavingsContributionSourceIds]). Những dòng
/// đó đã được Phase 9 import thành `transactions` thường (bucket "Chuyển
/// khoản / Tiết kiệm") — Phase 19 KHÔNG tạo giao dịch mới, chỉ gắn
/// `goalId` ngược lại vào các giao dịch đã có, đúng triết lý D7 (tiến độ là
/// một SUM trên dữ liệu có sẵn, không ghi sổ song song).
class StagedRollySavingsGoal {
  const StagedRollySavingsGoal({
    required this.sourceId,
    required this.rollyGoalId,
    required this.name,
    required this.targetAmountMinor,
    required this.currency,
    required this.currencyScale,
    required this.targetDate,
    required this.isArchived,
    required this.totalContributedMinor,
  });

  final String sourceId;
  final int rollyGoalId;
  final String name;
  final int targetAmountMinor;
  final String currency;
  final int currencyScale;
  final DateTime? targetDate;

  /// Map từ `completed` của Rolly — mục tiêu đã đạt xong lúc còn ở Rolly thì
  /// vào thẳng mục "Đã lưu trữ" ở TonyFino thay vì mục đang hoạt động.
  final bool isArchived;

  /// Chỉ có khi đọc từ `savings_with_total.json` — dùng làm ORACLE đối
  /// chiếu (SUM các giao dịch vừa gắn `goalId` phải khớp số này), KHÔNG lưu
  /// vào DB (không có cột nào cho nó, tiến độ luôn tính lại từ transactions).
  final int? totalContributedMinor;
}

class RollySavingsParseResult {
  const RollySavingsParseResult({required this.goals, required this.issues});
  final List<StagedRollySavingsGoal> goals;
  final List<String> issues;
}

RollySavingsParseResult parseRollySavingsGoals(List<dynamic> rawRows) {
  final issues = <String>[];
  final goals = <StagedRollySavingsGoal>[];

  for (final entry in rawRows) {
    final row = entry as Map<String, dynamic>;
    final id = row['id'] as int;

    final currencyCode = row['currency_code'] as String?;
    if (currencyCode != 'VND') {
      issues.add(
        'Mục tiêu id=$id có currency_code "$currencyCode" khác VND — app '
        'chỉ hỗ trợ VND (xem Money.vnd), bỏ qua thay vì đoán currencyScale.',
      );
      continue;
    }

    final title = (row['title'] as String?)?.trim();
    if (title == null || title.isEmpty) {
      issues.add('Mục tiêu id=$id không có title — bỏ qua.');
      continue;
    }

    final amount = _requireNonNegativeIntAmount(
      row['achieve_amount'],
      rowId: id,
      fieldName: 'achieve_amount',
      issues: issues,
    );
    if (amount == null) continue;

    final achieveDate = row['achieve_date'] as String?;
    final totalAmountRaw = row['total_amount'];
    final totalContributedMinor = totalAmountRaw is num
        ? totalAmountRaw.round()
        : null;

    goals.add(
      StagedRollySavingsGoal(
        sourceId: 'rolly-savings:$id',
        rollyGoalId: id,
        name: title,
        targetAmountMinor: amount,
        currency: 'VND',
        currencyScale: 0,
        targetDate: achieveDate == null ? null : _parseVnLocalDate(achieveDate),
        isArchived: row['completed'] == true,
        totalContributedMinor: totalContributedMinor,
      ),
    );
  }

  return RollySavingsParseResult(goals: goals, issues: issues);
}

/// Từ các dòng thô `input.json`, tìm mọi dòng `type: 'Savings'` là "chiều ra
/// khỏi ví" (có `wallet_id` khác null — walletLeg, cùng lựa chọn Phase 9 đã
/// dùng làm `sourceId` của giao dịch) và có `linking_savings_id` trỏ tới một
/// mục tiêu — nhóm `sourceId` giao dịch (`'rolly:$id'`, khớp CHÍNH XÁC
/// `sourceId` Phase 9 đã ghi) theo id mục tiêu Rolly gốc.
Map<int, List<String>> mapSavingsContributionSourceIds(
  List<dynamic> rawInputRows,
) {
  final result = <int, List<String>>{};
  for (final entry in rawInputRows) {
    final row = entry as Map<String, dynamic>;
    if (row['type'] != 'Savings') continue;
    final linkingSavingsId = row['linking_savings_id'] as int?;
    if (linkingSavingsId == null || row['wallet_id'] == null) continue;
    final id = row['id'] as int;
    (result[linkingSavingsId] ??= []).add('rolly:$id');
  }
  return result;
}

/// Cùng bất biến "amount Rolly luôn ≥0, số nguyên" đã xác nhận cho bảng
/// `input` (Phase 9) — áp dụng lại cho `achieve_amount`, báo issue thay vì
/// làm tròn/đoán dấu khi vi phạm.
int? _requireNonNegativeIntAmount(
  Object? raw, {
  required int rowId,
  required String fieldName,
  required List<String> issues,
}) {
  if (raw is! num) {
    issues.add(
      'Mục tiêu id=$rowId có $fieldName không phải số ("$raw") — bỏ qua.',
    );
    return null;
  }
  if (raw < 0) {
    issues.add('Mục tiêu id=$rowId có $fieldName âm ($raw) — bỏ qua.');
    return null;
  }
  final rounded = raw.round();
  if ((raw - rounded).abs() > 1e-9) {
    issues.add(
      'Mục tiêu id=$rowId có $fieldName không nguyên ($raw) — bỏ qua.',
    );
    return null;
  }
  return rounded;
}

/// Giống hệt `_parseVnLocalDate` của `rolly_json_parser.dart` (Phase 9) —
/// KHÔNG dùng `DateTime.parse` để tránh mọi suy diễn múi giờ ngầm.
DateTime _parseVnLocalDate(String date) {
  final parts = date.split('-');
  if (parts.length != 3) {
    throw FormatException('Định dạng date lạ, không phải YYYY-MM-DD: "$date"');
  }
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
