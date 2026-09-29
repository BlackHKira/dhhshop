import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../auth/auth_controller.dart';
import 'catalog_controller.dart';
import 'catalog_models.dart';

class StorefrontScreen extends ConsumerStatefulWidget {
  const StorefrontScreen({super.key});

  static const route = '/home';

  @override
  ConsumerState<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StorefrontScreenState extends ConsumerState<StorefrontScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    // Chỉ đổi từ khoá trong bộ nhớ, không gọi Firestore: listener đã giữ
    // sẵn toàn bộ catalog nên lọc tại đó tốn 0 read và phản hồi tức thì.
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) ref.read(catalogSearchProvider.notifier).update(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final user = ref.watch(authUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.electric_bolt,
                size: 18,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'DHHShop',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        actions: [
          // Chỉ seller/admin mới thấy nút quản lý sản phẩm.
          if (user?.isStaff() ?? false)
            IconButton(
              icon: const Icon(Icons.inventory_2_outlined),
              tooltip: 'Quản lý sản phẩm',
              onPressed: () => context.push('/seller'),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: user == null
                ? 'Đăng xuất'
                : 'Đăng xuất · ${user.displayName}',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm sản phẩm…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(catalogSearchProvider.notifier).clear();
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: catalog.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorView(
                message: error.toString(),
                onRetry: () => refetchCatalog(ref),
              ),
              data: (products) => products.isEmpty
                  ? _EmptyView(
                      onClear: () {
                        _searchController.clear();
                        ref.read(catalogSearchProvider.notifier).clear();
                      },
                    )
                  : RefreshIndicator(
                      onRefresh: () async => refetchCatalog(ref),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final crossAxisCount = width < 600
                              ? 2
                              : width < 900
                                  ? 3
                                  : width < 1300
                                      ? 4
                                      : width < 1700
                                          ? 5
                                          : 6;
                          final childAspectRatio = width < 600
                              ? 0.62
                              : width < 900
                                  ? 0.75
                                  : 0.85;
                          return GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(12),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: childAspectRatio,
                            ),
                            itemCount: products.length,
                            itemBuilder: (context, index) =>
                                _ProductCard(product: products[index]),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/product/${product.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: _ProductImage(imageData: product.imageData),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatVnd(product.price),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.stockAvailable == null
                        ? '—'
                        : 'Còn ${product.stockAvailable}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: (product.stockAvailable ?? 0) > 0
                              ? Colors.green.shade700
                              : Colors.grey,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({this.imageData});

  final String? imageData;

  @override
  Widget build(BuildContext context) {
    final data = imageData;
    if (data == null || data.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }
    try {
      final bytes = base64Decode(data);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      );
    } catch (_) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.broken_image_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48),
            const SizedBox(height: 12),
            const Text('Không tìm thấy sản phẩm nào.'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onClear, child: const Text('Xóa tìm kiếm')),
          ],
        ),
      ),
    );
  }
}