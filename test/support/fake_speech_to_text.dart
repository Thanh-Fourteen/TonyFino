import 'dart:convert';

import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

/// Nhận dạng giọng nói giả cho widget test — thay `SpeechToTextPlatform.
/// instance` (kênh native tới `SpeechRecognizer` của Android) để test tự bơm
/// kết quả tạm thời/cuối cùng qua [emitResult] và trạng thái qua
/// [emitStatus], không cần micro thật.
///
/// 🚨 Lấy qua [installFakeSpeechToText], KHÔNG tự `new` rồi gán cho từng
/// test: `SpeechToText()` là singleton sống suốt tiến trình test và chỉ nối
/// `onTextRecognition`/`onStatus` vào platform ở lần `initialize()` ĐẦU
/// TIÊN. Fake thứ hai gán sau đó sẽ không bao giờ được nối — [emitResult]
/// gọi vào hư không. Vì vậy cả tiến trình dùng MỘT fake, chỉ đặt lại bộ đếm.
class FakeSpeechToTextPlatform extends SpeechToTextPlatform {
  int listenCalls = 0;
  int stopCalls = 0;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> initialize({
    debugLogging = false,
    List<SpeechConfigOption>? options,
  }) async => true;

  @override
  Future<bool> listen({
    String? localeId,
    partialResults = true,
    onDevice = false,
    int listenMode = 0,
    sampleRate = 0,
    SpeechListenOptions? options,
  }) async {
    listenCalls++;
    onStatus?.call('listening');
    return true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    onStatus?.call('notListening');
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<List<dynamic>> locales() async => const [];

  /// Bơm một kết quả nhận dạng theo đúng định dạng JSON plugin native gửi
  /// lên (`resultType`: 0 = tạm thời, 2 = cuối cùng).
  void emitResult(String words, {required bool isFinal}) {
    onTextRecognition?.call(
      jsonEncode({
        'alternates': [
          {'recognizedWords': words, 'confidence': 0.9},
        ],
        'resultType': isFinal ? 2 : 0,
      }),
    );
  }

  void emitStatus(String status) => onStatus?.call(status);
}

FakeSpeechToTextPlatform? _shared;

FakeSpeechToTextPlatform installFakeSpeechToText() {
  final fake = _shared ??= FakeSpeechToTextPlatform();
  fake
    ..listenCalls = 0
    ..stopCalls = 0;
  SpeechToTextPlatform.instance = fake;
  return fake;
}
