import 'dart:async';

/// Gộp nhiều stream lại thành một: phát ra mỗi khi BẤT KỲ stream nào có
/// giá trị mới, kèm giá trị mới nhất của những stream còn lại.
///
/// Tự viết vì Dart SDK không có sẵn `Stream.zip` (đó là ý niệm của RxJS /
/// Reactor, không nằm trong `dart:async`), cũng không có hàm tương đương.
///
/// Chỉ phát khi đã có giá trị của TẤT CẢ các nhánh — nếu phát sớm thì lần
/// đầu tiên sẽ mang dữ liệu `null` chỗ chưa tới, và màn hình hiện "Còn —"
/// rồi mới nhảy sang số thật.
Stream<List<T>> combineLatest<T>(List<Stream<T>> streams) {
  if (streams.isEmpty) {
    throw ArgumentError('combineLatest cần ít nhất một stream.');
  }
  final slots = List<T?>.filled(streams.length, null);

  return Stream<List<T>>.multi((controller) {
    final subscriptions = <StreamSubscription<T>>[];
    for (var i = 0; i < streams.length; i++) {
      subscriptions.add(
        streams[i].listen(
          (value) {
            slots[i] = value;
            if (slots.every((slot) => slot != null)) {
              controller.add(List<T>.of(slots.cast<T>()));
            }
          },
          onError: controller.addError,
        ),
      );
    }
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
  });
}
