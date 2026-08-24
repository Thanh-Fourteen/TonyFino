import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `Clock` inject được — TUYỆT ĐỐI không `DateTime.now()` trong features
/// (date_parser Phase 7, ghi nhận giao dịch, v.v.), để test đóng băng thời gian
/// được và không sợ chạy vào nửa đêm/đổi múi giờ.
final clockProvider = Provider<Clock>((ref) => const Clock());
