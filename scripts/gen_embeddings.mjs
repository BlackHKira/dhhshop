// Sinh embedding cho catalog để chatbot RAG (F4) truy hồi được.
//
//   node --env-file=.env scripts/gen_embeddings.mjs --project hddshop-bea07
//   node --env-file=.env scripts/gen_embeddings.mjs --project hddshop-bea07 --limit 10
//   node --env-file=.env scripts/gen_embeddings.mjs --project hddshop-bea07 --dry-run
//
// Vì sao cần script này:
//   - `products.embedding` mặc định là mảng rỗng, nên RAG không có gì để
//     so khớp. Mỗi lần thêm / sửa mô tả sản phẩm lại phải sinh lại.
//   - Firestore không có kiểu vector, nên embedding lưu thành mảng số thật
//     và **cosine similarity tính ở tầng app** — thay cho `pgvector`.
//     Script này chỉ lo phần tính vector, không lo phần so khớp.
//
// Vì sao chạy bằng Admin SDK chứ không ghi từ app:
//   `firestore.rules` chỉ cho staff ghi `products`, mà mỗi lần ghi cũng phải
//   qua client. Chạy 100 sản phẩm bằng tay thì mất 100 thao tác và tốn
//   hết hạn mức Firestore. Admin SDK bỏ qua Rules, nên script là công cụ
//   một lần chạy cho kho dữ liệu, không phải luồng của người dùng.
//
// Idempotent: chỉ ghi lên sản phẩm có `embedding` rỗng hoặc thiếu, trừ khi
// `--force`. Vì vậy chạy lại không tốn quota Gemini cho những sản phẩm đã có.
//
// Key lấy từ GEMINI_API_KEY. Key sẽ lộ trong bản build của app (không có
// tầng proxy) — xem mục 4.8 của `phase.md`. Ở đây key chỉ nằm trong script
// chạy local và đọc từ `.env` đã bị .gitignore chặn, không commit lên GitHub.

import { createRequire } from 'node:module';

const require = createRequire(new URL('../functions/package.json', import.meta.url));
const admin = require('firebase-admin');

const API_BASE = 'https://generativelanguage.googleapis.com/v1beta';
// Gemini `text-embedding-004` trả 768 chiều. Đổi model thì phải đổi cả
// hằng số này — client đọc `embedding[0]` để biết số chiều khi tính cosine.
const MODEL = 'text-embedding-004';
const DIM = 768;

// Rate limit phía Gemini: script chạy tuần tự + nghỉ giữa các lần gọi để
// không bị 429. Chậm hơn nhưng 100 sản phẩm vẫn xong trong vài phút.
const DELAY_MS = 250;

function parseArgs(argv) {
  const args = { project: null, limit: 0, force: false, dryRun: false };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    const value = argv[i + 1];
    if (flag === '--project') args.project = value;
    if (flag === '--limit') args.limit = Number(value) || 0;
    if (flag === '--force') args.force = true;
    if (flag === '--dry-run') args.dryRun = true;
  }
  return args;
}

/// Ghép văn bản để nhúng. Chỉ lấy tên + mô tả + thông số: giá và tồn kho
/// thay đổi liên tục nên không nhúng vào — chatbot đọc chúng ở thời điểm
/// trả lời, nhúng sẽ thành thông tin sai.
async function buildText(ref, product) {
  const parts = [product.name ?? '', product.description ?? ''];
  const specs = await ref.collection('specs').get();
  if (!specs.empty) {
    const lines = specs.docs
      .map((d) => `${d.id}: ${d.data()?.value ?? ''}`)
      .filter((s) => s.split(': ')[1]);
    if (lines.length) parts.push(lines.join('\n'));
  }
  return parts.join('\n').replace(/\s+/g, ' ').trim();
}

async function embed(apiKey, text) {
  const res = await fetch(`${API_BASE}/models/${MODEL}:embedContent`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-goog-api-key': apiKey },
    body: JSON.stringify({
      model: `models/${MODEL}`,
      content: { parts: [{ text }] },
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`${res.status} ${res.statusText}: ${body.slice(0, 300)}`);
  }
  const json = await res.json();
  const vector = json?.embedding?.values;
  if (!Array.isArray(vector)) {
    throw new Error('API không trả về embedding.values — kiểm tra lại model/key.');
  }
  if (vector.length !== DIM) {
    // Ghi vector sai số chiều thì cosine tính ra sai và RAG trả kết quả bậy.
    // Chặn ở đây thành lỗi rõ ràng thay vì âm thầm ghi xuống Firestore.
    throw new Error(
      `Số chiều ${vector.length} ≠ ${DIM} của ${MODEL}. Mọi sản phẩm đã sinh ` +
        'trước đó cũng phải sinh lại — dừng lại để không ghi dữ liệu hỏng.',
    );
  }
  return vector;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.error('Thiếu GEMINI_API_KEY. Chạy: node --env-file=.env scripts/gen_embeddings.mjs');
    process.exit(1);
  }
  const projectId = args.project ?? process.env.GCLOUD_PROJECT;
  if (!projectId) {
    console.error('Thiếu --project (ví dụ: --project hddshop-bea07).');
    process.exit(1);
  }

  const app = admin.apps.length
    ? admin.app()
    : admin.initializeApp({ credential: admin.credential.applicationDefault() });
  const db = admin.firestore(app);
  await db.settings({ ignoreUndefinedProperties: true });

  let query = db.collection('products').where('deleted_at', '==', null);
  if (!args.force) {
    // Chỉ lấy sản phẩm chưa có embedding. Firestore không so sánh "mảng
    // rỗng" được bằng query, nên lấy hết rồi lọc trong JS — 100 doc thì
    // không đáng để đánh đổi độ phức tạp của query.
    query = query.orderBy('sku');
  }
  let snap = await query.get();
  let docs = snap.docs;
  if (args.limit > 0) docs = docs.slice(0, args.limit);

  const targets = args.force
    ? docs
    : docs.filter((d) => {
        const e = d.data()?.embedding;
        return !Array.isArray(e) || e.length === 0;
      });

  console.log(
    `${targets.length}/${docs.length} sản phẩm cần sinh embedding` +
      (args.force ? ' (--force: ghi lại tất cả)' : ''),
  );
  if (targets.length === 0) {
    console.log('Không có gì để làm.');
    return;
  }

  let ok = 0;
  const failed = [];
  for (const [index, doc] of targets.entries()) {
    const text = await buildText(doc.ref, doc.data());
    if (!text) {
      failed.push([doc.id, 'tên và mô tả đều rỗng']);
      continue;
    }
    try {
      const vector = await embed(apiKey, text);
      if (args.dryRun) {
        console.log(`[${index + 1}/${targets.length}] ${doc.id} — ${DIM} chiều (dry-run)`);
      } else {
        await doc.ref.update({ embedding: vector });
        console.log(`[${index + 1}/${targets.length}] ${doc.id} ✓ ${DIM} chiều`);
      }
      ok += 1;
    } catch (error) {
      failed.push([doc.id, error.message]);
      console.error(`[${index + 1}/${targets.length}] ${doc.id} ✗ ${error.message}`);
      // Hết quota hoặc 429 thì dừng luôn: chạy tiếp chỉ nhận thêm lỗi và
      // tốn thêm request.
      if (/\b429\b|quota|RESOURCE_EXHAUSTED/i.test(error.message)) {
        console.error('Chạm hạn mức — dừng. Chạy lại sau để tiếp tục phần còn lại.');
        break;
      }
    }
    await sleep(DELAY_MS);
  }

  console.log(`\nXong ${ok}/${targets.length}.`);
  if (args.dryRun) console.log('(--dry-run: không có gì được ghi lên Firestore)');
  if (failed.length) {
    console.log(`Bỏ qua ${failed.length} sản phẩm:`);
    for (const [id, why] of failed) console.log(`  - ${id}: ${why}`);
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
