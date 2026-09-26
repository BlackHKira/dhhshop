import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import 'catalog_controller.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(catalogDetailProvider(productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết sản phẩm')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 12),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(catalogDetailProvider(productId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (product) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProductImage(imageUrl: product.imageUrl, height: 260),
            const SizedBox(height: 12),
            Text(
              product.name,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (product.categoryName != null)
              Chip(
                label: Text(product.categoryName!),
                visualDensity: VisualDensity.compact,
              ),
            const SizedBox(height: 8),
            Text(
              formatVnd(product.price),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              _stockLabel(product.stockAvailable),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: (product.stockAvailable ?? 0) > 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
            ),
            const SizedBox(height: 16),
            if (product.specs.isNotEmpty) ...[
              Text('Thông số kỹ thuật',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: product.specs.entries
                      .map(
                        (entry) => ListTile(
                          dense: true,
                          title: Text(entry.key,
                              style: Theme.of(context).textTheme.bodyMedium),
                          trailing: Text(entry.value,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (product.description.isNotEmpty) ...[
              Text('Mô tả', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(product.description,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  String _stockLabel(int? stock) {
    if (stock == null) return 'Số lượng tồn: —';
    if (stock <= 0) return 'Hết hàng';
    if (stock <= 5) return 'Chỉ còn $stock sản phẩm';
    return 'Còn $stock sản phẩm';
  }
}

class ProductImage extends StatelessWidget {
  const ProductImage({super.key, this.imageUrl, this.height});

  final String? imageUrl;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.image_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          height: height,
          alignment: Alignment.center,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}