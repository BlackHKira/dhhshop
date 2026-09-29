import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Chạy với production Firebase hay Emulator Suite (`firebase emulators:start`)?
/// Default: production (mặc định của app). Đặt `--dart-define=USE_FIREBASE_EMULATOR=true`
/// khi dev/đồ án chạy emulator local.
const bool useFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATOR',
  defaultValue: false,
);

/// Host của emulator: Android emulator phải dùng `10.0.2.2` để trỏ về máy chủ;
/// web / desktop dùng `127.0.0.1`.
String get emulatorHost {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return '10.0.2.2';
  }
  return '127.0.0.1';
}

Future<void> ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) return;

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (useFirebaseEmulators) {
    try {
      await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    } catch (_) {
      // Emulator chưa bật thì vẫn dùng được app; các lời gọi auth/fs sẽ lỗi sau
    }
  }
}