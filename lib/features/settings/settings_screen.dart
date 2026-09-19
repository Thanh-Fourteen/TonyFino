import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lifecycle/app_lock_session.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/build_info.dart';
import '../../data/services/biometric/biometric_service.dart';
import '../../debug/style_gallery.dart';
import '../../theme/context_ext.dart';
import 'backup/backup_controller.dart';
import 'import/import_screen.dart';
import 'settings_controller.dart';
import '../../theme/tokens/icons.dart';

final _biometricSupportedProvider = FutureProvider<bool>((ref) {
  return BiometricService().isSupported();
});

final _packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final packageInfo = ref.watch(_packageInfoProvider);
    final biometricSupported = ref.watch(_biometricSupportedProvider);
    final backup = ref.watch(backupControllerProvider);
    final backupController = ref.read(backupControllerProvider.notifier);

    ref.listen(backupControllerProvider.select((s) => s.lastResult), (
      _,
      result,
    ) {
      if (result == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result is BackupActionSuccess
                ? result.message
                : (result as BackupActionError).message,
          ),
          backgroundColor: result is BackupActionError
              ? context.colors.budgetOver
              : null,
        ),
      );
      backupController.dismissResult();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: EdgeInsets.all(context.space.screenHorizontal),
        children: [
          const _SectionHeader('Giao diện', first: true),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Sáng')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Tối')),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('Theo hệ thống'),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (selection) =>
                controller.setThemeMode(selection.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Đen tuyền (AMOLED)'),
            subtitle: const Text('Nền đen tuyệt đối, tiết kiệm pin màn OLED'),
            value: settings.amoled,
            onChanged: settings.themeMode == ThemeMode.light
                ? null
                : (value) => controller.setAmoled(value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Màu động theo hệ thống (Material You)'),
            subtitle: const Text('Lấy màu nhấn từ hình nền máy'),
            value: settings.dynamicColorEnabled,
            onChanged: (value) => controller.setDynamicColorEnabled(value),
          ),
          const _SectionHeader('Trang chủ'),
          // Bật/tắt từng khối. KHÔNG có nút "khôi phục mặc định": bật lại
          // đúng khối muốn xem là một chạm, thêm một nút nữa chỉ làm dài
          // màn hình cho một việc hiếm.
          for (final section in HomeSection.values)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              // KHÔNG có dòng mô tả: tên khối đã tự nói (xem ghi chú ở
              // `HomeSection`). Năm dòng phụ liên tiếp biến nhóm này thành
              // một khối chữ dày, đúng chỗ Tony kêu "ghi chú nhiều quá".
              title: Text(section.label),
              value: settings.homeSections.contains(section),
              onChanged: (value) =>
                  controller.setHomeSectionEnabled(section, value),
            ),
          const _SectionHeader('Bảo mật'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ẩn số tiền'),
            subtitle: const Text('Bấm con mắt ở thanh trên cùng để hiện lại'),
            value: settings.hideAmounts,
            onChanged: controller.setHideAmounts,
          ),
          biometricSupported.when(
            data: (supported) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Khoá vân tay / khuôn mặt'),
              subtitle: Text(
                supported
                    ? 'Yêu cầu xác thực mỗi khi mở lại TonyFino'
                    : 'Máy này không hỗ trợ hoặc chưa đăng ký sinh trắc học',
              ),
              value: settings.biometricLockEnabled,
              onChanged: supported
                  ? (value) {
                      // Người dùng đang đứng NGAY ĐÂY và vừa tự tay bật —
                      // tin phiên này, khoá có hiệu lực từ lần rời
                      // foreground kế tiếp (xem `AppLockSession`).
                      if (value) {
                        ref.read(appLockSessionProvider.notifier).trust();
                      }
                      controller.setBiometricLockEnabled(value);
                    }
                  : null,
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const _SectionHeader('Sao lưu'),
          Text(
            backup.lastBackupAt == null
                ? 'Chưa sao lưu lần nào'
                : 'Sao lưu gần nhất: ${backup.lastBackupAt!.day}/'
                      '${backup.lastBackupAt!.month}/${backup.lastBackupAt!.year} '
                      '${backup.lastBackupAt!.hour.toString().padLeft(2, '0')}:'
                      '${backup.lastBackupAt!.minute.toString().padLeft(2, '0')}',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: context.space.sm),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: backup.isWorking
                      ? null
                      : backupController.backupNow,
                  child: const Text('Sao lưu ngay'),
                ),
              ),
              SizedBox(width: context.space.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: backup.isWorking
                      ? null
                      : () => _confirmRestore(context, backupController),
                  child: const Text('Khôi phục'),
                ),
              ),
            ],
          ),
          SizedBox(height: context.space.xs),
          TextButton(
            onPressed: backup.isWorking ? null : backupController.shareBackup,
            child: const Text('Chia sẻ bản sao lưu qua ứng dụng khác'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sao lưu tự động hàng ngày'),
            subtitle: const Text(
              'Chạy nền mỗi ngày, giờ giấc do Android quyết',
            ),
            value: backup.autoBackupEnabled,
            onChanged: (value) => backupController.setAutoBackupEnabled(value),
          ),
          // Cài đặt DẠNG GIÁ TRỊ (dropdown + giải thích dài) tách khỏi
          // khối hàng điều hướng phía trên: xen một hàng cao gấp ba giữa
          // các hàng đều nhau làm cả nhóm trông lộn xộn.
          const _SectionHeader('Nâng cao'),
          Row(
            children: [
              const Expanded(child: Text('Kỳ tháng bắt đầu ngày')),
              DropdownButton<int>(
                value: settings.budgetAnchorDay,
                items: [
                  for (var day = 1; day <= 31; day++)
                    DropdownMenuItem(value: day, child: Text('$day')),
                ],
                onChanged: (day) {
                  if (day == null) return;
                  controller.setBudgetAnchorDay(day);
                },
              ),
            ],
          ),
          Text(
            'Đặt theo ngày nhận lương nếu kỳ không trùng tháng lịch',
            style: context.text.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const _AiSectionLabel(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dùng AI khi câu quá mơ hồ'),
            subtitle: const Text(
              'Chỉ gọi khi app không tự đoán được, qua proxy riêng',
            ),
            value: settings.cloudFallbackEnabled,
            onChanged: (value) => controller.setCloudFallbackEnabled(value),
          ),
          SizedBox(height: context.space.xs),
          OutlinedButton(
            onPressed: () =>
                _editAiFallbackBaseUrl(context, controller, settings),
            child: const Text('Đổi địa chỉ proxy'),
          ),
          const _SectionHeader('Dữ liệu'),
          _NavRow(
            icon: kIconSwapHoriz,
            label: 'Nhập / xuất dữ liệu',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ImportScreen()),
            ),
          ),
          const _SectionHeader('Giới thiệu'),
          packageInfo.when(
            data: (info) =>
                _AboutBlock(version: '${info.version}+${info.buildNumber}'),
            loading: () => const _AboutBlock(version: '…'),
            error: (_, _) => const _AboutBlock(version: '?'),
          ),
          if (kDebugMode) ...[
            SizedBox(height: context.space.xxl),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const StyleGalleryScreen(),
                ),
              ),
              child: const Text('Style Gallery (debug)'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Khôi phục GHI ĐÈ toàn bộ dữ liệu hiện có (`BackupService.importFromJson`)
/// — xác nhận trước, không cho một cú chạm vô tình xoá dữ liệu thật.
Future<void> _confirmRestore(
  BuildContext context,
  BackupController controller,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Khôi phục từ file backup?'),
      content: const Text(
        'Toàn bộ giao dịch, danh mục, ngân sách HIỆN CÓ sẽ bị THAY THẾ bằng '
        'nội dung file backup. Hành động này không thể hoàn tác.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Khôi phục'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await controller.restoreFromFile();
  }
}

/// Đổi được trong Settings (D8) — để sau này chuyển sang Cloudflare Worker
/// (hoặc một máy khác) là cắm-vào-là-chạy, không cần build lại app.
Future<void> _editAiFallbackBaseUrl(
  BuildContext context,
  AppSettingsController controller,
  AppSettings settings,
) async {
  final newUrl = await showDialog<String>(
    context: context,
    builder: (dialogContext) =>
        _AiFallbackBaseUrlDialog(initialUrl: settings.aiFallbackBaseUrl),
  );
  if (newUrl != null && newUrl.isNotEmpty) {
    await controller.setAiFallbackBaseUrl(newUrl);
  }
}

/// `TextEditingController` sở hữu bởi CHÍNH `State` này, huỷ trong
/// `dispose()` của nó — KHÔNG huỷ ngay sau `showDialog` trả về ở hàm gọi:
/// `Navigator.pop` chỉ BẮT ĐẦU animation đóng, `TextField` bên trong vẫn còn
/// sống (và vẫn lắng nghe controller) suốt animation đó — huỷ controller
/// sớm ném "used after being disposed" giữa lúc sheet đang trồi xuống, một
/// bug thật bắt được qua test, không phải lý thuyết.
class _AiFallbackBaseUrlDialog extends StatefulWidget {
  const _AiFallbackBaseUrlDialog({required this.initialUrl});

  final String initialUrl;

  @override
  State<_AiFallbackBaseUrlDialog> createState() =>
      _AiFallbackBaseUrlDialogState();
}

class _AiFallbackBaseUrlDialogState extends State<_AiFallbackBaseUrlDialog> {
  late final _controller = TextEditingController(text: widget.initialUrl);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Địa chỉ proxy AI'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(hintText: 'https://.../tonyfino-ai/'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

class _AboutBlock extends StatelessWidget {
  const _AboutBlock({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final rows = {
      'Phiên bản': version,
      'Git SHA': BuildInfo.gitSha,
      'Build lúc': BuildInfo.buildTime,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows.entries.map((entry) {
        return Padding(
          padding: EdgeInsets.only(bottom: context.space.xs),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  entry.key,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(entry.value, style: context.text.bodyMedium),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Một mục điều hướng ở màn Cài đặt — icon trong đĩa màu + nhãn + chevron.
///
/// Thay cho `OutlinedButton` tràn ngang: bảy nút viền giống hệt nhau xếp dọc
/// vừa nặng thị giác vừa không nói được "bấm vào sẽ ĐI ĐÂU ĐÓ" (nút viền
/// trông như một hành động tại chỗ). Chevron nói đúng điều đó, icon giúp
/// quét mắt tìm mục, và hàng gọn hơn nút ~30% chiều dọc. Cùng ngôn ngữ hàng
/// tràn viền với danh sách giao dịch và màn Ngân sách.
class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.radii.sm),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.space.sm),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  // Nền tròn sau icon dùng PETROL, không phải cam: cam ở
                  // 10% trên nền trắng ra một sắc be nhạt — mắt đọc thành
                  // nâu chứ không thành "cam nhạt" (Tony: "các màu nâu ở
                  // các nền icon"). Icon bên trong cũng petrol nên cả cụm
                  // là một khối cùng tông.
                  color: context.colors.brandText.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: context.colors.brandText),
              ),
              SizedBox(width: context.space.md),
              Expanded(child: Text(label, style: context.text.bodyLarge)),
              Icon(
                kIconChevronRight,
                size: 20,
                color: context.colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiêu đề một nhóm trong Cài đặt — một widget duy nhất thay cho cặp
/// `SizedBox(xxl) + Text(titleMedium)` lặp lại ở mười chỗ.
///
/// Ngoài chuyện gọn code, nó ép khoảng cách giữa các nhóm bằng nhau: trước
/// đây mỗi nhóm tự viết `SizedBox` nên chỉ cần một chỗ quên là cả màn lệch
/// nhịp — Tony nhận xét "không gọn gàng gì cả" đúng vào chuyện đó.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.first = false});

  final String title;

  /// Nhóm ĐẦU TIÊN không cần khoảng đệm phía trên (đã có padding của màn).
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: first ? 0 : context.space.xxl,
        bottom: context.space.sm,
      ),
      child: Text(
        title,
        style: context.text.labelMedium?.copyWith(
          color: context.colors.brandText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Nhãn phụ trong nhóm "Nâng cao" — nhỏ hơn tiêu đề nhóm, không tạo thêm
/// một nhóm mới (Cài đặt đã đủ nhóm rồi).
class _AiSectionLabel extends StatelessWidget {
  const _AiSectionLabel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.space.lg),
      child: Text('Trợ lý AI đám mây', style: context.text.titleMedium),
    );
  }
}
