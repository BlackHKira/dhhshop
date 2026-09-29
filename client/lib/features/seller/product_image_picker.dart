import 'dart:convert';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/validation.dart';

/// Ngân sách cho ẢNH GỐC (đã nén, trước khi base64 hoá).
///
/// Đặt theo byte thô vì đó là thứ ta kiểm soát được: cứ mỗi lần vượt ngân
/// sách thì nén lại với chất lượng thấp hơn. `image_picker` đã thu nhỏ
/// sẵn về [kMaxDimension] px, nên phần lớn ảnh điện thoại rơi ngay
/// dưới ngưỡng và không tốn thêm vòng nén nào.
const int kImageTargetBytes = 260000;
const double kMaxDimension = 900;

/// Nén nhiều vòng thay vì một lần, giảm dần chất lượng và cạ kích thước
/// ở mỗi vòng. Dừng khi đã vừa ngân sách, nên ảnh nhỏ vẫn giữ nguyên
/// chất lượng gốc.
const List<({int quality, int minEdge})> _steps = [
  (quality: 80, minEdge: 600),
  (quality: 65, minEdge: 480),
  (quality: 50, minEdge: 400),
  (quality: 40, minEdge: 320),
];

/// Ảnh vẫn nặng hơn ngân sách sau khi đã nén hết mức.
class ImageTooLargeException implements Exception {
  const ImageTooLargeException([this.sizeBytes = 0, this.limitBytes = kImageTargetBytes]);

  final int sizeBytes;
  final int limitBytes;

  @override
  String toString() => 'Ảnh vẫn còn ${(sizeBytes / 1024).round()} KB '
      'sau khi nén, vượt giới hạn ${(limitBytes / 1024).round()} KB. '
      'Vui lòng chọn ảnh nhỏ hơn hoặc chụp ở độ phân giải thấp hơn.';

  String get message => toString();
}

/// Chọn ảnh từ thư viện, nén lại và trả về chuỗi base64 để ghi vào
/// `products.image_data`.
///
/// Trả `null` khi người dùng bỏ chọn (không phải lỗi).
///
/// Vì sao ảnh nằm trong doc Firestore mà không dùng Firebase Storage:
/// gói Spark không cho Storage trong đồ án này, và ảnh nằm trong doc thì
/// storefront đọc luôn được cùng lần đọc sản phẩm, không tốn thêm một vòng
/// request nào. Đổi lại là phải kiểm soát kích thước — xem
/// [kMaxImageBase64Length].
Future<String?> pickProductImage() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: kMaxDimension,
    maxHeight: kMaxDimension,
    imageQuality: 85,
    // Ảnh sản phẩm không cần định vị hay thông tin hệ thống; tắt để
    // không kéo theo metadata trong file.
    requestFullMetadata: false,
  );
  if (picked == null) return null;

  var bytes = await picked.readAsBytes();

  for (final step in _steps) {
    if (bytes.length <= kImageTargetBytes) break;
    final compressed =
        await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: step.minEdge,
      minHeight: step.minEdge,
      quality: step.quality,
      format: CompressFormat.jpeg,
    );
    // Nén không ăn hiệu quả (ảnh vốn đã nhỏ, hoặc backend web không can
    // thiệp) thì dừng thay vì quay vòng tới hết danh sách.
    if (compressed.isEmpty || compressed.length >= bytes.length) break;
    bytes = compressed;
  }

  if (bytes.length > kImageTargetBytes) {
    throw ImageTooLargeException(bytes.length, kImageTargetBytes);
  }

  final encoded = base64Encode(bytes);
  if (encoded.length > kMaxImageBase64Length) {
    throw ImageTooLargeException(bytes.length, kImageTargetBytes);
  }
  return encoded;
}

/// Kiểm tra lại ảnh đang có sẵn (khi sửa sản phẩm cũ, hoặc ảnh do script
/// seed nạp vào) có nằm trong giới hạn không.
bool isImageWithinLimit(String? base64Data) =>
    base64Data == null || base64Data.length <= kMaxImageBase64Length;

/// Bỏ ảnh khỏi sản phẩm.
const String kEmptyImage = '';
