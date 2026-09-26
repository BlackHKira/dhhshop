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
    this.imageUrl,
    this.stockAvailable,
    this.specs = const {},
  });

  final int id;
  final int storeId;
  final int? categoryId;
  final String? categoryName;
  final String name;
  final String sku;
  final String description;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  final int? stockAvailable;
  final Map<String, String> specs;

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    return CatalogProduct(
      id: json['id'] as int,
      storeId: json['store_id'] as int,
      categoryId: category is Map ? category['id'] as int? : null,
      categoryName: category is Map ? category['name'] as String? : null,
      name: json['name'] as String,
      sku: json['sku'] as String,
      description: (json['description'] as String?) ?? '',
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      stockAvailable: json['stock_available'] as int?,
      specs: (json['specs'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, value.toString())) ??
          const {},
    );
  }
}