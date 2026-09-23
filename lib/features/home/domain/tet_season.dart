/// "Áo Tết cho giao diện" — nghiên cứu 2026-09-23 mục 29
/// (`docs/competitor-feature-research.md` § Bổ sung).
///
/// 🚨 Ngày Tết Nguyên Đán tính theo âm lịch, KHÔNG suy ra được bằng công thức
/// — bảng dưới đây tra TỪNG NĂM từ nguồn ngoài (qppstudio.net, đối chiếu
/// nhiều nguồn 2026-09-23), không đoán/không nội suy. Năm KHÔNG có trong
/// bảng thì [isTetSeason] trả `false` — thà im lặng không đổi giao diện còn
/// hơn đoán sai ngày Tết của một năm chưa tra.
const Map<int, (int month, int day)> _tetDates = {
  2025: (1, 29),
  2026: (2, 17),
  2027: (2, 6),
  2028: (1, 26),
  2029: (2, 13),
  2030: (2, 2),
  2031: (1, 23),
};

/// `now` trong khoảng [-3, +4] ngày quanh mồng Một Tết của ĐÚNG năm dương
/// lịch chứa `now` — "~1 tuần quanh Tết" (nghiên cứu), gồm vài ngày cận Tết
/// (Tất niên) và những ngày đầu năm mới. Không có bảng cho năm đó → `false`.
bool isTetSeason(DateTime now) {
  final tet = _tetDates[now.year];
  if (tet == null) return false;
  final tetDate = DateTime(now.year, tet.$1, tet.$2);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(tetDate).inDays;
  return diff >= -3 && diff <= 4;
}
