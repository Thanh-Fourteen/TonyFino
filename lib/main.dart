import 'package:flutter/material.dart';
import 'bootstrap.dart';

void main() async {
  runApp(await bootstrap(const TonyFinoApp()));
}

class TonyFinoApp extends StatelessWidget {
  const TonyFinoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TonyFino',
      debugShowCheckedModeBanner: false,
      // Theme thật dựng ở Phase 5. Đây chỉ là chỗ giữ để scaffold chạy.
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: const _ScaffoldPlaceholder(),
    );
  }
}

class _ScaffoldPlaceholder extends StatelessWidget {
  const _ScaffoldPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Text(
            'TonyFino\nscaffold sẵn sàng',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'BeVietnamPro', fontSize: 20),
          ),
        ),
      ),
    );
  }
}
