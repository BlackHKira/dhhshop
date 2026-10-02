import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shop_client/features/auth/auth_controller.dart';

FirebaseException _err(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

void main() {
  group('signupFirestoreError', () {
    test('nói đúng nguồn lỗi thay vì gộp chung "không thể xác thực"', () {
      final msg = signupFirestoreError(_err('permission-denied'), cleaned: true);
      expect(msg, contains('Security Rules'));
      // Không được dán nhãn lỗi đăng nhập — nó sẽ hướng người dùng sai chỗ.
      expect(msg, isNot(contains('thác')));
      expect(msg, isNot(contains('không thể xác thực')));
    });

    test('lỗi mạng nói là mạng, không phải Rules', () {
      final msg = signupFirestoreError(_err('unavailable'), cleaned: true);
      expect(msg, contains('mạng'));
      expect(msg, isNot(contains('Rules')));
    });

    test('mã lỗi lạ thì nhường nguyên mã vào thông điệp', () {
      final msg = signupFirestoreError(_err('deadline-exceeded'), cleaned: true);
      expect(msg, contains('deadline-exceeded'));
    });

    // Nhánh này quan trọng nhất: nếu báo sai, người dùng bấm lại đăng ký sẽ
    // thấy "Email đã được sử dụng" mà không hiểu vì sao.
    test('xoá tài khoản được thì bảo thử lại là xong', () {
      final msg = signupFirestoreError(_err('permission-denied'), cleaned: true);
      expect(msg, contains('đã được xoá'));
      expect(msg, isNot(contains('CHƯA xoá')));
      expect(msg, isNot(contains('Console')));
    });

    test('xoá KHÔNG được thì phải nhắc xoá tay ở Console', () {
      final msg = signupFirestoreError(_err('permission-denied'), cleaned: false);
      expect(msg, contains('CHƯA xoá được'));
      expect(msg, contains('Firebase Console'));
      expect(msg, contains('email vẫn bị báo đã dùng'));
    });

    test('mọi thông điệp đều kết thúc bằng hướng dẫn hành động', () {
      for (final code in ['permission-denied', 'unavailable', 'weird-code']) {
        for (final cleaned in [true, false]) {
          final msg = signupFirestoreError(_err(code), cleaned: cleaned);
          expect(
            msg.contains('thử lại'),
            isTrue,
            reason: 'code=$code cleaned=$cleaned → "$msg"',
          );
        }
      }
    });
  });
}