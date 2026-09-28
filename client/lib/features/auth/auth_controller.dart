import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.roles = const {},
  });

  final String uid;
  final String name;
  final String email;
  final Set<String> roles;

  bool hasRole(String role) => roles.contains(role);

  bool isStoreStaff() =>
      hasRole('system_admin') ||
      hasRole('seller') ||
      hasRole('shipper') ||
      hasRole('viewer');
}

const Set<String> _knownRoles = {
  'system_admin',
  'customer',
  'seller',
  'shipper',
  'viewer',
};

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
      final idToken = await user.getIdTokenResult();
      final claims = idToken.claims ?? const <String, dynamic>{};
      final roles = <String>{
        for (final claim in _knownRoles)
          if (claims[claim] == true) claim,
      };
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      state = AuthSuccess(
        AppUser(
          uid: user.uid,
          name: (data['name'] as String?) ?? user.displayName ?? '',
          email: user.email ?? (data['email'] as String?) ?? '',
          roles: roles,
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
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name.trim(),
        'email': user.email ?? '',
        'phone': '',
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
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

final authLoadingProvider = Provider<bool>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is AuthLoading;
});