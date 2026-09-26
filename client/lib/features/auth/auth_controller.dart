import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/token_storage.dart';
import 'models.dart';

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
    restore();
    return const AuthInitial();
  }

  Dio get _dio => ref.read(dioProvider);

  TokenStorage get _storage => ref.read(tokenStorageProvider);

  Future<void> restore() async {
    try {
      final token = await _storage.read();
      if (token == null || token.isEmpty) return;
      await fetchUser();
    } catch (_) {
      state = const AuthInitial();
    }
  }

  Future<void> fetchUser() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/user');
      state = AuthSuccess(AppUser.fromJson(res.data!));
    } on DioException catch (e) {
      await _storage.clear();
      state = AuthError(_message(e));
    }
  }

  Future<void> login(String email, String password) async {
    state = const AuthLoading();
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/login',
        data: {'email': email, 'password': password},
      );
      final token = res.data!['token'] as String;
      await _storage.write(token);
      state = AuthSuccess(AppUser.fromJson(res.data!['user'] as Map<String, dynamic>));
    } on DioException catch (e) {
      state = AuthError(_message(e));
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = const AuthLoading();
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
        },
      );
      final token = res.data!['token'] as String;
      await _storage.write(token);
      state = AuthSuccess(AppUser.fromJson(res.data!['user'] as Map<String, dynamic>));
    } on DioException catch (e) {
      state = AuthError(_message(e));
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/api/logout');
    } on DioException catch (_) {
      // ignore
    } finally {
      await _storage.clear();
      state = const AuthInitial();
    }
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return 'Không thể kết nối máy chủ. Vui lòng thử lại.';
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final authUserProvider = Provider<AppUser?>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is AuthSuccess ? state.user : null;
});