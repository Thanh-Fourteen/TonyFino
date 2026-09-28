import 'dart:math' as math;

/// Một dòng chữ OCR cùng BỐN GÓC thật của nó trên ảnh (toạ độ pixel, theo
/// chiều kim đồng hồ từ góc trên-trái — đúng thứ tự `TextLine.cornerPoints`
/// của ML Kit). Bản thuần Dart để luật ghép hàng test được trên host.
///
/// Bốn góc chứ không phải khung chữ nhật: với ảnh nghiêng, khung chữ nhật
/// của một dòng dài cao gấp mấy lần chữ (nó bao cả đoạn dốc), còn hai góc
/// trên cho ra độ dốc của dòng với DẤU chắc chắn đúng — không phải đoán quy
/// ước chiều của trường `angle`.
class OcrLineBox {
  const OcrLineBox({
    required this.text,
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  /// Dòng thẳng, không nghiêng — cho test và cho nền tảng không có góc.
  factory OcrLineBox.axisAligned({
    required String text,
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) => OcrLineBox(
    text: text,
    topLeft: math.Point(left, top),
    topRight: math.Point(right, top),
    bottomRight: math.Point(right, bottom),
    bottomLeft: math.Point(left, bottom),
  );

  final String text;
  final math.Point<double> topLeft;
  final math.Point<double> topRight;
  final math.Point<double> bottomRight;
  final math.Point<double> bottomLeft;

  double get centerX =>
      (topLeft.x + topRight.x + bottomRight.x + bottomLeft.x) / 4;
  double get centerY =>
      (topLeft.y + topRight.y + bottomRight.y + bottomLeft.y) / 4;

  /// Chiều cao CHỮ (cạnh trái/phải của tứ giác), không phải khung bao.
  double get height =>
      (topLeft.distanceTo(bottomLeft) + topRight.distanceTo(bottomRight)) / 2;

  /// Độ dốc dy/dx của cạnh trên (trục y hướng xuống) — `null` nếu dòng quá
  /// hẹp để đo đáng tin.
  double? get slope {
    final dx = topRight.x - topLeft.x;
    if (dx < height * 2) return null;
    return (topRight.y - topLeft.y) / dx;
  }
}

/// Ghép các dòng OCR thành HÀNG như mắt người đọc hoá đơn — trái sang phải
/// trên cùng một độ cao — rồi trả văn bản mỗi hàng một dòng.
///
/// 🚨 Vì sao không dùng thẳng `RecognizedText.text` của ML Kit: nó nối chữ
/// theo KHỐI (block), mà trên hoá đơn cột nhãn và cột số thường là hai khối
/// tách rời. "Tổng số" và "414,000" khi đó rơi vào hai chỗ xa nhau trong văn
/// bản — bộ trích xuất đọc "dòng có nhãn tổng" sẽ thấy dòng đó KHÔNG có số.
///
/// 🚨 Nắn nghiêng trước khi ghép: ảnh nghiêng vài độ là số ở mép phải lệch
/// hẳn một hàng so với nhãn ở mép trái. Đo trên ảnh dựng hoá đơn Emart
/// nghiêng 6° qua ML Kit thật: "Tổng số" bị ghép với 383,334 (dòng thuế bên
/// dưới) thay vì 414,000. Máy quét tài liệu đã nắn sẵn, nhưng đường dự phòng
/// (camera thường) và ảnh chụp màn hình thì không.
///
/// Cách nắn: lấy TRUNG VỊ độ dốc các dòng đủ dài (một vài dòng đọc lệch
/// không kéo được trung vị), rồi đo độ cao mỗi dòng dọc theo hướng vuông góc
/// với chiều nghiêng đó — tức là chiếu tâm dòng về mép trái: `y − x·dốc`.
///
/// Luật ghép: hai dòng cùng hàng khi độ cao đã nắn chênh nhau không quá nửa
/// chiều cao chữ nhỏ hơn.
String arrangeIntoRows(List<OcrLineBox> lines) {
  final kept = [
    for (final line in lines)
      if (line.text.trim().isNotEmpty) line,
  ];
  final pageSlope = _medianSlope(kept);

  final positioned = [
    for (final line in kept)
      (line: line, rowY: line.centerY - line.centerX * pageSlope),
  ]..sort((a, b) => a.rowY.compareTo(b.rowY));

  final rows = <List<({OcrLineBox line, double rowY})>>[];
  for (final item in positioned) {
    final row = rows.isEmpty ? null : rows.last;
    if (row != null && _sameRow(row.first, item)) {
      row.add(item);
    } else {
      rows.add([item]);
    }
  }

  return rows
      .map((row) {
        row.sort((a, b) => a.line.centerX.compareTo(b.line.centerX));
        return row.map((i) => i.line.text.trim()).join('  ');
      })
      .join('\n');
}

double _medianSlope(List<OcrLineBox> lines) {
  final slopes = [
    for (final line in lines)
      if (line.slope case final s?) s,
  ]..sort();
  if (slopes.isEmpty) return 0;
  return slopes[slopes.length ~/ 2];
}

/// So với dòng ĐẦU hàng (không phải dòng mới nhất) để một hàng không "trôi"
/// dần xuống dưới qua một chuỗi dòng mỗi dòng lệch một chút.
bool _sameRow(
  ({OcrLineBox line, double rowY}) anchor,
  ({OcrLineBox line, double rowY}) item,
) {
  final tolerance = math.min(anchor.line.height, item.line.height) / 2;
  return (item.rowY - anchor.rowY).abs() <= tolerance;
}
