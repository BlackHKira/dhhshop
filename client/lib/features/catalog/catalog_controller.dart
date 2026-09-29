import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalog_models.dart';

class CatalogNotifier extends AsyncNotifier<List<CatalogProduct>> {
  String _term = '';

  @override
  Future<List<CatalogProduct>> build() => _fetch();

  Future<List<CatalogProduct>> _fetch() async {
    final term = _term.trim().toLowerCase();
    final fs = FirebaseFirestore.instance;

    // Một cửa hàng → không lọc `store_id`. Sản phẩm đã xoá mềm thì loại ra
    // ở client: `deleted_at == null` mới hiện.
    final productsSnap = await fs
        .collection('products')
        .where('deleted_at', isEqualTo: null)
        .get();
    final invSnap = await fs.collection('inventory').get();
    final catSnap = await fs.collection('categories').get();

    final stockByProduct = {
      for (final doc in invSnap.docs)
        doc.data()['product_id'] as String?:
            (doc.data()['stock_available'] as num?)?.toInt(),
    };
    final categoryNameById = {
      for (final doc in catSnap.docs)
        doc.id: (doc.data()['name'] as String?) ?? '',
    };

    final products = productsSnap.docs
        .map((doc) {
          final data = doc.data();
          return CatalogProduct.fromFirestore(doc.id, data).enriched(
            categoryName: categoryNameById[data['category_id']],
            stockAvailable: stockByProduct[doc.id],
          );
        })
        .where((p) => p.isAvailable)
        .toList();

    if (term.isEmpty) return products;
    return products
        .where((p) =>
            p.name.toLowerCase().contains(term) ||
            p.sku.toLowerCase().contains(term))
        .toList();
  }

  Future<void> search(String term) async {
    if (term.trim() == _term) return;
    _term = term.trim();
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }
}

final catalogProvider =
    AsyncNotifierProvider<CatalogNotifier, List<CatalogProduct>>(
        CatalogNotifier.new);

final catalogDetailProvider =
    FutureProvider.family<CatalogProduct, String>((ref, id) async {
  final fs = FirebaseFirestore.instance;
  final doc = await fs.collection('products').doc(id).get();
  if (!doc.exists) throw Exception('Không tìm thấy sản phẩm.');
  final data = doc.data()!;

  final invDoc = await fs.collection('inventory').doc(id).get();
  final specsSnap = await doc.reference.collection('specs').get();

  String? categoryName;
  final categoryId = data['category_id'] as String?;
  if (categoryId != null) {
    final catDoc = await fs.collection('categories').doc(categoryId).get();
    categoryName = catDoc.data()?['name'] as String?;
  }

  return CatalogProduct.fromFirestore(doc.id, data).enriched(
    categoryName: categoryName,
    stockAvailable: (invDoc.data()?['stock_available'] as num?)?.toInt(),
    specs: {
      for (final spec in specsSnap.docs)
        spec.id: (spec.data()['value'] as String?) ?? '',
    },
  );
});