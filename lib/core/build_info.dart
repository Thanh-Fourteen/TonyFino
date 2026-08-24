/// Hằng số nhúng lúc BUILD qua `--dart-define` (`tool/build_apk.sh`) —
/// KHÔNG phải giờ hệ thống đọc lúc chạy, nên không phạm Luật #3 (Clock
/// inject): đây là mốc thời gian của lần `flutter build` sinh ra APK này,
/// cố định vĩnh viễn trong binary, không đổi giữa các lần mở app (D4).
class BuildInfo {
  const BuildInfo._();

  static const gitSha = String.fromEnvironment('GIT_SHA', defaultValue: 'dev');
  static const buildTime = String.fromEnvironment(
    'BUILD_TIME',
    defaultValue: 'dev',
  );
}
