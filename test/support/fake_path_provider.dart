import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// `getApplicationDocumentsDirectory()` (`path_provider`) không có platform
/// instance mặc định trong `flutter_test` — trỏ về một thư mục TẠM THẬT
/// (`Directory.systemTemp.createTemp`, dọn qua [FakePathProviderPlatform.dispose])
/// để `ReceiptImageService`/`PathService` ghi/đọc file thật được trên host,
/// không cần thiết bị hay mock hoá `dart:io` (Phase 17, cho test round-trip
/// backup có ảnh hoá đơn đính kèm).
class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform(this._dir);

  final Directory _dir;

  static Future<FakePathProviderPlatform> install() async {
    final dir = await Directory.systemTemp.createTemp('tonyfino_test_docs_');
    final platform = FakePathProviderPlatform(dir);
    PathProviderPlatform.instance = platform;
    return platform;
  }

  Future<void> dispose() async {
    if (await _dir.exists()) {
      await _dir.delete(recursive: true);
    }
  }

  @override
  Future<String?> getApplicationDocumentsPath() async => _dir.path;
}
