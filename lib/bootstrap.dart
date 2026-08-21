import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Khởi tạo chung trước khi chạy app. Gọi từ main().
Future<Widget> bootstrap(Widget app) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge (Android 15+ cưỡng chế). System bar trong suốt, KHÔNG set màu
  // nền cho chúng — set màu là deprecated trên Android 15+ và Play cảnh báo.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  return ProviderScope(child: app);
}
