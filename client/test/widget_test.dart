import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shop_client/features/auth/auth_controller.dart';
import 'package:shop_client/features/auth/login_screen.dart';
import 'package:shop_client/features/auth/register_screen.dart';

class _FakeAuthController extends AuthController {
  @override
  AuthState build() => const AuthInitial();
}

/// `MaterialApp` + `ProviderScope` bọc quanh màn cần thử. `MaterialApp` có
/// sẵn `Navigator` nên nút quay lại trên `AppBar` của màn đăng ký vẫn hoạt
/// động, và `ScaffoldMessenger` có chỗ để hiện thông báo.
Widget _host(Widget child) => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('login screen hiện đủ trường và nút', (tester) async {
    await tester.pumpWidget(_host(const LoginScreen()));

    expect(find.text('DHHShop'), findsOneWidget);
    expect(find.text('Đăng nhập để xem đơn hàng, lịch sử mua và bảo hành.'),
        findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Mật khẩu'), findsOneWidget);
    expect(find.text('Quên?'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
    expect(find.text('Chưa có tài khoản? Đăng ký ngay'), findsOneWidget);
  });

  testWidgets('login screen có thẻ tài khoản demo', (tester) async {
    await tester.pumpWidget(_host(const LoginScreen()));

    expect(find.text('TÀI KHOẢN DEMO'), findsOneWidget);
    for (final email in [
      'customer@demo.com',
      'seller@demo.com',
      'admin@demo.com',
    ]) {
      expect(find.textContaining(email), findsOneWidget);
    }
  });

  testWidgets('bấm tài khoản demo thì điền sẵn email và mật khẩu',
      (tester) async {
    await tester.pumpWidget(_host(const LoginScreen()));

    await tester.tap(find.textContaining('admin@demo.com'));
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields.length, 2);
    expect(fields.first.controller?.text, 'admin@demo.com');
    expect(fields.last.controller?.text, 'admin123');
  });

  testWidgets('bỏ trống mọi trường thì báo lỗi inline dưới ô',
      (tester) async {
    await tester.pumpWidget(_host(const LoginScreen()));

    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    // validator chạy và lỗi hiện ngay dưới ô, không phải ở chỗ khác
    expect(find.text('Nhập email.'), findsOneWidget);
    expect(find.text('Nhập mật khẩu'), findsOneWidget);
  });

  testWidgets('quên mật khẩu thì bắt nhập email trước', (tester) async {
    await tester.pumpWidget(_host(const LoginScreen()));

    await tester.tap(find.text('Quên?'));
    await tester.pump();

    expect(
      find.text('Nhập email trước rồi bấm Quên mật khẩu.'),
      findsOneWidget,
    );
  });

  testWidgets('register screen hiện đủ trường theo prototype', (tester) async {
    await tester.pumpWidget(_host(const RegisterScreen()));

    expect(find.widgetWithText(TextFormField, 'Họ và tên'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Số điện thoại'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Mật khẩu'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Xác nhận mật khẩu'), findsOneWidget);
    expect(
      find.textContaining('Không yêu cầu CCCD'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Tôi đồng ý với Điều khoản'),
      findsOneWidget,
    );
    expect(find.text('Đã có tài khoản? Đăng nhập'), findsOneWidget);
  });

  testWidgets('chưa tích đồng ý thì không cho tạo tài khoản', (tester) async {
    await tester.pumpWidget(_host(const RegisterScreen()));

    // Điền hết ô cho hợp lệ trước — nếu để trống thì `validate()` chặn ở
    // các ô trước và không bao giờ tới bước kiểm tra checkbox.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Họ và tên'),
      'Nguyen Van A',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'khach@demo.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Số điện thoại'),
      '0912345678',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mật khẩu'),
      'matkhau123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Xác nhận mật khẩu'),
      'matkhau123',
    );

    final button = find.widgetWithText(FilledButton, 'Tạo tài khoản');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Cần đồng ý Điều khoản'),
      findsOneWidget,
    );
  });

  testWidgets('số điện thoại sai bị chặn ở chỗ ô đó', (tester) async {
    await tester.pumpWidget(_host(const RegisterScreen()));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Số điện thoại'),
      '912',
    );
    final button = find.widgetWithText(FilledButton, 'Tạo tài khoản');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Số điện thoại phải là 10 chữ số'),
      findsOneWidget,
    );
  });
}