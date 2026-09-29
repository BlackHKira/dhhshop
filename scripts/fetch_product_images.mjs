// Tải ảnh sản phẩm về catalog_raw/<slug>.jpg từ image_urls.json.
//
//   node scripts/fetch_product_images.mjs [--urls <path>] [--out <dir>] [--force]
//
// image_urls.json: { "<slug>": "https://cdn.tgdd.vn/.../xxx.jpg", ... }
// (file này do bước tìm URL bằng websearch/webfetch tạo ra).
//
// - Bỏ qua slug đã có file (trừ --force).
// - User-Agent giả Chrome, timeout 20s, retry 3 lần.
// - Chỉ nhận content-type ảnh (jpeg/png/webp).

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { NEW_PRODUCTS } from './catalog_data.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');

const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36';

function parseArgs(argv) {
  const args = {
    urls: path.join(ROOT, '..', 'temp_urls.json'),
    out: path.join(ROOT, '..', 'catalog_raw'),
    force: false,
  };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--urls') args.urls = argv[i + 1];
    if (argv[i] === '--out') args.out = argv[i + 1];
    if (argv[i] === '--force') args.force = true;
  }
  return args;
}

async function download(url, dest) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 20000);
  try {
    const res = await fetch(url, {
      headers: { 'User-Agent': UA, 'Accept': 'image/*,*/*' },
      signal: ctrl.signal,
      redirect: 'follow',
    });
    if (!res.ok) return `HTTP ${res.status}`;
    const ct = res.headers.get('content-type') || '';
    if (!ct.startsWith('image/')) return `not image (${ct})`;
    const buf = Buffer.from(await res.arrayBuffer());
    if (buf.length < 2000) return `too small (${buf.length}b)`;
    fs.writeFileSync(dest, buf);
    return null;
  } catch (e) {
    return e.message;
  } finally {
    clearTimeout(timer);
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  fs.mkdirSync(args.out, { recursive: true });

  let urlMap = {};
  if (fs.existsSync(args.urls)) {
    urlMap = JSON.parse(fs.readFileSync(args.urls, 'utf8'));
  } else {
    console.log(`Không thấy ${args.urls} → không có URL để tải.`);
  }

  let ok = 0;
  let skip = 0;
  let fail = 0;
  const failures = [];

  for (const p of NEW_PRODUCTS) {
    const url = urlMap[p.slug];
    const dest = path.join(args.out, `${p.slug}.jpg`);
    if (!url) {
      fail += 1;
      failures.push(`${p.slug}: no url`);
      continue;
    }
    if (fs.existsSync(dest) && !args.force) {
      skip += 1;
      continue;
    }
    let err = null;
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      err = await download(url, dest);
      if (!err) break;
      if (attempt < 3) await new Promise((r) => setTimeout(r, 1000));
    }
    if (err) {
      fail += 1;
      failures.push(`${p.slug}: ${err}`);
      try { if (fs.existsSync(dest)) fs.unlinkSync(dest); } catch {}
    } else {
      ok += 1;
      const size = fs.statSync(dest).size;
      console.log(`OK ${p.slug} (${size}b)`);
    }
  }

  console.log(`\nTải xong: ok=${ok} skip=${skip} fail=${fail}`);
  if (failures.length) {
    console.log('FAIL:');
    for (const f of failures) console.log('  ' + f);
  }
}

main().catch((e) => {
  console.error('Lỗi:', e.stack || e.message);
  process.exit(1);
});
