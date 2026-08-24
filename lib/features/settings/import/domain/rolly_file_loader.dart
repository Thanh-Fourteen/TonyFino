import 'dart:convert';

/// Đọc file Rolly Tony chọn — hai hình dạng được chấp nhận:
/// - **mảng trần** `[{...input row...}, ...]` — đúng hình dạng
///   `raw_rolly/input.json` kéo thẳng từ Supabase (Phase 2). Tên danh mục sẽ
///   hiện dưới dạng "Danh mục #{id}" (vẫn ánh xạ được, chỉ kém đẹp).
/// - **object gộp** `{"input": [...], "category_view": [...]}` — Tony gộp
///   thêm `category_view.json` để có tên danh mục thật trong màn ánh xạ.
///   Đây KHÔNG phải hình dạng Supabase phát ra, mà là quy ước riêng của
///   TonyFino (viết trong hint UI) để một lần chọn file là đủ cho cả hai
///   bảng — tránh phải build một luồng "chọn 2 file" phức tạp hơn cho một
///   việc dùng đúng một lần.
class RollyImportFile {
  const RollyImportFile({
    required this.inputRows,
    required this.categoryTitleById,
  });

  final List<dynamic> inputRows;
  final Map<int, String> categoryTitleById;
}

class RollyFileFormatException implements Exception {
  RollyFileFormatException(this.message);
  final String message;

  @override
  String toString() => 'RollyFileFormatException: $message';
}

RollyImportFile decodeRollyImportFile(List<int> bytes) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } catch (e) {
    throw RollyFileFormatException(
      'File không đọc được — không phải JSON hợp lệ ($e).',
    );
  }

  if (decoded is List) {
    return RollyImportFile(inputRows: decoded, categoryTitleById: const {});
  }

  if (decoded is Map<String, dynamic>) {
    final input = decoded['input'];
    if (input is! List) {
      throw RollyFileFormatException(
        'File JSON dạng object nhưng thiếu mảng "input" (bảng giao dịch Rolly).',
      );
    }
    final categoryTitleById = <int, String>{};
    final categoryView = decoded['category_view'];
    if (categoryView is List) {
      for (final entry in categoryView) {
        final row = entry as Map<String, dynamic>;
        categoryTitleById[row['id'] as int] = row['title'] as String;
      }
    }
    return RollyImportFile(
      inputRows: input,
      categoryTitleById: categoryTitleById,
    );
  }

  throw RollyFileFormatException(
    'File JSON không đúng hình dạng mong đợi — phải là mảng giao dịch, hoặc '
    'object {"input": [...], "category_view": [...]}.',
  );
}

/// Hình dạng file cho import tiết kiệm cũ (Phase 19) — tiếp nối đúng quy ước
/// "gộp nhiều bảng vào một file" đã có ở [decodeRollyImportFile]:
/// `{"savings": [...], "input": [...]}`. Bắt buộc CẢ HAI khoá (khác
/// [decodeRollyImportFile] không có fallback mảng trần) vì việc gắn
/// `goalId` ngược vào giao dịch cũ cần `input` để tìm đúng `sourceId` —
/// thiếu một trong hai thì không đối chiếu được, không import mù mờ.
class RollySavingsImportFile {
  const RollySavingsImportFile({
    required this.savingsRows,
    required this.inputRows,
  });

  final List<dynamic> savingsRows;
  final List<dynamic> inputRows;
}

RollySavingsImportFile decodeRollySavingsImportFile(List<int> bytes) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } catch (e) {
    throw RollyFileFormatException(
      'File không đọc được — không phải JSON hợp lệ ($e).',
    );
  }

  if (decoded is! Map<String, dynamic>) {
    throw RollyFileFormatException(
      'File JSON phải là object {"savings": [...], "input": [...]}.',
    );
  }
  final savings = decoded['savings'];
  final input = decoded['input'];
  if (savings is! List || input is! List) {
    throw RollyFileFormatException(
      'File JSON thiếu mảng "savings" hoặc "input" — cần cả hai để đối '
      'chiếu giao dịch tiết kiệm đã import (Phase 9) với mục tiêu (Phase 19).',
    );
  }
  return RollySavingsImportFile(savingsRows: savings, inputRows: input);
}

/// Hình dạng file cho khôi phục danh mục phụ (sau Phase 20, xem
/// docs/decisions.md) — cùng quy ước gộp bảng: `{"subcategory": [...],
/// "input": [...]}`.
class RollySubcategoryImportFile {
  const RollySubcategoryImportFile({
    required this.subcategoryRows,
    required this.inputRows,
  });

  final List<dynamic> subcategoryRows;
  final List<dynamic> inputRows;
}

RollySubcategoryImportFile decodeRollySubcategoryImportFile(List<int> bytes) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } catch (e) {
    throw RollyFileFormatException(
      'File không đọc được — không phải JSON hợp lệ ($e).',
    );
  }

  if (decoded is! Map<String, dynamic>) {
    throw RollyFileFormatException(
      'File JSON phải là object {"subcategory": [...], "input": [...]}.',
    );
  }
  final subcategory = decoded['subcategory'];
  final input = decoded['input'];
  if (subcategory is! List || input is! List) {
    throw RollyFileFormatException(
      'File JSON thiếu mảng "subcategory" hoặc "input" — cần cả hai để khôi '
      'phục danh mục phụ cho giao dịch đã import (Phase 9).',
    );
  }
  return RollySubcategoryImportFile(
    subcategoryRows: subcategory,
    inputRows: input,
  );
}
