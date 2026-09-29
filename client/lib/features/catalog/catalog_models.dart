import 'package:cloud_firestore/cloud_firestore.dart';

/// DocID cố định của cửa hàng trong `settings/store`.
/// MVP chỉ có MỘT cửa hàng nên mọi doc khác không mang `store_id`
/// (xem `de-tai-tong-the.md` §"Vì sao bỏ store_id khỏi mọi doc").
const String kStoreDocId = 'store';

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.sku,
    required this.description,
    required this.price,
    required this.isAvailable,
    this.categoryId,
    this.categoryName,
    this.imageData,
    this.stockAvailable,
    this.deletedAt,
    this.specs = const {},
  });

  /// docID Firestore = slug của sản phẩm (chống trùng).
  final String id;
  final String? categoryId;
  final String? categoryName;
  final String name;
  final String sku;
  final String description;
  final double price;

  /// Ảnh base64 nén nội tuyến (`products.image_data`).
  final String? imageData;
  final bool isAvailable;

  /// Xoá mềm: `deleted_at` có giá trị nghĩa là sản phẩm đã bị ẩn.
  final Timestamp? deletedAt;

  /// Tồn khả dụng (join từ `inventory/{productId}` — public read).
  final int? stockAvailable;

  /// Thông số kỹ thuật (subcollection `products/{id}/specs`).
  final Map<String, String> specs;

  factory CatalogProduct.fromFirestore(String id, Map<String, dynamic> data) {
    return CatalogProduct(
      id: id,
      categoryId: data['category_id'] as String?,
      categoryName: null,
      name: (data['name'] as String?) ?? '',
      sku: (data['sku'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      imageData: data['image_data'] as String?,
      isAvailable: (data['is_available'] as bool?) ?? true,
      deletedAt: data['deleted_at'] as Timestamp?,
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
      categoryId: categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name,
      sku: sku,
      description: description,
      price: price,
      imageData: imageData,
      isAvailable: isAvailable,
      deletedAt: deletedAt,
      stockAvailable: stockAvailable ?? this.stockAvailable,
      specs: specs ?? this.specs,
    );
  }
}