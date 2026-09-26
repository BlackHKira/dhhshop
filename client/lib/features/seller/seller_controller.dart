import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../catalog/catalog_models.dart';

class CategoryItem {
  const CategoryItem({required this.id, required this.name});

  final int id;
  final String name;

  factory CategoryItem.fromJson(Map<String, dynamic> json) => CategoryItem(
        id: json['id'] as int,
        name: json['name'] as String,
      );
}

final sellerCategoriesProvider = FutureProvider<List<CategoryItem>>((ref) async {
  final res = await ref.read(dioProvider).get<Map<String, dynamic>>('/api/categories');
  final data = res.data!['data'] as List;
  return data
      .map((item) => CategoryItem.fromJson(item as Map<String, dynamic>))
      .toList();
});

class SellerProductsNotifier extends AsyncNotifier<List<CatalogProduct>> {
  @override
  Future<List<CatalogProduct>> build() => _fetch();

  Future<List<CatalogProduct>> _fetch() async {
    final res =
        await ref.read(dioProvider).get<Map<String, dynamic>>('/api/seller/products');
    final data = res.data!['data'] as List;
    return data
        .map((item) => CatalogProduct.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }

  Future<CatalogProduct> create({
    required String name,
    required String sku,
    required double price,
    required String description,
    int? categoryId,
    int? stock,
    List<Map<String, String>> specs = const [],
  }) async {
    final res = await ref.read(dioProvider).post<Map<String, dynamic>>(
          '/api/seller/products',
          data: _payload(
            name: name,
            sku: sku,
            price: price,
            description: description,
            categoryId: categoryId,
            stock: stock,
            specs: specs,
          ),
        );
    return CatalogProduct.fromJson(res.data!['data'] as Map<String, dynamic>);
  }

  Future<CatalogProduct> updateProduct(
    int id, {
    required String name,
    required String sku,
    required double price,
    required String description,
    int? categoryId,
    List<Map<String, String>> specs = const [],
  }) async {
    final res = await ref.read(dioProvider).put<Map<String, dynamic>>(
          '/api/seller/products/$id',
          data: _payload(
            name: name,
            sku: sku,
            price: price,
            description: description,
            categoryId: categoryId,
            specs: specs,
          ),
        );
    return CatalogProduct.fromJson(res.data!['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await ref.read(dioProvider).delete('/api/seller/products/$id');
    await refresh();
  }

  Future<String> uploadImage(int id, XFileBytes file) async {
    final form = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        file.bytes,
        filename: file.name,
      ),
    });
    final res = await ref.read(dioProvider).post<Map<String, dynamic>>(
          '/api/seller/products/$id/image',
          data: form,
        );
    return res.data!['image_url'] as String;
  }

  Map<String, dynamic> _payload({
    required String name,
    required String sku,
    required double price,
    required String description,
    int? categoryId,
    int? stock,
    List<Map<String, String>> specs = const [],
  }) {
    return {
      'category_id': categoryId,
      'sku': sku.trim(),
      'name': name.trim(),
      'description': description.trim(),
      'price': price,
      'stock': ?stock,
      'is_available': true,
      'specs': specs
          .where((s) => s['key']!.trim().isNotEmpty)
          .map((s) => {'key': s['key']!.trim(), 'value': s['value']!.trim()})
          .toList(),
    };
  }
}

class XFileBytes {
  const XFileBytes({required this.bytes, required this.name});

  final List<int> bytes;
  final String name;
}

final sellerProductsProvider =
    AsyncNotifierProvider<SellerProductsNotifier, List<CatalogProduct>>(
        SellerProductsNotifier.new);