/// Chuẩn hoá và kiểm tra dữ liệu TRƯỚC khi ghi Firestore.
///
/// Gói Spark không có tầng server, nên Security Rules là lớp kiểm phía
/// sau DUY NHẤT. Nhưng Rules chỉ kiểm được kiểu dữ liệu và quan hệ giữa
/// các con số — không phân biệt "Tên  sản phẩm " với "Tên sản phẩm",
/// không biết chuỗi nào chứa HTML, và khi vi phạm chỉ trả về mã lỗi
/// `permission-denied` khó hiểu. Phần này chặn ở client để dữ liệu bẩn
/// không bao giờ lên Firestore và để người bán biết chính xác sai ở đâu.
/// Rules vẫn giữ vai trò chặn cuối nếu client bị can thiệp.
library;

/// Giới hạn độ dài — trùng các `.size()` đã kiểm trong `firestore.rules`.
/// Hai bên phải giống nhau, nếu lệch thì client cho qua những gì Rules
/// sẽ chặn, và người bán thấy lỗi không giải thích được.
const int kMaxNameLength = 120;
const int kMaxSkuLength = 40;
const int kMaxDescriptionLength = 2000;
const int kMaxCategoryNameLength = 60;
const int kMaxSpecKeyLength = 40;
const int kMaxSpecValueLength = 120;

/// Trần giá và tồn kho. Cùng giới hạn `.size()` của Firestore cho số, và
/// cũng đủ thực tế: 1 tỷ đồng / 1 triệu đơn vị.
const int kMaxPriceVnd = 1000000000;
const int kMaxStock = 1000000;

/// Firestore giới hạn 1 MiB cho MỘT document. Ảnh base64 phình ~4/3 so
/// với ảnh gốc, mà doc sản phẩm còn phải chứa tên, SKU, mô tả, thông số
/// — nên phần ảnh phải nhỏ hơn nhiều, không phải sát 1 MiB. Rules cũng
/// chặn đúng ngưỡng này.
const int kMaxImageBase64Length = 700000;

final RegExp _htmlTag = RegExp(r'<[^>]*>');
final RegExp _htmlEntity = RegExp(r'&(#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6}|[a-zA-Z]{2,10});');
final RegExp _controlChars = RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]');
final RegExp _allWhitespace = RegExp(r'\s+');
final RegExp _inlineSpace = RegExp(r'[^\S\n]+');
final RegExp _blankLines = RegExp(r'\n{3,}');

/// Bỏ thẻ HTML và entity, loại ký tự điều khiển, gộp khoảng trắng.
///
/// Bỏ thẻ HTML thay vì escape vì Flutter hiển thị bằng `Text`, không dựng
/// DOM — nhưng mô tả sản phẩm sau này sẽ đi vào prompt chatbot và có thể
/// render markdown. Cắt sạch ngay từ lúc ghi thì mọi nơi sau đó đều an
/// toàn mà không phải nhớ escape ở từng chỗ hiển thị.
String sanitizeText(String? raw, {bool keepNewlines = false}) {
  var s = (raw ?? '')
      .replaceAll(_htmlTag, ' ')
      .replaceAll(_htmlEntity, '')
      .replaceAll(_controlChars, ' ');
  if (keepNewlines) {
    // Giữ xuống dòng cho mô tả: gộp khoảng trắng ngang, rồi dồn các
    // dòng trống thành tối đa một dòng trống.
    s = s.replaceAll(_inlineSpace, ' ').replaceAll(_blankLines, '\n\n');
  } else {
    // Trường một dòng như tên, SKU, tên danh mục: xuống dòng phải bị gộp
    // thành khoảng trắng, nếu không tên sản phẩm có thể mang ký tự xuống
    // dòng và làm vỡ ô hiển thị một dòng.
    s = s.replaceAll(_allWhitespace, ' ');
  }
  return s.trim();
}

/// DocID chống trùng: giữ chữ cái (kể cả tiếng Việt có dấu) và chữ số,
/// thay phần còn lại bằng dấu gạch nối. `Điện thoại` → `điện-thoại`,
/// không phải `i-n-tho-i` như khi lọc theo `[a-z0-9]`.
String slugify(String value) {
  final slug = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty
      ? 'muc-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
      : slug;
}

/// DocID sản phẩm — chỉ ký tự ASCII, giữ NGUYÊN quy tắc của phiên bản cũ
/// (`[^a-z0-9]+` → `-`).
///
/// Cố ý không dùng [slugify] ở đây: [slugify] giữ chữ tiếng Việt, còn
/// docID sản phẩm thì đã có 100 doc trên Firestore được sinh bằng quy tắc
/// cũ. Đổi quy tắc là đổi docID, mà đổi docID nghĩa là mất sản phẩm cũ.
/// Ngoài ra [validateSku] đã chỉ cho phép ASCII nên hai quy tắc cho kết
/// quả giống nhau với mọi SKU hợp lệ — nhưng giữ riêng để không phụ thuộc
/// vào điều đó.
String productDocIdFromSku(String sku) {
  final slug = sku
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty
      ? 'product-${DateTime.now().millisecondsSinceEpoch}'
      : slug;
}

/// Đọc số kiểu Việt Nam: bỏ dấu chấm phân tách nghìn, chấp nhận cả dấu
/// phẩy. Trả `null` nếu không phải số hợp lệ.
int? parseAmount(String? raw) {
  final digits = sanitizeText(raw).replaceAll(RegExp(r'[.,\s]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

/// Bỏ khoảng trắng và ký tự lạ để so trùng SKU không bị soi bằng
/// "IP15 Pro" vs "IP15PRO" — hai SKU khác nhau về ý nghĩa.
String normalizeSku(String? raw) =>
    sanitizeText(raw).replaceAll(RegExp(r'[\s_]+'), '-').toUpperCase();

String? validateProductName(String? raw) {
  final v = sanitizeText(raw);
  if (v.isEmpty) return 'Vui lòng nhập tên sản phẩm.';
  if (v.length > kMaxNameLength) {
    return 'Tên sản phẩm tối đa $kMaxNameLength ký tự (hiện ${v.length}).';
  }
  return null;
}

String? validateSku(String? raw) {
  final v = sanitizeText(raw);
  if (v.isEmpty) return 'Vui lòng nhập mã SKU.';
  if (v.length > kMaxSkuLength) {
    return 'SKU tối đa $kMaxSkuLength ký tự.';
  }
  if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(v)) {
    return 'SKU chỉ gồm chữ, số và các ký tự . _ -';
  }
  return null;
}

String? validatePrice(String? raw) {
  final v = parseAmount(raw);
  if (v == null) return 'Giá phải là số, ví dụ 1.500.000';
  if (v < 0) return 'Giá không được âm.';
  if (v > kMaxPriceVnd) return 'Giá vượt quá giới hạn cho phép.';
  return null;
}

String? validateStock(String? raw) {
  if (sanitizeText(raw).isEmpty) return null;
  final v = parseAmount(raw);
  if (v == null) return 'Tồn kho phải là số nguyên.';
  if (v < 0) return 'Tồn kho không được âm.';
  if (v > kMaxStock) return 'Tồn kho vượt quá giới hạn cho phép.';
  return null;
}

String? validateDescription(String? raw) {
  final v = sanitizeText(raw, keepNewlines: true);
  if (v.length > kMaxDescriptionLength) {
    return 'Mô tả tối đa $kMaxDescriptionLength ký tự (hiện ${v.length}).';
  }
  return null;
}

String? validateCategoryName(String? raw) {
  final v = sanitizeText(raw);
  if (v.isEmpty) return 'Vui lòng nhập tên danh mục.';
  if (v.length > kMaxCategoryNameLength) {
    return 'Tên danh mục tối đa $kMaxCategoryNameLength ký tự.';
  }
  return null;
}

/// Một dòng thông số: tên không trống, cả hai vừa giới hạn độ dài.
String? validateSpec(String key, String value) {
  final k = sanitizeText(key);
  final v = sanitizeText(value);
  if (k.isEmpty) return null;
  if (k.length > kMaxSpecKeyLength) {
    return 'Tên thông số "${_clip(k)}" quá dài (tối đa $kMaxSpecKeyLength).';
  }
  if (v.length > kMaxSpecValueLength) {
    return 'Giá trị của "${_clip(k)}" quá dài (tối đa $kMaxSpecValueLength).';
  }
  return null;
}

String _clip(String s) => s.length <= 24 ? s : '${s.substring(0, 24)}…';
