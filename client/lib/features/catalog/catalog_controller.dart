import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/combine_latest.dart';
import 'catalog_models.dart';

/// Sản phẩm còn bán. Một cửa hàng nên không lọc `store_id`.
///
/// `deleted_at == null` khớp cả doc có field null lẫn doc thiếu field, nên
/// sản phẩm cũ tạo trước khi thêm `deleted_at` vẫn hiện.
final liveProductsProvider = StreamProvider<List<CatalogProduct>>((ref) {
  return FirebaseFirestore.instance
      .collection('products')
      .where('deleted_at', isEqualTo: null)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => CatalogProduct.fromFirestore(doc.id, doc.data()))
          .toList());
});

/// Tồn khả dụng theo productId — docID của `inventory` chính là productId
/// nên join chỉ cần tra theo `doc.id`, không phải đọc `product_id`.
///
/// Số tồn là thứ khách nhìn đầu tiên và cũng là thứ thay đổi nhiều nhất
/// (bán, nhập, huỷ đơn). Nghe trực tiếp collection nên mọi thay đổi đều
/// hiện ngay mà không cần kéo lại danh sách sản phẩm.
final stockByProductProvider = StreamProvider<Map<String, int>>((ref) {
  return FirebaseFirestore.instance.collection('inventory').snapshots().map(
        (snapshot) => <String, int>{
          for (final doc in snapshot.docs)
            doc.id: (doc.data()['stock_available'] as num?)?.toInt() ?? 0,
        },
      );
});

/// Tên danh mục theo docID. Danh mục đã xoá mềm không hiện.
final categoryNameByIdProvider = StreamProvider<Map<String, String>>((ref) {
  return FirebaseFirestore.instance
      .collection('categories')
      .where('deleted_at', isEqualTo: null)
      .snapshots()
      .map((snapshot) => <String, String>{
        for (final doc in snapshot.docs)
          doc.id: (doc.data()['name'] as String?) ?? '',
      });
});

/// Từ khoá tìm kiếm đang gõ.
class CatalogSearch extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;

  void clear() => state = '';
}

final catalogSearchProvider =
    NotifierProvider<CatalogSearch, String>(CatalogSearch.new);

/// Danh sách sản phẩm storefront: gộp tồn + danh mục, lọc theo từ khoá và
/// chỉ hiện món còn bán.
///
/// Lọc từ khoá ở client, không `where` xuống Firestore: dữ liệu đã nằm
/// sẵn trong bộ nhớ của listener, lọc tại đó tốn 0 read. Đổi lại là phải
/// tải toàn bộ catalog — với vài chục sản phẩm thì rẻ hơn hẳn độ trễ
/// một vòng ghi mỗi lần gõ phím.
final catalogProvider = Provider<AsyncValue<List<CatalogProduct>>>((ref) {
  final products = ref.watch(liveProductsProvider);
  final stock = ref.watch(stockByProductProvider);
  final categories = ref.watch(categoryNameByIdProvider);
  final term = ref.watch(catalogSearchProvider).trim().toLowerCase();

  return products.when(
    loading: () => const AsyncLoading<List<CatalogProduct>>(),
    error: (error, stack) => AsyncError<List<CatalogProduct>>(error, stack),
    data: (items) {
      // Chờ cả ba nguồn xong mới dựng danh sách, nếu không sẽ nhấp nháy:
      // một nhịp hiện "Còn —" rồi mới thay bằng số tồn thật.
      if (stock.isLoading || categories.isLoading) {
        return const AsyncLoading<List<CatalogProduct>>();
      }
      // Tồn và danh mục lỗi thì vẫn cho xem catalog: mất số tồn còn hơn
      // mất cả trang. Chỉ lỗi sản phẩm mới chặn trang.
      // `AsyncValue.value` ở lớp gốc là kiểu nullable, nên phải đi qua
      // `maybeWhen` chứ không đọc thẳng rồi dùng.
      final stockByProduct = stock.maybeWhen(
        data: (value) => value,
        orElse: () => const <String, int>{},
      );
      final nameByCategory = categories.maybeWhen(
        data: (value) => value,
        orElse: () => const <String, String>{},
      );

      return AsyncData(
        items
            .map((product) {
              // Gán vào biến cục bộ để Dart thu hẹp kiểu `String?` thành
              // `String` — thuộc tính của đối tượng không được thu hẹp kiểu.
              final categoryId = product.categoryId;
              return product.enriched(
                categoryName: categoryId == null
                    ? null
                    : nameByCategory[categoryId],
                stockAvailable: stockByProduct[product.id],
              );
            })
            .where((product) => product.isAvailable)
            .where(
              (product) =>
                  term.isEmpty ||
                  product.name.toLowerCase().contains(term) ||
                  product.sku.toLowerCase().contains(term),
            )
            .toList(),
      );
    },
  );
});

/// Ép nghe lại ba nguồn khi người dùng kéo để làm mới. Listener tự đồng bộ
/// nên về đúng nghĩa thì không cần, nhưng còn một đường để dữ liệu bị
/// sửa từ bên ngoài (Console, script seed) thì kéo là cách nhanh nhất.
void refetchCatalog(WidgetRef ref) {
  ref.invalidate(liveProductsProvider);
  ref.invalidate(stockByProductProvider);
  ref.invalidate(categoryNameByIdProvider);
}

/// Chi tiết một sản phẩm, nghe trực tiếp: đổi giá hay bán hết hàng đều cập
/// nhật ngay, không cần bấm làm mới.
final catalogDetailProvider =
    StreamProvider.family<CatalogProduct, String>((ref, id) async* {
  final fs = FirebaseFirestore.instance;
  final productRef = fs.collection('products').doc(id);

  final head = await productRef.snapshots().first;
  if (!head.exists) {
    throw Exception('Không tìm thấy sản phẩm.');
  }

  String? categoryName;
  final categoryId = head.data()?['category_id'] as String?;
  if (categoryId != null && categoryId.isNotEmpty) {
    final cat = await fs.collection('categories').doc(categoryId).get();
    categoryName = (cat.data()?['name'] as String?)?.trim();
  }

  // Tên danh mục và thông số đọc MỘT LẦN, không nghe. Cả hai chỉ đổi khi
  // seller sửa, mà lúc đó người dùng đang ở màn sửa chứ không phải màn
  // này. Nghe thêm hai nguồn chỉ để đổi một cái chip và một bảng là tốn
  // read không xứng — doc sản phẩm chứa ảnh base64, đọc lại nó tốn hơn
  // nhiều so với một doc thông số.
  final specsSnapshot = await productRef.collection('specs').get();
  final specs = {
    for (final spec in specsSnapshot.docs)
      spec.id: (spec.data()['value'] as String?) ?? '',
  };

  // Hai stream CÙNG kiểu nên gộp được: đổi giá, bán hết hàng, đổi trạng
  // thái bán đều cập nhật ngay mà không tải lại cả trang.
  final bundle = combineLatest(
    <Stream<DocumentSnapshot<Map<String, dynamic>>>>[
      productRef.snapshots(),
      fs.collection('inventory').doc(id).snapshots(),
    ],
  );

  yield* bundle.map((parts) {
    final data = parts[0].data();
    if (data == null) {
      throw Exception('Không tìm thấy sản phẩm.');
    }
    return CatalogProduct.fromFirestore(id, data).enriched(
      categoryName: categoryName,
      stockAvailable: (parts[1].data()?['stock_available'] as num?)?.toInt(),
      specs: specs,
    );
  });
});
