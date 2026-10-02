import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/validation.dart';

/// Ba vai trò của hệ thống. Trùng với `validRole()` trong `firestore.rules`
/// và với §6 của `de-tai-tong-the.md` (đã bỏ `system_admin`, `shipper`,
/// `viewer` vì cửa hàng tự giao và chỉ có một cửa hàng).
enum UserRole {
  customer,
  seller,
  admin;

  static UserRole fromFirestore(Object? raw) => switch (raw) {
        'seller' => UserRole.seller,
        'admin' => UserRole.admin,
        _ => UserRole.customer,
      };
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
  });

  final String uid;

  /// `users/{uid}.display_name`
  final String displayName;
  final String email;

  /// `users/{uid}.role` — Security Rules đọc đúng trường này
  /// (`function role()`), nên client phải đọc cũng trường này.
  final UserRole role;

  bool isSeller() => role == UserRole.seller;
  bool isAdmin() => role == UserRole.admin;

  /// seller + admin = mọi quyền vận hành cửa hàng (khớp `isStaff()`).
  bool isStaff() => isSeller() || isAdmin();
}

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthSuccess extends AuthState {
  const AuthSuccess(this.user);

  final AppUser user;
}

class AuthError extends AuthState {
  const AuthError(this.message);

  final String message;
}

/// Đã gửi xong email đặt lại mật khẩu. Tách khỏi `AuthSuccess` vì state này
/// không đổi phiên đăng nhập — người dùng vẫn đang ở màn login và còn phải
/// nhập mật khẩu mới.
class AuthResetSent extends AuthState {
  const AuthResetSent();
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    try {
      FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
    } catch (_) {
      // Firebase chưa cấu hình (thiếu `flutterfire configure` / môi trường test)
      // — vẫn mở app; event đăng nhập sẽ cập nhật state sau.
    }
    return const AuthInitial();
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      state = const AuthInitial();
      return;
    }
    state = const AuthLoading();
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      state = AuthSuccess(
        AppUser(
          uid: user.uid,
          displayName: (data['display_name'] as String?) ??
              user.displayName ??
              '',
          email: user.email ?? (data['email'] as String?) ?? '',
          role: UserRole.fromFirestore(data['role']),
        ),
      );
    } catch (_) {
      state = const AuthInitial();
    }
  }

  Future<void> login(String email, String password) async {
    state = const AuthLoading();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      state = AuthError(_message(e));
    }
  }

  Future<void> register(
    String name,
    String email,
    String password,
    String phone,
  ) async {
    state = const AuthLoading();
    // Giữ lại user vừa tạo ở Firebase Auth, để nếu ghi hồ sơ Firestore hỏng
    // thì xoá được user đó. Bỏ qua thì còn lại tài khoản mồ côi chiếm email,
    // và lần đăng ký sau sẽ báo "Email đã được sử dụng" mà không ai hiểu
    // vì sao.
    User? created;
    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        state = const AuthError('Không thể tạo tài khoản.');
        return;
      }
      created = user;
      await user.updateDisplayName(name.trim());
      // Bắt buộc đủ field mà `firestore.rules` đòi ở `users/{uid}` create:
      // role == 'customer', email khác rỗng, is_active == true,
      // created_at == request.time. Thiếu `role` là đăng ký bị chặn.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'display_name': name.trim(),
        'email': user.email ?? '',
        // `phone` không bắt buộc trong Rules, nhưng điền thì phải đúng dạng
        // để sổ địa chỉ đối chiếu được — nên chuẩn hoá trước khi ghi.
        'phone': normalizePhone(phone),
        'role': UserRole.customer.name,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'deleted_at': null,
      });
    } on FirebaseAuthException catch (e) {
      state = AuthError(_message(e));
    } on FirebaseException catch (e) {
      // Lỗi Firestore KHÔNG phải lỗi đăng nhập: trước đây không có nhánh
      // bắt nó nên lỗi ném ra ngoài, người dùng chỉ thấy app im lặng.
      final cleaned = await _deleteOrphan(created);
      state = AuthError(signupFirestoreError(e, cleaned: cleaned));
    }
  }

  /// Xoá user Auth đã tạo khi ghi hồ sơ Firestore thất bại.
  ///
  /// `createUserWithEmailAndPassword` đăng nhập luôn tài khoản vừa tạo nên
  /// `user.delete()` chạy được ngay. Trả `true` nếu xoá sạch.
  Future<bool> _deleteOrphan(User? created) async {
    if (created == null) return true;
    try {
      await created.delete();
      return true;
    } on FirebaseAuthException {
      return false;
    }
  }

  /// Gửi email đặt lại mật khẩu. Firebase tự sinh link và gửi đi, không cần
  /// server riêng — nhưng **không** báo cho người dùng biết tài khoản có tồn
  /// tại hay không, vì báo thì kẻ xấu dò email đăng ký của người khác.
  /// `firestore.rules` cũng không có đường để biết ngoài việc thử đăng nhập.
  Future<void> sendPasswordReset(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.trim(),
      );
      state = const AuthResetSent();
    } on FirebaseAuthException catch (e) {
      state = AuthError(_message(e));
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'user-not-found':
      case 'wrong-password':
        return 'Email hoặc mật khẩu không đúng.';
      case 'email-already-in-use':
        return 'Email đã được sử dụng.';
      case 'weak-password':
        return 'Mật khẩu quá yếu (tối thiểu 6 ký tự).';
      case 'too-many-requests':
        return 'Quá nhiều lần thử. Hãy thử lại sau.';
      case 'network-request-failed':
        return 'Không có mạng. Kiểm tra kết nối rồi thử lại.';
      default:
        return 'Không thể xác thực. Vui lòng thử lại.';
    }
  }
}

/// Thông điệp cho lỗi Firestore khi đăng ký. Nói đúng nguồn lỗi thay vì
/// dùng chung "không thể xác thực" — lỗi Rules trả về `permission-denied`
/// chứ không phải lỗi đăng nhập, dán nhãn sai thì người đọc bị hướng sai.
///
/// [cleaned] = đã xoá được tài khoản Auth hay chưa. Chưa xoá được thì phải
/// nhắc người dùng xoá tay, nếu không họ bấm lại sẽ thấy "Email đã được
/// sử dụng" mà không hiểu vì sao.
String signupFirestoreError(FirebaseException e, {required bool cleaned}) {
  final cause = switch (e.code) {
    'permission-denied' =>
      'Security Rules từ chối tạo hồ sơ (thiếu field bắt buộc, hoặc Rules đang '
          'chạy khác với Emulator).',
    'unavailable' => 'Không có mạng nên không lưu được hồ sơ.',
    _ => 'Không lưu được hồ sơ (${e.code}).',
  };
  final tail = cleaned
      ? 'Tài khoản vừa tạo đã được xoá, hãy thử lại.'
      : 'Tài khoản vừa tạo CHƯA xoá được — hãy xoá tay nó trong Firebase '
          'Console rồi thử lại, nếu không email vẫn bị báo đã dùng.';
  return '$cause $tail';
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final authUserProvider = Provider<AppUser?>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is AuthSuccess ? state.user : null;
});