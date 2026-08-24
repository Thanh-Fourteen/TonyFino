// H6 (TODOS.md § Phase 12 Xác minh): "giả lập đích backup bị thu hồi quyền
// → banner phải hiện, ghi lại được → banner phải tắt". Giả lập qua
// `backupHealthProbeProvider` — tách khỏi `AndroidSafDestination` thật (cần
// platform channel SAF, không có trong `flutter_test`).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonyfino/features/settings/backup/backup_health_provider.dart';

import '../../../support/fake_shared_preferences.dart';

void main() {
  setUp(() => installFakeSharedPreferences());

  test(
    'chưa từng bật sao lưu tự động → healthy null, KHÔNG coi là hỏng',
    () async {
      final container = ProviderContainer(
        overrides: [
          backupHealthProbeProvider.overrideWithValue(() async => false),
        ],
      );
      addTearDown(container.dispose);

      await container.read(backupHealthProvider.notifier).check();
      final state = container.read(backupHealthProvider);
      expect(state.hasChecked, isTrue);
      expect(state.healthy, isNull);
    },
  );

  test(
    'đã bật sao lưu tự động, grant bị thu hồi → healthy = false (banner phải hiện)',
    () async {
      await SharedPreferencesAsync().setBool(
        'tonyfino_auto_backup_enabled',
        true,
      );
      final container = ProviderContainer(
        overrides: [
          backupHealthProbeProvider.overrideWithValue(() async => false),
        ],
      );
      addTearDown(container.dispose);

      await container.read(backupHealthProvider.notifier).check();
      expect(container.read(backupHealthProvider).healthy, isFalse);
    },
  );

  test(
    'sau khi khắc phục, ghi/đọc lại được → healthy = true (banner phải tắt)',
    () async {
      await SharedPreferencesAsync().setBool(
        'tonyfino_auto_backup_enabled',
        true,
      );
      var probeOk = false;
      final container = ProviderContainer(
        overrides: [
          backupHealthProbeProvider.overrideWithValue(() async => probeOk),
        ],
      );
      addTearDown(container.dispose);

      await container.read(backupHealthProvider.notifier).check();
      expect(container.read(backupHealthProvider).healthy, isFalse);

      probeOk = true;
      await container.read(backupHealthProvider.notifier).check();
      expect(container.read(backupHealthProvider).healthy, isTrue);
    },
  );
}
