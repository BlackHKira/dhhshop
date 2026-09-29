import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shop_client/features/auth/auth_controller.dart';
import 'package:shop_client/features/auth/login_screen.dart';

class _FakeAuthController extends AuthController {
  @override
  AuthState build() => const AuthInitial();
}

void main() {
  testWidgets('login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('DHHShop'), findsOneWidget);
    expect(find.text('Đăng nhập để tiếp tục'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
  });
}