import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wallets_providers.dart';

/// Lựa chọn ví của Tony, đọc từ prefs — CHỈ là "ví lần trước", không phải
/// nguồn sự thật. `null` = chưa đọc xong, hoặc chưa từng chọn.
///
/// Tách riêng khỏi [selectedWalletIdProvider] để provider kia suy ra được
/// ĐỒNG BỘ: nếu tự nó phải chờ prefs thì có một quãng "chưa biết ví nào",
/// và mọi thứ đọc danh mục trong quãng đó (gợi ý ánh xạ lúc import, bộ chọn
/// danh mục) nhìn thấy danh sách rỗng rồi chốt luôn kết quả sai.
class WalletSelectionOverride extends Notifier<int?> {
  static const _key = 'tonyfino_selected_wallet_id';

  @override
  int? build() {
    unawaited(_load());
    return null;
  }

  Future<void> _load() async {
    final saved = await _read();
    if (saved != null && state != saved) state = saved;
  }

  Future<void> select(int walletId) async {
    state = walletId;
    try {
      await SharedPreferencesAsync().setInt(_key, walletId);
    } catch (_) {
      // Không nhớ được thì phiên này vẫn đúng — xem [_read].
    }
  }

  /// Dựng `SharedPreferencesAsync` LƯỜI trong try: constructor của nó ném
  /// lỗi ĐỒNG BỘ khi chưa set platform instance (widget test không gọi
  /// `installFakeSharedPreferences`). Để nó làm field khởi tạo thì cả
  /// Notifier rơi vào trạng thái lỗi và MỌI màn danh mục trắng trơn.
  Future<int?> _read() async {
    try {
      return await SharedPreferencesAsync().getInt(_key);
    } catch (_) {
      return null;
    }
  }
}

final walletSelectionOverrideProvider =
    NotifierProvider<WalletSelectionOverride, int?>(
      WalletSelectionOverride.new,
    );

/// Ví ĐANG XEM — nguồn phạm vi cho mọi màn kể từ v11 (mỗi ví có bộ danh mục
/// riêng).
///
/// Vì sao phải có: hai ví đều có thể có danh mục tên "Ăn uống" và đó là hai
/// danh mục KHÁC NHAU. Màn danh mục/ngân sách/báo cáo không lọc theo ví sẽ
/// hiện hai dòng trùng tên không phân biệt nổi — phạm vi "một ví" là bắt
/// buộc, không phải tuỳ chọn.
///
/// Suy ra ĐỒNG BỘ từ danh sách ví: có ví là có ngay câu trả lời. Lựa chọn
/// đã lưu chỉ được dùng khi ví đó CÒN TỒN TẠI (Tony xoá/lưu trữ ví đang
/// chọn thì tự rơi về ví đầu tiên, không kẹt ở một id chết).
///
/// `null` CHỈ khi danh sách ví chưa tải xong — call site coi đó là "đang
/// tải", ĐỪNG tự đoán ví ở từng chỗ.
final selectedWalletIdProvider = Provider<int?>((ref) {
  final wallets = ref.watch(activeWalletsProvider).value;
  if (wallets == null || wallets.isEmpty) return null;
  final saved = ref.watch(walletSelectionOverrideProvider);
  if (saved != null && wallets.any((w) => w.id == saved)) return saved;
  return wallets.first.id;
});
