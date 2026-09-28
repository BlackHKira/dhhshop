import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Cấu hình Firebase của project `hddshop-bea07`.
///
/// ⚠️ Chạy `flutterfire configure` (sau khi `firebase login`) sẽ tự sinh file này
/// với giá trị thật của project. Các hằng số dưới đây là **placeholder** chỉ đủ
/// dùng khi chạy trên Emulator; đừng dùng key giả này cho production.
abstract final class AppFirebaseOptions {
  static const String _projectId = 'hddshop-bea07';
  static const String _appIdWeb = '1:000000000000:web:placeholder';
  static const String _appIdAndroid = '1:000000000000:android:placeholder';
  static const String _apiKey = 'AIzaSyPLACEHOLDER_REPLACE_BY_FLUTTERFIRE';
  static const String _messagingSenderId = '000000000000';
  static const String _storageBucket = 'hddshop-bea07.appspot.com';
  static const String _authDomain = 'hddshop-bea07.firebaseapp.com';

  static FirebaseOptions get current {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: _apiKey,
        appId: _appIdWeb,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        authDomain: _authDomain,
        storageBucket: _storageBucket,
      );
    }
    return const FirebaseOptions(
      apiKey: _apiKey,
      appId: _appIdAndroid,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      storageBucket: _storageBucket,
    );
  }
}