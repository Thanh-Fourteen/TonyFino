import '../../../core/text/ascii_fold.dart';

/// Kết quả trích xuất từ văn bản OCR thô của một hoá đơn — CHỈ gợi ý, không
/// bao giờ dùng thẳng để ghi giao dịch (Luật #7, xem `TransactionFormPrefill.
/// fromReceiptScan`). Cả hai trường đều `null` được — call site tự quyết
/// định fallback (form vẫn mở, chỉ trống hơn, Tony tự gõ tay).
class ReceiptOcrExtraction {
  const ReceiptOcrExtraction({this.merchantName, this.amountMinor});

  final String? merchantName;

  /// VND nguyên (currencyScale 0) — số tiền LỚN NHẤT tìm được trên dòng có
  /// nhãn "tổng" (ưu tiên), hoặc số lớn nhất toàn hoá đơn nếu không dòng nào
  /// khớp nhãn (kém tin cậy hơn, xem [_findTotalAmount]).
  final int? amountMinor;
}

/// Nhãn "tổng tiền" tiếng Việt + tiếng Anh thường gặp trên hoá đơn siêu thị/
/// quán ăn thật — so khớp trên bản KHÔNG DẤU (qua [foldToAscii], cùng cách
/// `note_ascii`/`category_matcher` đã dùng từ Phase 4/7) vì OCR đôi khi làm
/// mất/sai dấu ở đúng những chữ quan trọng nhất.
const _totalLabels = [
  'tong cong',
  'tong tien',
  'tong thanh toan',
  'tong so tien',
  // "Tổng số" — nhãn Emart dùng. Bắt được nhờ chụp hoá đơn THẬT của Tony
  // (Emart Sala Thủ Thiêm 23/08/2026); danh sách nhãn cũ nghĩ ra trong đầu
  // không có nó, nên hoá đơn rơi thẳng xuống nhánh dự phòng.
  'tong so',
  'thanh tien',
  'can thanh toan',
  'total',
  'grand total',
];

/// Khớp số kiểu Việt Nam có dấu phân cách nghìn (`125.000`, `1,250,000`) HOẶC
/// một chuỗi 4–9 chữ số liền không phân cách (`125000`) — hoá đơn in cả hai
/// kiểu tuỳ máy in/phần mềm POS.
///
/// 🚨 Chặn trên 9 chữ số là CỐ Ý, không phải con số tuỳ tiện: mã vạch EAN-13
/// (13 chữ số), mã số thuế (10), mã hoá đơn, số điện thoại đều dài hơn thế.
/// Không chặn thì trên hoá đơn siêu thị thật — nơi mỗi dòng hàng in kèm mã
/// vạch — số "lớn nhất" LUÔN là một mã vạch. Hoá đơn Emart của Tony trả về
/// 8.936.136.116.143đ trước khi có chặn này.
///
/// Mất gì: một khoản ≥ 1 tỉ đồng in KHÔNG có dấu phân cách sẽ bị bỏ qua. Đổi
/// lại là không bao giờ đề nghị một mã vạch làm số tiền — đánh đổi đúng
/// chiều cho một app chi tiêu cá nhân.
final _numberPattern = RegExp(r'\d{1,3}(?:[.,]\d{3})+|(?<!\d)\d{4,9}(?!\d)');

/// Trích merchant + tổng tiền từ văn bản thô do `ReceiptOcrService` trả về.
/// Hàm THUẦN DART — không Flutter/DB/platform channel — cùng kỷ luật tách
/// biệt engine (ML Kit, ở `data/services/`) khỏi luật trích xuất (ở đây) như
/// `category_matcher.dart` (Phase 7) đã tách khỏi bất kỳ nguồn từ khoá nào.
ReceiptOcrExtraction extractReceiptInfo(String ocrText) {
  final lines = ocrText
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) return const ReceiptOcrExtraction();

  // Dòng đầu tiên KHÔNG rỗng của hoá đơn — gần như luôn là tên cửa hàng/quán
  // (in đậm/to nhất, ở trên cùng). Không cố "thông minh" hơn (lọc theo độ
  // dài, số chữ cái...) — một gợi ý sai vẫn sửa được ngay trong form, đúng
  // tinh thần Luật #7 (chỉ điền sẵn, không quyết định thay).
  return ReceiptOcrExtraction(
    merchantName: lines.first,
    amountMinor: _findTotalAmount(lines),
  );
}

/// Ưu tiên số tiền trên dòng có NHÃN "tổng" (đáng tin hơn — vị trí cố định,
/// không lẫn với đơn giá/số lượng từng món) — LẤY DÒNG KHỚP NHÃN CUỐI CÙNG
/// nếu có nhiều (vd hoá đơn có "Tổng tiền hàng" rồi mới tới "Tổng thanh
/// toán" thật ở cuối, sau khi cộng phí/giảm giá). Không có dòng nào khớp
/// nhãn → lùi về số LỚN NHẤT toàn hoá đơn (tổng luôn ≥ mọi dòng thành phần)
/// — kém tin cậy hơn, chấp nhận được vì kết quả chỉ là điền sẵn, Tony luôn
/// xác nhận lại số tiền.
///
/// Nhánh dự phòng CHỈ xét số có DẤU PHÂN CÁCH NGHÌN. Trên hoá đơn siêu thị,
/// mỗi dòng hàng in kèm mã vạch dài, còn giá tiền thì luôn có dấu phân cách
/// — đòi dấu phân cách là cách rẻ nhất để tách "số tiền" khỏi "mã". Nhánh
/// khớp NHÃN thì không đòi, vì ở đó vị trí đã đủ tin cậy.
int? _findTotalAmount(List<String> lines) {
  int? lastLabelMatch;
  int? largestAny;

  for (final line in lines) {
    final matches = _numberPattern.allMatches(line).toList();
    if (matches.isEmpty) continue;

    final all = matches.map((m) => _parseVndNumber(m.group(0)!)).toList();
    final grouped = [
      for (final m in matches)
        if (m.group(0)!.contains(RegExp(r'[.,]'))) _parseVndNumber(m.group(0)!),
    ];

    if (grouped.isNotEmpty) {
      final groupedMax = grouped.reduce((a, b) => a > b ? a : b);
      if (largestAny == null || groupedMax > largestAny) {
        largestAny = groupedMax;
      }
    }

    final folded = foldToAscii(line);
    if (_totalLabels.any(folded.contains)) {
      lastLabelMatch = all.reduce((a, b) => a > b ? a : b);
    }
  }

  return lastLabelMatch ?? largestAny;
}

int _parseVndNumber(String raw) =>
    int.parse(raw.replaceAll(RegExp(r'[.,]'), ''));
