# DHHShop — Ứng dụng bán hàng đồ điện tử (Flutter + Firebase)

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
firestore.rules    Security Rules (tầng kiểm tra DUY NHẤT — không có server chạy lại phía sau)
firestore.indexes.json
```

Tài liệu đặc tả: `C:\code\đồ án\de-tai-tong-the.md` + `phase.md`.

## Chạy cục bộ (Emulator Suite)

Yêu cầu: Node 20+ (`firebase-tools`), JDK 21+ (Firestore emulator bắt buộc Java ≥ 21).

> Đường dẫn thư mục có dấu tiếng Việt làm Firestore Emulator (Java) không mở được
> `firestore.rules`. Tạo junction đường dẫn ASCII rồi chạy emulator từ đó
> (`cmd /c mklink /J C:\dhh-emu "<đường dẫn dự án>"`).

```powershell
# 1) bật emulators (Auth 9099 · Firestore 8888 · Hosting 5000)
firebase emulators:start

# 2) chạy app Flutter — bật flag emulator khi dev local
cd client; flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true
```

## Chạy với Firebase thật (production)

Yêu cầu 1 lần trên Firebase Console:
- **Authentication → Sign-in method → Email/Password** (bật).
- **Firestore Database → Create database** (`asia-southeast1`, production mode).
- Deploy rules + indexes: `firebase deploy --only firestore:rules,firestore:indexes --project hddshop-bea07`.

```powershell
# mặc định app nối production Firebase; không cần flag
cd client; flutter run -d chrome
```

> `client/lib/firebase_options.dart` do `flutterfire configure` sinh ra (project `hddshop-bea07`,
> android app `hddshop.client` + web app `shop_client`). Muốn regenerate:
> `firebase login && firebase use hddshop-bea07 && flutterfire configure`.
> Emulator test nhanh (smoke): `firebase emulators:exec --only auth,firestore,functions `
> `"powershell -NoProfile -File <path>/emulator_smoke.ps1"` (script nằm ngoài repo, thư mục temp).

## Seed dữ liệu demo lên Production

Dùng Admin SDK script (không cần deploy Functions). Cần Service Account key từ
**Firebase Console → Project settings → Service accounts → Generate new private key**.

```powershell
cd functions; npm.cmd install; cd ..
node scripts/seed_production.mjs `
  --service-account C:\path\key.json `
  --project hddshop-bea07 `
  --images-dir C:\path\seed_images
```

Script seed: 3 vai trò `admin` / `seller` / `customer` lưu tại `users/{uid}.role`,
`settings/store` (thông tin cửa hàng + tài khoản nhận tiền QR), `delivery_zones`,
danh mục, sản phẩm (+`specs`), `inventory` và tài khoản demo kèm role.
**Idempotent**: dữ liệu đã tồn tại → bỏ qua; email đã có → skip user.

> ⚠️ Không bao giờ commit file key (`*firebase-adminsdk*.json` đã có trong `.gitignore`).
