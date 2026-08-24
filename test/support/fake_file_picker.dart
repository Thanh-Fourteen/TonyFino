import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';

/// [PlatformFile] giả cho widget test — [FilePicker.pickFile] không có cách
/// nào tự nhiên chạy trong widget test (không có native file picker thật),
/// nên fake ở tầng `FilePickerPlatform.instance` giống hệt cách
/// `fake_shared_preferences.dart` fake `SharedPreferencesAsyncPlatform` ở
/// Phase 8 — cùng một mẫu, đã chứng minh hoạt động tốt cho platform
/// singleton kiểu này.
base class _FakePlatformFile extends PlatformFile {
  _FakePlatformFile(this.name, this._bytes);

  @override
  final String name;
  final Uint8List _bytes;

  @override
  Uri get uri => Uri.parse('memory://$name');

  @override
  XFile get xFile => XFile.fromData(_bytes, name: name);

  @override
  Future<int> length() async => _bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(_bytes);
}

class FakeFilePicker extends FilePickerPlatform {
  /// Set trước mỗi lần gọi `pickFile` mà test muốn giả lập — `null` giả lập
  /// người dùng bấm Huỷ.
  Uint8List? nextFileBytes;
  String nextFileName = 'fake.json';

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    final bytes = nextFileBytes;
    if (bytes == null) return null;
    return _FakePlatformFile(nextFileName, bytes);
  }
}

/// Gọi trong `setUp()` — trả về instance để test set `nextFileBytes` trước
/// mỗi lần bấm nút chọn file.
FakeFilePicker installFakeFilePicker() {
  final fake = FakeFilePicker();
  FilePickerPlatform.instance = fake;
  return fake;
}
