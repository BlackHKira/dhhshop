import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/validation.dart';
import '../catalog/catalog_models.dart';

/// ═══════════════════════════════════════════════════════════════
///  DANH MỤC
/// ═══════════════════════════════════════════════════════════════

class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    this.sortOrder = 0,
    this.isActive = true,
    this.deletedAt,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;

  /// Xoá mềm: có giá trị nghĩa là danh mục đã bị ẩn. Sản phẩm cũ vẫn
  /// trỏ tới danh mục này nên không xoá cứng.
  final Timestamp? deletedAt;

  bool get isLive => deletedAt == null;

  factory CategoryItem.fromFirestore(String id, Map<String, dynamic> data) {
    return CategoryItem(
      id: id,
      name: (data['name'] as String?) ?? '',
      sortOrder: (data['sort_order'] as num?)?.toInt() ?? 0,
      isActive: (data['is_active'] as bool?) ?? true,
      deletedAt: data['deleted_at'] as Timestamp?,
    );
  }
}

/// Danh mục còn hiện — nguồn cho dropdown chọn danh mục trong form SP.
final activeCategoriesProvider = StreamProvider<List<CategoryItem>>((ref) {
  return FirebaseFirestore.instance
      .collection('categories')
      .where('deleted_at', isEqualTo: null)
      .snapshots()
      .map(_toItems);
});

/// Tất cả danh mục kể cả đã ẩn — nguồn cho màn hình quản lý.
final allCategoriesProvider = StreamProvider<List<CategoryItem>>((ref) {
  return FirebaseFirestore.instance
      .collection('categories')
      .snapshots()
      .map(_toItems);
});

List<CategoryItem> _toItems(QuerySnapshot<Map<String, dynamic>> snapshot) {
  final items = snapshot.docs
      .map((doc) => CategoryItem.fromFirestore(doc.id, doc.data()))
      .toList();
  items.sort((a, b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
  });
  return items;
}

/// Ghi danh mục. `AsyncNotifier<void>` vì mọi thao tác đều là lệnh, không có
/// trạng thái cần đọc lại — màn hình tự giữ cờ đang lưu.
class CategoryAdmin extends AsyncNotifier<void> {
  @override
  void build() {}

  /// Tạo danh mục mới, docID = slug(tên) nên hai lần gõ cùng một tên chỉ
  /// tạo ra một danh mục.
  Future<String> create({required String name, int sortOrder = 0}) async {
    final clean = sanitizeText(name);
    _require(validateCategoryName(clean));

    final fs = FirebaseFirestore.instance;
    final id = slugify(clean);
    final ref = fs.collection('categories').doc(id);

    final existing = await ref.get();
    if (existing.exists) {
      // Không nuốt im lặng: nếu ghi đè thì sản phẩm đang dùng danh mục này
      // bị đổi tên ngoài ý muốn.
      throw StateError(
        'Danh mục "${(existing.data()?['name'] as String?) ?? id}" đã tồn tại.',
      );
    }

    await ref.set({
      'name': clean,
      'sort_order': sortOrder,
      'is_active': true,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'deleted_at': null,
    });
    return id;
  }

  /// Đổi tên. docID giữ nguyên để không phải sửa lại `category_id` của mọi
  /// sản phẩm đang dùng danh mục.
  Future<void> rename(String id, {required String name, int? sortOrder}) async {
    final clean = sanitizeText(name);
    _require(validateCategoryName(clean));

    await FirebaseFirestore.instance.collection('categories').doc(id).update({
      'name': clean,
      'sort_order': ?sortOrder,
      'updated_at': FieldValue.serverTimestamp(),    });
  }

  /// Ẩn / hiện lại. Không xoá cứng vì sản phẩm cũ vẫn tham chiếu docID này.
  Future<void> setDeleted(String id, {required bool deleted}) async {
    await FirebaseFirestore.instance.collection('categories').doc(id).update({
      'deleted_at': deleted ? FieldValue.serverTimestamp() : null,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}

/// Báo lỗi kiểm tra dữ liệu dưới dạng thông điệp cho người dùng đọc được.
void _require(String? error) {
  if (error != null) throw StateError(error);
}

final categoryAdminProvider =
    AsyncNotifierProvider<CategoryAdmin, void>(CategoryAdmin.new);

/// Số sản phẩm còn bán theo từng danh mục — để cảnh báo trước khi ẩn một
/// danh mục, tránh việc sản phẩm mất nhãn ngay lúc bấm.
final categoryUsageProvider = StreamProvider<Map<String, int>>((ref) {
  return FirebaseFirestore.instance
      .collection('products')
      .where('deleted_at', isEqualTo: null)
      .snapshots()
      .map((snapshot) {
    final counts = <String, int>{};
    for (final doc in snapshot.docs) {
      final id = doc.data()['category_id'] as String?;
      if (id != null && id.isNotEmpty) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return counts;
  });
});

/// ═══════════════════════════════════════════════════════════════
///  TỒN KHO — điều chỉnh tay (nhập hàng / kiểm kho / trả hàng)
/// ═══════════════════════════════════════════════════════════════

/// Số tồn của một sản phẩm, đọc từ `inventory/{productId}`.
class StockRow {
  const StockRow({
    required this.productId,
    required this.productName,
    required this.stockOnHand,
    required this.stockReserved,
    required this.stockAvailable,
  });

  final String productId;
  final String productName;
  final int stockOnHand;
  final int stockReserved;
  final int stockAvailable;

  factory StockRow.fromFirestore(
    String id,
    Map<String, dynamic> inv,
    String name,
  ) {
    int read(String key) => (inv[key] as num?)?.toInt() ?? 0;
    return StockRow(
      productId: id,
      productName: name,
      stockOnHand: read('stock_on_hand'),
      stockReserved: read('stock_reserved'),
      stockAvailable: read('stock_available'),
    );
  }
}

/// `type` hợp lệ — trùng `validMovement()` trong `firestore.rules`.
enum MovementType {
  purchase('purchase', 'Nhập hàng'),
  adjustment('adjustment', 'Kiểm kho'),
  returnIn('return', 'Trả hàng'),
  saleOnline('sale_online', 'Bán online'),
  reserve('reserve', 'Giữ chỗ'),
  release('release', 'Nhuyên đơn');

  const MovementType(this.wire, this.label);
  final String wire;
  final String label;
}

final stockRowsProvider = StreamProvider<List<StockRow>>((ref) {
  return FirebaseFirestore.instance
      .collection('inventory')
      .snapshots()
      .asyncMap((invSnap) async {
    final names = <String, String>{};
    for (final doc in (await FirebaseFirestore.instance
            .collection('products')
            .get())
        .docs) {
      names[doc.id] = (doc.data()['name'] as String?) ?? doc.id;
    }
    final rows = invSnap.docs
        .map((doc) => StockRow.fromFirestore(doc.id, doc.data(), names[doc.id] ?? doc.id))
        .toList();
    rows.sort((a, b) => a.productName.compareTo(b.productName));
    return rows;
  });
});

/// Lịch sử biến động tồn, mới nhất trước.
final stockMovementsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('stock_movements')
      .orderBy('created_at', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map((d) => d.data()).toList());
});

/// Điều chỉnh tồn kho bằng tay.
///
/// Ghi bằng transaction vì phải giữ đúng bất biến hiệu mà
/// `availableFollowsDelta()` kiểm: đọc tồn cũ rồi mới tính tồn mới, nếu
/// hai người cùng nhập hàng mà đọc rồi ghi bằng `set` thì người sau ghi đè
/// số của người trước và tổng tồn sai — mà bất biến hiệu lại vẫn hợp lệ
/// vì so với chính số vừa ghi.
///
/// `delta` dương là tăng (nhập hàng), âm là giảm (trả hàng). Ghi kèm một
/// dòng `stock_movements` vì Rules không cho sửa / xoá dòng nhật ký.
///
/// `onChanged` được gọi sau khi ghi xong để màn hình làm mới danh sách.
/// Truyền callback thay vì `Ref` để hàm này không phụ thuộc Riverpod —
/// gọi được từ dialog, từ nút AppBar, hay từ test.
Future<void> adjustStock({
  required String productId,
  required int delta,
  required MovementType type,
  required String reason,
  required void Function() onChanged,
}) async {
  if (delta == 0) {
    throw StateError('Số lượng không được bằng 0.');
  }
  final cleanReason = sanitizeText(reason);
  if (cleanReason.isEmpty) {
    throw StateError('Phải ghi lý do điều chỉnh tồn kho.');
  }
  if (cleanReason.length > kMaxReasonLength) {
    throw StateError('Lý do tối đa $kMaxReasonLength ký tự.');
  }

  final fs = FirebaseFirestore.instance;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    throw StateError('Chưa đăng nhập nên không điều chỉnh được tồn kho.');
  }

  final invRef = fs.collection('inventory').doc(productId);
  await fs.runTransaction((txn) async {
    final snap = await txn.get(invRef);
    final inv = snap.data();
    if (inv == null) {
      throw StateError('Sản phẩm này chưa có dòng tồn kho để điều chỉnh.');
    }
    int read(String key) => (inv[key] as num?)?.toInt() ?? 0;
    final onHand = read('stock_on_hand');
    final reserved = read('stock_reserved');
    final nextOnHand = onHand + delta;

    // Rules chỉ chặn `stock_on_hand >= 0`, nhưng tồn thực không thể âm —
    // và âm thì `stock_reserved <= stock_on_hand` cũng đỏ. Báo lỗi rõ ràng
    // ở đây tốt hơn để user nhìn thấy `permission-denied`.
    if (nextOnHand < 0) {
      throw StateError(
        'Tồn thực hiện tại là $onHand, không thể giảm $delta đơn vị.',
      );
    }
    if (reserved > nextOnHand) {
      throw StateError(
        'Còn $reserved đơn vị đang được giữ chỗ cho đơn chưa xác nhận, '
        'nên tồn thực tối thiểu là $reserved.',
      );
    }

    final now = FieldValue.serverTimestamp();
    txn.update(invRef, {
      'stock_on_hand': nextOnHand,
      'stock_available': nextOnHand - reserved,
      'updated_at': now,
    });
    // Nhật ký ghi `quantity` là số đơn vị biến động (âm khi trả hàng) và
    // `note` là lý do cụ thể — Rules chỉ bắt buộc `reason` khác rỗng, phần
    // ghi rõ hơn thì để ở client.
    txn.set(fs.collection('stock_movements').doc(), {
      'product_id': productId,
      'type': type.wire,
      'quantity': delta,
      'reason': cleanReason,
      'note': cleanReason,
      'actor_id': uid,
      'order_id': null,
      'created_at': now,
    });
  });
  onChanged();
}

/// ═══════════════════════════════════════════════════════════════
///  SẢN PHẨM
/// ═══════════════════════════════════════════════════════════════

class SellerProductsNotifier extends AsyncNotifier<List<CatalogProduct>> {
  Future<List<CatalogProduct>> _fetch() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('deleted_at', isEqualTo: null)
        .get();
    final stockSnap =
        await FirebaseFirestore.instance.collection('inventory').get();
    final stockByProduct = {
      for (final doc in stockSnap.docs)
        doc.id: (doc.data()['stock_available'] as num?)?.toInt() ?? 0,
    };
    return snapshot.docs
        .map((doc) => CatalogProduct.fromFirestore(doc.id, doc.data())
            .enriched(stockAvailable: stockByProduct[doc.id]))
        .toList();
  }

  @override
  Future<List<CatalogProduct>> build() => _fetch();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }

  /// Tạo sản phẩm mới. Một lần ghi batch gồm: doc sản phẩm + specs +
  /// tồn kho + dòng nhật kho.
  Future<CatalogProduct> create({
    required String name,
    required String sku,
    required double price,
    required String description,
    required String categoryId,
    int? stock,
    String? imageData,
    List<Map<String, String>> specs = const [],
  }) async {
    final fs = FirebaseFirestore.instance;
    final cleanName = sanitizeText(name);
    final cleanSku = sanitizeText(sku).toUpperCase();
    final cleanDescription = sanitizeText(description, keepNewlines: true);
    final cleanSpecs = _cleanSpecs(specs);

    _require(validateProductName(cleanName));
    _require(validateSku(cleanSku));
    _require(validatePrice(price.toInt().toString()));
    _require(validateDescription(cleanDescription));
    _require(validateCategoryName(categoryId));
    _require(validateStock(stock?.toString()));
    _requireImage(imageData);

    final id = productDocIdFromSku(cleanSku);
    final productRef = fs.collection('products').doc(id);

    // docID là slug(SKU) nên báo trùng SKU cũng là báo trùng docID. Nếu
    // không kiểm, `set` sẽ ĐÈ lên sản phẩm đang bán: mất ảnh, mất thông
    // số, mất lịch sử — mà không có bất kỳ lỗi nào được ném ra.
    final existing = await productRef.get();
    if (existing.exists) {
      throw StateError(
        'SKU "$cleanSku" đã tồn tại (sản phẩm '
        '"${(existing.data()?['name'] as String?) ?? id}").',
      );
    }

    final batch = fs.batch();
    final now = FieldValue.serverTimestamp();
    batch.set(productRef, {
      'category_id': categoryId,
      'sku': cleanSku,
      'name': cleanName,
      'description': cleanDescription,
      'price': price,
      'image_data': imageData ?? '',
      'is_available': true,
      'sort_order': 0,
      'embedding': const <dynamic>[],
      'deleted_at': null,
      'created_at': now,
      'updated_at': now,
    });
    _writeSpecs(batch, productRef, cleanSpecs);
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
    // Mọi biến động tồn phải có dòng nhật ký kèm lý do và người thao tác,
    // vì stock_movements không sửa / không xoá được. Tạo sản phẩm kèm
    // tồn đầu là một lần nhập kho thật, không ghi thì tổng nhập xuất lệch
    // với tồn và admin không còn cách đối chiếu.
    if ((stock ?? 0) > 0) {
      batch.set(fs.collection('stock_movements').doc(), {
        'product_id': id,
        'type': 'purchase',
        'quantity': stock,
        'reason': 'Nhập kho ban đầu khi tạo sản phẩm',
        'actor_id': _currentUid(),
        'order_id': null,
        'created_at': now,
      });
    }

    await batch.commit();
    await refresh();
    return _readProduct(id);
  }

  Future<CatalogProduct> updateProduct(
    String id, {
    required String name,
    required String sku,
    required double price,
    required String description,
    required String categoryId,
    String? imageData,
    List<Map<String, String>> specs = const [],
  }) async {
    final fs = FirebaseFirestore.instance;
    final productRef = fs.collection('products').doc(id);

    final cleanName = sanitizeText(name);
    final cleanDescription = sanitizeText(description, keepNewlines: true);
    final cleanSpecs = _cleanSpecs(specs);

    _require(validateProductName(cleanName));
    _require(validateSku(sku));
    _require(validatePrice(price.toInt().toString()));
    _require(validateDescription(cleanDescription));
    _require(validateCategoryName(categoryId));
    _requireImage(imageData);

    final specsRef = productRef.collection('specs');
    final existingSpecs = await specsRef.get();

    final batch = fs.batch();
    batch.update(productRef, {
      'category_id': categoryId,
      'sku': sanitizeText(sku).toUpperCase(),
      'name': cleanName,
      'description': cleanDescription,
      'price': price,
      'image_data': ?imageData,
      'updated_at': FieldValue.serverTimestamp(),
    });
    _writeSpecs(batch, productRef, cleanSpecs);
    // Dòng thông số bị gỡ trên form phải bị xoá thật, nếu không chỉ ghi
    // thêm mà không xoá thì thông số cũ vẫn còn trong Firestore và lọt lên
    // trang chi tiết.
    for (final doc in existingSpecs.docs) {
      if (!cleanSpecs.containsKey(doc.id)) {
        batch.delete(specsRef.doc(doc.id));
      }
    }

    await batch.commit();
    await refresh();
    return _readProduct(id);
  }

  /// Xoá mềm: ẩn khỏi storefront, giữ lịch sử đơn.
  Future<void> delete(String id) async {
    await FirebaseFirestore.instance
        .collection('products')
        .doc(id)
        .update({'deleted_at': FieldValue.serverTimestamp()});
    await refresh();
  }

  void _writeSpecs(
    WriteBatch batch,
    DocumentReference<Map<String, dynamic>> productRef,
    Map<String, String> specs,
  ) {
    final specsRef = productRef.collection('specs');
    for (final entry in specs.entries) {
      batch.set(specsRef.doc(entry.key), {'value': entry.value});
    }
  }

  /// Lọc và chuẩn hoá dòng thông số: bỏ dòng trống, cắt khoảng trắng, cắt
  /// khoá thành docID an toàn. `specs/{docID}` nên khoá chỉ nên là ký tự
  /// đơn giản — Firestore cấm `/` trong docID.
  Map<String, String> _cleanSpecs(List<Map<String, String>> raw) {
    final out = <String, String>{};
    for (final row in raw) {
      final key = slugify(sanitizeText(row['key'] ?? ''));
      if (key.isEmpty) continue;
      _require(validateSpec(row['key'] ?? '', row['value'] ?? ''));
      out[key] = sanitizeText(row['value'] ?? '');
    }
    return out;
  }

  String _currentUid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Chưa đăng nhập nên không ghi được nhật ký tồn kho.');
    }
    return uid;
  }

  void _requireImage(String? imageData) {
    if (imageData != null && imageData.length > kMaxImageBase64Length) {
      throw StateError(
        'Ảnh quá lớn (${(imageData.length / 1024).round()} KB). '
        'Giới hạn Firestore là 1 MiB cho mỗi tài liệu.',
      );
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

final sellerProductsProvider =
    AsyncNotifierProvider<SellerProductsNotifier, List<CatalogProduct>>(
        SellerProductsNotifier.new);
