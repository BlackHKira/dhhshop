import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> register(String name, String email, String password) async {
    state = const AuthLoading();
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
      await user.updateDisplayName(name.trim());
      // Bắt buộc đủ field mà `firestore.rules` đòi ở `users/{uid}` create:
      // role == 'customer', email khác rỗng, is_active == true,
      // created_at == request.time. Thiếu `role` là đăng ký bị chặn.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'display_name': name.trim(),
        'email': user.email ?? '',
        'phone': '',
        'role': UserRole.customer.name,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'deleted_at': null,
      });
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
      default:
        return 'Không thể xác thực. Vui lòng thử lại.';
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final authUserProvider = Provider<AppUser?>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is AuthSuccess ? state.user : null;
});