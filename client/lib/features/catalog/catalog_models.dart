/// ID cửa hàng chính (theo seed `stores/main`).
const String kStoreId = 'main';

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.storeId,
    required this.name,
    required this.sku,
    required this.description,
    required this.price,
    required this.isAvailable,
    this.categoryId,
    this.categoryName,
    this.imageData,
    this.stockAvailable,
    this.specs = const {},
  });

  /// docID Firestore = slug của sản phẩm (chống trùng).
  final String id;
  final String storeId;
  final String? categoryId;
  final String? categoryName;
  final String name;
  final String sku;
  final String description;
  final double price;

  /// Ảnh base64 nén nội tuyến (`products.image_data` — Phase 4, F1 để trống).
  final String? imageData;
  final bool isAvailable;

  /// Tồn khả dụng (join từ `inventory/{storeId}_{productId}` — public read).
  final int? stockAvailable;

  /// Thông số kỹ thuật (subcollection `products/{id}/specs`).
  final Map<String, String> specs;

  factory CatalogProduct.fromFirestore(String id, Map<String, dynamic> data) {
    return CatalogProduct(
      id: id,
      storeId: (data['store_id'] as String?) ?? '',
      categoryId: data['category_id'] as String?,
      categoryName: null,
      name: (data['name'] as String?) ?? '',
      sku: (data['sku'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      imageData: data['image_data'] as String?,
      isAvailable: (data['is_available'] as bool?) ?? true,
      stockAvailable: null,
      specs: const {},
    );
  }

  CatalogProduct enriched({
    String? categoryName,
    int? stockAvailable,
    Map<String, String>? specs,
  }) {
    return CatalogProduct(
      id: id,
      storeId: storeId,
      categoryId: categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name,
      sku: sku,
      description: description,
      price: price,
      imageData: imageData,
      isAvailable: isAvailable,
      stockAvailable: stockAvailable ?? this.stockAvailable,
      specs: specs ?? this.specs,
    );
  }
}