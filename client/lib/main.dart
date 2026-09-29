import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'core/firebase/firebase_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ensureFirebaseInitialized();
  } catch (_) {
    // Lỗi cấu hình Firebase (vd chưa chạy `flutterfire configure`) —
    // vẫn mở app để thấy lỗi cụ thể khi dùng chức năng đăng nhập.
  }
  runApp(const ProviderScope(child: DoAnApp()));
}

class DoAnApp extends ConsumerWidget {
  const DoAnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'DHHShop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}