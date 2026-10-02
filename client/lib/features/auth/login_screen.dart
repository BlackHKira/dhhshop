import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/validation.dart';
import 'auth_controller.dart';

/// Tài khoản demo cho sẵn ở `scripts/seed_production.mjs`. Bấm vào để điền
/// sẵn — trình bày cho GVHD thì không phải gõ tay, tránh sai ký tự.
const _demoAccounts = <({String label, String email, String pass})>[
  (label: 'Khách hàng', email: 'customer@demo.com', pass: 'customer123'),
  (label: 'Seller', email: 'seller@demo.com', pass: 'seller123'),
  (label: 'Admin', email: 'admin@demo.com', pass: 'admin123'),
];

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .login(_emailController.text, _passwordController.text);
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    final ok = email.contains('@');
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập email trước rồi bấm Quên mật khẩu.')),
      );
      return;
    }
    await ref.read(authControllerProvider.notifier).sendPasswordReset(email);
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          auth is AuthResetSent
              ? 'Đã gửi link đặt lại mật khẩu tới $email.'
              : auth is AuthError
                  ? auth.message
                  : 'Vui lòng thử lại.',
        ),
      ),
    );
  }

  void _fillDemo(String email, String pass) {
    // `reset()` xoá sạch nội dung các ô nên phải gọi TRƯỚC khi điền — gọi
    // sau thì nó xoá luôn thứ vừa điền.
    _formKey.currentState?.reset();
    _emailController.text = email;
    _passwordController.text = pass;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final loading = auth is AuthLoading;
    final error = auth is AuthError ? auth.message : null;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'DHHShop',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đăng nhập để xem đơn hàng, lịch sử mua và bảo hành.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: validateEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: TextButton(
                        onPressed: _forgotPassword,
                        child: const Text('Quên?'),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Nhập mật khẩu' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  // Lỗi chung đặt ngay dưới ô mật khẩu, sát chỗ vừa bấm.
                  // Lỗi riêng từng ô thì `validator` đã hiện inline rồi.
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              error,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Đăng nhập'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () => context.push('/register'),
                    child: const Text('Chưa có tài khoản? Đăng ký ngay'),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TÀI KHOẢN DEMO',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 8),
                          for (final a in _demoAccounts)
                            InkWell(
                              onTap: loading
                                  ? null
                                  : () => _fillDemo(a.email, a.pass),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${a.email} / ${a.pass}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Text(
                                      a.label,
                                      style: Theme.of(context).textTheme.labelSmall,
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.arrow_downward, size: 14),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kiểm tra email dùng chung cho cả hai màn — trả về thông điệp lỗi hoặc
/// `null` nếu hợp lệ.
