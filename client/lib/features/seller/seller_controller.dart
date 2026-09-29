import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalog/catalog_models.dart';

class CategoryItem {
  const CategoryItem({required this.id, required this.name});

  final String id;
  final String name;
}

final sellerCategoriesProvider = FutureProvider<List<CategoryItem>>((ref) async {
  final snapshot =
      await FirebaseFirestore.instance.collection('categories').get();
  return snapshot.docs
      .map((doc) => CategoryItem(
            id: doc.id,
            name: (doc.data()['name'] as String?) ?? '',
          ))
      .toList();
});

class SellerProductsNotifier extends AsyncNotifier<List<CatalogProduct>> {
  @override
  Future<List<CatalogProduct>> build() => _fetch();

  Future<List<CatalogProduct>> _fetch() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('deleted_at', isEqualTo: null)
        .get();
    final stockSnap =
        await FirebaseFirestore.instance.collection('inventory').get();
    final stockByProduct = {
      for (final doc in stockSnap.docs)
        doc.data()['product_id'] as String?:
            (doc.data()['stock_available'] as num?)?.toInt(),
    };
    return snapshot.docs
        .map((doc) => CatalogProduct.fromFirestore(doc.id, doc.data())
            .enriched(stockAvailable: stockByProduct[doc.id]))
        .toList();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }

  /// SP mới: docID = slug(SKU) — batch (product + specs + inventory).
  Future<CatalogProduct> create({
    required String name,
    required String sku,
    required double price,
    required String description,
    String? categoryId,
    int? stock,
    List<Map<String, String>> specs = const [],
  }) async {
    final fs = FirebaseFirestore.instance;
    final id = _slugify(sku);
    final productRef = fs.collection('products').doc(id);

    // Rules đòi `category_id is string`; form đã chặn nhưng controller
    // chặn lần nữa để không gửi write chắc chắn bị từ chối.
    if (categoryId == null || categoryId.isEmpty) {
      throw StateError('Sản phẩm phải có danh mục.');
    }

    final batch = fs.batch();
    final now = FieldValue.serverTimestamp();
    batch.set(productRef, {
      'category_id': categoryId,
      'sku': sku.trim(),
      'name': name.trim(),
      'description': description.trim(),
      'price': price,
      'image_data': '',
      'is_available': true,
      'sort_order': 0,
      'embedding': <dynamic>[],
      'deleted_at': null,
      'created_at': now,
      'updated_at': now,
    });
    _writeSpecs(batch, productRef, specs);
    // docID của `inventory` là productId (không còn tiền tố storeId).
    batch.set(
      fs.collection('inventory').doc(id),
      {
        'product_id': id,
        'stock_on_hand': stock ?? 0,
        'stock_reserved': 0,
        'stock_available': stock ?? 0,
        'updated_at': now,
      },
    );

    await batch.commit();
    return _readProduct(id);
  }

  Future<CatalogProduct> updateProduct(
    String id, {
    required String name,
    required String sku,
    required double price,
    required String description,
    String? categoryId,
    List<Map<String, String>> specs = const [],
  }) async {
    final fs = FirebaseFirestore.instance;
    final productRef = fs.collection('products').doc(id);

    if (categoryId == null || categoryId.isEmpty) {
      throw StateError('Sản phẩm phải có danh mục.');
    }

    final batch = fs.batch();
    batch.update(productRef, {
      'category_id': categoryId,
      'sku': sku.trim(),
      'name': name.trim(),
      'description': description.trim(),
      'price': price,
      'updated_at': FieldValue.serverTimestamp(),
    });
    _writeSpecs(batch, productRef, specs);

    await batch.commit();
    return _readProduct(id);
  }

  Future<void> delete(String id) async {
    // Soft delete: ẩn khỏi storefront, giữ lịch sử đơn.
    await FirebaseFirestore.instance
        .collection('products')
        .doc(id)
        .update({'deleted_at': FieldValue.serverTimestamp()});
    await refresh();
  }

  void _writeSpecs(
    WriteBatch batch,
    DocumentReference<Map<String, dynamic>> productRef,
    List<Map<String, String>> specs,
  ) {
    final specsRef = productRef.collection('specs');
    for (final spec in specs) {
      final key = spec['key']?.trim() ?? '';
      final value = spec['value']?.trim() ?? '';
      if (key.isEmpty) continue;
      batch.set(specsRef.doc(key), {'value': value});
    }
  }

  Future<CatalogProduct> _readProduct(String id) async {
    final fs = FirebaseFirestore.instance;
    final doc = await fs.collection('products').doc(id).get();
    final invDoc = await fs.collection('inventory').doc(id).get();
    final specsSnap = await doc.reference.collection('specs').get();
    return CatalogProduct.fromFirestore(doc.id, doc.data()!).enriched(
      stockAvailable: (invDoc.data()?['stock_available'] as num?)?.toInt(),
      specs: {
        for (final spec in specsSnap.docs)
          spec.id: (spec.data()['value'] as String?) ?? '',
      },
    );
  }
}

String _slugify(String value) {
  final slug = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'product-${DateTime.now().millisecondsSinceEpoch}' : slug;
}

final sellerProductsProvider =
    AsyncNotifierProvider<SellerProductsNotifier, List<CatalogProduct>>(
        SellerProductsNotifier.new);