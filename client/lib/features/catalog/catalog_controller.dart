import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'catalog_models.dart';

class CatalogNotifier extends AsyncNotifier<List<CatalogProduct>> {
  String _term = '';

  @override
  Future<List<CatalogProduct>> build() => _fetch();

  Future<List<CatalogProduct>> _fetch() async {
    final dio = ref.read(dioProvider);
    final query = <String, dynamic>{};
    final term = _term.trim();
    if (term.isNotEmpty) query['search'] = term;
    final res = await dio.get<Map<String, dynamic>>('/api/catalog', queryParameters: query);
    final data = res.data!['data'] as List;
    return data
        .map((item) => CatalogProduct.fromJson(item as Map<String, dynamic>))
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
    AsyncNotifierProvider<CatalogNotifier, List<CatalogProduct>>(CatalogNotifier.new);

final catalogDetailProvider =
    FutureProvider.family<CatalogProduct, int>((ref, id) async {
  final res = await ref
      .read(dioProvider)
      .get<Map<String, dynamic>>('/api/catalog/$id');
  return CatalogProduct.fromJson(res.data!['data'] as Map<String, dynamic>);
});