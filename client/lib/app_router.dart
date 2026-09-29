import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/catalog/catalog_models.dart';
import 'features/catalog/product_detail_screen.dart';
import 'features/catalog/storefront_screen.dart';
import 'features/seller/seller_category_screen.dart';
import 'features/seller/seller_product_form_screen.dart';
import 'features/seller/seller_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      final state0 = ref.read(authControllerProvider);
      final loggedIn = state0 is AuthSuccess;
      final onAuthPage = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      if (!loggedIn && !onAuthPage) return '/login';
      if (loggedIn && onAuthPage) return StorefrontScreen.route;

      // Đây chỉ là chặn ở tầng UI cho giao diện gọn; Security Rules mới là
      // nơi thật sự chặn dữ liệu (seller không đọc/ghi được ngoài phạm vi).
      final inSellerArea = state.matchedLocation.startsWith('/seller');
      if (loggedIn && inSellerArea && !state0.user.isStaff()) {
        return StorefrontScreen.route;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: StorefrontScreen.route,
        builder: (context, state) => const StorefrontScreen(),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) => ProductDetailScreen(
          productId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: SellerScreen.route,
        builder: (context, state) => const SellerScreen(),
      ),
      GoRoute(
        path: SellerCategoryScreen.route,
        builder: (context, state) => const SellerCategoryScreen(),
      ),
      GoRoute(
        path: '/seller/product',
        builder: (context, state) => const SellerProductFormScreen(),
      ),
      GoRoute(
        path: '/seller/product/:id',
        builder: (context, state) {
          final product = state.extra;
          return SellerProductFormScreen(
            product: product is CatalogProduct ? product : null,
          );
        },
      ),
    ],
  );
});

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}