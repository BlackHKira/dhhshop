# HDDShop — Ứng dụng bán hàng đồ điện tử (Flutter + Firebase)

Đồ án tốt nghiệp: **Xây dựng ứng dụng bán hàng đồ điện tử đa nền tảng bằng Flutter tích hợp AI Chatbot tư vấn mua sắm (Sử dụng Cloud & LLM API)**.

## Stack

- **Frontend:** Flutter (Android + Web) — `client/` — Riverpod, go_router, Firebase SDK (Auth + Firestore).
- **Backend:** Firebase (gói **Spark free**) — Authentication, Cloud Firestore + Security Rules. **Không deploy Functions/Storage** ngoài production.
- **Logic nghiệp vụ:** Flutter client-side + Security Rules (tuyến bảo mật chính).
- **Chatbot:** LLM API (Gemini REST) + RAG (embedding + cosine app-level).
- **CI/CD:** GitHub Actions → deploy Hosting + `firestore:rules` + `firestore:indexes`.

## Cấu trúc

```
client/            Flutter app (Android + Web)
functions/         Cloud Functions (Firebase) — chỉ dev/test trên Emulator (KHÔNG deploy)
firebase.json      Firebase project config (Hosting + Emulator)
firestore.rules    Security Rules
```

Tài liệu đặc tả: `C:\code\đồ án\de-tai-tong-the.md` + `phase.md`.

## Chạy cục bộ (Emulator Suite)

Yêu cầu: Node 20+ (`firebase-tools`), JDK 21+ (Firestore emulator bắt buộc Java ≥ 21).

```powershell
# 1) build functions rồi bật emulators (Auth 9099 · Firestore 8080 · Functions 5001 · Hosting 5000)
cd functions; npm.cmd install; npm.cmd run build; cd ..
firebase emulators:start

# 2) seed dữ liệu demo (gọi callable `seedDemoData` trên emulator, body {"data":{}}):
#    http://127.0.0.1:5001/hddshop-bea07/us-central1/seedDemoData

# 3) chạy app Flutter (mặc định kết nối emulator qua `USE_FIREBASE_EMULATOR=true`)
cd client; flutter run -d chrome
```

> `client/lib/firebase_options.dart` do `flutterfire configure` sinh ra (project `hddshop-bea07`,
> android app `hddshop.client` + web app `shop_client`). Muốn regenerate:
> `firebase login && firebase use hddshop-bea07 && flutterfire configure`.
> Emulator test nhanh (smoke): `firebase emulators:exec --only auth,firestore,functions `
> `"powershell -NoProfile -File <path>/emulator_smoke.ps1"` (script nằm ngoài repo, thư mục temp).
