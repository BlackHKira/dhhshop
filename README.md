# Ứng dụng bán hàng đồ điện tử đa nền tảng bằng Flutter + Firebase

Đồ án tốt nghiệp: **Xây dựng ứng dụng bán hàng đồ điện tử đa nền tảng bằng Flutter tích hợp AI Chatbot tư vấn mua sắm (Sử dụng Cloud & LLM API)**.

## Stack

- **Frontend:** Flutter (Android + Web) — `client/` — Riverpod, go_router.
- **Backend:** Firebase serverless — Authentication, Cloud Firestore, Cloud Functions (Node.js/TypeScript), Storage, Hosting.
- **Chatbot:** LLM API (Gemini) + RAG (embedding + cosine app-level).
- **CI/CD:** GitHub Actions → Firebase deploy.

## Cấu trúc

```
client/            Flutter app (Android + Web)
functions/         Cloud Functions (Firebase) — logic nghiệp vụ
firebase.json      Firebase project config (Hosting + Functions + Emulator)
firestore.rules    Security Rules
```

Tài liệu đặc tả: `C:\code\đồ án\de-tai-tong-the.md` + `phase.md`.